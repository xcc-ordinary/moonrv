///|
// RISC-V instruction vocabulary. Week-1 covers the full RV32I base integer ISA
// plus the Zicsr instructions and MRET needed to run the official riscv-tests
// `p` environment, and FENCE/FENCE.I (treated as barriers / no-ops). Variants
// carry decoded fields, not raw bits. M / C / RV64 widening arrive in week 2+.
#derive(Debug, Eq)
pub(all) enum Instr {
  Lui(Int, Int) // rd, imm_u (already in place)
  Auipc(Int, Int) // rd, imm_u
  Jal(Int, Int) // rd, imm_j
  Jalr(Int, Int, Int) // rd, rs1, imm_i
  Branch(Int, Int, Int, Int) // funct3, rs1, rs2, imm_b
  Load(Int, Int, Int, Int) // funct3, rd, rs1, imm_i
  Store(Int, Int, Int, Int) // funct3, rs1, rs2, imm_s
  OpImm(Int, Int, Int, Int, Int) // funct3, rd, rs1, imm_i (or shamt), funct7
  Op(Int, Int, Int, Int, Int) // funct3, rd, rs1, rs2, funct7
  OpImm32(Int, Int, Int, Int, Int) // RV64 *W: funct3, rd, rs1, imm/shamt, funct7
  Op32(Int, Int, Int, Int, Int) // RV64 *W: funct3, rd, rs1, rs2, funct7
  Csr(Int, Int, Int, Int) // funct3, rd, csr, rs1 (or zimm)
  Ecall
  Ebreak
  Mret
  Fence
  Unsupported(Int) // raw word, for diagnostics
}

///|
// Sign-extend the low `bits` bits of `value` to a full 32-bit Int.
pub fn sign_extend(value : Int, bits : Int) -> Int {
  let shift = 32 - bits
  (value << shift) >> shift
}

///|
fn imm_i(word : Int) -> Int {
  word >> 20
}

///|
fn imm_s(word : Int) -> Int {
  let raw = (((word >> 25) & 0x7F) << 5) | ((word >> 7) & 0x1F)
  sign_extend(raw, 12)
}

///|
fn imm_b(word : Int) -> Int {
  let b12 = (word >> 31) & 1
  let b11 = (word >> 7) & 1
  let b10_5 = (word >> 25) & 0x3F
  let b4_1 = (word >> 8) & 0xF
  let raw = (b12 << 12) | (b11 << 11) | (b10_5 << 5) | (b4_1 << 1)
  sign_extend(raw, 13)
}

///|
fn imm_j(word : Int) -> Int {
  let b20 = (word >> 31) & 1
  let b10_1 = (word >> 21) & 0x3FF
  let b11 = (word >> 20) & 1
  let b19_12 = (word >> 12) & 0xFF
  let raw = (b20 << 20) | (b19_12 << 12) | (b11 << 11) | (b10_1 << 1)
  sign_extend(raw, 21)
}

///|
// Decode one 32-bit RV32 instruction word (full RV32I + Zicsr + MRET + FENCE).
pub fn decode(word : Int) -> Instr {
  let opcode = word & 0x7F
  let rd = (word >> 7) & 0x1F
  let funct3 = (word >> 12) & 0x7
  let rs1 = (word >> 15) & 0x1F
  let rs2 = (word >> 20) & 0x1F
  let funct7 = (word >> 25) & 0x7F
  match opcode {
    0x37 => Instr::Lui(rd, word & (-4096))
    0x17 => Instr::Auipc(rd, word & (-4096))
    0x6F => Instr::Jal(rd, imm_j(word))
    0x67 => Instr::Jalr(rd, rs1, imm_i(word))
    0x63 => Instr::Branch(funct3, rs1, rs2, imm_b(word))
    0x03 => Instr::Load(funct3, rd, rs1, imm_i(word))
    0x23 => Instr::Store(funct3, rs1, rs2, imm_s(word))
    0x13 =>
      if funct3 == 1 || funct3 == 5 {
        // SLLI / SRLI / SRAI: imm field is the shift amount (6 bits for RV64;
        // bit 5 is always 0 in valid RV32), funct7 selects SRA.
        Instr::OpImm(funct3, rd, rs1, (word >> 20) & 0x3F, funct7)
      } else {
        Instr::OpImm(funct3, rd, rs1, imm_i(word), 0)
      }
    0x33 => Instr::Op(funct3, rd, rs1, rs2, funct7)
    0x1B =>
      if funct3 == 1 || funct3 == 5 {
        Instr::OpImm32(funct3, rd, rs1, (word >> 20) & 0x1F, funct7)
      } else {
        Instr::OpImm32(funct3, rd, rs1, imm_i(word), 0)
      }
    0x3B => Instr::Op32(funct3, rd, rs1, rs2, funct7)
    0x73 =>
      if word == 0x00000073 {
        Instr::Ecall
      } else if word == 0x00100073 {
        Instr::Ebreak
      } else if word == 0x30200073 {
        Instr::Mret
      } else if funct3 != 0 {
        Instr::Csr(funct3, rd, (word >> 20) & 0xFFF, rs1)
      } else {
        Instr::Unsupported(word)
      }
    0x0F => Instr::Fence
    _ => Instr::Unsupported(word)
  }
}