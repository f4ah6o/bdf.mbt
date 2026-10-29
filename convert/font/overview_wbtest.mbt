///|
test "overview formatting handles fractional values and date limits" {
  assert_eq(info_decimal(-1.0 / 65536.0), "-0")
  assert_eq(info_decimal(3.125), "3.125")
  assert_eq(info_bytesize(1536), "1.5 KB")
  assert_eq(
    info_head_time(b"\x00\x00\x00\x00\x00\x00\x00\x01"[:], 0),
    ("1904-01-01 00:00:01 UTC", "1904-01-01T00:00:01Z"),
  )
  assert_eq(info_head_time(b"\xff\xff\xff\xff\xff\xff\xff\xff"[:], 0), ("", ""))
}

///|
test "overview includes font counts and SFNT table list" {
  let file = load(small_font())
  let face = file.faces()[0]
  let sections = file.overview(face)
  assert_eq(sections.map(s => s.title), [
    "Names", "License", "Font", "Metrics (font units)",
  ])
  let counts = sections[2].rows
  assert_true(counts.any(r => r.label == "Glyphs" && r.value == "2"))
  assert_true(counts.any(r => r.label == "Characters" && r.value == "0"))
  let tables = face.table_list()
  assert_eq(tables.length(), 1)
  assert_eq(tables[0].label, "maxp")
  assert_eq(tables[0].value, "6 bytes")
}
