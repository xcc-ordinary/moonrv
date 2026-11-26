///|
#derive(Debug, Eq)
pub(all) enum StepResult64 {
  Ok
  Halted
  Unsupported(Int)
}

///|
// RV64 hardware thread: 64-bit register file / pc / CSRs. Guest memory stays
// base-relative and Int-addressed (milestone images live below 2^32); register
// values and arithmetic are full Int64. Isolated from the RV32 `exec` hart so
// the verified RV32 path cannot regress.
pub struct Hart64 {
  regs : Array[Int64]
  mem : @memory.Memory
  csrs : Array[Int64]
  mut pc : Int64
  tohost : Int64
  mut halted : Bool
  mut pass : Bool
  mut fail_code : Int64
  mut exit_code : Int64
  mut bad_word : Int
  mut steps : Int
  mut reservation : Int64 // LR/SC reservation address (-1 = none)
  stdout : Array[Int]
}

///|
pub fn Hart64::new_at(mem : @memory.Memory, entry : Int, tohost : Int) -> Hart64 {
  {
    regs: Array::make(32, 0L),
    mem,
    csrs: Array::make(4096, 0L),
    pc: entry.to_int64(),
    tohost: tohost.to_int64(),
    halted: false,
    pass: false,
    fail_code: 0L,
    exit_code: 0L,
    bad_word: 0,
    steps: 0,
    reservation: -1L,
    stdout: [],
  }
}

///|
fn Hart64::get(self : Hart64, i : Int) -> Int64 {
  if i == 0 {
    0L
  } else {
    self.regs[i]
  }
}

///|
fn Hart64::set(self : Hart64, i : Int, v : Int64) -> Unit {
  if i != 0 {
    self.regs[i] = v
  }
}

///|
fn sext32(x : Int64) -> Int64 {
  (x << 32) >> 32
}

///|
fn ult64(a : Int64, b : Int64) -> Bool {
  let min64 = -9223372036854775807L - 1L
  (a ^ min64) < (b ^ min64)
}

///|
fn srl64(a : Int64, n : Int) -> Int64 {
  if n == 0 {
    a
  } else {
    (a >> n) & ((1L << (64 - n)) - 1L)
  }
}

///|
// Unsigned 64-bit high half of a*b via 16-bit limbs (no Int128 needed).
fn mulhu64(a : Int64, b : Int64) -> Int64 {
  let al = [a & 0xFFFFL, (a >> 16) & 0xFFFFL, (a >> 32) & 0xFFFFL, (a >> 48) & 0xFFFFL]
  let bl = [b & 0xFFFFL, (b >> 16) & 0xFFFFL, (b >> 32) & 0xFFFFL, (b >> 48) & 0xFFFFL]
  let prod = Array::make(8, 0L)
  for i = 0; i < 4; i = i + 1 {
    let mut carry = 0L
    for j = 0; j < 4; j = j + 1 {
      let cur = prod[i + j] + al[i] * bl[j] + carry
      prod[i + j] = cur & 0xFFFFL
      carry = cur >> 16
    }
    prod[i + 4] = carry
  }
  prod[4] | (prod[5] << 16) | (prod[6] << 32) | (prod[7] << 48)
}

///|
fn mulh64(a : Int64, b : Int64) -> Int64 {
  let mut h = mulhu64(a, b)
  if a < 0L {
    h = h - b
  }
  if b < 0L {
    h = h - a
  }
  h
}

///|
fn mulhsu64(a : Int64, b : Int64) -> Int64 {
  let mut h = mulhu64(a, b)
  if a < 0L {
    h = h - b
  }
  h
}

///|
// Unsigned 64-bit division by binary long division (correct for all operands).
fn udivrem64(a : Int64, b : Int64) -> (Int64, Int64) {
  if b == 0L {
    return (-1L, a)
  }
  let mut q = 0L
  let mut r = 0L
  for i = 63; i >= 0; i = i - 1 {
    r = (r << 1) | ((a >> i) & 1L)
    if !ult64(r, b) {
      r = r - b
      q = q | (1L << i)
    }
  }
  (q, r)
}

