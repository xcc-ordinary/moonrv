///|
// Sieve of Eratosthenes benchmark (sieve.c, gcc -O2, freestanding). Counts primes
// below 8192 (= 1028) on both RV32 and RV64, exercising .bss, nested loops and
// byte stores. Used by `moonrv bench` for instruction-count comparison.
test "sieve benchmark: primes below 8192 (rv32 + rv64)" {
  match run_data(hex_bytes(sieve_rv32_hex)) {
    Some(r) => {
      assert_eq(r.exit_code, 0L)
      assert_eq(r.stdout, "primes=1028\n")
    }
    None => assert_eq(true, false)
  }
  match run_data(hex_bytes(sieve_rv64_hex)) {
    Some(r) => {
      assert_eq(r.exit_code, 0L)
      assert_eq(r.stdout, "primes=1028\n")
    }
    None => assert_eq(true, false)
  }
}