///|
test "ISO BMFF boxes handle extended, end-sized and truncated boxes" {
  let data = b"\x00\x00\x00\x0btestabc\x00\x00\x00\x01wide\x00\x00\x00\x00\x00\x00\x00\x13xyz\x00\x00\x00\x00tailok"
  let boxes = iso_boxes(data)
  assert_eq(boxes.length(), 3)
  assert_eq(iso_find(boxes, b"test").to_bytes(), b"abc")
  assert_eq(iso_find(boxes, b"wide").to_bytes(), b"xyz")
  assert_eq(iso_find(boxes, b"tail").to_bytes(), b"ok")
  for n in 0..<=data.length() {
    ignore(iso_boxes(data[:n]))
  }
  assert_eq(
    iso_boxes(b"\x00\x00\x00\x01wide\xff\xff\xff\xff\xff\xff\xff\xff").length(),
    0,
  )
}
