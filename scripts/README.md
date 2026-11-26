# scripts

## gen_diff.py — differential corpus generator

Generates a reproducible differential test corpus for moonrv against
`qemu-riscv32` (the reference oracle).

Pipeline:

1. A fixed-seed LCG (`random.Random(20261126)`) builds 60 random RV32IM
   user-mode programs: registers are initialised with random `addi`, then 24
   random register-register ops (I + M), then the result is moved to `a0` and the
   program exits via `ecall` (`a7 = 93`).
2. Each program's raw instruction words are emitted as `.word` directives and
   assembled into a proper static RV32 ELF with `riscv64-unknown-elf-gcc`
   (`-march=rv32ima -mabi=ilp32 -nostdlib -static`). Hand-built minimal ELFs are
   rejected by qemu-user, so a real toolchain image is used.
3. `qemu-riscv32` runs each ELF; the low 8 bits of its exit code are recorded as
   the reference result. **qemu-user requires the executable bit**, so the file
   is `chmod 0755` before running.
4. The `(ELF hex, expected exit)` pairs are emitted as `suite/diff_wbtest.mbt`,
   a MoonBit test that replays every program in moonrv and asserts
   `(exit_code & 0xFF) == expected`.

Usage:

```bash
# requires: qemu-user, gcc-riscv64-unknown-elf, python3
python3 scripts/gen_diff.py suite/diff_wbtest.mbt
moon test --target wasm
```

The committed corpus is a frozen regression artifact: `moon test` replays it with
no external oracle. The CI `differential` job regenerates it against QEMU on every
run, so any RV32IM semantic divergence between moonrv and QEMU fails the build.
Changing `SEED` or `NPROG` explores new programs; a failure is reproducible from
the seed and the offending hex ELF.