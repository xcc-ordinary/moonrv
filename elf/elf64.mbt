///|
// ELF64 little-endian loader. The milestone rv64ui/um images load within the
// 32-bit address range (base 0x8000_0000), so segment addresses are kept as Int
// and the same base-relative `Memory` / `Elf` shape is reused; the exec64 hart
// widens registers/pc to Int64. Full 64-bit address spaces are future work.

///|
fn rd64(d : Array[Int], o : Int) -> Int64 {
  let lo = rd32(d, o).to_int64() & 0xFFFFFFFFL
  let hi = rd32(d, o + 4).to_int64() & 0xFFFFFFFFL
  lo | (hi << 32)
}

///|
fn find_tohost64(d : Array[Int]) -> Int {
  let shoff = rd64(d, 40).to_int()
  let shentsize = rd16(d, 58)
  let shnum = rd16(d, 60)
  if shoff == 0 || shnum == 0 {
    return -1
  }
  let mut sym_off = 0
  let mut sym_size = 0
  let mut sym_entsize = 24
  let mut str_off = 0
  for i = 0; i < shnum; i = i + 1 {
    let sh = shoff + i * shentsize
    if rd32(d, sh + 4) == 2 {
      // SHT_SYMTAB
      sym_off = rd64(d, sh + 24).to_int()
      sym_size = rd64(d, sh + 32).to_int()
      let ent = rd64(d, sh + 56).to_int()
      sym_entsize = if ent == 0 {
        24
      } else {
        ent
      }
      let link = rd32(d, sh + 40)
      str_off = rd64(d, shoff + link * shentsize + 24).to_int()
    }
  }
  if sym_off == 0 {
    return -1
  }
  let mut off = sym_off
  while off < sym_off + sym_size {
    let name_off = rd32(d, off)
    let value = rd64(d, off + 8).to_int()
    if cstr(d, str_off + name_off) == "tohost" {
      return value
    }
    off = off + sym_entsize
  }
  -1
}

///|
pub fn load64(d : Array[Int]) -> Elf? {
  if d.length() < 64 {
    return None
  }
  if d[0] != 0x7F || d[1] != 0x45 || d[2] != 0x4C || d[3] != 0x46 {
    return None
  }
  if d[4] != 2 || d[5] != 1 {
    // ELFCLASS64 + ELFDATA2LSB
    return None
  }
  let entry = rd64(d, 24).to_int()
  let phoff = rd64(d, 32).to_int()
  let phentsize = rd16(d, 54)
  let phnum = rd16(d, 56)
  let mut base = 0
  let mut end = 0
  let mut found = false
  for i = 0; i < phnum; i = i + 1 {
    let ph = phoff + i * phentsize
    if rd32(d, ph) == 1 {
      let paddr = rd64(d, ph + 24).to_int()
      let memsz = rd64(d, ph + 40).to_int()
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
      let offset = rd64(d, ph + 8).to_int()
      let paddr = rd64(d, ph + 24).to_int()
      let filesz = rd64(d, ph + 32).to_int()
      for j = 0; j < filesz; j = j + 1 {
        mem.write_u8(paddr + j, d[offset + j])
      }
    }
  }
  Some({ entry, base, tohost: find_tohost64(d), mem })
}