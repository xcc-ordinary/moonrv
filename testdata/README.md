# testdata — vendored RISC-V test ELFs

These are **test fixtures only**, not part of the moonrv implementation.

## rv32ui-p-* (42 files)

- Source: [riscv-software-src/riscv-tests](https://github.com/riscv-software-src/riscv-tests),
  `isa/rv32ui/` (shallow clone of `master`, 2026-11-26).
- Test environment submodule `env` =
  [riscv/riscv-test-env](https://github.com/riscv/riscv-test-env)
  @ `6de71edb142be36319e380ce782c3d1830c65d68`.
- License: **BSD-3-Clause** (riscv-tests). Retained upstream; no modification.
- The upstream repo ships only `.S` sources, so the ELFs were cross-compiled:

  ```bash
  git clone --depth 1 https://github.com/riscv-software-src/riscv-tests
  cd riscv-tests && git submodule update --init --recursive
  cd isa
  # Ubuntu gcc-riscv64-unknown-elf 10.2.0 / binutils 2.35.1
  make XLEN=32 RISCV_PREFIX=riscv64-unknown-elf- rv32ui-p-<name>
  ```

  (`-march=rv32g -mabi=ilp32 -static -nostdlib`, linked with `env/p/link.ld`;
  load base `0x8000_0000`, `tohost` mailbox at `0x8000_1000`.)

## hello-rv32

- Original freestanding RV32IM assembly (`write` + `exit` Linux syscalls),
  assembled with the same toolchain at `-Ttext=0x10000`. Prints
  `Hello, moonrv!\n`. MIT (this project).

## Usage

The ELFs are embedded as byte arrays in the `suite` package (`suite/data.mbt`,
generated) so `moon test` reproduces the full compliance run on any backend
without a filesystem. `moonrv suite` / `moonrv run <name>` use the same images.