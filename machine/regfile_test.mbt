///|
test "x0 hardwired zero" {
  let rf = @machine.RegFile::new()
  rf.set(0, 42)
  assert_eq(rf.get(0), 0)
  rf.set(1, 7)
  assert_eq(rf.get(1), 7)
  rf.set(1, -3)
  assert_eq(rf.get(1), -3)
}