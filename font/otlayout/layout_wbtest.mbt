///|
test "layout script features and filtered lookups" {
  let data : Bytes = b"\x00\x01\x00\x00\x00\x0a\x00\x20\x00\x3a\x00\x01\x6c\x61\x74\x6e\x00\x08\x00\x04\x00\x00\x00\x00\x00\x00\x00\x02\x00\x00\x00\x01\x00\x02\x6c\x69\x67\x61\x00\x0e\x6b\x65\x72\x6e\x00\x14\x00\x00\x00\x01\x00\x00\x00\x00\x00\x01\x00\x09\x00\x01\x00\x04\x00\x01\x00\x10\x00\x00\x00\x03"
  let table = parse_layout(data[:]).unwrap()
  assert_eq(table.scripts.length(), 1)
  assert_eq(table.scripts[0].tag, "latn")
  assert_eq(table.features.length(), 2)
  assert_eq(table.features[0].lookups, [0])
  assert_eq(table.features[1].lookups, [])
  assert_eq(table.lookups[0].mark_set, 3)
  assert_eq(table.script_features(), [["latn"], ["latn"]])
}
