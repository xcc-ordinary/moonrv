# moonrv

Pure-MoonBit **RISC-V user-mode ISA simulator** (RV32IMC / RV64IMC) with Linux
syscall emulation — the missing *execution/verification* layer for MoonBit's
growing RISC-V *code-generation* ecosystem.

> Status: **RV32IMC + RV64IM implemented — official compliance 118/118 green.**
> The simulator executes the full official **riscv-tests** user-mode matrix:
> `rv32ui-p` 42/42, `rv32um-p` 8/8, `rv32uc-p` 1/1, `rv64ui-p` 54/54,
> `rv64um-p` 13/13, plus a real `hello-world` ELF. **17 tests green** on `wasm`
> and `wasm-gc`, including a **60-case differential corpus checked against
> `qemu-riscv32`**. See [`docs/riscv-tests-results.txt`](docs/riscv-tests-results.txt).
> CLI: `suite | run | trace | disasm | list | demo`.

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

**In scope (one-month target):**

- RV32IMC + RV64IMC user-mode interpretation (C compressed extension included,
  since toolchains emit RVC by default)
- Zicsr + machine-mode CSR subset; traps (illegal instr / ecall / ebreak /
  misaligned / access fault)
- ELF loading (reusing `moonbit-community/elf`), stack/heap/auxv setup
- Linux syscall emulation subset: exit / write / read / brk / mmap / munmap /
  openat / close / fstat / writev / gettimeofday …
- CLI: `run | trace | disasm | bench | diff`

**Out of scope (explicit future work, see [`docs/scope.md`](docs/scope.md)):**
S-mode / Sv32 / Sv39 MMU / page tables / virtio / booting xv6 or Linux
(full-system simulation); A-extension atomics (stretch); F/D/V; GDB stub.

## Architecture

| Package    | Responsibility                                            |
| ---------- | --------------------------------------------------------- |
| `isa`      | instruction vocabulary + decoder (RV32I + Zicsr + RV64 `*W`), RVC expander (`rvc.mbt`), disassembler (`disasm.mbt`) |
| `machine`  | register file (x0 hardwired zero) + minimal CSR file       |
| `memory`   | flat little-endian base-relative guest memory (u8/u16/u32/u64) |
| `elf`      | ELF32 (`elf.mbt`) + ELF64 (`elf64.mbt`) loaders: PT_LOAD mapping + `tohost` lookup |
| `exec`     | RV32 hart step / run loop, Linux syscalls, tohost pass/fail |
| `exec64`   | RV64 hart (Int64) sharing the `isa` decoder; RV64M high-multiply / long-division |
| `suite`    | embedded riscv-tests ELFs (hex) + hello-world, runner, trace/disasm, QEMU differential corpus |
| `cmd/moonrv` | CLI: `suite` / `run` / `trace` / `disasm` / `list` / `demo` |
| `scripts`  | `gen_diff.py` — seeded random-program generator checked against QEMU |

## Quickstart

```bash
moon update
moon test --target wasm        # 17 tests: 118/118 compliance + hello + 60-case QEMU diff
moon test --target wasm-gc
moon run cmd/moonrv --target wasm -- suite          # riscv-tests: 118/118 passed
moon run cmd/moonrv --target wasm -- run hello      # Hello, moonrv!  [PASS]
moon run cmd/moonrv --target wasm -- run rv64ui-p-add
moon run cmd/moonrv --target wasm -- trace hello 12 # single-step trace (ABI reg names)
moon run cmd/moonrv --target wasm -- disasm rv32ui-p-add 20
```

The official suite ELFs are vendored under [`testdata/`](testdata) (built from
riscv-tests source, BSD) and embedded into the `suite` package so the whole
compliance run is reproducible with `moon test` on any backend — no filesystem
or external oracle required.

## Verification plan

1. **riscv-tests** official compliance suite → pass/fail matrix.
   **Done: 118/118 pass** — `rv32ui-p` 42, `rv32um-p` 8, `rv32uc-p` 1,
   `rv64ui-p` 54, `rv64um-p` 13
   ([`docs/riscv-tests-results.txt`](docs/riscv-tests-results.txt)). The `-v-`
   (virtual-memory) variants are out of scope (they exercise the MMU).
2. **Differential testing** vs `qemu-riscv32`. **Done:** `scripts/gen_diff.py`
   generates seeded random RV32IM user-mode programs, runs them on QEMU to obtain
   reference exit codes, and emits a frozen corpus (`suite/diff_wbtest.mbt`)
   replayed by `moon test`. A dedicated CI job regenerates the corpus against
   QEMU on every run, so a semantic divergence fails the build.
3. **Fuzzing**: the same generator is seed-reproducible; any counterexample is
   captured as a hex ELF + expected exit code and replayed deterministically.
4. **Benchmarks** (stretch): Dhrystone / CoreMark cross-compiled to RISC-V ELF,
   output and score compared against spike.

## Origin & license

Original implementation in MoonBit. Specifications referenced: RISC-V ISA manuals
(Unprivileged / Privileged). spike, QEMU and riscv-tests are used **only as
behavioral oracles / test fixtures**; no GPL code is copied into this project.
Licensed under **MIT** (see [`LICENSE`](LICENSE)).

Independent from the author's other contest projects `moonjudge` (competitive
judging) and `moonexfat` (exFAT forensics) — different domain, no shared core.