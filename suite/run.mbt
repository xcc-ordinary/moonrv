///|
fn hex_val(c : Char) -> Int {
  match c {
    '0'..='9' => c.to_int() - 48
    'a'..='f' => c.to_int() - 87
    'A'..='F' => c.to_int() - 55
    _ => 0
  }
}

///|
// Decode a hex string into a byte array (each 0..255).
pub fn hex_bytes(s : String) -> Array[Int] {
  let out = []
  let mut hi = -1
  for c in s {
    let v = hex_val(c)
    if hi < 0 {
      hi = v
    } else {
      out.push(hi * 16 + v)
      hi = -1
    }
  }
  out
}

///|
// Unified run result across RV32 / RV64 so the suite and CLI treat every image
// the same way.
pub struct RunResult {
  pass : Bool
  fail_code : Int64
  bad_word : Int
  steps : Int
  exit_code : Int64
  stdout : String
}

///|
// Load and run an embedded ELF image, dispatching on ELF class (32 vs 64).
pub fn run_data(data : Array[Int]) -> RunResult? {
  if data.length() > 4 && data[4] == 2 {
    match @elf.load64(data) {
      Some(e) => {
        let h = @exec64.Hart64::new_at(e.mem, e.entry, e.tohost)
        ignore(h.run(2000000))
        Some(
          {
            pass: h.pass,
            fail_code: h.fail_code,
            bad_word: h.bad_word,
            steps: h.steps,
            exit_code: h.exit_code,
            stdout: h.stdout_string(),
          },
        )
      }
      None => None
    }
  } else {
    match @elf.load(data) {
      Some(e) => {
        let h = @exec.Hart::new_at(e.mem, e.entry, e.tohost)
        ignore(h.run(2000000))
        Some(
          {
            pass: h.pass,
            fail_code: h.fail_code.to_int64(),
            bad_word: h.bad_word,
            steps: h.steps,
            exit_code: h.exit_code.to_int64(),
            stdout: h.stdout_string(),
          },
        )
      }
      None => None
    }
  }
}

///|
// Look up an embedded image by name (e.g. "rv32ui-p-add", "rv64ui-p-add", "hello").
pub fn lookup(name : String) -> Array[Int]? {
  for entry in registry() {
    let (n, data) = entry
    if n == name {
      return Some(data)
    }
  }
  None
}