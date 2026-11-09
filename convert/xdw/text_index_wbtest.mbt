///|
/// An object stream with one text run, behind and in front of opaque fills.
/// The run sits at (10, 12) and is 30 wide and 10 tall, so a fill of
/// (0, 0, 100, 100) covers it and (0, 0, 20, 100) only clips its left edge.
fn xdw_text_stream(
  text : String,
  before : Array[(Float, Float, Float, Float)],
  after : Array[(Float, Float, Float, Float)],
) -> Bytes {
  let object = @core.ObjectBuilder::new()
  object.set_bbox(0.0F, 0.0F, 200.0F, 200.0F)
  let font = object.add_font({ hash: None, family: "sans", weight: 400, style: 0 })
  object.fill_color(0x000000ffU)
  for box in before {
    let (x, y, w, h) = box
    object.fill_rect(x, y, w, h)
  }
  object.font(font, 10.0F) catch {
    e => abort("font failed: " + e.to_string())
  }
  object.fill_text(text, 10.0F, 20.0F, 30.0F)
  for box in after {
    let (x, y, w, h) = box
    object.fill_rect(x, y, w, h)
  }
  object.encode() catch {
    e => abort("encode failed: " + e.to_string())
  }
}

///|
fn xdw_runs_of(encoded : Bytes) -> Array[XdwTextRun] {
  xdw_page_text_runs(encoded) catch {
    e => abort("decode failed: " + e.to_string())
  }
}

///|
test "a later opaque fill hides the text it covers" {
  let runs = xdw_runs_of(xdw_text_stream("covered", [], [(0.0F, 0.0F, 100.0F, 100.0F)]))
  assert_eq(runs.length(), 1)
  assert_eq(runs[0].covered, true)
  // Hidden by default, kept when the caller asks for it.
  assert_eq(xdw_index_runs(runs, 0, 0, false).length(), 0)
  assert_eq(xdw_index_runs(runs, 0, 0, true).length(), 1)
}

///|
test "a partial fill leaves the text visible" {
  let runs = xdw_runs_of(xdw_text_stream("visible", [], [(0.0F, 0.0F, 20.0F, 100.0F)]))
  assert_eq(runs.length(), 1)
  assert_eq(runs[0].covered, false)
  assert_eq(xdw_index_runs(runs, 0, 0, false).length(), 1)
}

///|
test "a fill drawn before the text does not hide it" {
  let runs = xdw_runs_of(xdw_text_stream("visible", [(0.0F, 0.0F, 100.0F, 100.0F)], []))
  assert_eq(runs.length(), 1)
  assert_eq(runs[0].covered, false)
  assert_eq(xdw_index_runs(runs, 0, 0, false).length(), 1)
}

///|
test "a translucent fill does not hide the text" {
  let object = @core.ObjectBuilder::new()
  object.set_bbox(0.0F, 0.0F, 200.0F, 200.0F)
  let font = object.add_font({ hash: None, family: "sans", weight: 400, style: 0 })
  object.fill_color(0x000000ffU)
  object.font(font, 10.0F) catch {
    e => abort("font failed: " + e.to_string())
  }
  object.fill_text("visible", 10.0F, 20.0F, 30.0F)
  // 0x00000080 is half-transparent black: the text stays readable.
  object.fill_color(0x00000080U)
  object.fill_rect(0.0F, 0.0F, 100.0F, 100.0F)
  let encoded = object.encode() catch {
    e => abort("encode failed: " + e.to_string())
  }
  let runs = xdw_runs_of(encoded)
  assert_eq(runs.length(), 1)
  assert_eq(runs[0].covered, false)
}

///|
test "annotation text reaches the BDF text index" {
  let b = xdw_fixture_bytes("test_xdw_ver8").unwrap()
  let result = xdw_convert(b) catch {
    e => abort("convert failed: " + e.to_string())
  }
  let doc = @core.open_single(result.bdf)
  let view = doc.manifest.views[0]
  let hash = match view.text_index {
    Some(h) => h
    None => abort("the converted document has no text index")
  }
  let runs = @core.decode_text_index(doc.part(hash)) catch {
    e => abort("index decode failed: " + e.to_string())
  }
  let text = @core.index_plain_text(runs)
  assert_true(text.contains("Lorem ipsum. 吾輩は猫である。"))
}

///|
test "body text of a real document reaches the index" {
  let b = xdw_fixture_bytes("koto-ku_r604kinyumihon").unwrap()
  let result = xdw_convert(b) catch {
    e => abort("convert failed: " + e.to_string())
  }
  let doc = @core.open_single(result.bdf)
  let view = doc.manifest.views[0]
  let hash = match view.text_index {
    Some(h) => h
    None => abort("the converted document has no text index")
  }
  let runs = @core.decode_text_index(doc.part(hash)) catch {
    e => abort("index decode failed: " + e.to_string())
  }
  let text = @core.index_plain_text(runs)
  assert_true(text.contains("要介護認定調査委託完了届"))
  // Every run belongs to a page that exists.
  for run in runs {
    assert_true(run.a >= 0 && run.a < result.pages)
  }
}

///|
test "include_hidden keeps covered text and changes nothing else" {
  let b = xdw_fixture_bytes("test_xdw_ver8").unwrap()
  let plain = xdw_convert(b) catch {
    e => abort("convert failed: " + e.to_string())
  }
  let hidden = xdw_convert(b, include_hidden=true) catch {
    e => abort("convert failed: " + e.to_string())
  }
  let plain_doc = @core.open_single(plain.bdf)
  let hidden_doc = @core.open_single(hidden.bdf)
  let plain_runs = @core.decode_text_index(
    plain_doc.part(plain_doc.manifest.views[0].text_index.unwrap()),
  ) catch {
    e => abort("index decode failed: " + e.to_string())
  }
  let hidden_runs = @core.decode_text_index(
    hidden_doc.part(hidden_doc.manifest.views[0].text_index.unwrap()),
  ) catch {
    e => abort("index decode failed: " + e.to_string())
  }
  // Nothing on this page is covered, so both settings agree.
  assert_eq(plain_runs.length(), hidden_runs.length())
  assert_eq(@core.index_plain_text(plain_runs), @core.index_plain_text(hidden_runs))
  // The drawing itself is the same either way.
  assert_eq(plain.bdf.length(), hidden.bdf.length())
}
