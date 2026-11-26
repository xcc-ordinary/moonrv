///|
test "little endian u32 roundtrip" {
  let m = @memory.Memory::new(16)
  m.write_u32(0, 0x12345678)
  assert_eq(m.read_u32(0), 0x12345678)
  assert_eq(m.bytes[0], 0x78)
  assert_eq(m.bytes[1], 0x56)
  assert_eq(m.bytes[2], 0x34)
  assert_eq(m.bytes[3], 0x12)
}