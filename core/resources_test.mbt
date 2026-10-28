///|
// Encoded by shibukawa/bdf at 4f9af52 using Object.Encode with all paint
// variants, a system font, an embedded font and an image reference.
test "upstream object retains paints and fonts" {
  let decoded = @core.decode_object_resources(
    b"\x42\x4f\x42\x4a\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xa0\x41\x00\x00\xa0\x41\x00\x00\x04\x00\x00\x00\x80\x3f\x00\x00\x00\x40\x00\x00\x40\x40\x00\x00\x80\x40\x02\x00\x00\x80\xbf\x44\x33\x22\x11\x00\x00\x00\x40\xdd\xcc\xbb\xaa\x01\x00\x00\x80\x3f\x00\x00\x00\x40\x00\x00\x40\x40\x00\x00\x80\x40\x00\x00\xa0\x40\x00\x00\xc0\x40\x00\x02\x00\x00\x80\x3f\x00\x00\x00\x40\x00\x00\x40\x40\x00\x03\x00\x01\x00\x00\x80\x3f\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x80\x3f\x00\x00\x00\x00\x00\x00\x00\x00\x02\x01\x05\x73\x65\x72\x69\x66\xbc\x02\x01\x00\x04\x05\x06\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x90\x01\x00\x01\x01\x02\x03\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x1d\x11\x00\x13\x01\x11\x02\x1a\x00\x00\x00\x40\x41\x20\x00\x00\x80\x3f\x00\x00\x00\x40\x00\x00\x40\x40\x00\x00\x80\x40",
  )
  assert_eq(decoded.paints.length(), 4)
  guard decoded.paints[0] is Gradient(0, coords, stops) else {
    fail("linear gradient")
  }
  assert_eq(coords, [1.0, 2.0, 3.0, 4.0])
  assert_eq(stops.length(), 2)
  assert_eq((stops[0].offset, stops[0].color), (-1.0, 0x11223344))
  assert_eq(stops[1].offset, 2.0)
  guard decoded.paints[1] is Gradient(1, radial, _) else {
    fail("radial gradient")
  }
  assert_eq(radial, [1.0, 2.0, 3.0, 4.0, 5.0, 6.0])
  guard decoded.paints[2] is Gradient(2, conic, _) else {
    fail("conic gradient")
  }
  assert_eq(conic, [1.0, 2.0, 3.0])
  guard decoded.paints[3] is Pattern(image, repeat, matrix) else {
    fail("pattern")
  }
  assert_eq((image, repeat), (0, 1))
  assert_eq(matrix, [1.0, 0.0, 0.0, 1.0, 0.0, 0.0])
  assert_eq(decoded.fonts[0].family, "serif")
  assert_eq(
    (decoded.fonts[0].hash, decoded.fonts[0].weight, decoded.fonts[0].style),
    (None, 700, 1),
  )
  assert_eq(decoded.fonts[1].hash, Some("04050600000000000000000000000000"))
  assert_eq(decoded.fonts[1].weight, 400)
  assert_eq(decoded.object.images[0], "01020300000000000000000000000000")
}

///|
test "truncated paint resources are rejected" {
  let bad : Bytes = b"BOBJ\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00"
  let rejected = try {
    ignore(@core.decode_object_resources(bad))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}
