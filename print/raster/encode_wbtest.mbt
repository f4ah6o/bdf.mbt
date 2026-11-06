///|
test "encode pwg image" {
  let image = RasterImage::new(
    2,
    2,
    Bytes::from_array([
      255, 0, 0, 255, 0, 255, 0, 255,
      0, 0, 255, 255, 255, 255, 255, 255,
    ].map(fn(v) { v.to_byte() })),
  )
  let page : Page = { ..Page::new(2, 2, 300, 300, SRGB_8) }
  let data = encode_pwg(page, image)
  let pages = read(data)
  assert_eq(pages.length(), 1)
  assert_eq(pages[0].rows[0].to_array().map(fn(b) { b.to_int() }), [255, 0, 0, 0, 255, 0])
  assert_eq(pages[0].rows[1].to_array().map(fn(b) { b.to_int() }), [0, 0, 255, 255, 255, 255])
}

///|
test "encode urf image" {
  let image = RasterImage::new(
    2,
    1,
    Bytes::from_array([10, 10, 10, 255, 20, 20, 20, 255].map(fn(v) { v.to_byte() })),
  )
  let page : Page = { ..Page::new(2, 1, 300, 300, SGRAY_8) }
  let data = encode_urf(page, image)
  let pages = read_urf(data)
  assert_eq(pages.length(), 1)
  assert_eq(pages[0].page.typ, SGRAY_8)
  assert_eq(pages[0].rows[0].to_array().map(fn(b) { b.to_int() }), [10, 20])
}

///|
test "encode pclm image" {
  let image = RasterImage::new(
    2,
    1,
    Bytes::from_array([10, 10, 10, 255, 20, 20, 20, 255].map(fn(v) { v.to_byte() })),
  )
  let page : Page = { ..Page::new(2, 1, 300, 300, SGRAY_8) }
  let data = encode_pclm(page, image, { strip_height: 16, compression: "flate" })
  let text = @utf8.decode_lossy(data)
  assert_true(text.contains("%PCLm 1.0"))
  assert_true(text.contains("/DeviceGray"))
  let wrong = try {
    ignore(encode_pwg(page, RasterImage::new(1, 1, Bytes::from_array([0, 0, 0, 255].map(fn(v) { v.to_byte() })))))
    false
  } catch {
    RasterError(_) => true
  }
  assert_true(wrong, msg="image and page sizes")
}
