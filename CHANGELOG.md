# Changelog

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