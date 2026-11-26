///|
// RV32 integer register file. x0 is hardwired to zero: writes are dropped and
// reads always return 0. RV64 widening (Int64) is a week-3 stretch goal.
pub struct RegFile {
  regs : Array[Int]
}

///|
pub fn RegFile::new() -> RegFile {
  { regs: Array::make(32, 0) }
}

///|
pub fn RegFile::get(self : RegFile, i : Int) -> Int {
  if i == 0 {
    0
  } else {
    self.regs[i]
  }
}

///|
pub fn RegFile::set(self : RegFile, i : Int, v : Int) -> Unit {
  if i != 0 {
    self.regs[i] = v
  }
}