///|
test "rv32ui-p official suite: all green" {
  for entry in registry() {
    let (name, data) = entry
    if name == "hello" {
      continue
    }
    match run_data(data) {
      Some(hart) => {
        if !hart.pass {
          println(
            "FAIL \{name}: code=\{hart.fail_code} bad_word=\{hart.bad_word} steps=\{hart.steps}",
          )
        }
        assert_eq(hart.pass, true)
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
  match run_data(hello_rv32) {
    Some(hart) => {
      assert_eq(hart.pass, true)
      assert_eq(hart.exit_code, 0)
      assert_eq(hart.stdout_string(), "Hello, moonrv!\n")
    }
    None => assert_eq(true, false)
  }
}