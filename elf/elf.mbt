///|
// Minimal ELF32 little-endian loader for static RISC-V executables. Parses the
// program headers, copies every PT_LOAD segment into base-relative guest
// memory, and locates the `tohost` symbol (the riscv-tests pass/fail mailbox)
// via the section-header symbol table. Input is a byte array (each 0..255) so
// the loader stays pure and testable on every backend, including wasm.
pub struct Elf {
  entry : Int
  base : Int
  tohost : Int // -1 when the ELF has no `tohost` symbol
  mem : @memory.Memory
}

///|
fn rd16(d : Array[Int], o : Int) -> Int {
  d[o] | (d[o + 1] << 8)
}

///|
fn rd32(d : Array[Int], o : Int) -> Int {
  d[o] | (d[o + 1] << 8) | (d[o + 2] << 16) | (d[o + 3] << 24)
}

///|
fn cstr(d : Array[Int], o : Int) -> String {
  let sb = StringBuilder()
  let mut i = o
  while i < d.length() && d[i] != 0 {
    sb.write_char(Int::unsafe_to_char(d[i]))
    i = i + 1
  }
  sb.to_string()
}

///|
// Find the value of the `tohost` symbol, or -1 if absent.
fn find_tohost(d : Array[Int]) -> Int {
  let shoff = rd32(d, 32)
  let shentsize = rd16(d, 46)
  let shnum = rd16(d, 48)
  if shoff == 0 || shnum == 0 {
    return -1
  }
  let mut sym_off = 0
  let mut sym_size = 0
  let mut sym_entsize = 16
  let mut str_off = 0
  for i = 0; i < shnum; i = i + 1 {
    let sh = shoff + i * shentsize
    let sh_type = rd32(d, sh + 4)
    if sh_type == 2 {
      // SHT_SYMTAB
      sym_off = rd32(d, sh + 16)
      sym_size = rd32(d, sh + 20)
      let ent = rd32(d, sh + 36)
      sym_entsize = if ent == 0 {
        16
      } else {
        ent
      }
      let link = rd32(d, sh + 24)
      str_off = rd32(d, shoff + link * shentsize + 16)
    }
  }
  if sym_off == 0 {
    return -1
  }
  let mut off = sym_off
  while off < sym_off + sym_size {
    let name_off = rd32(d, off)
    let value = rd32(d, off + 4)
    if cstr(d, str_off + name_off) == "tohost" {
      return value
    }
    off = off + sym_entsize
  }
  -1
}

///|
// Unsigned less-than on 32-bit Ints (guest addresses >= 0x8000_0000 are
// negative when read as signed Int, so segment bounds must compare unsigned).
fn ult(a : Int, b : Int) -> Bool {
  let min_int = -2147483647 - 1
  (a ^ min_int) < (b ^ min_int)
}

///|
// Load an ELF32 image. Returns None if the magic/class/encoding is not a
// little-endian ELF32 file.
pub fn load(d : Array[Int]) -> Elf? {
  if d.length() < 52 {
    return None
  }
  if d[0] != 0x7F || d[1] != 0x45 || d[2] != 0x4C || d[3] != 0x46 {
    return None
  }
  if d[4] != 1 || d[5] != 1 {
    // ELFCLASS32 + ELFDATA2LSB
    return None
  }
  let entry = rd32(d, 24)
  let phoff = rd32(d, 28)
  let phentsize = rd16(d, 42)
  let phnum = rd16(d, 44)
  let mut base = 0
  let mut end = 0
  let mut found = false
  for i = 0; i < phnum; i = i + 1 {
    let ph = phoff + i * phentsize
    if rd32(d, ph) == 1 {
      // PT_LOAD
      let paddr = rd32(d, ph + 12)
      let memsz = rd32(d, ph + 20)
      let pe = paddr + memsz
      if !found {
        base = paddr
        end = pe
        found = true
      } else {
        if ult(paddr, base) {
          base = paddr
        }
        if ult(end, pe) {
          end = pe
        }
      }
    }
  }
  if !found {
    return None
  }
  let mem = @memory.Memory::new_at(base, end - base + 0x10000)
  for i = 0; i < phnum; i = i + 1 {
    let ph = phoff + i * phentsize
    if rd32(d, ph) == 1 {
      let offset = rd32(d, ph + 4)
      let paddr = rd32(d, ph + 12)
      let filesz = rd32(d, ph + 16)
      for j = 0; j < filesz; j = j + 1 {
        mem.write_u8(paddr + j, d[offset + j])
      }
    }
  }
  Some({ entry, base, tohost: find_tohost(d), mem })
}