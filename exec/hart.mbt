///|
#derive(Debug, Eq)
pub(all) enum StepResult {
  Ok
  Halted
  Unsupported(Int)
}

///|
// One hardware thread: register file + guest memory + CSR file + program
// counter, plus the user-mode run state (halt/pass/exit code and captured
// stdout). `tohost` is the riscv-tests pass/fail mailbox address (-1 when the
// loaded ELF has no such symbol, e.g. a freestanding hello-world).
pub struct Hart {
  regs : @machine.RegFile
  mem : @memory.Memory
  csrs : @machine.CsrFile
  mut pc : Int
  tohost : Int
  mut halted : Bool
  mut pass : Bool
  mut fail_code : Int
  mut exit_code : Int
  mut bad_word : Int
  mut steps : Int
  mut brk : Int
  mut reservation : Int // LR/SC reservation address (-1 = none)
  stdout : Array[Int]
}

///|
pub fn Hart::new(mem : @memory.Memory) -> Hart {
  Hart::new_at(mem, 0, -1)
}

///|
pub fn Hart::new_at(mem : @memory.Memory, entry : Int, tohost : Int) -> Hart {
  {
    regs: @machine.RegFile::new(),
    mem,
    csrs: @machine.CsrFile::new(),
    pc: entry,
    tohost,
    halted: false,
    pass: false,
    fail_code: 0,
    exit_code: 0,
    bad_word: 0,
    steps: 0,
    brk: 0,
    reservation: -1,
    stdout: [],
  }
}

///|
// Unsigned less-than on 32-bit Ints: flipping the sign bit maps unsigned order
// onto signed order.
fn ult(a : Int, b : Int) -> Bool {
  let min_int = -2147483647 - 1
  (a ^ min_int) < (b ^ min_int)
}

///|
// Logical right shift of a 32-bit value by n (0..31).
fn srl32(a : Int, n : Int) -> Int {
  if n == 0 {
    a
  } else {
    (a >> n) & ((1 << (32 - n)) - 1)
  }
}

///|
// Zero-extend a 32-bit Int to a non-negative Int64 (its unsigned value).
fn to_u64(x : Int) -> Int64 {
  if x < 0 {
    x.to_int64() + 4294967296L
  } else {
    x.to_int64()
  }
}

///|
// MULH: high 32 bits of signed×signed product.
fn mulh(a : Int, b : Int) -> Int {
  ((a.to_int64() * b.to_int64()) >> 32).to_int()
}

///|
// MULHSU: high 32 bits of signed×unsigned product.
fn mulhsu(a : Int, b : Int) -> Int {
  ((a.to_int64() * to_u64(b)) >> 32).to_int()
}

///|
// MULHU: high 32 bits of unsigned×unsigned product, via 16-bit limbs so the
// intermediate sums never overflow Int64.
fn mulhu(a : Int, b : Int) -> Int {
  let al = (a & 0xFFFF).to_int64()
  let ah = ((a >> 16) & 0xFFFF).to_int64()
  let bl = (b & 0xFFFF).to_int64()
  let bh = ((b >> 16) & 0xFFFF).to_int64()
  let ll = al * bl
  let mid = ah * bl + al * bh + (ll >> 16)
  (ah * bh + (mid >> 16)).to_int()
}

///|
fn udiv(a : Int, b : Int) -> Int {
  (to_u64(a) / to_u64(b)).to_int()
}

///|
fn urem(a : Int, b : Int) -> Int {
  (to_u64(a) % to_u64(b)).to_int()
}

///|
// Linux user-mode syscalls used by the milestone programs: write(64),
// exit(93), read(63, returns EOF). Unknown numbers return -ENOSYS in a0.
fn Hart::ecall(self : Hart) -> StepResult {
  let num = self.regs.get(17)
  let a0 = self.regs.get(10)
  let next = self.pc + 4
  match num {
    93 | 94 => {
      self.exit_code = a0
      self.pass = a0 == 0
      if a0 != 0 {
        self.fail_code = a0
      }
      self.halted = true
      StepResult::Halted
    }
    64 => {
      let buf = self.regs.get(11)
      let len = self.regs.get(12)
      for i = 0; i < len; i = i + 1 {
        self.stdout.push(self.mem.read_u8(buf + i))
      }
      self.regs.set(10, len)
      self.pc = next
      StepResult::Ok
    }
    63 => {
      self.regs.set(10, 0)
      self.pc = next
      StepResult::Ok
    }
    66 => {
      // writev(fd, iov, iovcnt): gather buffers into stdout.
      let iov = self.regs.get(11)
      let cnt = self.regs.get(12)
      let mut total = 0
      for k = 0; k < cnt; k = k + 1 {
        let base = self.mem.read_u32(iov + k * 8)
        let len = self.mem.read_u32(iov + k * 8 + 4)
        for i = 0; i < len; i = i + 1 {
          self.stdout.push(self.mem.read_u8(base + i))
        }
        total = total + len
      }
      self.regs.set(10, total)
      self.pc = next
      StepResult::Ok
    }
    169 => {
      // gettimeofday(tv, tz): report a fixed epoch (deterministic runs).
      let tv = self.regs.get(10)
      if tv != 0 {
        self.mem.write_u32(tv, 0)
        self.mem.write_u32(tv + 4, 0)
      }
      self.regs.set(10, 0)
      self.pc = next
      StepResult::Ok
    }
    214 => {
      // brk(addr): simple program-break within the loaded window.
      let req = self.regs.get(10)
      if self.brk == 0 {
        self.brk = self.mem.base + 0x8000
      }
      if req != 0 {
        self.brk = req
      }
      self.regs.set(10, self.brk)
      self.pc = next
      StepResult::Ok
    }
    _ => {
      self.regs.set(10, -1)
      self.pc = next
      StepResult::Ok
    }
  }
}

