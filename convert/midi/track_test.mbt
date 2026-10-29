///|
test "track scanner preserves running status across system and meta events" {
  let body = b"\x00\x90\x3c\x64\x00\xf0\x01\x7f\x00\xff\x03\x01x\x60\x3c\x00\x00\xff\x2f\x00\xff"
  let scan = @midi.scan_track(body, 1000L)
  assert_false(scan.damaged)
  assert_true(scan.saw_end)
  assert_eq(scan.end_tick, 96L)
  assert_eq(scan.parsed, body.length() - 1)
  assert_eq(scan.events.length(), 5)
  assert_eq(scan.events[3].status, 0x90)
  assert_eq(scan.events[3].data, b"\x3c\x00")
  assert_eq(scan.events[2].kind, 3)
  assert_eq(scan.events[2].data, b"x")
}

///|
test "track scanner retains the last complete event at a cut" {
  let scan = @midi.scan_track(b"\x00\xc0\x07\x81\x80\x80\x80", 1000L)
  assert_true(scan.damaged)
  assert_false(scan.saw_end)
  assert_eq(scan.parsed, 3)
  assert_eq(scan.problem, "a delta time longer than 4 bytes")
  assert_eq(scan.events.length(), 1)
  let long = @midi.scan_track(b"\x00\xc0\x07\x7f\x90\x3c\x40", 20L)
  assert_true(long.damaged)
  assert_eq(long.problem, "long")
  assert_eq(long.parsed, 3)
}
