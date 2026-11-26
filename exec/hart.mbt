///|
#derive(Debug, Eq)
pub(all) enum StepResult {
  Ok
  Ecall
  Ebreak
  Unsupported(Int)
}

///|
// One hardware thread: register file + guest memory + program counter.
// CSR file, trap handling and the full execute loop are week-1/2 work.
pub struct Hart {
  regs : @machine.RegFile
  mem : @memory.Memory
  mut pc : Int
}

///|
pub fn Hart::new(mem : @memory.Memory) -> Hart {
  { regs: @machine.RegFile::new(), mem: mem, pc: 0 }
}

///|
// Execute one instruction at pc. Walking skeleton implements LUI/AUIPC/ADDI/
// ADD/SUB and reports ECALL/EBREAK; all other encodings are Unsupported.
// TODO(week1): full RV32I, branches/jumps/loads/stores, then M and C.
pub fn Hart::step(self : Hart) -> StepResult {
  let word = self.mem.read_u32(self.pc)
  match @isa.decode(word) {
    @isa.Instr::Lui(rd, imm) => {
      self.regs.set(rd, imm)
      self.pc = self.pc + 4
      StepResult::Ok
    }
    @isa.Instr::Auipc(rd, imm) => {
      self.regs.set(rd, self.pc + imm)
      self.pc = self.pc + 4
      StepResult::Ok
    }
    @isa.Instr::Addi(rd, rs1, imm) => {
      self.regs.set(rd, self.regs.get(rs1) + imm)
      self.pc = self.pc + 4
      StepResult::Ok
    }
    @isa.Instr::Add(rd, rs1, rs2) => {
      self.regs.set(rd, self.regs.get(rs1) + self.regs.get(rs2))
      self.pc = self.pc + 4
      StepResult::Ok
    }
    @isa.Instr::Sub(rd, rs1, rs2) => {
      self.regs.set(rd, self.regs.get(rs1) - self.regs.get(rs2))
      self.pc = self.pc + 4
      StepResult::Ok
    }
    @isa.Instr::Ecall => StepResult::Ecall
    @isa.Instr::Ebreak => StepResult::Ebreak
    @isa.Instr::Unsupported(w) => StepResult::Unsupported(w)
  }
}