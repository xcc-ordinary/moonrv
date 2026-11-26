# Changelog

## 0.0.5 — RV32IMAC + RV64IMAC, real C programs, bench

- **A extension** (RV32A + RV64A): `Instr::Atomic` decode; LR/SC reservation
  tracked by address and invalidated by intervening stores; AMO
  swap/add/xor/and/or/min/max/minu/maxu in W and D widths. `rv32ua` 10 + `rv64ua` 19.
- **RV64C**: `decode_compressed64` (C.LD/SD/LDSP/SDSP, C.ADDIW, C.SUBW/ADDW,
  keeps C.LWSP/C.SWSP). `rv64uc-p-rvc` green.
- **Real gcc-compiled C**: freestanding `fib.c` / `sieve.c` (-O2, no libc) run
  end-to-end. New syscalls mmap/munmap/getpid; Hart initializes sp from the
  memory window so C stack frames work.
- **bench CLI**: `moonrv bench [name]` reports executed-instruction counts;
  default sieve kernel on RV32/RV64 (primes<8192=1028, 123707 instructions).
- **Acceptance: official matrix 148/148**, 19 tests green on wasm + wasm-gc.

## 0.0.4 — differential vs QEMU + trace/disasm CLI + wider syscalls

- **Differential harness**: `scripts/gen_diff.py` generates seeded random RV32IM
  user-mode programs, assembles them with the RISC-V cross toolchain, runs them on
  `qemu-riscv32` for reference exit codes, and emits a frozen 60-case corpus
  (`suite/diff_wbtest.mbt`) replayed by `moon test`. New CI job `differential`
  regenerates the corpus against QEMU on every run. **17 tests green.**
- **CLI**: `trace <name> [max]` single-step execution trace and `disasm <name>
  [count]` disassembly, both with ABI register names (`isa/disasm.mbt`).
- **Wider Linux syscalls**: `writev` (66), `exit_group` (94), `gettimeofday` (169),
  `brk` (214) added to the RV32 hart.
- Note: qemu-user requires the executable bit on the ELF; the generator sets it.

## 0.0.3 — RV64IM + full official suite green

- New `exec64` package: isolated Int64 hart (RV64I + W-word ops + M), so the
  verified RV32 path cannot regress. 128-bit high-multiply (MULH/MULHSU/MULHU)
  via 16-bit limbs; unsigned DIVU/REMU via binary long division.
- `isa`: RV64 opcodes OP-IMM-32 / OP-32, 6-bit shift amounts; `elf`: ELF64
  loader; `memory`: 64-bit load/store.
- **Acceptance: rv64ui-p 54/54 and rv64um-p 13/13 pass.** Combined official
  matrix now **118/118** (rv32ui 42 + rv32um 8 + rv32uc 1 + rv64ui 54 + rv64um 13)
  plus hello-world. 16 tests green on wasm + wasm-gc.
- Suite fixtures stored as hex strings (wasm data segments) to stay under the
  per-function size limit; decoded at runtime. Matrix: `docs/riscv-tests-results.txt`.

## 0.0.2 — week-1 milestone: rv32ui green

- **Full RV32I** decode + execute: OP-IMM / OP / LUI / AUIPC / JAL / JALR /
  BRANCH / LOAD / STORE / SYSTEM, plus **Zicsr** (CSRRW/S/C + immediate forms),
  **MRET** and FENCE.
- New `elf` package: ELF32 little-endian loader, PT_LOAD mapping into
  base-relative memory, `tohost` symbol lookup via the section-header symtab.
- New `machine::CsrFile`; `exec` run loop with step budget, Linux user-mode
  syscalls (`write`/`exit`/`read`), and riscv-tests `tohost` pass/fail detection.
- New `suite` package: 42 official `rv32ui-p` ELFs + a `hello-world` ELF embedded
  as byte arrays; reproducible compliance run on every backend.
- **Acceptance met: `rv32ui-p` 42/42 pass; hello-world prints and exits 0.**
  14 tests green on `wasm` and `wasm-gc`. Matrix: `docs/rv32ui-p-results.txt`.
- CLI: `suite` / `run <name>` / `list` / `demo`.
- Fixtures built from riscv-tests source (BSD); see `testdata/README.md`.

## 0.0.1 — walking skeleton

- Module scaffold: `isa` / `machine` / `memory` / `exec` / `cmd/moonrv`.
- Correct RV32I subset: LUI / AUIPC / ADDI / ADD / SUB / ECALL / EBREAK
  (decode + execute), x0 hardwired zero, flat little-endian memory.
- CLI `demo` runs a tiny program end-to-end (x1=5, x2=10).
- 7 tests green on `wasm` and `wasm-gc`; GitHub Actions CI.
- Docs: scope boundaries, week-1 rv32ui acceptance checklist.