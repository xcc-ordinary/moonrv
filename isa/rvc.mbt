///|
// RVC (compressed) decoder: expands a 16-bit instruction into the equivalent
// 32-bit `Instr` so the execute stage is shared. Only the integer RV32C subset
// is covered; floating-point compressed loads/stores are out of scope.
// Reference: RISC-V Unprivileged ISA, "C" Standard Extension.

///|
fn c_j_imm(hw : Int) -> Int {
  let raw = (((hw >> 12) & 1) << 11) | (((hw >> 11) & 1) << 4) |
    (((hw >> 9) & 3) << 8) | (((hw >> 8) & 1) << 10) |
    (((hw >> 7) & 1) << 6) | (((hw >> 6) & 1) << 7) |
    (((hw >> 3) & 7) << 1) | (((hw >> 2) & 1) << 5)
  sign_extend(raw, 12)
}

///|
fn c_b_imm(hw : Int) -> Int {
  let raw = (((hw >> 12) & 1) << 8) | (((hw >> 10) & 3) << 3) |
    (((hw >> 5) & 3) << 6) | (((hw >> 3) & 3) << 1) | (((hw >> 2) & 1) << 5)
  sign_extend(raw, 9)
}

///|
fn c_imm6(hw : Int) -> Int {
  sign_extend((((hw >> 12) & 1) << 5) | ((hw >> 2) & 0x1F), 6)
}

///|
fn c_shamt(hw : Int) -> Int {
  (((hw >> 12) & 1) << 5) | ((hw >> 2) & 0x1F)
}

///|
// C.LW / C.SW shared offset: uimm[5:3|2|6].
fn c_lwsw_off(hw : Int) -> Int {
  (((hw >> 10) & 7) << 3) | (((hw >> 6) & 1) << 2) | (((hw >> 5) & 1) << 6)
}

///|
pub fn decode_compressed(hw : Int) -> Instr {
  let op = hw & 3
  let f3 = (hw >> 13) & 7
  match op {
    0 =>
      match f3 {
        0 => {
          // C.ADDI4SPN: addi rd', x2, nzuimm
          let rd = 8 + ((hw >> 2) & 7)
          let imm = (((hw >> 7) & 0xF) << 6) | (((hw >> 11) & 3) << 4) |
            (((hw >> 5) & 1) << 3) | (((hw >> 6) & 1) << 2)
          if imm == 0 {
            Instr::Unsupported(hw)
          } else {
            Instr::OpImm(0, rd, 2, imm, 0)
          }
        }
        2 => {
          // C.LW
          let rs1 = 8 + ((hw >> 7) & 7)
          let rd = 8 + ((hw >> 2) & 7)
          Instr::Load(2, rd, rs1, c_lwsw_off(hw))
        }
        6 => {
          // C.SW
          let rs1 = 8 + ((hw >> 7) & 7)
          let rs2 = 8 + ((hw >> 2) & 7)
          Instr::Store(2, rs1, rs2, c_lwsw_off(hw))
        }
        _ => Instr::Unsupported(hw) // C.FLD / FLW / FSD / FSW
      }
    1 =>
      match f3 {
        0 => {
          // C.ADDI / C.NOP
          let rd = (hw >> 7) & 0x1F
          Instr::OpImm(0, rd, rd, c_imm6(hw), 0)
        }
        1 => Instr::Jal(1, c_j_imm(hw)) // C.JAL (RV32)
        2 => {
          // C.LI
          let rd = (hw >> 7) & 0x1F
          Instr::OpImm(0, rd, 0, c_imm6(hw), 0)
        }
        3 => {
          let rd = (hw >> 7) & 0x1F
          if rd == 2 {
            // C.ADDI16SP
            let imm = sign_extend(
              (((hw >> 12) & 1) << 9) | (((hw >> 3) & 3) << 7) |
              (((hw >> 5) & 1) << 6) | (((hw >> 2) & 1) << 5) |
              (((hw >> 6) & 1) << 4),
              10,
            )
            Instr::OpImm(0, 2, 2, imm, 0)
          } else {
            // C.LUI
            Instr::Lui(rd, c_imm6(hw) << 12)
          }
        }
        4 => {
          let rs1 = 8 + ((hw >> 7) & 7)
          match (hw >> 10) & 3 {
            0 => Instr::OpImm(5, rs1, rs1, c_shamt(hw), 0) // C.SRLI
            1 => Instr::OpImm(5, rs1, rs1, c_shamt(hw), 0x20) // C.SRAI
            2 => Instr::OpImm(7, rs1, rs1, c_imm6(hw), 0) // C.ANDI
            _ => {
              let rs2 = 8 + ((hw >> 2) & 7)
              if ((hw >> 12) & 1) == 0 {
                match (hw >> 5) & 3 {
                  0 => Instr::Op(0, rs1, rs1, rs2, 0x20) // C.SUB
                  1 => Instr::Op(4, rs1, rs1, rs2, 0) // C.XOR
                  2 => Instr::Op(6, rs1, rs1, rs2, 0) // C.OR
                  _ => Instr::Op(7, rs1, rs1, rs2, 0) // C.AND
                }
              } else {
                Instr::Unsupported(hw) // C.SUBW / C.ADDW (RV64)
              }
            }
          }
        }
        5 => Instr::Jal(0, c_j_imm(hw)) // C.J
        6 => Instr::Branch(0, 8 + ((hw >> 7) & 7), 0, c_b_imm(hw)) // C.BEQZ
        _ => Instr::Branch(1, 8 + ((hw >> 7) & 7), 0, c_b_imm(hw)) // C.BNEZ
      }
    2 =>
      match f3 {
        0 => {
          // C.SLLI
          let rd = (hw >> 7) & 0x1F
          Instr::OpImm(1, rd, rd, c_shamt(hw), 0)
        }
        2 => {
          // C.LWSP: lw rd, offset(x2)
          let rd = (hw >> 7) & 0x1F
          let off = (((hw >> 12) & 1) << 5) | (((hw >> 4) & 7) << 2) |
            (((hw >> 2) & 3) << 6)
          Instr::Load(2, rd, 2, off)
        }
        4 => {
          let rs1 = (hw >> 7) & 0x1F
          let rs2 = (hw >> 2) & 0x1F
          if ((hw >> 12) & 1) == 0 {
            if rs2 == 0 {
              Instr::Jalr(0, rs1, 0) // C.JR
            } else {
              Instr::Op(0, rs1, 0, rs2, 0) // C.MV
            }
          } else if rs1 == 0 && rs2 == 0 {
            Instr::Ebreak // C.EBREAK
          } else if rs2 == 0 {
            Instr::Jalr(1, rs1, 0) // C.JALR
          } else {
            Instr::Op(0, rs1, rs1, rs2, 0) // C.ADD
          }
        }
        6 => {
          // C.SWSP: sw rs2, offset(x2)
          let rs2 = (hw >> 2) & 0x1F
          let off = (((hw >> 9) & 0xF) << 2) | (((hw >> 7) & 3) << 6)
          Instr::Store(2, 2, rs2, off)
        }
        _ => Instr::Unsupported(hw) // C.FLDSP / FLWSP / FSDSP / FSWSP
      }
    _ => Instr::Unsupported(hw)
  }
}