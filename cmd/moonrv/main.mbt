// moonrv CLI: pure-MoonBit RISC-V user-mode ISA simulator.
// Walking skeleton: `demo` runs a tiny RV32I program end-to-end.
// Full subcommands (run/trace/disasm/bench/diff) land in week 1+.

///|
fn main {
  let args = @env.args()
  if args.length() >= 2 && args[1] == "demo" {
    demo()
  } else {
    print_usage()
  }
}

///|
fn print_usage() -> Unit {
  println("moonrv - pure-MoonBit RISC-V user-mode ISA simulator (skeleton)")
  println("")
  println("usage:")
  println("  moonrv demo    Run the walking-skeleton RV32I demo (addi/add/ecall)")
  println("")
  println(
    "planned: run | trace | disasm | bench | diff  (docs/week1-rv32ui-checklist.md)",
  )
}

///|
fn demo() -> Unit {
  let mem = @memory.Memory::new(64)
  mem.write_u32(0, 0x00500093) // addi x1, x0, 5
  mem.write_u32(4, 0x00108133) // add  x2, x1, x1
  mem.write_u32(8, 0x00000073) // ecall
  let hart = @exec.Hart::new(mem)
  let mut running = true
  let mut steps = 0
  while running && steps < 100 {
    match hart.step() {
      @exec.StepResult::Ok => steps = steps + 1
      @exec.StepResult::Ecall => running = false
      @exec.StepResult::Ebreak => running = false
      @exec.StepResult::Unsupported(w) => {
        println("unsupported instruction word: \{w}")
        running = false
      }
    }
  }
  println(
    "demo finished: x1=\{hart.regs.get(1)} x2=\{hart.regs.get(2)} (expected x1=5 x2=10)",
  )
}