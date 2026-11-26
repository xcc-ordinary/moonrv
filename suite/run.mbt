///|
// Load and run an embedded ELF image, returning the finished hart (or None if
// the image is not a valid ELF32). The step budget is generous; every program
// in the milestone suite halts in a few hundred instructions.
pub fn run_data(data : Array[Int]) -> @exec.Hart? {
  match @elf.load(data) {
    Some(e) => {
      let hart = @exec.Hart::new_at(e.mem, e.entry, e.tohost)
      ignore(hart.run(2000000))
      Some(hart)
    }
    None => None
  }
}

///|
// Look up an embedded image by name (e.g. "rv32ui-p-add", "hello").
pub fn lookup(name : String) -> Array[Int]? {
  for entry in registry() {
    let (n, data) = entry
    if n == name {
      return Some(data)
    }
  }
  None
}