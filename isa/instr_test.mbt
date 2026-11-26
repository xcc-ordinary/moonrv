///|
test "sign_extend" {
  assert_eq(@isa.sign_extend(0xFFF, 12), -1)
  assert_eq(@isa.sign_extend(0x7FF, 12), 2047)
  assert_eq(@isa.sign_extend(0x800, 12), -2048)
}

///|
test "decode addi x1, x0, 5" {
  assert_eq(@isa.decode(0x00500093), @isa.Instr::OpImm(0, 1, 0, 5, 0))
}

///|
test "decode add/sub x3, x1, x2" {
  assert_eq(@isa.decode(0x002081B3), @isa.Instr::Op(0, 3, 1, 2, 0))
  assert_eq(@isa.decode(0x402081B3), @isa.Instr::Op(0, 3, 1, 2, 0x20))
}

///|
test "decode lui/ecall/mret" {
  assert_eq(@isa.decode(0x12345137), @isa.Instr::Lui(2, 0x12345000))
  assert_eq(@isa.decode(0x00000073), @isa.Instr::Ecall)
  assert_eq(@isa.decode(0x30200073), @isa.Instr::Mret)
}

///|
test "decode srai x1, x1, 3" {
  // 0x4030D093 = srai x1, x1, 3
  assert_eq(@isa.decode(0x4030D093), @isa.Instr::OpImm(5, 1, 1, 3, 0x20))
}

///|
test "decode sw x2, 8(x1)" {
  // 0x0020A423 = sw x2, 8(x1)
  assert_eq(@isa.decode(0x0020A423), @isa.Instr::Store(2, 1, 2, 8))
}