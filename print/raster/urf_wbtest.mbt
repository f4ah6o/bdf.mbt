///|
test "urf header" {
  let page : Page = {
    ..Page::new(120, 80, 300, 300, SGRAY_8),
    quality: 4,
    media_position: 2,
  }
  let header = urf_header(page)
  assert_eq(header.length(), URF_HEADER_SIZE)
  assert_eq(header[0].to_int(), 8)
  assert_eq(header[1].to_int(), 0)
  assert_eq(header[2].to_int(), 1)
  assert_eq(header[3].to_int(), 4)
  assert_eq(header[5].to_int(), 2)
  assert_eq(raster_read_u32(header, 12), 120)
  assert_eq(raster_read_u32(header, 16), 80)
  assert_eq(raster_read_u32(header, 20), 300)
  let rgb : Page = { ..Page::new(10, 20, 300, 300, SRGB_8), duplex: true, tumble: true }
  let rgb_header = urf_header(rgb)
  assert_eq(rgb_header[0].to_int(), 24)
  assert_eq(rgb_header[1].to_int(), 1)
  assert_eq(rgb_header[2].to_int(), 2)
  let bad = try {
    ignore(urf_header({ ..Page::new(1, 1, 300, 300, BLACK_1) }))
    false
  } catch {
    RasterError(_) => true
  }
  assert_true(bad, msg="Apple Raster has no one-bit type")
}

///|
test "urf stream round trip" {
  let page : Page = { ..Page::new(2, 2, 300, 300, SGRAY_8) }
  let writer = Writer::new_urf(1)
  writer.start_page(page)
  writer.write_row(Bytes::from_array([10, 20].map(fn(v) { v.to_byte() })))
  writer.write_row(Bytes::from_array([30, 40].map(fn(v) { v.to_byte() })))
  let data = writer.close()
  let pages = read_urf(data)
  assert_eq(pages.length(), 1)
  assert_eq(pages[0].page.width, 2)
  assert_eq(pages[0].page.height, 2)
  assert_eq(pages[0].page.typ, SGRAY_8)
  assert_eq(pages[0].page.xdpi, 300)
  assert_eq(pages[0].rows[0].to_array().map(fn(b) { b.to_int() }), [10, 20])
  assert_eq(pages[0].rows[1].to_array().map(fn(b) { b.to_int() }), [30, 40])
  let not_urf = try {
    ignore(read_urf(Bytes::from_array([1, 2, 3])))
    false
  } catch {
    RasterError(_) => true
  }
  assert_true(not_urf, msg="not an Apple Raster stream")
}
