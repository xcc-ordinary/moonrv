# Scope boundaries

## In scope — one-month deliverable

User-mode RV32IMC / RV64IMC ISA simulation with Linux syscall emulation. This is
the same operating point as spike's proxy-kernel mode, `qemu-riscv32/64`
user-mode, and mini-rv32ima: run statically-linked RISC-V ELF binaries, emulate
a subset of Linux syscalls, no kernel / no MMU.

- Base ISA: RV32I then RV64I (register/ALU widening).
- M extension: MUL / MULH / MULHSU / MULHU / DIV / DIVU / REM / REMU.
- C extension: compressed instruction expansion (toolchains emit RVC by default).
- Zicsr + machine-mode CSR subset; trap/exception handling.
- ELF loader (reuse `moonbit-community/elf`), stack/heap/auxv.
- Linux syscall subset (exit/write/read/brk/mmap/munmap/openat/close/fstat/…).
- CLI: run / trace / disasm / bench / diff.

## Out of scope — explicit future work

Stated here so the one-month boundary is unambiguous and reviewers can see the
range discipline:

- **Full-system simulation**: S-mode, Sv32/Sv39 MMU, page tables, virtio,
  booting xv6 or Linux. (This was the high-risk path flagged in the 11-23 gap
  scan; deliberately excluded.)
- **A extension** (LR/SC, AMO): optional stretch, only after RV32IMC is solid.
- **F/D floating point, V vector**: not simulated. (`rvv` is a codegen backend,
  not an execution target for this project.)
- **GDB remote stub**: `moondbg` already exists; avoid piggy-back increment.

## Independence

`moonrv` (CPU emulation) shares no core with `moonjudge` (competitive judging) or
`moonexfat` (exFAT forensics). Only the *methodology* of differential/cross
validation is reused, which is an engineering strength, not project splitting.