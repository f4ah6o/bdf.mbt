///|
test "GSUB substitution closure follows chains" {
  let data = b"\x00\x01\x00\x00\x00\x00\x00\x00\x00\x0a\x00\x01\x00\x04\x00\x01\x00\x00\x00\x01\x00\x08\x00\x02\x00\x0a\x00\x02\x00\x02\x00\x03\x00\x01\x00\x02\x00\x01\x00\x02"
  let table = parse_gsub(data[:]).unwrap()
  assert_eq(table.reachable([1]), [1, 2, 3])
  assert_false(table.truncated())
}

///|
test "invalid GSUB headers are rejected" {
  assert_true(parse_gsub(b""[:]) is None)
  assert_true(
    parse_gsub(b"\x00\x02\x00\x00\x00\x00\x00\x00\x00\x00"[:]) is None,
  )
}

///|
test "GSUB lookup budget stays exhausted across calls" {
  let data = b"\x00\x01\x00\x00\x00\x00\x00\x00\x00\x0a\x00\x01\x00\x04\x00\x01\x00\x00\x00\x01\x00\x08\x00\x02\x00\x0a\x00\x02\x00\x02\x00\x03\x00\x01\x00\x02\x00\x01\x00\x02"
  let table = parse_gsub(data[:]).unwrap()
  table.steps = 1L
  assert_eq(table.reachable([1]), [1])
  assert_true(table.truncated())
  assert_eq(table.reachable([1]), [1])
  assert_true(table.truncated())
}
