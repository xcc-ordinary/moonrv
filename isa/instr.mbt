///|
// Instruction vocabulary. Walking skeleton covers a small correct RV32I subset;
// the full RV32IMC / RV64IMC vocabulary is filled in during week 1+ (see
// docs/week1-rv32ui-checklist.md). Variants carry decoded fields, not raw bits.
#derive(Debug, Eq)
pub(all) enum Instr {
  Lui(Int, Int) // rd, imm_u (already shifted into place)
  Auipc(Int, Int) // rd, imm_u
  Addi(Int, Int, Int) // rd, rs1, imm_i (sign-extended)
  Add(Int, Int, Int) // rd, rs1, rs2
  Sub(Int, Int, Int) // rd, rs1, rs2
  Ecall
  Ebreak
  Unsupported(Int) // raw word, for diagnostics
}

///|
// Sign-extend the low `bits` bits of `value` to a full 32-bit Int.
pub fn sign_extend(value : Int, bits : Int) -> Int {
  let shift = 32 - bits
  (value << shift) >> shift
}

///|
// Decode one 32-bit RV32 instruction word. Skeleton handles LUI/AUIPC/ADDI/
// ADD/SUB/ECALL/EBREAK correctly; everything else returns Unsupported(word).
// Compressed (C) instructions are expanded to 32-bit before reaching here (TODO).
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
    0x13 =>
      match funct3 {
        0x0 => Instr::Addi(rd, rs1, word >> 20)
        _ => Instr::Unsupported(word)
      }
    0x33 =>
      match (funct3, funct7) {
        (0x0, 0x00) => Instr::Add(rd, rs1, rs2)
        (0x0, 0x20) => Instr::Sub(rd, rs1, rs2)
        _ => Instr::Unsupported(word)
      }
    0x73 =>
      if word == 0x00000073 {
        Instr::Ecall
      } else if word == 0x00100073 {
        Instr::Ebreak
      } else {
        Instr::Unsupported(word)
      }
    _ => Instr::Unsupported(word)
  }
}