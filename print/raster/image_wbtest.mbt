///|
test "row conversion" {
  let image = RasterImage::new(
    2,
    1,
    Bytes::from_array([
      255, 0, 0, 255, 255, 255, 255, 255,
    ].map(fn(v) { v.to_byte() })),
  )
  assert_eq(row_bytes(image, 0, SRGB_8).to_array().map(fn(b) { b.to_int() }), [255, 0, 0, 255, 255, 255])
  let gray = row_bytes(image, 0, SGRAY_8).to_array().map(fn(b) { b.to_int() })
  assert_true(gray[0] >= 75 && gray[0] <= 77, msg="red luma")
  assert_eq(gray[1], 255)
  assert_eq(row_bytes(image, 0, BLACK_1).to_array().map(fn(b) { b.to_int() }), [0x80])
  assert_eq(row_bytes(image, 0, SGRAY_1).to_array().map(fn(b) { b.to_int() }), [0x7f])
  let clear = RasterImage::new(
    1,
    1,
    Bytes::from_array([255, 0, 0, 0].map(fn(v) { v.to_byte() })),
  )
  assert_eq(row_bytes(clear, 0, SGRAY_8).to_array().map(fn(b) { b.to_int() }), [255])
}

///|
test "writer image rows" {
  let page : Page = { ..Page::new(2, 2, 300, 300, SRGB_8) }
  let image = RasterImage::new(
    2,
    2,
    Bytes::from_array([
      255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 255, 255,
    ].map(fn(v) { v.to_byte() })),
  )
  let writer = Writer::new()
  writer.start_page(page)
  writer.write_image_row(image, 0)
  writer.write_image_row(image, 1)
  let data = writer.close()
  let pages = read(data)
  assert_eq(pages[0].rows[0].to_array().map(fn(b) { b.to_int() }), [255, 0, 0, 0, 255, 0])
  assert_eq(pages[0].rows[1].to_array().map(fn(b) { b.to_int() }), [0, 0, 255, 255, 255, 255])
  let wrong = RasterImage::new(1, 1, Bytes::from_array([0, 0, 0, 255].map(fn(v) { v.to_byte() })))
  let failed = try {
    writer.write_image_row(wrong, 0)
    false
  } catch {
    RasterError(_) => true
  }
  assert_true(failed, msg="another width")
}
