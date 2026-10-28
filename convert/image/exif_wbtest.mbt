///|
test "EXIF directory parsing reads little-endian values and offsets" {
  let input = b"Exif\x00\x00II\x2a\x00\x08\x00\x00\x00\x02\x00\x12\x01\x03\x00\x01\x00\x00\x00\x06\x00\x00\x00\x0e\x01\x02\x00\x06\x00\x00\x00\x26\x00\x00\x00\x00\x00\x00\x00hello\x00"
  guard exif_fields(input) is Some(fields) else { fail("valid EXIF rejected") }
  assert_true(fields.little)
  assert_eq(fields.orientation, 6)
  assert_eq(fields.primary.get(0x010e), Some(b"hello\x00"))
}

///|
test "EXIF directory parsing reads big-endian values" {
  let input = b"MM\x00\x2a\x00\x00\x00\x08\x00\x01\x01\x12\x00\x03\x00\x00\x00\x01\x00\x08\x00\x00\x00\x00\x00\x00"
  guard exif_fields(input) is Some(fields) else { fail("valid EXIF rejected") }
  assert_false(fields.little)
  assert_eq(fields.orientation, 8)
}

///|
test "EXIF parser accepts truncation without out-of-bounds access" {
  let input = b"Exif\x00\x00II\x2a\x00\x08\x00\x00\x00\x01\x00\x12\x01\x03\x00\x01\x00\x00\x00\x06\x00\x00\x00"
  for n in 0..<=input.length() {
    ignore(exif_fields(input[:n].to_bytes()))
  }
  assert_true(exif_fields(b"not EXIF") is None)
}

///|
test "EXIF ignores oversized TIFF values and invalid orientations" {
  let data = b"II\x2a\x00\x08\x00\x00\x00\x02\x00\x12\x01\x03\x00\x01\x00\x00\x00\x09\x00\x00\x00\x0e\x01\x0c\x00\xff\xff\xff\xff\xff\xff\xff\xff"
  guard exif_fields(data) is Some(fields) else {
    fail("TIFF directory should be readable")
  }
  assert_eq(fields.orientation, 0)
  assert_true(fields.primary.get(0x010e) is None)
}
