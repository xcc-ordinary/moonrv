///|
// Minimal disassembler: format a decoded RV32/RV64 instruction as text. Used by
// the `disasm` and `trace` CLI subcommands and useful for teaching.
fn regname(i : Int) -> String {
  let names = [
    "zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2", "s0", "s1", "a0", "a1",
    "a2", "a3", "a4", "a5", "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
    "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6",
  ]
  names[i]
}

///|
pub fn to_hex(v : Int64) -> String {
  if v == 0L {
    return "0"
  }
  let digits = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e',
    'f',
  ]
  let buf = []
  let mut x = v
  while x > 0L {
    buf.push(digits[(x & 0xFL).to_int()])
    x = x >> 4
  }
  let sb = StringBuilder()
  for i = buf.length() - 1; i >= 0; i = i - 1 {
    sb.write_char(buf[i])
  }
  sb.to_string()
}

///|
fn hx(v : Int) -> String {
  to_hex(v.to_int64() & 0xFFFFFFFFL)
}

///|
pub fn disasm(word : Int, pc : Int) -> String {
  match decode(word) {
    Instr::Lui(rd, imm) => "lui \{regname(rd)}, 0x\{hx(imm >> 12)}"
    Instr::Auipc(rd, imm) => "auipc \{regname(rd)}, 0x\{hx(imm >> 12)}"
    Instr::Jal(rd, imm) => "jal \{regname(rd)}, 0x\{hx(pc + imm)}"
    Instr::Jalr(rd, rs1, imm) => "jalr \{regname(rd)}, \{imm}(\{regname(rs1)})"
    Instr::Branch(f3, rs1, rs2, imm) => {
      let mn = match f3 {
        0 => "beq"
        1 => "bne"
        4 => "blt"
        5 => "bge"
        6 => "bltu"
        _ => "bgeu"
      }
      "\{mn} \{regname(rs1)}, \{regname(rs2)}, 0x\{hx(pc + imm)}"
    }
    Instr::Load(f3, rd, rs1, imm) => {
      let mn = match f3 {
        0 => "lb"
        1 => "lh"
        2 => "lw"
        3 => "ld"
        4 => "lbu"
        5 => "lhu"
        _ => "lwu"
      }
      "\{mn} \{regname(rd)}, \{imm}(\{regname(rs1)})"
    }
    Instr::Store(f3, rs1, rs2, imm) => {
      let mn = match f3 {
        0 => "sb"
        1 => "sh"
        2 => "sw"
        _ => "sd"
      }
      "\{mn} \{regname(rs2)}, \{imm}(\{regname(rs1)})"
    }
    Instr::OpImm(f3, rd, rs1, imm, f7) => {
      match f3 {
        0 => if rd == 0 && rs1 == 0 && imm == 0 {
          "nop"
        } else {
          "addi \{regname(rd)}, \{regname(rs1)}, \{imm}"
        }
        1 => "slli \{regname(rd)}, \{regname(rs1)}, \{imm}"
        5 => if (f7 & 0x20) != 0 {
          "srai \{regname(rd)}, \{regname(rs1)}, \{imm}"
        } else {
          "srli \{regname(rd)}, \{regname(rs1)}, \{imm}"
        }
        2 => "slti \{regname(rd)}, \{regname(rs1)}, \{imm}"
        3 => "sltiu \{regname(rd)}, \{regname(rs1)}, \{imm}"
        4 => "xori \{regname(rd)}, \{regname(rs1)}, \{imm}"
        6 => "ori \{regname(rd)}, \{regname(rs1)}, \{imm}"
        _ => "andi \{regname(rd)}, \{regname(rs1)}, \{imm}"
      }
    }
    Instr::Op(f3, rd, rs1, rs2, f7) => {
      let base = match f3 {
        0 => if f7 == 0x20 {
          "sub"
        } else if f7 == 1 {
          "mul"
        } else {
          "add"
        }
        1 => if f7 == 1 {
          "mulh"
        } else {
          "sll"
        }
        2 => if f7 == 1 {
          "mulhsu"
        } else {
          "slt"
        }
        3 => if f7 == 1 {
          "mulhu"
        } else {
          "sltu"
        }
        4 => if f7 == 1 {
          "div"
        } else {
          "xor"
        }
        5 => if f7 == 1 {
          "divu"
        } else if f7 == 0x20 {
          "sra"
        } else {
          "srl"
        }
        6 => if f7 == 1 {
          "rem"
        } else {
          "or"
        }
        _ => if f7 == 1 {
          "remu"
        } else {
          "and"
        }
      }
      "\{base} \{regname(rd)}, \{regname(rs1)}, \{regname(rs2)}"
    }
    Instr::OpImm32(f3, rd, rs1, imm, f7) => {
      let mn = match f3 {
        0 => "addiw"
        1 => "slliw"
        _ => if (f7 & 0x20) != 0 {
          "sraiw"
        } else {
          "srliw"
        }
      }
      "\{mn} \{regname(rd)}, \{regname(rs1)}, \{imm}"
    }
    Instr::Op32(f3, rd, rs1, rs2, f7) => {
      let mn = match f3 {
        0 => if f7 == 0x20 {
          "subw"
        } else if f7 == 1 {
          "mulw"
        } else {
          "addw"
        }
        1 => "sllw"
        4 => if f7 == 1 {
          "divw"
        } else {
          "divuw"
        }
        5 => if f7 == 0x20 {
          "sraw"
        } else {
          "srlw"
        }
        6 => "remw"
        _ => "remuw"
      }
      "\{mn} \{regname(rd)}, \{regname(rs1)}, \{regname(rs2)}"
    }
    Instr::Atomic(f5, f3, rd, rs1, rs2) => {
      let w = if f3 == 2 { "w" } else { "d" }
      if f5 == 0x02 {
        "lr.\{w} \{regname(rd)}, (\{regname(rs1)})"
      } else if f5 == 0x03 {
        "sc.\{w} \{regname(rd)}, \{regname(rs2)}, (\{regname(rs1)})"
      } else {
        let op = match f5 {
          0x01 => "amoswap"
          0x00 => "amoadd"
          0x04 => "amoxor"
          0x0C => "amoand"
          0x08 => "amoor"
          0x10 => "amomin"
          0x14 => "amomax"
          0x18 => "amominu"
          _ => "amomaxu"
        }
        "\{op}.\{w} \{regname(rd)}, \{regname(rs2)}, (\{regname(rs1)})"
      }
    }
    Instr::Csr(f3, rd, csr, rs1) => {
      let mn = match f3 {
        1 => "csrrw"
        2 => "csrrs"
        3 => "csrrc"
        5 => "csrrwi"
        6 => "csrrsi"
        _ => "csrrci"
      }
      "\{mn} \{regname(rd)}, 0x\{to_hex(csr.to_int64())}, \{regname(rs1)}"
    }
    Instr::Ecall => "ecall"
    Instr::Ebreak => "ebreak"
    Instr::Mret => "mret"
    Instr::Fence => "fence"
    Instr::Unsupported(w) => ".word 0x\{hx(w)}"
  }
}