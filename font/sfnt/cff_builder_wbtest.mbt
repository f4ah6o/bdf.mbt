///|
test "bare CFF wraps into an OpenType font" {
  let cff = b"\x01\x00\x04\x01\x00\x01\x01\x01\x05Test\x00\x01\x01\x01\x07\x1d\x00\x00\x00\x1c\x11\x00\x00\x00\x00\x00\x01\x01\x01\x02\x0e"
  let otf = from_cff(
    cff,
    1000,
    2,
    [500, 600],
    Map([(65, 1)]),
    "Test CFF",
    400,
    false,
  )
  assert_true(otf.length() > 100)
  assert_eq(otf[:4], b"OTTO"[:])
  let mut cff_tag = false
  let mut index = 0
  while index + 4 <= otf.length() {
    if otf[index:index + 4] == b"CFF "[:] {
      cff_tag = true
    }
    index += 1
  }
  assert_true(cff_tag, msg="CFF table tag")
  let parsed = parse(otf)
  assert_eq(parsed.metrics.glyph_count, 2)
  assert_true(parsed.metrics.is_cff)
}
