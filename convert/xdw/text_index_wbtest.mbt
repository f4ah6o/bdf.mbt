///|
/// Little-endian u16 into a buffer.
fn xdw_t_u16(b : @buffer.Buffer, v : Int32) -> Unit {
  b.write_byte((v & 0xff).to_byte())
  b.write_byte(((v >> 8) & 0xff).to_byte())
}

///|
/// Little-endian u32 into a buffer.
fn xdw_t_u32(b : @buffer.Buffer, v : Int32) -> Unit {
  b.write_byte((v & 0xff).to_byte())
  b.write_byte(((v >> 8) & 0xff).to_byte())
  b.write_byte(((v >> 16) & 0xff).to_byte())
  b.write_byte(((v >> 24) & 0xff).to_byte())
}

///|
fn xdw_t_i32s(values : Array[Int32]) -> Bytes {
  let b = @buffer.Buffer()
  for v in values {
    xdw_t_u32(b, v)
  }
  b.to_bytes()
}

///|
fn xdw_t_record(kind : Int32, payload : Bytes) -> Bytes {
  let b = @buffer.Buffer()
  xdw_t_u32(b, kind)
  xdw_t_u32(b, 8 + payload.length())
  b.write_bytes(payload)
  b.to_bytes()
}

///|
/// An EMF header (88 bytes) and the given records.
fn xdw_t_emf(
  frame : Array[Int32],
  device : Array[Int32],
  mm : Array[Int32],
  records : Array[Bytes],
) -> Bytes {
  let b = @buffer.Buffer()
  xdw_t_u32(b, 1)
  xdw_t_u32(b, 88)
  for v in [0, 0, 100, 100] {
    xdw_t_u32(b, v)
  }
  for v in frame {
    xdw_t_u32(b, v)
  }
  b.write_bytes(b" EMF")
  xdw_t_u32(b, 0x10000)
  xdw_t_u32(b, 88)
  xdw_t_u32(b, 1)
  xdw_t_u16(b, 1)
  xdw_t_u16(b, 0)
  xdw_t_u32(b, 0)
  xdw_t_u32(b, 0)
  xdw_t_u32(b, 0)
  for v in device {
    xdw_t_u32(b, v)
  }
  for v in mm {
    xdw_t_u32(b, v)
  }
  for r in records {
    b.write_bytes(r)
  }
  b.to_bytes()
}

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
fn xdw_encode(object : @core.ObjectBuilder) -> Bytes {
  object.encode() catch {
    e => abort("encode failed: " + e.to_string())
  }
}

///|
fn xdw_index_of(encoded : Bytes, include_hidden : Bool) -> Array[@core.IndexRun] {
  let (runs, _) = xdw_page_index_runs(encoded, 0, 0, include_hidden) catch {
    e => abort("index failed: " + e.to_string())
  }
  runs
}

///|
fn xdw_covered_of(encoded : Bytes) -> Array[Int32] {
  let resources = @core.decode_object_resources(encoded) catch {
    e => abort("decode failed: " + e.to_string())
  }
  xdw_covered_ordinals(encoded, resources) catch {
    e => abort("coverage failed: " + e.to_string())
  }
}

///|
/// The index runs of a converted document's first view.
fn xdw_document_index(bdf : Bytes) -> Array[@core.IndexRun] {
  let doc = @core.open_single(bdf) catch {
    e => abort("open failed: " + e.to_string())
  }
  let view = doc.manifest.views[0]
  let hash = match view.text_index {
    Some(h) => h
    None => abort("the converted document has no text index")
  }
  @core.decode_text_index(doc.part(hash)) catch {
    e => abort("index decode failed: " + e.to_string())
  }
}

///|
test "a later opaque fill hides the text it covers" {
  let encoded = xdw_text_stream("covered", [], [(0.0F, 0.0F, 100.0F, 100.0F)])
  assert_eq(xdw_covered_of(encoded), [0])
  // Hidden by default, kept when the caller asks for it.
  assert_eq(xdw_index_of(encoded, false).length(), 0)
  assert_eq(xdw_index_of(encoded, true).length(), 1)
}

///|
test "a partial fill leaves the text visible" {
  let encoded = xdw_text_stream("visible", [], [(0.0F, 0.0F, 20.0F, 100.0F)])
  assert_eq(xdw_covered_of(encoded).length(), 0)
  assert_eq(xdw_index_of(encoded, false).length(), 1)
}

