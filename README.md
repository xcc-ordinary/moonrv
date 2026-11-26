# moonrv

Pure-MoonBit **RISC-V user-mode ISA simulator** (RV32IMAC / RV64IMAC) with Linux
syscall emulation — the missing *execution/verification* layer for MoonBit's
growing RISC-V *code-generation* ecosystem.

> Status: **RV32IMAC + RV64IMAC implemented — official compliance 148/148 green.**
> The simulator executes the full official **riscv-tests** user-mode matrix:
> `rv32ui-p` 42, `rv32um-p` 8, `rv32uc-p` 1, `rv32ua-p` 10, `rv64ui-p` 54,
> `rv64um-p` 13, `rv64ua-p` 19, `rv64uc-p` 1, plus real gcc-compiled C programs
> (`hello`, `fib`, `sieve`). **19 tests green** on `wasm` and `wasm-gc`, including
> a **60-case differential corpus checked against `qemu-riscv32`**. See
> [`docs/riscv-tests-results.txt`](docs/riscv-tests-results.txt).
> CLI: `suite | run | bench | trace | disasm | list | demo`.

## Why this project

MoonBit already has RISC-V **codegen** — `aurasuisui/rvv` (vector backend),
`Kaida-Amethyst/MoonMIR`, `Kaida-Amethyst/MoonLLVM` — but **no ISA simulator** to
verify that generated instructions actually execute correctly. `moonrv` fills
that oracle gap. It is also a teaching simulator for OS / computer-architecture
courses, and because it is pure MoonBit it runs on `native`, `js`, `wasm` and
`wasm-gc` — including **a RISC-V playground inside the browser**.

External baselines (used as differential oracles, **no code copied**):
[spike / riscv-isa-sim](https://github.com/riscv-software-src/riscv-isa-sim) (BSD),
[QEMU](https://www.qemu.org/) (GPL, oracle only),
[mini-rv32ima](https://github.com/cnlohr/mini-rv32ima) (MIT),
[riscv-tests](https://github.com/riscv-software-src/riscv-tests) (BSD).

## Scope

**In scope (implemented):**

- RV32IMAC + RV64IMAC user-mode interpretation (M multiply/divide, A atomics
  LR/SC + AMO, C compressed — toolchains emit RVC by default)
- Zicsr + machine-mode CSR subset; MRET; FENCE
- ELF32/ELF64 loading, PT_LOAD mapping, `tohost` lookup, stack setup
- Linux syscall emulation subset: exit / exit_group / write / writev / read /
  brk / mmap / munmap / getpid / gettimeofday
- CLI: `suite | run | bench | trace | disasm | list | demo`

**Out of scope (explicit future work, see [`docs/scope.md`](docs/scope.md)):**
S-mode / Sv32 / Sv39 MMU / page tables / virtio / booting xv6 or Linux
(full-system simulation); F/D floating point; V vector; GDB stub.

## Architecture

| Package    | Responsibility                                            |
| ---------- | --------------------------------------------------------- |
| `isa`      | decoder (RV32I + Zicsr + RV64 `*W` + A atomics), RV32/RV64 RVC expanders, disassembler |
| `machine`  | register file (x0 hardwired zero) + minimal CSR file       |
| `memory`   | flat little-endian base-relative guest memory (u8/u16/u32/u64) |
| `elf`      | ELF32 (`elf.mbt`) + ELF64 (`elf64.mbt`) loaders: PT_LOAD mapping + `tohost` lookup |
| `exec`     | RV32 hart step / run loop, Linux syscalls, LR/SC reservation, tohost pass/fail |
| `exec64`   | RV64 hart (Int64) sharing the `isa` decoder; RV64M high-multiply / long-division |
| `suite`    | embedded riscv-tests ELFs (hex) + C demos, runner, trace/disasm, QEMU differential corpus |
| `cmd/moonrv` | CLI: `suite` / `run` / `bench` / `trace` / `disasm` / `list` / `demo` |
| `scripts`  | `gen_diff.py` — seeded random-program generator checked against QEMU |

## Quickstart

```bash
moon update
moon test --target wasm        # 19 tests: 148/148 compliance + C demos + 60-case QEMU diff
moon test --target wasm-gc
moon run cmd/moonrv --target wasm -- suite          # riscv-tests: 148/148 passed
moon run cmd/moonrv --target wasm -- run fib        # fib20=6765 / pid=1 / OK
moon run cmd/moonrv --target wasm -- bench          # sieve RV32 vs RV64 instruction counts
moon run cmd/moonrv --target wasm -- trace hello 12 # single-step trace (ABI reg names)
moon run cmd/moonrv --target wasm -- disasm rv32ui-p-add 20
```

The official suite ELFs are vendored under [`testdata/`](testdata) (built from
riscv-tests source, BSD) and embedded into the `suite` package so the whole
compliance run is reproducible with `moon test` on any backend — no filesystem
or external oracle required.

## Verification plan

1. **riscv-tests** official compliance suite → pass/fail matrix.
   **Done: 148/148 pass** — `rv32ui` 42, `rv32um` 8, `rv32uc` 1, `rv32ua` 10,
   `rv64ui` 54, `rv64um` 13, `rv64ua` 19, `rv64uc` 1
   ([`docs/riscv-tests-results.txt`](docs/riscv-tests-results.txt)). The `-v-`
   (virtual-memory) variants are out of scope (they exercise the MMU).
2. **Differential testing** vs `qemu-riscv32`. **Done:** `scripts/gen_diff.py`
   generates seeded random RV32IM user-mode programs, runs them on QEMU to obtain
   reference exit codes, and emits a frozen corpus (`suite/diff_wbtest.mbt`)
   replayed by `moon test`. A dedicated CI job regenerates the corpus against
   QEMU on every run, so a semantic divergence fails the build.
3. **Real C programs**: freestanding gcc-compiled kernels (`fib.c`, `sieve.c`,
   `-O2`, no libc) run end-to-end, exercising the wider syscall subset and stack.
4. **Benchmarks**: `moonrv bench` reports executed-instruction counts for the
   sieve kernel on RV32 and RV64. Dhrystone / CoreMark vs spike is future work.

## Origin & license

Original implementation in MoonBit. Specifications referenced: RISC-V ISA manuals
(Unprivileged / Privileged). spike, QEMU and riscv-tests are used **only as
behavioral oracles / test fixtures**; no GPL code is copied into this project.
Licensed under **MIT** (see [`LICENSE`](LICENSE)).

Independent from the author's other contest projects `moonjudge` (competitive
judging) and `moonexfat` (exFAT forensics) — different domain, no shared core.