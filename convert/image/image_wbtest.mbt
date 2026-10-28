///|
test "BMP conversion stores the original and draws it as an accessible figure" {
  let bmp = b"BM\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x28\x00\x00\x00\x0c\x00\x00\x00\xf8\xff\xff\xff"
  let converted = convert(bmp, name="flag.bmp")
  assert_eq(converted.format, "bmp")
  assert_eq((converted.width, converted.height), (12.0, 8.0))
  assert_eq(converted.summary, "1 page (12 × 8 px, BMP)")
  let doc = @core.open_single(converted.bdf)
  assert_eq(doc.manifest.parts.length(), 2)
  assert_eq(doc.part(doc.manifest.parts[0].hash), bmp)
  let page = doc.manifest.views[0].pages[0]
  assert_eq((page.width, page.height), (9.0, 6.0))
  let object = @core.decode_object(doc.part(page.layers[0].object))
  assert_eq(object.bbox, (0.0, 0.0, 9.0, 6.0))
  assert_eq(object.strings, ["flag.bmp", ""])
  assert_eq(object.images, [doc.manifest.parts[0].hash])
  assert_eq(
    object.ops,
    b"\x71\x0a\x00\x42\x01\x02\x40\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x10\x41\x00\x00\xc0\x40\x71\x0b\x01",
  )
}

///|
test "ICO conversion chooses the largest icon and title supplies alt text" {
  let icon = b"\x00\x00\x01\x00\x02\x00\x10\x10\x00\x00\x01\x00\x08\x00\x01\x00\x00\x00\x26\x00\x00\x00\x00\x20\x00\x00\x01\x00\x20\x00\x01\x00\x00\x00\x27\x00\x00\x00\x00\x00"
  let result = convert(icon, title="Icon", name="icon.ico")
  assert_eq((result.format, result.width, result.height), ("ico", 256.0, 32.0))
  let doc = @core.open_single(result.bdf)
  let page = doc.manifest.views[0].pages[0]
  assert_eq(doc.manifest.views[0].title, "Icon")
  assert_eq((page.width, page.height), (192.0, 24.0))
  let object = @core.decode_object(doc.part(page.layers[0].object))
  assert_eq(object.strings, ["Icon", ""])
}

///|
test "image conversion rejects malformed and unsupported data" {
  for
    input in [
      b"", b"BM", b"BM\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x28\x00\x00\x00",
      b"\x89PNG\r\n\x1a\n",
    ] {
    let rejected = try {
      ignore(convert(input))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
