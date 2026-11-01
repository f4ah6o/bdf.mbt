///|
fn emf_test_fixture(text : String) -> Bytes {
  @base64.decode(text, ignore_whitespace=true) catch {
    _ => b""
  }
}

///|
test "EMF detection and page size" {
  let data = emf_test_fixture(emf_fixture)
  assert_eq(@metafile.kind(data), "emf")
  let size = @metafile.size(data)
  assert_true(size is Some(_))
  let (width, height) = size.unwrap()
  assert_eq(width.round().to_int(), 75)
  assert_eq(height.round().to_int(), 75)
  let result = convert(data)
  assert_eq(result.pages, 1)
  let doc = @core.open_single(result.bdf)
  let page = doc.manifest.views[0].pages[0]
  assert_eq(page.width.round().to_int(), 75)
  assert_eq(page.height.round().to_int(), 75)
}

///|
test "EMF replay draws text, a bitmap and a hatch" {
  let data = emf_test_fixture(emf_fixture)
  let result = convert(data)
  let doc = @core.open_single(result.bdf)
  let page = doc.manifest.views[0].pages[0]
  let object = @core.decode_object(doc.part(page.layers[0].object))
  assert_eq(object.strings.contains("EMF テキスト"), true)
  assert_eq(object.images.length(), 1)
  let image = doc.part(object.images[0])
  assert_eq(image[:8], b"\x89PNG\r\n\x1a\n"[:])
  assert_true(
    result.warnings.contains("metafile hatch brushes are approximated"),
  )
}

///|
test "WMF replay draws Shift_JIS text" {
  let data = emf_test_fixture(wmf_fixture)
  assert_eq(@metafile.kind(data), "wmf")
  let result = convert(data)
  assert_eq(result.pages, 1)
  assert_eq(result.warnings, [])
  let doc = @core.open_single(result.bdf)
  let page = doc.manifest.views[0].pages[0]
  let object = @core.decode_object(doc.part(page.layers[0].object))
  assert_eq(object.strings.contains("日本語"), true)
}
