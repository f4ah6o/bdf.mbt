///|
fn idml_test_fixture(text : String) -> Bytes {
  @gzip.decompress(@base64.decode(text[:], ignore_whitespace=true)[:]) catch { _ => b"" }
}

///|
test "IDML detection and page geometry" {
  let data = idml_test_fixture(idml_basic_fixture)
  assert_eq(detect(data), true)
  let result = convert(data)
  assert_eq(result.pages, 3)
  assert_eq(result.summary, "3 page(s), 0 embedded font(s)")
  let doc = @core.open_single(result.bdf)
  assert_eq(doc.manifest.views.length(), 1)
  assert_eq(doc.manifest.views[0].kind, "fixed")
  for page in doc.manifest.views[0].pages {
    assert_eq(page.width.round().to_int(), 400)
    assert_eq(page.height.round().to_int(), 560)
    assert_eq(page.layers.length(), 2)
    assert_eq(page.layers[0].role, "master")
    assert_eq(page.layers[1].role, "body")
  }
}

///|
test "IDML text and resources are read" {
  let data = idml_test_fixture(idml_basic_fixture)
  let result = convert(data)
  let doc = @core.open_single(result.bdf)
  let index = @core.decode_text_index(doc.part(doc.manifest.views[0].text_index.unwrap()))
  let mut text = ""
  for run in index {
    text += run.text
  }
  assert_eq(text.contains("InDesign サンプル"), true)
  assert_eq(text.contains("the story ends"), true)
  let pages = ["", "", ""]
  for run in index {
    if run.a >= 0 && run.a < 3 {
      pages[run.a] += run.text
    }
  }
  assert_eq(pages[0].contains("InDesign サンプル"), true)
  assert_eq(pages[2].contains("the story ends"), true)
}

///|
test "vertical IDML text is converted" {
  let data = idml_test_fixture(idml_vertical_fixture)
  let result = convert(data)
  assert_eq(result.pages > 0, true)
  let doc = @core.open_single(result.bdf)
  let page = doc.manifest.views[0].pages[0]
  assert_eq(page.layers.length(), 2)
}
