///|
test "pclm run length" {
  let data = Bytes::from_array([1, 2, 3, 3].map(fn(v) { v.to_byte() }))
  assert_eq(pclm_run_length(data).to_array().map(fn(b) { b.to_int() }), [1, 1, 2, 255, 3, 128])
  assert_eq(pclm_num(0.24), "0.24")
  assert_eq(pclm_num(72.0 / 300.0), "0.24")
}

///|
test "pclm stream" {
  let writer = PclmWriter::new({ strip_height: 1, compression: "rle" })
  let page : Page = {
    ..Page::new(4, 2, 300, 300, SGRAY_8),
    page_width: 4,
    page_height: 2,
  }
  writer.start_page(page)
  writer.write_row(Bytes::from_array([1, 2, 3, 4].map(fn(v) { v.to_byte() })))
  writer.write_row(Bytes::from_array([5, 6, 7, 8].map(fn(v) { v.to_byte() })))
  let data = writer.close()
  let text = @utf8.decode_lossy(data)
  assert_true(text.contains("%PDF-1.7"), msg="PDF header")
  assert_true(text.contains("%PCLm 1.0"), msg="PCLm header")
  assert_true(text.contains("/DeviceGray"), msg="gray space")
  assert_true(text.contains("/RunLengthDecode"), msg="RLE filter")
  assert_true(text.contains("/Count 1"), msg="one page")
  assert_true(text.contains("startxref"), msg="xref")
}

///|
test "pclm rgb and errors" {
  let writer = PclmWriter::new({ strip_height: 16, compression: "" })
  let page : Page = { ..Page::new(2, 1, 300, 300, SRGB_8) }
  writer.start_page(page)
  writer.write_row(Bytes::from_array([1, 2, 3, 4, 5, 6].map(fn(v) { v.to_byte() })))
  let data = writer.close()
  let text = @utf8.decode_lossy(data)
  assert_true(text.contains("/DeviceRGB"), msg="RGB space")
  assert_true(text.contains("/FlateDecode"), msg="flate filter")
  let bad_type = try {
    ignore(PclmWriter::new({ strip_height: 16, compression: "rle" }).start_page({ ..Page::new(1, 1, 300, 300, BLACK_1) }))
    false
  } catch {
    RasterError(_) => true
  }
  assert_true(bad_type, msg="one-bit PCLm")
  let bad_compression = try {
    ignore(PclmWriter::new({ strip_height: 16, compression: "zip" }))
    false
  } catch {
    RasterError(_) => true
  }
  assert_true(bad_compression, msg="unknown compression")
  let short = try {
    let w = PclmWriter::new({ strip_height: 16, compression: "rle" })
    w.start_page({ ..Page::new(2, 2, 300, 300, SGRAY_8) })
    ignore(w.close())
    false
  } catch {
    RasterError(_) => true
  }
  assert_true(short, msg="a page short of rows")
}

///|
test "pclm image rows" {
  let writer = PclmWriter::new({ strip_height: 16, compression: "rle" })
  writer.start_page({ ..Page::new(2, 1, 300, 300, SGRAY_8) })
  let image = RasterImage::new(
    2,
    1,
    Bytes::from_array([10, 10, 10, 255, 20, 20, 20, 255].map(fn(v) { v.to_byte() })),
  )
  writer.write_image_row(image, 0)
  let data = writer.close()
  assert_true(@utf8.decode_lossy(data).contains("/DeviceGray"))
}

