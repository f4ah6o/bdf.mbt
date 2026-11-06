///|
fn raster_rows(data : Bytes) -> Array[Array[Int]] {
  let pages = read(data) catch { _ => [] }
  let out : Array[Array[Int]] = []
  if !pages.is_empty() {
    for row in pages[0].rows {
      out.push(row.to_array().map(fn(byte) { byte.to_int() }))
    }
  }
  out
}

///|
test "pwg stream round trip" {
  let page : Page = {
    ..Page::new(4, 3, 300, 300, SGRAY_8),
    page_width: 4,
    page_height: 3,
    total_pages: 1,
  }
  let writer = Writer::new()
  writer.start_page(page)
  writer.write_row(Bytes::from_array([1, 2, 3, 4].map(fn(v) { v.to_byte() })))
  writer.write_row(Bytes::from_array([5, 6, 7, 8].map(fn(v) { v.to_byte() })))
  writer.write_row(Bytes::from_array([9, 10, 11, 12].map(fn(v) { v.to_byte() })))
  let data = writer.close()
  let pages = read(data)
  assert_eq(pages.length(), 1)
  assert_eq(pages[0].page.width, 4)
  assert_eq(pages[0].page.height, 3)
  assert_eq(pages[0].page.typ, SGRAY_8)
  assert_eq(raster_rows(data), [[1, 2, 3, 4], [5, 6, 7, 8], [9, 10, 11, 12]])
}

///|
test "pwg stream repeats rows" {
  let page : Page = { ..Page::new(2, 3, 300, 300, SRGB_8) }
  let writer = Writer::new()
  writer.start_page(page)
  let row = Bytes::from_array([1, 2, 3, 4, 5, 6].map(fn(v) { v.to_byte() }))
  for _ in 0..<3 {
    writer.write_row(row)
  }
  let data = writer.close()
  assert_eq(raster_rows(data), [[1, 2, 3, 4, 5, 6], [1, 2, 3, 4, 5, 6], [1, 2, 3, 4, 5, 6]])
}

///|
test "pwg stream errors" {
  let writer = Writer::new()
  let before = try {
    writer.write_row(Bytes::from_array([0]))
    false
  } catch {
    RasterError(_) => true
  }
  assert_true(before, msg="a row before a page")
  let page : Page = { ..Page::new(2, 2, 300, 300, SGRAY_8) }
  writer.start_page(page)
  let wrong = try {
    writer.write_row(Bytes::from_array([0, 1, 2]))
    false
  } catch {
    RasterError(_) => true
  }
  assert_true(wrong, msg="a row of another width")
  ignore(writer.write_row(Bytes::from_array([0, 1])))
  ignore(writer.write_row(Bytes::from_array([2, 3])))
  let short = try {
    ignore(Writer::new().close())
    true
  } catch {
    RasterError(_) => false
  }
  assert_true(short, msg="an empty stream closes")
}

///|
test "pwg read limits" {
  let page : Page = { ..Page::new(2, 1, 300, 300, SGRAY_8) }
  let writer = Writer::new()
  writer.start_page(page)
  writer.write_row(Bytes::from_array([1, 2]))
  writer.start_page(page)
  writer.write_row(Bytes::from_array([3, 4]))
  let data = writer.close()
  assert_eq(read_limited(data, 2, 100).length(), 2)
  let pages = try {
    ignore(read_limited(data, 1, 100))
    false
  } catch {
    RasterError(_) => true
  }
  assert_true(pages, msg="too many pages")
  let pixels = try {
    ignore(read_limited(data, 2, 1))
    false
  } catch {
    RasterError(_) => true
  }
  assert_true(pixels, msg="too many pixels")
}

