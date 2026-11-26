# moonrv

Pure-MoonBit **RISC-V user-mode ISA simulator** (RV32IMC / RV64IMC) with Linux
syscall emulation — the missing *execution/verification* layer for MoonBit's
growing RISC-V *code-generation* ecosystem.

> Status: **week-1 milestone reached — rv32ui green.** The full RV32I base ISA
> + Zicsr + MRET executes the official **riscv-tests `rv32ui-p` suite: 42/42
> pass**, and a real `hello-world` ELF runs to completion (`write` + `exit`
> syscalls). 14 tests green on `wasm` and `wasm-gc`. See the committed matrix
> [`docs/rv32ui-p-results.txt`](docs/rv32ui-p-results.txt). M / C / RV64 and the
> wider syscall set are the next steps
> ([`docs/week1-rv32ui-checklist.md`](docs/week1-rv32ui-checklist.md)).

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
| `isa`      | instruction vocabulary + decoder (full RV32I + Zicsr), sign extension |
| `machine`  | register file (x0 hardwired zero) + minimal CSR file       |
| `memory`   | flat little-endian base-relative guest memory             |
| `elf`      | ELF32 loader: PT_LOAD mapping + `tohost` symbol lookup    |
| `exec`     | hart step / run loop, Linux syscalls (write/exit/read), tohost pass/fail |
| `suite`    | embedded riscv-tests rv32ui-p ELFs + hello-world, runner  |
| `cmd/moonrv` | CLI: `suite` / `run` / `list` / `demo`                  |

Planned packages: `syscall` (wider Linux ABI), `disasm`, `diff` (oracle).

## Quickstart

```bash
moon update
moon test --target wasm        # 14 tests, incl. rv32ui-p 42/42 + hello-world
moon test --target wasm-gc
moon run cmd/moonrv --target wasm -- suite        # rv32ui-p: 42/42 passed
moon run cmd/moonrv --target wasm -- run hello    # Hello, moonrv!  [PASS]
moon run cmd/moonrv --target wasm -- run rv32ui-p-add
moon run cmd/moonrv --target wasm -- demo         # x1=5 x2=10
```

The official suite ELFs are vendored under [`testdata/`](testdata) (built from
riscv-tests source, BSD) and embedded into the `suite` package so the whole
compliance run is reproducible with `moon test` on any backend — no filesystem
or external oracle required.

## Verification plan

1. **riscv-tests** official compliance suite → pass/fail matrix.
   **Done: `rv32ui-p` 42/42 pass** ([`docs/rv32ui-p-results.txt`](docs/rv32ui-p-results.txt)).
   Next: `rv32um` (M), `rv32uc` (C), then RV64. The `-v-` (virtual-memory)
   variants are out of scope (they exercise the MMU; see `docs/scope.md`).
2. **Differential testing** vs spike / qemu-riscv-user at syscall boundaries
   (registers / memory / exit code), as an independent CI job.
3. **Benchmarks**: Dhrystone / CoreMark cross-compiled to RISC-V ELF, output and
   score compared against spike.
4. **Fuzzing**: seeded random instruction streams, moonrv vs spike, counterexample
   saved and reproducible by seed.

## Origin & license

Original implementation in MoonBit. Specifications referenced: RISC-V ISA manuals
(Unprivileged / Privileged). spike, QEMU and riscv-tests are used **only as
behavioral oracles / test fixtures**; no GPL code is copied into this project.
Licensed under **MIT** (see [`LICENSE`](LICENSE)).

Independent from the author's other contest projects `moonjudge` (competitive
judging) and `moonexfat` (exFAT forensics) — different domain, no shared core.