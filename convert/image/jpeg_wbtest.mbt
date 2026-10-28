///|
test "JPEG dimensions and EXIF orientation" {
  let plain = b"\xff\xd8\xff\xc0\x00\x07\x08\x00\x05\x00\x07\xff\xd9"
  let result = convert(plain, name="photo.jpg")
  assert_eq((result.format, result.width, result.height), ("jpeg", 7.0, 5.0))
  assert_eq(result.summary, "1 page (7 × 5 px, JPEG)")
  let turned = b"\xff\xd8\xff\xe1\x00\x22Exif\x00\x00II\x2a\x00\x08\x00\x00\x00\x01\x00\x12\x01\x03\x00\x01\x00\x00\x00\x06\x00\x00\x00\x00\x00\x00\x00\xff\xc0\x00\x07\x08\x00\x05\x00\x07\xff\xd9"
  let rotated = convert(turned)
  assert_eq((rotated.width, rotated.height), (5.0, 7.0))
}

///|
test "JPEG rejects metadata that has not yet been ported" {
  let xmp = b"\xff\xd8\xff\xe1\x00\x1fhttp://ns.adobe.com/xap/1.0/\x00\xff\xc0\x00\x07\x08\x00\x05\x00\x07"
  let rejected = try {
    ignore(convert(xmp))
    false
  } catch {
    ImageFailure(message) => message.contains("XMP")
    _ => false
  }
  assert_true(rejected)
}
