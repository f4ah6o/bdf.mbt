///|
fn psd_test_fixture(text : String) -> Bytes {
  @base64.decode(text, ignore_whitespace=true) catch {
    _ => b""
  }
}

///|
fn psd_test_png_size(data : Bytes) -> (Int32, Int32) {
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
fn psd_test_page(result : PsdResult, index : Int32) -> @core.Page raise {
  let doc = @core.open_single(result.bdf)
  doc.manifest.views[0].pages[index]
}

///|
test "Photoshop detection" {
  assert_true(detect(psd_test_fixture(psd_fixture_rgb32)))
  assert_true(detect(psd_test_fixture(psd_fixture_large)))
  assert_false(detect(b"8BPS"))
  assert_false(detect(b"not a psd file"))
}

///|
test "Photoshop colour modes convert on both targets" {
  for
    (name, fixture) in [
      ("bitmap", psd_fixture_bitmap),
      ("cmyk", psd_fixture_cmyk),
      ("gray16", psd_fixture_gray16),
      ("indexed", psd_fixture_indexed),
      ("lab", psd_fixture_lab),
      ("rgb32", psd_fixture_rgb32),
      ("large", psd_fixture_large),
    ] {
    let result = convert(psd_test_fixture(fixture))
    assert_eq(result.pages, 1)
    assert_eq(result.summary, "1 page(s)")
    let page = psd_test_page(result, 0)
    assert_eq((page.width, page.height), (24.0, 12.0))
    let doc = @core.open_single(result.bdf)
    let object = @core.decode_object(doc.part(page.layers[0].object))
    let image = doc.part(object.images[0])
    assert_eq(psd_test_png_size(image), (24, 12))
  }
}

///|
test "Photoshop layers keep their resolution" {
  let result = convert(psd_test_fixture(psd_fixture_layers))
  assert_eq(result.pages, 1)
  assert_eq(result.summary, "1 page(s)")
  let page = psd_test_page(result, 0)
  assert_eq((page.width, page.height), (80.0, 60.0))
  let doc = @core.open_single(result.bdf)
  let object = @core.decode_object(doc.part(page.layers[0].object))
  let image = doc.part(object.images[0])
  assert_eq(psd_test_png_size(image), (160, 120))
}

///|
test "Photoshop artboards become pages" {
  let result = convert(psd_test_fixture(psd_fixture_artboards))
  assert_eq(result.pages, 3)
  assert_eq(result.summary, "3 artboard(s)")
  let doc = @core.open_single(result.bdf)
  let pages = doc.manifest.views[0].pages
  assert_eq((pages[0].width, pages[0].height), (200.0, 150.0))
  assert_eq((pages[1].width, pages[1].height), (180.0, 120.0))
  assert_eq((pages[2].width, pages[2].height), (160.0, 120.0))
  let without = convert(
    psd_test_fixture(psd_fixture_artboards),
    artboards=false,
  )
  assert_eq(without.pages, 1)
  assert_eq(without.summary, "1 page(s)")
}

///|
test "Photoshop data without a composite fails explicitly" {
  let data = psd_test_fixture(psd_fixture_rgb32)
  // The converter reads the composite; a broken image data section is an
  // explicit error rather than a blank page.
  let error = try {
    ignore(convert(data[:data.length() - 10].to_owned()))
    ""
  } catch {
    PsdInvalid(message) => message
  }
  assert_true(error != "")
}
