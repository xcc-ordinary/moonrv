///|
test "riscv-tests official suite: all green" {
  for entry in registry() {
    let (name, data) = entry
    if name == "hello" {
      continue
    }
    match run_data(data) {
      Some(r) => {
        if !r.pass {
          println(
            "FAIL \{name}: code=\{r.fail_code} bad_word=\{r.bad_word} steps=\{r.steps}",
          )
        }
        assert_eq(r.pass, true)
      }
      None => {
        println("LOAD FAIL \{name}")
        assert_eq(true, false)
      }
    }
  }
}

///|
test "hello-world ELF prints greeting and exits 0" {
  match run_data(hex_bytes(hello_rv32_hex)) {
    Some(r) => {
      assert_eq(r.pass, true)
      assert_eq(r.exit_code, 0L)
      assert_eq(r.stdout, "Hello, moonrv!\n")
    }
    None => assert_eq(true, false)
  }
}