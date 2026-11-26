# Week 1 acceptance checklist — rv32ui green

Goal: by end of week 1, the official **riscv-tests `rv32ui`** suite passes on
moonrv, and a real `hello-world` ELF runs to completion. This is the first public,
 runnable milestone.

## 0. Fixtures & tooling (day 1)

- [ ] Vendor prebuilt `riscv-tests` ELFs (BSD) into `testdata/riscv-tests/`
      (rv32ui-p-* and rv32ui-v-*). Record source commit + license in
      `testdata/README.md`.
- [ ] Confirm an oracle is reachable in CI: `qemu-riscv32` (apt `qemu-user`) or
      a built `spike`. Add `scripts/run-riscv-tests.sh` skeleton.
- [ ] Add a cross-compiler path for custom ELFs (clang `--target=riscv32` + lld,
      or riscv-gnu-toolchain) — only needed for hello-world / benchmarks.

## 1. ELF loader (day 1–2)

- [ ] New `loader` package; integrate `moonbit-community/elf`.
- [ ] Parse ELF32 header + program headers; map PT_LOAD segments into `memory`.
- [ ] Set entry `pc`, initialize stack pointer + auxv; expose `tohost`/`fromhost`
      symbols (riscv-tests writes pass/fail to `tohost`).
- [ ] Test: load a vendored rv32ui ELF, assert entry point and segment bytes.

## 2. RV32I decode + execute (day 2–4)

Fill `isa::decode` and `exec::step` group by group, each with unit tests:

- [ ] OP-IMM: ADDI / SLTI / SLTIU / XORI / ORI / ANDI / SLLI / SRLI / SRAI
- [ ] OP: ADD / SUB / SLL / SLT / SLTU / XOR / SRL / SRA / OR / AND
- [ ] LUI / AUIPC (already in skeleton — verify against suite)
- [ ] JAL / JALR (pc-relative, link register, alignment)
- [ ] BRANCH: BEQ / BNE / BLT / BGE / BLTU / BGEU (B-type immediate)
- [ ] LOAD: LB / LH / LW / LBU / LHU (sign/zero extension)
- [ ] STORE: SB / SH / SW (S-type immediate)
- [ ] SYSTEM: ECALL / EBREAK; FENCE (nop for user-mode)
- [ ] x0 hardwired zero enforced everywhere (skeleton already does).

## 3. Trap / tohost handling (day 4)

- [ ] Illegal instruction → trap; misaligned load/store policy.
- [ ] riscv-tests `tohost` write detection: value 1 = pass, else fail code.
- [ ] `exec::run(fuel)` loop with step budget; report pass/fail/timeout.

## 4. Suite run + milestone (day 5)

- [ ] `scripts/run-riscv-tests.sh` runs all rv32ui ELFs, emits a pass/fail matrix.
- [ ] **Acceptance: rv32ui-p-* all pass** (virtual-memory `-v-` variants may be
      deferred since they exercise MMU — document which are skipped and why).
- [ ] hello-world ELF (write syscall) runs and prints to stdout.
- [ ] Wire the suite into CI as an independent job; commit the matrix artifact.
- [ ] Public commit + README update: "rv32ui green" milestone.

## Definition of done (week 1)

`moon test` green (wasm + wasm-gc) **and** rv32ui-p suite pass matrix committed
**and** hello-world runs. Anything not finished is listed explicitly in README
(range discipline is a scored dimension).