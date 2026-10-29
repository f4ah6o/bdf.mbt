///|
test "TrueType outlines decode implied points and stop recursive composites" {
  let head = Bytes::make(54, 0).to_array()
  put16(head, 18, 1000)
  let glyf = b"\x00\x01\x00\x00\x00\x00\x00\x0a\x00\x0a\x00\x01\x00\x00\x36\x36\x00\x0a\x00\x0a\xff\xff\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x01\x00\x00"
  let tables : Map[String, Array[Byte]] = {
    "head": head,
    "maxp": b"\x00\x01\x00\x00\x00\x03".to_array(),
    "loca": b"\x00\x00\x00\x0a\x00\x12\x00\x12".to_array(),
    "glyf": glyf.to_array(),
  }
  let font = parse(build_tables(tables, false))
  let (ok, path) = font.outline_truetype(0)
  assert_true(ok)
  assert_eq(path, [
    Move(5.0, 5.0),
    Quad(0.0, 0.0, 5.0, 5.0),
    Quad(10.0, 10.0, 5.0, 5.0),
    Close,
  ])
  assert_false(font.outline_truetype(1).0)
  assert_true(font.outline_truetype(2).0)
  assert_false(font.outline_truetype(3).0)
}
