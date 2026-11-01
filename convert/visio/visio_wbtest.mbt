///|
fn visio_test_fixture(text : String) -> Bytes {
  @gzip.decompress(@base64.decode(text[:], ignore_whitespace=true)[:]) catch {
    _ => b""
  }
}

///|
test "VSDX pages and layers" {
  let data = visio_test_fixture(visio_shapes_fixture)
  assert_eq(detect(data), true)
  let result = convert(data)
  assert_eq(result.pages, 2)
  assert_eq(result.summary, "2 page(s), 0 embedded font(s)")
  let doc = @core.open_single(result.bdf)
  for page in doc.manifest.views[0].pages {
    assert_eq(page.width.round().to_int(), 792)
    assert_eq(page.height.round().to_int(), 612)
    assert_eq(page.layers.length(), 2)
    assert_eq(page.layers[0].role, "background")
    assert_eq(page.layers[1].role, "body")
  }
}

///|
test "VSDX shape text is extracted" {
  let data = visio_test_fixture(visio_shapes_fixture)
  let result = convert(data)
  let doc = @core.open_single(result.bdf)
  let index = @core.decode_text_index(doc.part(doc.manifest.views[0].text_index.unwrap()))
  let mut text = ""
  for run in index {
    text += run.text
  }
  for want in ["BDF from Visio: shapes.vsdx", "Theme quick styles", "Turned", "connector label", "Nested item"] {
    assert_eq(text.contains(want), true)
  }
  assert_eq(text.contains("Hidden layer"), false)
}

///|
test "VSDX flowchart is converted" {
  let data = visio_test_fixture(visio_flow_fixture)
  let result = convert(data)
  assert_eq(result.pages, 1)
  let doc = @core.open_single(result.bdf)
  let index = @core.decode_text_index(doc.part(doc.manifest.views[0].text_index.unwrap()))
  let mut text = ""
  for run in index {
    text += run.text
  }
  for want in ["Start", "Collect input", "Valid?", "Flowchart test drawing"] {
    assert_eq(text.contains(want), true)
  }
}
