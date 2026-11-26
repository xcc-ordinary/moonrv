# Changelog

## 0.0.1 — walking skeleton

- Module scaffold: `isa` / `machine` / `memory` / `exec` / `cmd/moonrv`.
- Correct RV32I subset: LUI / AUIPC / ADDI / ADD / SUB / ECALL / EBREAK
  (decode + execute), x0 hardwired zero, flat little-endian memory.
- CLI `demo` runs a tiny program end-to-end (x1=5, x2=10).
- 7 tests green on `wasm` and `wasm-gc`; GitHub Actions CI.
- Docs: scope boundaries, week-1 rv32ui acceptance checklist.