///|
// Execute one instruction at pc. Full RV32I + Zicsr + MRET + FENCE.
pub fn Hart::step(self : Hart) -> StepResult {
  let hw = self.mem.read_u16(self.pc)
  let mut ilen = 4
  let mut instr = @isa.decode(self.mem.read_u32(self.pc))
  if (hw & 3) != 3 {
    // RVC: low two bits != 11 marks a 16-bit compressed instruction.
    ilen = 2
    instr = @isa.decode_compressed(hw)
  }
  match instr {
    @isa.Instr::Lui(rd, imm) => {
      self.regs.set(rd, imm)
      self.pc = self.pc + ilen
      StepResult::Ok
    }
    @isa.Instr::Auipc(rd, imm) => {
      self.regs.set(rd, self.pc + imm)
      self.pc = self.pc + ilen
      StepResult::Ok
    }
    @isa.Instr::Jal(rd, imm) => {
      self.regs.set(rd, self.pc + ilen)
      self.pc = self.pc + imm
      StepResult::Ok
    }
    @isa.Instr::Jalr(rd, rs1, imm) => {
      let target = (self.regs.get(rs1) + imm) & (-2)
      self.regs.set(rd, self.pc + ilen)
      self.pc = target
      StepResult::Ok
    }
    @isa.Instr::Branch(f3, rs1, rs2, imm) => {
      let a = self.regs.get(rs1)
      let b = self.regs.get(rs2)
      let taken = match f3 {
        0 => a == b
        1 => a != b
        4 => a < b
        5 => a >= b
        6 => ult(a, b)
        7 => !ult(a, b)
        _ => false
      }
      if taken {
        self.pc = self.pc + imm
      } else {
        self.pc = self.pc + ilen
      }
      StepResult::Ok
    }
    @isa.Instr::Load(f3, rd, rs1, imm) => {
      let addr = self.regs.get(rs1) + imm
      let value = match f3 {
        0 => @isa.sign_extend(self.mem.read_u8(addr), 8)
        1 => @isa.sign_extend(self.mem.read_u16(addr), 16)
        2 => self.mem.read_u32(addr)
        4 => self.mem.read_u8(addr)
        5 => self.mem.read_u16(addr)
        _ => 0
      }
      self.regs.set(rd, value)
      self.pc = self.pc + ilen
      StepResult::Ok
    }
    @isa.Instr::Store(f3, rs1, rs2, imm) => {
      let addr = self.regs.get(rs1) + imm
      let value = self.regs.get(rs2)
      match f3 {
        0 => self.mem.write_u8(addr, value)
        1 => self.mem.write_u16(addr, value)
        2 => self.mem.write_u32(addr, value)
        _ => ()
      }
      self.pc = self.pc + ilen
      if addr == self.reservation {
        self.reservation = -1
      }
      if self.tohost >= 0 && addr == self.tohost {
        self.pass = value == 1
        if value != 1 {
          self.fail_code = value
        }
        self.halted = true
        StepResult::Halted
      } else {
        StepResult::Ok
      }
    }
    @isa.Instr::OpImm(f3, rd, rs1, imm, f7) => {
      let a = self.regs.get(rs1)
      let value = match f3 {
        0 => a + imm
        2 => if a < imm {
          1
        } else {
          0
        }
        3 => if ult(a, imm) {
          1
        } else {
          0
        }
        4 => a ^ imm
        6 => a | imm
        7 => a & imm
        1 => a << (imm & 31)
        5 =>
          if f7 == 0x20 {
            a >> (imm & 31)
          } else {
            srl32(a, imm & 31)
          }
        _ => 0
      }
      self.regs.set(rd, value)
      self.pc = self.pc + ilen
      StepResult::Ok
    }
    @isa.Instr::Op(f3, rd, rs1, rs2, f7) => {
      if f7 == 1 {
        // M extension: MUL / MULH / MULHSU / MULHU / DIV / DIVU / REM / REMU.
        let a = self.regs.get(rs1)
        let b = self.regs.get(rs2)
        let min_int = -2147483647 - 1
        let value = match f3 {
          0 => a * b
          1 => mulh(a, b)
          2 => mulhsu(a, b)
          3 => mulhu(a, b)
          4 =>
            if b == 0 {
              -1
            } else if a == min_int && b == -1 {
              min_int
            } else {
              a / b
            }
          5 =>
            if b == 0 {
              -1
            } else {
              udiv(a, b)
            }
          6 =>
            if b == 0 {
              a
            } else if a == min_int && b == -1 {
              0
            } else {
              a % b
            }
          7 =>
            if b == 0 {
              a
            } else {
              urem(a, b)
            }
          _ => 0
        }
        self.regs.set(rd, value)
        self.pc = self.pc + ilen
        StepResult::Ok
      } else {
        let a = self.regs.get(rs1)
        let b = self.regs.get(rs2)
        let value = match f3 {
          0 => if f7 == 0x20 {
            a - b
          } else {
            a + b
          }
          1 => a << (b & 31)
          2 => if a < b {
            1
          } else {
            0
          }
          3 => if ult(a, b) {
            1
          } else {
            0
          }
          4 => a ^ b
          5 => if f7 == 0x20 {
            a >> (b & 31)
          } else {
            srl32(a, b & 31)
          }
          6 => a | b
          7 => a & b
          _ => 0
        }
        self.regs.set(rd, value)
        self.pc = self.pc + ilen
        StepResult::Ok
      }
    }
    @isa.Instr::Atomic(f5, f3, rd, rs1, rs2) => {
      // A extension (RV32: W width only). Single hart => LR/SC reservation is
      // tracked by address; any plain store to it invalidates the reservation.
      if f3 != 2 {
        StepResult::Unsupported(0)
      } else {
        let addr = self.regs.get(rs1)
        let b = self.regs.get(rs2)
        if f5 == 0x02 {
          // LR.W
          self.regs.set(rd, self.mem.read_u32(addr))
          self.reservation = addr
        } else if f5 == 0x03 {
          // SC.W
          if self.reservation == addr {
            self.mem.write_u32(addr, b)
            self.regs.set(rd, 0)
            self.reservation = -1
          } else {
            self.regs.set(rd, 1)
          }
        } else {
          let old = self.mem.read_u32(addr)
          let new = match f5 {
            0x01 => b // AMOSWAP
            0x00 => old + b // AMOADD
            0x04 => old ^ b // AMOXOR
            0x0C => old & b // AMOAND
            0x08 => old | b // AMOOR
            0x10 => if old < b { old } else { b } // AMOMIN
            0x14 => if old > b { old } else { b } // AMOMAX
            0x18 => if ult(old, b) { old } else { b } // AMOMINU
            0x1C => if ult(old, b) { b } else { old } // AMOMAXU
            _ => old
          }
          self.mem.write_u32(addr, new)
          self.regs.set(rd, old)
        }
        self.pc = self.pc + ilen
        StepResult::Ok
      }
    }
    @isa.Instr::Csr(f3, rd, csr, rs1) => {
      let old = self.csrs.get(csr)
      let mut src = self.regs.get(rs1)
      if f3 >= 5 {
        src = rs1
      }
      match f3 {
        1 => self.csrs.set(csr, src)
        2 =>
          if rs1 != 0 {
            self.csrs.set(csr, old | src)
          }
        3 =>
          if rs1 != 0 {
            self.csrs.set(csr, old & (src ^ (-1)))
          }
        5 => self.csrs.set(csr, src)
        6 =>
          if rs1 != 0 {
            self.csrs.set(csr, old | src)
          }
        7 =>
          if rs1 != 0 {
            self.csrs.set(csr, old & (src ^ (-1)))
          }
        _ => ()
      }
      self.regs.set(rd, old)
      self.pc = self.pc + ilen
      StepResult::Ok
    }
    @isa.Instr::Ecall => self.ecall()
    @isa.Instr::Ebreak => {
      self.halted = true
      StepResult::Halted
    }
    @isa.Instr::Mret => {
      self.pc = self.csrs.get(0x341) // mepc
      StepResult::Ok
    }
    @isa.Instr::Fence => {
      self.pc = self.pc + ilen
      StepResult::Ok
    }
    @isa.Instr::OpImm32(_, _, _, _, _) => StepResult::Unsupported(0)
    @isa.Instr::Op32(_, _, _, _, _) => StepResult::Unsupported(0)
    @isa.Instr::Unsupported(w) => StepResult::Unsupported(w)
  }
}

///|
// Run until halt (ecall exit / tohost write / ebreak), an unsupported encoding,
// or the step budget is exhausted. Returns true on a clean pass.
pub fn Hart::run(self : Hart, max_steps : Int) -> Bool {
  while !self.halted && self.steps < max_steps {
    match self.step() {
      StepResult::Ok => self.steps = self.steps + 1
      StepResult::Halted => self.steps = self.steps + 1
      StepResult::Unsupported(w) => {
        self.bad_word = w
        self.pass = false
        self.halted = true
      }
    }
  }
  self.pass
}

///|
pub fn Hart::stdout_string(self : Hart) -> String {
  let sb = StringBuilder()
  for b in self.stdout {
    sb.write_char(Int::unsafe_to_char(b))
  }
  sb.to_string()
}