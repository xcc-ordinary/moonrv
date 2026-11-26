// moonrv CLI: pure-MoonBit RISC-V user-mode ISA simulator.
// Week-1 milestone: `suite` runs the embedded official riscv-tests rv32ui-p
// suite, `run <name>` runs one embedded ELF (e.g. hello), `demo` runs the
// walking-skeleton program. File-based loading uses the same @elf loader.

///|
fn main {
  let args = @env.args()
  if args.length() >= 2 {
    match args[1] {
      "demo" => demo()
      "suite" => run_suite()
      "list" => list_images()
      "run" =>
        if args.length() >= 3 {
          run_image(args[2])
        } else {
          println("usage: moonrv run <name>   (see: moonrv list)")
        }
      _ => print_usage()
    }
  } else {
    print_usage()
  }
}

///|
fn print_usage() -> Unit {
  println("moonrv - pure-MoonBit RISC-V user-mode ISA simulator")
  println("")
  println("usage:")
  println("  moonrv suite          Run the official riscv-tests rv32ui-p suite")
  println("  moonrv run <name>     Run one embedded ELF (e.g. hello, rv32ui-p-add)")
  println("  moonrv list           List embedded ELF images")
  println("  moonrv demo           Run the walking-skeleton RV32I demo")
}

///|
fn run_suite() -> Unit {
  let mut passed = 0
  let mut total = 0
  for entry in @suite.registry() {
    let (name, data) = entry
    if name == "hello" {
      continue
    }
    total = total + 1
    match @suite.run_data(data) {
      Some(hart) =>
        if hart.pass {
          passed = passed + 1
          println("PASS \{name}")
        } else {
          println(
            "FAIL \{name} code=\{hart.fail_code} bad_word=\{hart.bad_word}",
          )
        }
      None => println("LOADFAIL \{name}")
    }
  }
  println("----")
  println("riscv-tests: \{passed}/\{total} passed")
}

///|
fn run_image(name : String) -> Unit {
  match @suite.lookup(name) {
    Some(data) =>
      match @suite.run_data(data) {
        Some(hart) => {
          let out = hart.stdout
          if out.length() > 0 {
            println(out)
          }
          if hart.pass {
            println("[PASS] \{name} (exit=\{hart.exit_code}, steps=\{hart.steps})")
          } else {
            println(
              "[FAIL] \{name} code=\{hart.fail_code} bad_word=\{hart.bad_word}",
            )
          }
        }
        None => println("invalid ELF image: \{name}")
      }
    None => println("unknown image: \{name}   (see: moonrv list)")
  }
}

///|
fn list_images() -> Unit {
  for entry in @suite.registry() {
    let (name, _) = entry
    println(name)
  }
}

///|
fn demo() -> Unit {
  let mem = @memory.Memory::new(64)
  mem.write_u32(0, 0x00500093) // addi x1, x0, 5
  mem.write_u32(4, 0x00108133) // add  x2, x1, x1
  mem.write_u32(8, 0x05D00893) // addi x17, x0, 93 (exit)
  mem.write_u32(12, 0x00000073) // ecall
  let hart = @exec.Hart::new(mem)
  ignore(hart.run(100))
  println(
    "demo finished: x1=\{hart.regs.get(1)} x2=\{hart.regs.get(2)} (expected x1=5 x2=10)",
  )
}