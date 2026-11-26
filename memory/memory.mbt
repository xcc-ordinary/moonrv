///|
// Flat guest memory, little-endian, base-relative. Guest addresses (e.g. the
// riscv-tests load address 0x8000_0000) are rebased by `base` so the backing
// array stays small. Bytes are stored as Int in 0..255. Out-of-range reads
// return 0 and out-of-range writes are dropped, which keeps the interpreter
// total while still covering every loaded segment plus a stack/heap window.
pub struct Memory {
  base : Int
  bytes : Array[Int]
}

///|
pub fn Memory::new(size : Int) -> Memory {
  { base: 0, bytes: Array::make(size, 0) }
}

///|
pub fn Memory::new_at(base : Int, size : Int) -> Memory {
  { base, bytes: Array::make(size, 0) }
}

///|
pub fn Memory::read_u8(self : Memory, addr : Int) -> Int {
  let i = addr - self.base
  if i < 0 || i >= self.bytes.length() {
    0
  } else {
    self.bytes[i]
  }
}

///|
pub fn Memory::write_u8(self : Memory, addr : Int, value : Int) -> Unit {
  let i = addr - self.base
  if i >= 0 && i < self.bytes.length() {
    self.bytes[i] = value & 0xFF
  }
}

///|
pub fn Memory::read_u16(self : Memory, addr : Int) -> Int {
  self.read_u8(addr) | (self.read_u8(addr + 1) << 8)
}

///|
pub fn Memory::write_u16(self : Memory, addr : Int, value : Int) -> Unit {
  self.write_u8(addr, value)
  self.write_u8(addr + 1, value >> 8)
}

///|
pub fn Memory::read_u32(self : Memory, addr : Int) -> Int {
  self.read_u8(addr) | (self.read_u8(addr + 1) << 8) |
  (self.read_u8(addr + 2) << 16) | (self.read_u8(addr + 3) << 24)
}

///|
pub fn Memory::write_u32(self : Memory, addr : Int, value : Int) -> Unit {
  self.write_u8(addr, value)
  self.write_u8(addr + 1, value >> 8)
  self.write_u8(addr + 2, value >> 16)
  self.write_u8(addr + 3, value >> 24)
}

///|
pub fn Memory::read_u64(self : Memory, addr : Int) -> Int64 {
  let lo = self.read_u32(addr).to_int64() & 0xFFFFFFFFL
  let hi = self.read_u32(addr + 4).to_int64() & 0xFFFFFFFFL
  lo | (hi << 32)
}

///|
pub fn Memory::write_u64(self : Memory, addr : Int, value : Int64) -> Unit {
  self.write_u32(addr, (value & 0xFFFFFFFFL).to_int())
  self.write_u32(addr + 4, ((value >> 32) & 0xFFFFFFFFL).to_int())
}

///|
// Copy a run of guest bytes (each 0..255) starting at guest address `addr`.
pub fn Memory::write_bytes(self : Memory, addr : Int, data : Array[Int]) -> Unit {
  for i = 0; i < data.length(); i = i + 1 {
    self.write_u8(addr + i, data[i])
  }
}