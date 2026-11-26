///|
// Real gcc-compiled freestanding C program (fib.c, -O2 -march=rv32imac): computes
// fib(20), allocates a buffer via anonymous mmap, queries getpid, and writes
// through both the static data segment and the mmap'd region. Exercises the
// wider Linux syscall subset (mmap / getpid / write / exit) on optimized C code.
test "freestanding C program: fib + mmap + getpid" {
  match run_data(hex_bytes(fib_rv32_hex)) {
    Some(r) => {
      assert_eq(r.exit_code, 0L)
      assert_eq(r.stdout, "fib20=6765\npid=1\nOK\n")
    }
    None => assert_eq(true, false)
  }
}