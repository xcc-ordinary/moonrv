///|
test "sign_extend" {
  assert_eq(@isa.sign_extend(0xFFF, 12), -1)
  assert_eq(@isa.sign_extend(0x7FF, 12), 2047)
  assert_eq(@isa.sign_extend(0x800, 12), -2048)
}

///|
test "decode addi x1, x0, 5" {
  assert_eq(@isa.decode(0x00500093), @isa.Instr::Addi(1, 0, 5))
}

///|
test "decode add/sub x3, x1, x2" {
  assert_eq(@isa.decode(0x002081B3), @isa.Instr::Add(3, 1, 2))
  assert_eq(@isa.decode(0x402081B3), @isa.Instr::Sub(3, 1, 2))
}

///|
test "decode lui/ecall" {
  assert_eq(@isa.decode(0x12345137), @isa.Instr::Lui(2, 0x12345000))
  assert_eq(@isa.decode(0x00000073), @isa.Instr::Ecall)
}