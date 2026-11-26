# Week 1 acceptance checklist — rv32ui green  ✅ DONE (2026-11-26)

Goal: the official **riscv-tests `rv32ui-p`** suite passes on moonrv, and a real
`hello-world` ELF runs to completion. **Achieved: 42/42 pass + hello-world.**
Matrix: [`rv32ui-p-results.txt`](rv32ui-p-results.txt). 14 tests green on
`wasm` + `wasm-gc`.

## 0. Fixtures & tooling

- [x] Vendor `riscv-tests` `rv32ui-p-*` ELFs (BSD) into `testdata/`.
      Built from source (the repo ships only `.S`); see `testdata/README.md`
      for the source commit, toolchain and build command.
- [x] Cross-compiler for custom ELFs: `gcc-riscv64-unknown-elf` (Ubuntu
      `gcc-riscv64-unknown-elf` 10.2.0) used to build the suite and hello-world.
- [ ] CI oracle (qemu/spike) for *differential* testing — deferred to the
      differential-testing milestone; the compliance suite itself needs no
      oracle (pass/fail is self-reported via `tohost` / exit code).

## 1. ELF loader

- [x] New `elf` package. **Deviation:** a small self-contained ELF32 parser
      rather than `moonbit-community/elf` (v0.0.1) — keeps the loader pure,
      dependency-free and testable on wasm; can swap later.
- [x] Parse ELF32 header + program headers; map PT_LOAD into base-relative
      `memory` (guest base 0x8000_0000 rebased so the array stays small).
- [x] Set entry `pc`; locate `tohost` via the section-header symbol table.
      Stack/auxv setup not needed for the freestanding `p` tests / hello.
- [x] Test: load + run vendored ELFs (the `suite` tests assert entry/segments
      indirectly by reaching the correct pass/fail result).

## 2. RV32I decode + execute

- [x] OP-IMM: ADDI / SLTI / SLTIU / XORI / ORI / ANDI / SLLI / SRLI / SRAI
- [x] OP: ADD / SUB / SLL / SLT / SLTU / XOR / SRL / SRA / OR / AND
- [x] LUI / AUIPC
- [x] JAL / JALR (pc-relative, link register, `& ~1` alignment)
- [x] BRANCH: BEQ / BNE / BLT / BGE / BLTU / BGEU (B-type immediate)
- [x] LOAD: LB / LH / LW / LBU / LHU (sign/zero extension)
- [x] STORE: SB / SH / SW (S-type immediate)
- [x] SYSTEM: ECALL / EBREAK / MRET; FENCE / FENCE.I as no-ops
- [x] Zicsr: CSRRW / CSRRS / CSRRC / CSRRWI / CSRRSI / CSRRCI (needed by the
      `p` environment init: mhartid / mtvec / mepc / mstatus / pmp / deleg …)
- [x] x0 hardwired zero enforced everywhere.

## 3. Trap / tohost handling

- [x] riscv-tests `tohost` write detection: value 1 = pass, else fail code.
- [x] `exec::run(fuel)` loop with step budget; reports pass/fail/timeout and
      the offending word on an unsupported encoding.
- [x] **Deviation (scope discipline):** misaligned load/store is handled
      directly in software (byte-wise flat memory) rather than trapping — this
      is exactly what `rv32ui-p-ma_data` expects, and keeps moonrv a *user-mode*
      simulator. Full privileged trap delivery (PMP/delegation/mode switch) is
      intentionally not modeled; the `p` init only needs CSR writes accepted and
      MRET → MEPC, which is implemented.

## 4. Suite run + milestone

- [x] `moonrv suite` runs all rv32ui-p ELFs and emits a pass/fail matrix.
- [x] **Acceptance: rv32ui-p-* 42/42 pass.** The `-v-` (virtual-memory) variants
      are out of scope (MMU); documented in `docs/scope.md`.
- [x] hello-world ELF (`write` + `exit`) prints `Hello, moonrv!` and exits 0.
- [x] Suite wired into `moon test` (embedded ELFs) → runs in CI on wasm/wasm-gc.
- [x] Public commit + README update: "rv32ui green" milestone.

## Next (week 2+)

M extension (`rv32um`), C compressed (`rv32uc`), RV64 widening, wider Linux
syscall set, `trace` / `disasm` / `diff` CLI, differential testing vs spike/QEMU.