///|
test "a fill drawn before the text does not hide it" {
  let encoded = xdw_text_stream("visible", [(0.0F, 0.0F, 100.0F, 100.0F)], [])
  assert_eq(xdw_covered_of(encoded).length(), 0)
  assert_eq(xdw_index_of(encoded, false).length(), 1)
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
  let encoded = xdw_encode(object)
  assert_eq(xdw_covered_of(encoded).length(), 0)
  assert_eq(xdw_index_of(encoded, false).length(), 1)
}

///|
test "a clip that excludes the fill keeps the text" {
  // The fill would cover the run, but the clip keeps it away from the text.
  let object = @core.ObjectBuilder::new()
  object.set_bbox(0.0F, 0.0F, 200.0F, 200.0F)
  let font = object.add_font({ hash: None, family: "sans", weight: 400, style: 0 })
  object.fill_color(0x000000ffU)
  object.font(font, 10.0F) catch {
    e => abort("font failed: " + e.to_string())
  }
  object.fill_text("visible", 10.0F, 20.0F, 30.0F)
  object.clip_rect(100.0F, 100.0F, 10.0F, 10.0F)
  object.fill_rect(0.0F, 0.0F, 100.0F, 100.0F)
  let encoded = xdw_encode(object)
  assert_eq(xdw_covered_of(encoded).length(), 0)
  assert_eq(xdw_index_of(encoded, false).length(), 1)
}

///|
test "a clip path keeps the text, because its shape is not provable" {
  let object = @core.ObjectBuilder::new()
  object.set_bbox(0.0F, 0.0F, 200.0F, 200.0F)
  let font = object.add_font({ hash: None, family: "sans", weight: 400, style: 0 })
  object.fill_color(0x000000ffU)
  object.font(font, 10.0F) catch {
    e => abort("font failed: " + e.to_string())
  }
  object.fill_text("visible", 10.0F, 20.0F, 30.0F)
  let clip = object.add_path(
    @core.Inline({ verbs: b"\x05", coordinates: [0.0, 0.0, 200.0, 200.0] }),
  )
  object.clip_path(clip, 0) catch {
    e => abort("clip failed: " + e.to_string())
  }
  object.fill_rect(0.0F, 0.0F, 100.0F, 100.0F)
  let encoded = xdw_encode(object)
  assert_eq(xdw_covered_of(encoded).length(), 0)
  assert_eq(xdw_index_of(encoded, false).length(), 1)
}

///|
test "an image does not hide the text, because its pixels may be transparent" {
  let object = @core.ObjectBuilder::new()
  object.set_bbox(0.0F, 0.0F, 200.0F, 200.0F)
  let font = object.add_font({ hash: None, family: "sans", weight: 400, style: 0 })
  object.fill_color(0x000000ffU)
  object.font(font, 10.0F) catch {
    e => abort("font failed: " + e.to_string())
  }
  object.fill_text("visible", 10.0F, 20.0F, 30.0F)
  let image = object.add_image("00000000000000000000000000000001")
  object.image(image, 0.0F, 0.0F, 100.0F, 100.0F) catch {
    e => abort("image failed: " + e.to_string())
  }
  let encoded = xdw_encode(object)
  assert_eq(xdw_covered_of(encoded).length(), 0)
  assert_eq(xdw_index_of(encoded, false).length(), 1)
}

///|
test "a real metafile rectangle hides the text it covers" {
  // EMF rectangles reach the object stream as a filled path, not as a
  // `FillRect`, so this is the shape that has to count as a cover.
  let object = @core.ObjectBuilder::new()
  object.set_bbox(0.0F, 0.0F, 200.0F, 200.0F)
  let font = object.add_font({ hash: None, family: "sans", weight: 400, style: 0 })
  object.fill_color(0x000000ffU)
  object.font(font, 10.0F) catch {
    e => abort("font failed: " + e.to_string())
  }
  object.fill_text("covered", 10.0F, 20.0F, 30.0F)
  let writer = @core.DocumentWriter::new()
  let records = [
    xdw_t_record(9, xdw_t_i32s([300, 300])), // SETWINDOWEXTEX
    xdw_t_record(17, xdw_t_i32s([1])), // SETMAPMODE MM_TEXT
    xdw_t_record(43, xdw_t_i32s([0, 0, 300, 300])), // RECTANGLE
    xdw_t_record(14, xdw_t_i32s([0, 0, 0])), // EOF
  ]
  let emf = xdw_t_emf([0, 0, 300, 300], [300, 300], [75, 75], records)
  let _ = @metafile.draw_into(object, writer, emf, 0.0, 0.0, 100.0, 100.0) catch {
    @metafile.MetafileInvalid(message) => abort("metafile failed: " + message)
  }
  let encoded = xdw_encode(object)
  assert_eq(xdw_covered_of(encoded), [0])
  assert_eq(xdw_index_of(encoded, false).length(), 0)
  assert_eq(xdw_index_of(encoded, true).length(), 1)
}

