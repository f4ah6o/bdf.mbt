///|
fn tiff_test_png_size(data : Bytes) -> (Int32, Int32) {
  if data.length() < 24 || data[:8] != b"\x89PNG\r\n\x1a\n"[:] {
    return (0, 0)
  }
  let width = (data[16].to_int() << 24) |
    (data[17].to_int() << 16) |
    (data[18].to_int() << 8) |
    data[19].to_int()
  let height = (data[20].to_int() << 24) |
    (data[21].to_int() << 16) |
    (data[22].to_int() << 8) |
    data[23].to_int()
  (width, height)
}

///|
fn tiff_test_near(a : Double, b : Double) -> Bool {
  let difference = a - b
  (if difference < 0.0 { -difference } else { difference }) < 0.01
}

///|
fn tiff_test_fixture(text : String) -> Bytes {
  @base64.decode(text, ignore_whitespace=true) catch {
    _ => b""
  }
}

///|
test "TIFF detection excludes CR2 raw files" {
  assert_true(detect(tiff_test_fixture(tiff_fixture_scan)))
  assert_true(detect(tiff_test_fixture(tiff_fixture_fax)))
  assert_true(detect(tiff_test_fixture(tiff_fixture_orientation)))
  assert_true(detect(b"II*\x00"))
  let raw = b"II*\x00\x08\x00\x00\x00CR\x02\x00"
  assert_false(detect(raw))
}

///|
test "Group 4 scan page is scaled to the resolution cap" {
  let data = tiff_test_fixture(tiff_fixture_scan)
  let result = convert(data)
  assert_eq(result.pages, 3)
  assert_eq(result.summary, "3 page(s), 1 scaled down to the resolution cap")
  assert_eq(result.warnings, [
    "page 2: TIFF: JPEG-compressed pages are not supported; the page is left blank",
  ])
  let doc = @core.open_single(result.bdf)
  let page = doc.manifest.views[0].pages[0]
  assert_true(tiff_test_near(page.width, 240.0))
  assert_true(tiff_test_near(page.height, 312.0))
  let object = @core.decode_object(doc.part(page.layers[0].object))
  assert_eq(object.images.length(), 1)
  let image = doc.part(object.images[0])
  assert_eq(tiff_test_png_size(image), (640, 832))
}

///|
test "Group 3 fax page keeps its aspect ratio" {
  let data = tiff_test_fixture(tiff_fixture_fax)
  let result = convert(data)
  assert_eq(result.pages, 2)
  assert_eq(result.summary, "2 page(s), 2 scaled down to the resolution cap")
  assert_eq(result.warnings, [])
  let doc = @core.open_single(result.bdf)
  let page = doc.manifest.views[0].pages[0]
  assert_true(tiff_test_near(page.width, 1728.0 / 204.0 * 72.0))
  assert_true(tiff_test_near(page.height, 280.0 / 98.0 * 72.0))
  let object = @core.decode_object(doc.part(page.layers[0].object))
  let image = doc.part(object.images[0])
  let (width, height) = tiff_test_png_size(image)
  assert_eq(height, 280)
  assert_true(width > 1600 && width < 1630)
}

///|
test "LZW RGB page keeps its size and metadata" {
  let data = tiff_test_fixture(tiff_fixture_orientation)
  let result = convert(data, title="Override")
  assert_eq(result.pages, 8)
  assert_eq(result.summary, "8 page(s)")
  assert_eq(result.warnings, [])
  let doc = @core.open_single(result.bdf)
  let page = doc.manifest.views[0].pages[0]
  assert_true(tiff_test_near(page.width, 96.0))
  assert_true(tiff_test_near(page.height, 64.0))
  let object = @core.decode_object(doc.part(page.layers[0].object))
  let image = doc.part(object.images[0])
  assert_eq(tiff_test_png_size(image), (96, 64))
}
