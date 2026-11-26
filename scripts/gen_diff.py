#!/usr/bin/env python3
"""Generate a differential corpus: random RV32IM user-mode programs, run on
qemu-riscv32 to obtain the reference exit code, and emit a MoonBit regression
test that replays them in moonrv. Reproducible via fixed seed."""
import os, random, struct, subprocess, sys

SEED = 20261126
NPROG = 60
OUT = sys.argv[1] if len(sys.argv) > 1 else "diff_wbtest.mbt"
QEMU = "qemu-riscv32"
BASE = 0x10000

def addi(rd, rs1, imm):
    imm &= 0xFFF
    return (imm << 20) | (rs1 << 15) | (0 << 12) | (rd << 7) | 0x13

def rtype(f7, f3, rd, rs1, rs2):
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | 0x33

OPS = [
    (0x00,0),(0x20,0),(0x00,1),(0x00,2),(0x00,3),(0x00,4),
    (0x00,5),(0x20,5),(0x00,6),(0x00,7),
    (0x01,0),(0x01,1),(0x01,4),(0x01,5),(0x01,6),(0x01,7),
]
ECALL = 0x00000073

def make_program(rng):
    words = []
    # initialize registers 1..31 with random small values
    for r in range(1, 32):
        words.append(addi(r, 0, rng.randint(-1024, 1023)))
    # random register ops
    for _ in range(24):
        f7, f3 = rng.choice(OPS)
        rd = rng.randint(0, 31); rs1 = rng.randint(0, 31); rs2 = rng.randint(0, 31)
        words.append(rtype(f7, f3, rd, rs1, rs2))
    # move a random register into a0, exit(a0)
    src = rng.randint(0, 31)
    words.append(addi(10, src, 0))
    words.append(addi(17, 0, 93))
    words.append(ECALL)
    return words

def build_elf(words):
    # Assemble the raw instruction words into a proper static RV32 ELF via gcc,
    # so the image is loadable by both qemu-riscv32 and moonrv.
    src = "/tmp/diff_prog.S"
    out = "/tmp/diff_prog.elf"
    with open(src, "w") as f:
        f.write(".option norvc\n.globl _start\n_start:\n")
        for w in words:
            f.write(".word 0x%08x\n" % (w & 0xFFFFFFFF))
    subprocess.run(
        ["riscv64-unknown-elf-gcc", "-march=rv32ima", "-mabi=ilp32",
         "-nostdlib", "-static", "-Wl,-e,_start", "-o", out, src],
        check=True, capture_output=True)
    with open(out, "rb") as f:
        return f.read()

def main():
    rng = random.Random(SEED)
    pairs = []
    tmp = "/tmp/diff_prog.elf"
    for i in range(NPROG):
        words = make_program(rng)
        elf = build_elf(words)
        with open(tmp, "wb") as f:
            f.write(elf)
        os.chmod(tmp, 0o755)  # qemu-user requires the executable bit
        try:
            p = subprocess.run([QEMU, tmp], capture_output=True, timeout=10)
            code = p.returncode & 0xFF
        except Exception:
            continue
        pairs.append((elf.hex(), code))
    # emit MoonBit test
    lines = []
    lines.append("///|")
    lines.append("// Differential corpus generated against qemu-riscv32 (seed %d)." % SEED)
    lines.append("// Each entry: (ELF hex, reference exit code low 8 bits).")
    lines.append("let diff_corpus : Array[(String, Int)] = [")
    for h, c in pairs:
        lines.append('  ("%s", %d),' % (h, c))
    lines.append("]")
    lines.append("")
    lines.append("///|")
    lines.append('test "differential vs qemu-riscv32" {')
    lines.append("  for pair in diff_corpus {")
    lines.append("    let (hex, expected) = pair")
    lines.append("    match run_data(hex_bytes(hex)) {")
    lines.append("      Some(r) => assert_eq((r.exit_code & 0xFFL).to_int(), expected)")
    lines.append("      None => assert_eq(true, false)")
    lines.append("    }")
    lines.append("  }")
    lines.append("}")
    with open(OUT, "w") as f:
        f.write("\n".join(lines) + "\n")
    print("generated %d differential cases -> %s" % (len(pairs), OUT))

if __name__ == "__main__":
    main()