///|
fn Hart64::ecall(self : Hart64) -> StepResult64 {
  let num = self.get(17)
  let a0 = self.get(10)
  let next = self.pc + 4L
  match num.to_int() {
    93 => {
      self.exit_code = a0
      self.pass = a0 == 0L
      if a0 != 0L {
        self.fail_code = a0
      }
      self.halted = true
      StepResult64::Halted
    }
    64 => {
      let buf = self.get(11).to_int()
      let len = self.get(12).to_int()
      for i = 0; i < len; i = i + 1 {
        self.stdout.push(self.mem.read_u8(buf + i))
      }
      self.set(10, len.to_int64())
      self.pc = next
      StepResult64::Ok
    }
    _ => {
      self.set(10, -1L)
      self.pc = next
      StepResult64::Ok
    }
  }
}

///|
pub fn Hart64::step(self : Hart64) -> StepResult64 {
  let pci = self.pc.to_int()
  let hw = self.mem.read_u16(pci)
  let mut ilen = 4
  let mut instr = @isa.decode(self.mem.read_u32(pci))
  if (hw & 3) != 3 {
    ilen = 2
    instr = @isa.decode_compressed(hw)
  }
  let ilen64 = ilen.to_int64()
  match instr {
    @isa.Instr::Lui(rd, imm) => {
      self.set(rd, sext32(imm.to_int64()))
      self.pc = self.pc + ilen64
      StepResult64::Ok
    }
    @isa.Instr::Auipc(rd, imm) => {
      self.set(rd, self.pc + sext32(imm.to_int64()))
      self.pc = self.pc + ilen64
      StepResult64::Ok
    }
    @isa.Instr::Jal(rd, imm) => {
      self.set(rd, self.pc + ilen64)
      self.pc = self.pc + imm.to_int64()
      StepResult64::Ok
    }
    @isa.Instr::Jalr(rd, rs1, imm) => {
      let target = (self.get(rs1) + imm.to_int64()) & (-2L)
      self.set(rd, self.pc + ilen64)
      self.pc = target
      StepResult64::Ok
    }
    @isa.Instr::Branch(f3, rs1, rs2, imm) => {
      let a = self.get(rs1)
      let b = self.get(rs2)
      let taken = match f3 {
        0 => a == b
        1 => a != b
        4 => a < b
        5 => a >= b
        6 => ult64(a, b)
        7 => !ult64(a, b)
        _ => false
      }
      if taken {
        self.pc = self.pc + imm.to_int64()
      } else {
        self.pc = self.pc + ilen64
      }
      StepResult64::Ok
    }
    @isa.Instr::Load(f3, rd, rs1, imm) => {
      let addr = (self.get(rs1) + imm.to_int64()).to_int()
      let value = match f3 {
        0 => @isa.sign_extend(self.mem.read_u8(addr), 8).to_int64()
        1 => @isa.sign_extend(self.mem.read_u16(addr), 16).to_int64()
        2 => self.mem.read_u32(addr).to_int64()
        3 => self.mem.read_u64(addr)
        4 => self.mem.read_u8(addr).to_int64()
        5 => self.mem.read_u16(addr).to_int64()
        6 => self.mem.read_u32(addr).to_int64() & 0xFFFFFFFFL
        _ => 0L
      }
      self.set(rd, value)
      self.pc = self.pc + ilen64
      StepResult64::Ok
    }
    @isa.Instr::Store(f3, rs1, rs2, imm) => {
      let addr64 = self.get(rs1) + imm.to_int64()
      let addr = addr64.to_int()
      let value = self.get(rs2)
      match f3 {
        0 => self.mem.write_u8(addr, value.to_int())
        1 => self.mem.write_u16(addr, value.to_int())
        2 => self.mem.write_u32(addr, value.to_int())
        3 => self.mem.write_u64(addr, value)
        _ => ()
      }
      self.pc = self.pc + ilen64
      if addr64 == self.reservation {
        self.reservation = -1L
      }
      if self.tohost >= 0L && addr64 == self.tohost {
        self.pass = value == 1L
        if value != 1L {
          self.fail_code = value
        }
        self.halted = true
        StepResult64::Halted
      } else {
        StepResult64::Ok
      }
    }
    @isa.Instr::OpImm(f3, rd, rs1, imm, f7) => {
      let a = self.get(rs1)
      let imm64 = imm.to_int64()
      let value = match f3 {
        0 => a + imm64
        2 => if a < imm64 {
          1L
        } else {
          0L
        }
        3 => if ult64(a, imm64) {
          1L
        } else {
          0L
        }
        4 => a ^ imm64
        6 => a | imm64
        7 => a & imm64
        1 => a << (imm & 63)
        5 =>
          if (f7 & 0x20) != 0 {
            a >> (imm & 63)
          } else {
            srl64(a, imm & 63)
          }
        _ => 0L
      }
      self.set(rd, value)
      self.pc = self.pc + ilen64
      StepResult64::Ok
    }
    @isa.Instr::Op(f3, rd, rs1, rs2, f7) => {
      let a = self.get(rs1)
      let b = self.get(rs2)
      let value = if f7 == 1 {
        let min64 = -9223372036854775807L - 1L
        match f3 {
          0 => a * b
          1 => mulh64(a, b)
          2 => mulhsu64(a, b)
          3 => mulhu64(a, b)
          4 =>
            if b == 0L {
              -1L
            } else if a == min64 && b == -1L {
              min64
            } else {
              a / b
            }
          5 => udivrem64(a, b).0
          6 =>
            if b == 0L {
              a
            } else if a == min64 && b == -1L {
              0L
            } else {
              a % b
            }
          7 => udivrem64(a, b).1
          _ => 0L
        }
      } else {
        match f3 {
          0 => if f7 == 0x20 {
            a - b
          } else {
            a + b
          }
          1 => a << (b.to_int() & 63)
          2 => if a < b {
            1L
          } else {
            0L
          }
          3 => if ult64(a, b) {
            1L
          } else {
            0L
          }
          4 => a ^ b
          5 => if (f7 & 0x20) != 0 {
            a >> (b.to_int() & 63)
          } else {
            srl64(a, b.to_int() & 63)
          }
          6 => a | b
          7 => a & b
          _ => 0L
        }
      }
      self.set(rd, value)
      self.pc = self.pc + ilen64
      StepResult64::Ok
    }
    @isa.Instr::OpImm32(f3, rd, rs1, imm, f7) => {
      let a = sext32(self.get(rs1))
      let value = match f3 {
        0 => sext32(a + imm.to_int64()) // ADDIW
        1 => sext32(a << (imm & 31)) // SLLIW
        5 =>
          if (f7 & 0x20) != 0 {
            sext32(a >> (imm & 31)) // SRAIW
          } else {
            sext32(srl64(self.get(rs1) & 0xFFFFFFFFL, imm & 31)) // SRLIW
          }
        _ => 0L
      }
      self.set(rd, value)
      self.pc = self.pc + ilen64
      StepResult64::Ok
    }
    @isa.Instr::Op32(f3, rd, rs1, rs2, f7) => {
      let a = sext32(self.get(rs1))
      let b = sext32(self.get(rs2))
      let sh = b.to_int() & 31
      let value = if f7 == 1 {
        // M-W: MULW / DIVW / DIVUW / REMW / REMUW (32-bit semantics).
        let a32 = a.to_int()
        let b32 = b.to_int()
        let min32 = -2147483647 - 1
        match f3 {
          0 => (a32 * b32).to_int64()
          4 =>
            if b32 == 0 {
              -1L
            } else if a32 == min32 && b32 == -1 {
              min32.to_int64()
            } else {
              (a32 / b32).to_int64()
            }
          5 => {
            let ua = a32.to_int64() & 0xFFFFFFFFL
            let ub = b32.to_int64() & 0xFFFFFFFFL
            if ub == 0L {
              -1L
            } else {
              sext32(ua / ub)
            }
          }
          6 =>
            if b32 == 0 {
              a
            } else if a32 == min32 && b32 == -1 {
              0L
            } else {
              (a32 % b32).to_int64()
            }
          7 => {
            let ua = a32.to_int64() & 0xFFFFFFFFL
            let ub = b32.to_int64() & 0xFFFFFFFFL
            if ub == 0L {
              a
            } else {
              sext32(ua % ub)
            }
          }
          _ => 0L
        }
      } else {
        match f3 {
          0 => if f7 == 0x20 {
            sext32(a - b) // SUBW
          } else {
            sext32(a + b) // ADDW
          }
          1 => sext32(a << sh) // SLLW
          5 => if f7 == 0x20 {
            sext32(a >> sh) // SRAW
          } else {
            sext32(srl64(self.get(rs1) & 0xFFFFFFFFL, sh)) // SRLW
          }
          _ => 0L
        }
      }
      self.set(rd, value)
      self.pc = self.pc + ilen64
      StepResult64::Ok
    }
    @isa.Instr::Atomic(f5, f3, rd, rs1, rs2) => {
      // A extension: W (32-bit, sign-extended) and D (64-bit) widths.
      let addr64 = self.get(rs1)
      let addr = addr64.to_int()
      let b = self.get(rs2)
      if f3 == 2 {
        let old = self.mem.read_u32(addr)
        let b32 = b.to_int()
        if f5 == 0x02 {
          self.set(rd, sext32(old.to_int64()))
          self.reservation = addr64
        } else if f5 == 0x03 {
          if self.reservation == addr64 {
            self.mem.write_u32(addr, b32)
            self.set(rd, 0L)
            self.reservation = -1L
          } else {
            self.set(rd, 1L)
          }
        } else {
          let new = match f5 {
            0x01 => b32
            0x00 => old + b32
            0x04 => old ^ b32
            0x0C => old & b32
            0x08 => old | b32
            0x10 => if old < b32 { old } else { b32 }
            0x14 => if old > b32 { old } else { b32 }
            0x18 => if ult64(old.to_int64() & 0xFFFFFFFFL, b & 0xFFFFFFFFL) { old } else { b32 }
            0x1C => if ult64(old.to_int64() & 0xFFFFFFFFL, b & 0xFFFFFFFFL) { b32 } else { old }
            _ => old
          }
          self.mem.write_u32(addr, new)
          self.set(rd, sext32(old.to_int64()))
        }
      } else if f3 == 3 {
        let old = self.mem.read_u64(addr)
        if f5 == 0x02 {
          self.set(rd, old)
          self.reservation = addr64
        } else if f5 == 0x03 {
          if self.reservation == addr64 {
            self.mem.write_u64(addr, b)
            self.set(rd, 0L)
            self.reservation = -1L
          } else {
            self.set(rd, 1L)
          }
        } else {
          let new = match f5 {
            0x01 => b
            0x00 => old + b
            0x04 => old ^ b
            0x0C => old & b
            0x08 => old | b
            0x10 => if old < b { old } else { b }
            0x14 => if old > b { old } else { b }
            0x18 => if ult64(old, b) { old } else { b }
            0x1C => if ult64(old, b) { b } else { old }
            _ => old
          }
          self.mem.write_u64(addr, new)
          self.set(rd, old)
        }
      }
      self.pc = self.pc + ilen64
      StepResult64::Ok
    }
    @isa.Instr::Csr(f3, rd, csr, rs1) => {
      let old = if csr == 0xF14 {
        0L
      } else {
        self.csrs[csr]
      }
      let mut src = self.get(rs1)
      if f3 >= 5 {
        src = rs1.to_int64()
      }
      let mut w = old
      let mut do_write = true
      match f3 {
        1 => w = src
        2 =>
          if rs1 != 0 {
            w = old | src
          } else {
            do_write = false
          }
        3 =>
          if rs1 != 0 {
            w = old & (src ^ (-1L))
          } else {
            do_write = false
          }
        5 => w = src
        6 =>
          if rs1 != 0 {
            w = old | src
          } else {
            do_write = false
          }
        7 =>
          if rs1 != 0 {
            w = old & (src ^ (-1L))
          } else {
            do_write = false
          }
        _ => do_write = false
      }
      if do_write && csr != 0xF14 {
        self.csrs[csr] = w
      }
      self.set(rd, old)
      self.pc = self.pc + ilen64
      StepResult64::Ok
    }
    @isa.Instr::Ecall => self.ecall()
    @isa.Instr::Ebreak => {
      self.halted = true
      StepResult64::Halted
    }
    @isa.Instr::Mret => {
      self.pc = self.csrs[0x341]
      StepResult64::Ok
    }
    @isa.Instr::Fence => {
      self.pc = self.pc + ilen64
      StepResult64::Ok
    }
    @isa.Instr::Unsupported(w) => StepResult64::Unsupported(w)
  }
}

///|
pub fn Hart64::run(self : Hart64, max_steps : Int) -> Bool {
  while !self.halted && self.steps < max_steps {
    match self.step() {
      StepResult64::Ok => self.steps = self.steps + 1
      StepResult64::Halted => self.steps = self.steps + 1
      StepResult64::Unsupported(w) => {
        self.bad_word = w
        self.pass = false
        self.halted = true
      }
    }
  }
  self.pass
}

///|
pub fn Hart64::stdout_string(self : Hart64) -> String {
  let sb = StringBuilder()
  for b in self.stdout {
    sb.write_char(Int::unsafe_to_char(b))
  }
  sb.to_string()
}