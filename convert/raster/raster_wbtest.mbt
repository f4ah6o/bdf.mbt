///|
fn raster_test_chunk(png : Bytes, kind : Bytes) -> Bytes {
  let mut offset = 8
  while offset + 12 <= png.length() {
    let length = (png[offset].to_int() << 24) |
      (png[offset + 1].to_int() << 16) |
      (png[offset + 2].to_int() << 8) |
      png[offset + 3].to_int()
    if length < 0 || offset + 12 + length > png.length() {
      return b""
    }
    if png[offset + 4:offset + 8] == kind[:] {
      return png[offset + 8:offset + 8 + length].to_bytes()
    }
    offset += 12 + length
  }
  b""
}

///|
test "PNG encoding writes RGBA scanlines with filter 0" {
  let rgba = b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10"
  let png = encode_png(2, 2, rgba)
  assert_eq(png[:8], b"\x89PNG\r\n\x1a\n"[:])
  let header = raster_test_chunk(png, b"IHDR")
  assert_eq(header.length(), 13)
  assert_eq(header[0:4], b"\x00\x00\x00\x02"[:])
  assert_eq(header[4:8], b"\x00\x00\x00\x02"[:])
  assert_eq(header[8], 8)
  assert_eq(header[9], 6)
  let raw = @zlib.decompress(raster_test_chunk(png, b"IDAT")) catch { _ => b"" }
  assert_eq(
    raw, b"\x00\x01\x02\x03\x04\x05\x06\x07\x08\x00\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10",
  )
  assert_eq(raster_test_chunk(png, b"IEND").length(), 0)
}

///|
test "PNG encoding rejects bad sizes and buffers" {
  let rejected = fn(width : Int32, height : Int32, rgba : Bytes) {
    try {
      ignore(encode_png(width, height, rgba))
      false
    } catch {
      _ => true
    }
  }
  assert_true(rejected(0, 1, b""))
  assert_true(rejected(1, 0, b""))
  assert_true(rejected(2, 2, b"\x00\x00\x00\x00"))
}

///|
test "box resize averages premultiplied RGBA" {
  let src = b"\x00\x00\x00\xff\xff\x00\x00\xff\x00\x00\x00\xff\xff\x00\x00\xff"
  let out = resize_box(src, 2, 2, 1, 1)
  assert_eq(out, b"\x80\x00\x00\xff")
}

///|
test "box resize keeps two-colour ink coverage" {
  // Three black pixels and one white pixel: the ink covers 3/4 of the
  // target, above the two-fifths threshold.
  let src = b"\x00\x00\x00\xff\x00\x00\x00\xff\x00\x00\x00\xff\xff\xff\xff\xff"
  assert_eq(resize_box(src, 2, 2, 1, 1, bilevel=true), b"\x00\x00\x00\xff")
  // One black pixel and three white ones: the ink covers 1/4, below it.
  let paper = b"\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\x00\x00\x00\xff"
  assert_eq(resize_box(paper, 2, 2, 1, 1, bilevel=true), b"\xff\xff\xff\xff")
}

///|
test "box resize does not scale up" {
  let src = b"\x01\x02\x03\x04"
  assert_eq(resize_box(src, 1, 1, 2, 2), src)
}

///|
test "fit size caps the resolution and the pixel count" {
  assert_eq(fit_size(1000, 500, 72.0, 36.0), (192, 96))
  assert_eq(fit_size(1000, 500, 1000.0, 500.0), (1000, 500))
  let (w, h) = fit_size(
    4000,
    4000,
    4000.0,
    4000.0,
    max_dpi=10000.0,
    max_pixels=1000000L,
  )
  assert_true(w.to_int64() * h.to_int64() <= 1000000L)
  assert_eq(fit_size(10, 10, 10.0, 10.0, max_pixels=-1L), (10, 10))
}

///|
test "raster document stores one image per page" {
  let png = encode_png(1, 1, b"\x01\x02\x03\x04")
  let result = write_document(
    [
      {
        image: png,
        format: "png",
        width_px: 1,
        height_px: 1,
        draw_width: 10.0,
        draw_height: 20.0,
        page_width: 10.0,
        page_height: 20.0,
        transform: None,
        alt: "a pixel",
      },
    ],
    title="Raster",
    source="test",
  )
  let doc = @core.open_single(result)
  assert_eq(doc.manifest.views.length(), 1)
  assert_eq(doc.manifest.views[0].title, "Raster")
  let page = doc.manifest.views[0].pages[0]
  assert_eq((page.width, page.height), (10.0, 20.0))
  assert_eq(page.layers.length(), 1)
  assert_eq(page.layers[0].role, "body")
  let object = @core.decode_object(doc.part(page.layers[0].object))
  assert_eq(object.bbox, (0.0, 0.0, 10.0, 20.0))
  assert_eq(object.strings, ["a pixel", ""])
  assert_eq(object.images.length(), 1)
  assert_eq(doc.part(object.images[0]), png)
}
