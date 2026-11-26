///|
test "walking skeleton: addi + add + ecall" {
  let mem = @memory.Memory::new(64)
  mem.write_u32(0, 0x00500093) // addi x1, x0, 5
  mem.write_u32(4, 0x00108133) // add  x2, x1, x1
  mem.write_u32(8, 0x00000073) // ecall
  let hart = @exec.Hart::new(mem)
  assert_eq(hart.step(), @exec.StepResult::Ok)
  assert_eq(hart.regs.get(1), 5)
  assert_eq(hart.step(), @exec.StepResult::Ok)
  assert_eq(hart.regs.get(2), 10)
  assert_eq(hart.step(), @exec.StepResult::Ecall)
  assert_eq(hart.pc, 8)
}