///|
test "a covered run leaves the ordinals of the runs after it alone" {
  // The viewer locates a hit by the ordinal the renderer gave the run, so a
  // run that survives filtering must keep the ordinal it was drawn with.
  let object = @core.ObjectBuilder::new()
  object.set_bbox(0.0F, 0.0F, 200.0F, 200.0F)
  let font = object.add_font({ hash: None, family: "sans", weight: 400, style: 0 })
  object.fill_color(0x000000ffU)
  object.font(font, 10.0F) catch {
    e => abort("font failed: " + e.to_string())
  }
  object.fill_text("hidden", 10.0F, 20.0F, 30.0F)
  object.fill_text("visible", 10.0F, 60.0F, 30.0F)
  object.fill_rect(0.0F, 0.0F, 100.0F, 40.0F)
  let encoded = xdw_encode(object)
  assert_eq(xdw_covered_of(encoded), [0])
  let runs = xdw_index_of(encoded, false)
  assert_eq(runs.length(), 1)
  assert_eq(runs[0].text, "visible")
  assert_eq(runs[0].ordinal, 1)
  // With the hidden run kept, both ordinals are the drawn ones.
  let all = xdw_index_of(encoded, true)
  assert_eq(all.map(fn(r) { r.ordinal }), [0, 1])
}

///|
test "an index whose every run is hidden is still written" {
  // A missing index makes the reader rebuild one from the object stream, which
  // would bring back exactly the text the index leaves out.
  let encoded = xdw_text_stream("covered", [], [(0.0F, 0.0F, 100.0F, 100.0F)])
  let (runs, drew_text) = xdw_page_index_runs(encoded, 0, 0, false) catch {
    e => abort("index failed: " + e.to_string())
  }
  assert_eq(runs.length(), 0)
  assert_eq(drew_text, true)
}

///|
test "an index is written whenever a page drew text" {
  // Every run filtered away still needs the part: leaving it out would let the
  // reader rebuild the index from the object stream and bring the text back.
  assert_eq(xdw_index_part_needed(true, false), true)
  // A document with no text at all needs nothing.
  assert_eq(xdw_index_part_needed(false, false), false)
  // A page that could not be read back falls back rather than dropping text.
  assert_eq(xdw_index_part_needed(true, true), false)
}

///|
test "an empty index part is not rebuilt from the object stream" {
  let object = @core.ObjectBuilder::new()
  object.set_bbox(0.0F, 0.0F, 200.0F, 200.0F)
  let font = object.add_font({ hash: None, family: "sans", weight: 400, style: 0 })
  object.fill_color(0x000000ffU)
  object.font(font, 10.0F) catch {
    e => abort("font failed: " + e.to_string())
  }
  object.fill_text("hidden", 10.0F, 20.0F, 30.0F)
  let encoded = xdw_encode(object)
  let writer = @core.DocumentWriter::new()
  let object_hash = writer.add_part("obj", encoded) catch {
    e => abort("part failed: " + e.to_string())
  }
  let index_hash = writer.add_part("idx", @core.encode_text_index([])) catch {
    e => abort("part failed: " + e.to_string())
  }
  writer.add_view(
    Json::object({
      "id": Json::string("pages"),
      "kind": Json::string("fixed"),
      "pages": Json::array(
        [
          Json::object({
            "w": Json::number(200.0, repr="200"),
            "h": Json::number(200.0, repr="200"),
            "layers": Json::array(
              [
                Json::object({
                  "role": Json::string("body"),
                  "obj": Json::string(object_hash),
                }),
              ],
            ),
          }),
        ],
      ),
      "textIndex": Json::string(index_hash),
    }),
  )
  let bdf = writer.write_single() catch {
    e => abort("write failed: " + e.to_string())
  }
  let doc = @core.open_single(bdf) catch {
    e => abort("open failed: " + e.to_string())
  }
  let runs = @render.view_text_index(
    doc.manifest.views[0],
    fn(hash) { doc.part(hash) },
    fn(_) { None },
  ) catch {
    e => abort("index failed: " + e.to_string())
  }
  // The object stream still holds "hidden"; the empty index must win.
  assert_eq(runs.length(), 0)
}

