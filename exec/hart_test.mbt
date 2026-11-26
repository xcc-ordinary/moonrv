///|
test "addi + add execute" {
  let mem = @memory.Memory::new(64)
  mem.write_u32(0, 0x00500093) // addi x1, x0, 5
  mem.write_u32(4, 0x00108133) // add  x2, x1, x1
  let hart = @exec.Hart::new(mem)
  assert_eq(hart.step(), @exec.StepResult::Ok)
  assert_eq(hart.regs.get(1), 5)
  assert_eq(hart.step(), @exec.StepResult::Ok)
  assert_eq(hart.regs.get(2), 10)
}

///|
test "ecall exit(0) halts and passes" {
  let mem = @memory.Memory::new(64)
  mem.write_u32(0, 0x05D00893) // addi x17, x0, 93
  mem.write_u32(4, 0x00000513) // addi x10, x0, 0
  mem.write_u32(8, 0x00000073) // ecall
  let hart = @exec.Hart::new(mem)
  assert_eq(hart.run(100), true)
  assert_eq(hart.exit_code, 0)
}

///|
test "tohost write 1 passes, odd value fails" {
  let mem = @memory.Memory::new(64)
  // addi x1, x0, 1 ; sw x1, 0(x0)  with tohost address 0
  mem.write_u32(0, 0x00100093)
  mem.write_u32(4, 0x00102023) // sw x1, 0(x0)
  let hart = @exec.Hart::new_at(mem, 0, 0)
  assert_eq(hart.run(100), true)
}

///|
test "branch beq taken skips" {
  let mem = @memory.Memory::new(64)
  // beq x0, x0, +8 ; addi x1,x0,1 (skipped) ; addi x2,x0,7
  mem.write_u32(0, 0x00000463) // beq x0,x0,8
  mem.write_u32(4, 0x00100093)
  mem.write_u32(8, 0x00700113) // addi x2,x0,7
  let hart = @exec.Hart::new(mem)
  ignore(hart.step())
  assert_eq(hart.pc, 8)
  ignore(hart.step())
  assert_eq(hart.regs.get(2), 7)
  assert_eq(hart.regs.get(1), 0)
}