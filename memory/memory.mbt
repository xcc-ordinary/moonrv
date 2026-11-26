///|
// Flat guest memory, little-endian. Bytes are stored as Int in 0..255 for
// simplicity in the skeleton; a tighter representation (Bytes/FixedArray) and
// sparse/page-backed memory for mmap arrive with the loader/syscall work.
pub struct Memory {
  bytes : Array[Int]
}

///|
pub fn Memory::new(size : Int) -> Memory {
  { bytes: Array::make(size, 0) }
}

///|
pub fn Memory::read_u32(self : Memory, addr : Int) -> Int {
  let b0 = self.bytes[addr]
  let b1 = self.bytes[addr + 1]
  let b2 = self.bytes[addr + 2]
  let b3 = self.bytes[addr + 3]
  b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
}

///|
pub fn Memory::write_u32(self : Memory, addr : Int, value : Int) -> Unit {
  self.bytes[addr] = value & 0xFF
  self.bytes[addr + 1] = (value >> 8) & 0xFF
  self.bytes[addr + 2] = (value >> 16) & 0xFF
  self.bytes[addr + 3] = (value >> 24) & 0xFF
}