///|
test "annotation text reaches the BDF text index" {
  let b = xdw_fixture_bytes("test_xdw_ver8").unwrap()
  let result = xdw_convert(b) catch {
    e => abort("convert failed: " + e.to_string())
  }
  let text = @core.index_plain_text(xdw_document_index(result.bdf))
  assert_true(text.contains("Lorem ipsum. 吾輩は猫である。"))
}

///|
test "body text of a real document reaches the index" {
  let b = xdw_fixture_bytes("koto-ku_r604kinyumihon").unwrap()
  let result = xdw_convert(b) catch {
    e => abort("convert failed: " + e.to_string())
  }
  let runs = xdw_document_index(result.bdf)
  let text = @core.index_plain_text(runs)
  assert_true(text.contains("要介護認定調査委託完了届"))
  // Every run belongs to a page that exists.
  for run in runs {
    assert_true(run.a >= 0 && run.a < result.pages)
  }
}

///|
test "phrases that span a line break stay searchable" {
  // The reader treats a line break as a hard boundary, so a run that merely
  // starts a new line must not be given one: these phrases were searchable
  // before the index existed and have to stay searchable.
  let b = xdw_fixture_bytes("koto-ku_r604kinyumihon").unwrap()
  let result = xdw_convert(b) catch {
    e => abort("convert failed: " + e.to_string())
  }
  let search = @core.TextSearch::new(xdw_document_index(result.bdf))
  for phrase in ["被保険者番号と 被保険者氏名", "基づき以 下のとおり"] {
    assert_true(search.search(phrase).length() > 0)
  }
}

///|
test "runs of different sizes on one baseline stay one word" {
  // A larger run on the same baseline is not a line break: its top edge moves
  // but its baseline does not, so the two runs still read as one word.
  let object = @core.ObjectBuilder::new()
  object.set_bbox(0.0F, 0.0F, 200.0F, 200.0F)
  let font = object.add_font({ hash: None, family: "sans", weight: 400, style: 0 })
  object.fill_color(0x000000ffU)
  object.font(font, 10.0F) catch {
    e => abort("font failed: " + e.to_string())
  }
  object.fill_text("Hello", 10.0F, 20.0F, 25.0F)
  object.font(font, 20.0F) catch {
    e => abort("font failed: " + e.to_string())
  }
  object.fill_text("World", 35.0F, 20.0F, 25.0F)
  let encoded = xdw_encode(object)
  let runs = xdw_index_of(encoded, false)
  assert_eq(runs.map(fn(r) { r.separator }), [2, 0])
  let search = @core.TextSearch::new(runs)
  assert_eq(search.search("HelloWorld").length(), 1)
}

///|
test "the index matches the fallback the reader used before it existed" {
  // Nothing in these samples is covered, so the stored index has to be exactly
  // what the reader would rebuild from the object stream: same runs, same
  // ordinals, same separators, same text.
  let mut total = 0
  for name in [
    "test_xdw_ver8",
    "test_xdw_ver9",
    "test_xdw_ver10",
    "okinawa-pref_61",
    "test_xbd_ver8",
    "koto-ku_r604kinyumihon",
  ] {
    let b = xdw_fixture_bytes(name).unwrap()
    let result = xdw_convert(b) catch {
      e => abort("convert failed: " + e.to_string())
    }
    let doc = @core.open_single(result.bdf) catch {
      e => abort("open failed: " + e.to_string())
    }
    let stored = xdw_document_index(result.bdf)
    let rebuilt = @render.build_page_text_index(
      doc.manifest.views[0],
      (hash) => Some(@core.decode_object_resources(doc.part(hash))),
    ) catch {
      e => abort("rebuild failed: " + e.to_string())
    }
    assert_eq(stored.length(), rebuilt.length())
    assert_eq(
      stored.map(fn(r) { (r.a, r.b, r.ordinal, r.separator, r.text) }),
      rebuilt.map(fn(r) { (r.a, r.b, r.ordinal, r.separator, r.text) }),
    )
    total += stored.length()
  }
  assert_eq(total, 262)
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
  let plain_runs = xdw_document_index(plain.bdf)
  let hidden_runs = xdw_document_index(hidden.bdf)
  // Nothing on this page is covered, so both settings agree.
  assert_eq(plain_runs.length(), hidden_runs.length())
  assert_eq(@core.index_plain_text(plain_runs), @core.index_plain_text(hidden_runs))
  // The drawing itself is the same either way.
  assert_eq(plain.bdf.length(), hidden.bdf.length())
}
