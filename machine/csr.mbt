///|
// Minimal Zicsr state sufficient for the riscv-tests `p` environment and
// user-mode execution. The full 12-bit CSR address space is backed by a flat
// array; writes are stored verbatim and reads return the stored value, with a
// few architecturally-fixed exceptions (mhartid reads 0). We deliberately do
// not model PMP / delegation / privilege-mode side effects: the `p` tests only
// need these writes to be accepted and MRET to jump to MEPC, which the hart
// handles. This keeps moonrv a user-mode simulator rather than a full system
// emulator (see docs/scope.md).
pub struct CsrFile {
  vals : Array[Int]
}

///|
pub fn CsrFile::new() -> CsrFile {
  { vals: Array::make(4096, 0) }
}

///|
pub fn CsrFile::get(self : CsrFile, addr : Int) -> Int {
  match addr {
    0xF14 => 0 // mhartid: single hart, id 0
    0x342 => self.vals[addr] // mcause
    _ => self.vals[addr]
  }
}

///|
pub fn CsrFile::set(self : CsrFile, addr : Int, value : Int) -> Unit {
  match addr {
    0xF14 => () // mhartid is read-only
    _ => self.vals[addr] = value
  }
}