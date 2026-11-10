///|
/// UTF-16LE bytes, the form an EMF text record stores.
fn x_utf16le(text : String) -> Bytes {
  let b = @buffer.Buffer()
  for ch in text {
    let u = ch.to_int()
    if u <= 0xffff {
      x_u16(b, u)
    } else {
      let v = u - 0x10000
      x_u16(b, 0xd800 | (v >> 10))
      x_u16(b, 0xdc00 | (v & 0x3ff))
    }
  }
  b.to_bytes()
}

///|
/// An `EMREXTTEXTOUTW` record that draws `text` at the origin.
fn x_text_record(text : String) -> Bytes {
  let b = @buffer.Buffer()
  for v in [0, 0, 100, 100] {
    x_u32(b, v) // bounds
  }
  x_u32(b, 1) // iGraphicsMode
  x_u32(b, 0) // exScale
  x_u32(b, 0) // eyScale
  x_u32(b, 0) // ptlReference.x
  x_u32(b, 0) // ptlReference.y
  let n = text.length()
  x_u32(b, n) // nChars
  x_u32(b, 76) // offString, from the record start
  x_u32(b, 0) // fOptions
  for v in [0, 0, 100, 100] {
    x_u32(b, v) // rcl
  }
  x_u32(b, 76 + n * 2) // offDx, after the string
  b.write_bytes(x_utf16le(text))
  for _ in 0..<n {
    x_u32(b, 1) // advance per character
  }
  x_record(84, b.to_bytes())
}

///|
/// An EMF that draws `text` at the origin.
fn x_text_emf(text : String) -> Bytes {
  let font = @buffer.Buffer()
  x_u32(font, 1) // ihFont
  x_u32(font, 12) // lfHeight
  x_u32(font, 0) // lfWidth
  x_u32(font, 0) // lfEscapement
  x_u32(font, 0) // lfOrientation
  x_u32(font, 400) // lfWeight
  for _ in 0..<8 {
    font.write_byte(b'\x00')
  }
  for _ in 0..<32 {
    x_u16(font, 0)
  }
  x_emf([0, 0, 1000, 1000], [
    x_record(9, x_i32s([1000, 1000])), // SETWINDOWEXTEX
    x_record(17, x_i32s([1])), // SETMAPMODE MM_TEXT
    x_record(22, x_i32s([24])), // SETTEXTALIGN TA_BASELINE
    x_record(82, font.to_bytes()), // EXTCREATEFONTINDIRECTW
    x_record(37, x_i32s([1])), // SELECTOBJECT
    x_text_record(text),
    x_record(14, x_i32s([0, 0, 0])), // EOF
  ])
}

///|
/// An EMF that fills its whole box and draws no text.
fn x_rect_emf() -> Bytes {
  x_emf([0, 0, 1000, 1000], [
    x_record(9, x_i32s([1000, 1000])), // SETWINDOWEXTEX
    x_record(17, x_i32s([1])), // SETMAPMODE MM_TEXT
    x_record(43, x_i32s([0, 0, 1000, 1000])), // RECTANGLE
    x_record(14, x_i32s([0, 0, 0])), // EOF
  ])
}

///|
fn x_annotation_object(
  record : Int,
  kind : Int64,
  x : Int64,
  y : Int64,
  w : Int64,
  h : Int64,
  rotation : Int64,
  text : String?,
) -> XdwObject {
  { place: 0, record, kind, x, y, w, h, rotation, text }
}

///|
/// A document with one page and the given objects, each backed by the record
/// at the same index.
fn x_annotation_doc(
  objects : Array[XdwObject],
  records : Array[PropRecord],
) -> XdwDocument {
  let base = x_doc(records, [])
  {
    ..base,
    pages: [{ record: 0, w: 21000L, h: 29700L, objects }],
  }
}

///|
/// Write the page's layers and index into a BDF and reopen it.
fn x_layers_bdf(
  built : XdwPageLayers,
  writer : @core.DocumentWriter,
) -> @core.Document {
  let index_hash = writer.add_part("idx", @core.encode_text_index(built.runs)) catch {
    e => abort("index part failed: " + e.to_string())
  }
  writer.add_view(
    Json::object({
      "id": Json::string("pages"),
      "kind": Json::string("fixed"),
      "pages": Json::array(
        [
          Json::object({
            "w": Json::number(595.0, repr="595"),
            "h": Json::number(842.0, repr="842"),
            "layers": Json::array(built.layers),
          }),
        ],
      ),
      "textIndex": Json::string(index_hash),
    }),
  )
  let bdf = writer.write_single() catch {
    e => abort("write failed: " + e.to_string())
  }
  @core.open_single(bdf) catch {
    e => abort("open failed: " + e.to_string())
  }
}

///|
/// The text a layer's object stream draws.
fn x_layer_text(doc : @core.Document, layer : @core.Layer) -> String {
  let resources = @core.decode_object_resources(doc.part(layer.object)) catch {
    e => abort("decode failed: " + e.to_string())
  }
  let content = @render.extract_text(resources, fn(_) { None }) catch {
    e => abort("extract failed: " + e.to_string())
  }
  @render.join_text(content.runs)
}

///|
/// The index runs of a reopened document's first view.
fn x_document_index(doc : @core.Document) -> Array[@core.IndexRun] {
  let view = doc.manifest.views[0]
  let hash = match view.text_index {
    Some(hash) => hash
    None => abort("the document has no text index")
  }
  @core.decode_text_index(doc.part(hash)) catch {
    e => abort("index decode failed: " + e.to_string())
  }
}

///|
/// A length-prefixed item, the form a property value uses.
fn x_item(bytes : Bytes) -> Bytes {
  let b = @buffer.Buffer()
  b.write_byte(bytes.length().to_byte())
  b.write_bytes(bytes)
  b.to_bytes()
}

///|
/// A big-endian number item.
fn x_num_item(n : Int64) -> Bytes {
  let b = @buffer.Buffer()
  let mut started = false
  for shift in [56, 48, 40, 32, 24, 16, 8, 0] {
    let byte = ((n >> shift) & 0xffL).to_int()
    if byte != 0 || started || shift == 0 {
      b.write_byte(byte.to_byte())
      started = true
    }
  }
  x_item(b.to_bytes())
}

///|
/// The attribute definitions for `%Text(w` (tag 100) and `childdim` (tag 101).
fn x_defs() -> Bytes {
  let b = @buffer.Buffer()
  for (tag, name) in [(100L, "%Text(w"), (101L, "childdim")] {
    b.write_bytes(x_num_item(tag))
    b.write_bytes(x_num_item(0L))
    b.write_bytes(x_num_item(0L))
    b.write_bytes(x_num_item(0L))
    b.write_bytes(x_item(@utf8.encode(name)))
  }
  b.to_bytes()
}

///|
fn x_attr(class : Int, tag : Int, value : Bytes) -> PropAttr {
  { class, tag, value }
}

///|
fn x_prop_record(depth : Int, kind : Int64, attrs : Array[PropAttr]) -> PropRecord {
  {
    depth,
    kind: Bytes::from_array(
      FixedArray::from_array([
        0x00, (kind >> 8).to_byte(), (kind & 0xff).to_byte(),
      ]),
    ),
    attrs,
  }
}

///|
test "page content and annotations become separate layers" {
  let doc = x_annotation_doc(
    [
      x_annotation_object(0, K_CONTENT, 0L, 0L, 21000L, 29700L, 0L, None),
      x_annotation_object(1, K_TEXT, 1000L, 1000L, 5000L, 1000L, 0L, Some("annotation text")),
    ],
    [
      x_record_with_drawing(K_CONTENT, 4, x_text_emf("body text"), false),
      x_record_with_drawing(K_TEXT, 4, x_text_emf("annotation text"), true),
    ],
  )
  let writer = @core.DocumentWriter::new()
  let warnings : Array[String] = []
  let built = doc.xdw_page_layers(doc.pages[0], 0, writer, warnings) catch {
    e => abort("layers failed: " + e.to_string())
  }
  guard warnings.is_empty() else {
    abort("unexpected warnings: \{warnings.join(",")}")
  }
  let opened = x_layers_bdf(built, writer)
  let page = opened.manifest.views[0].pages[0]
  assert_eq(page.layers.map(fn(layer) { layer.role }), ["body", "annotation"])
  // The body layer carries the page content and nothing else.
  assert_eq(x_layer_text(opened, page.layers[0]), "body text")
  // The annotation layer carries the annotation and nothing else.
  assert_eq(x_layer_text(opened, page.layers[1]), "annotation text")
  // The index keeps the layers apart: body runs are layer 0, annotation runs
  // are layer 1, and each text appears once.
  let runs = x_document_index(opened)
  assert_eq(runs.map(fn(run) { (run.b, run.text) }), [
    (0, "body text"),
    (1, "annotation text"),
  ])
  assert_eq(@core.index_plain_text(runs), "body text\nannotation text")
}

///|
test "an opaque annotation hides body text by default and keeps it with include_hidden" {
  let doc = x_annotation_doc(
    [
      x_annotation_object(0, K_CONTENT, 0L, 0L, 21000L, 29700L, 0L, None),
      x_annotation_object(1, K_RECT, -7000L, -7000L, 20000L, 20000L, 0L, None),
    ],
    [
      x_record_with_drawing(K_CONTENT, 4, x_text_emf("body text"), false),
      x_record_with_drawing(K_RECT, 4, x_rect_emf(), true),
    ],
  )
  let writer = @core.DocumentWriter::new()
  let warnings : Array[String] = []
  let built = doc.xdw_page_layers(doc.pages[0], 0, writer, warnings) catch {
    e => abort("layers failed: " + e.to_string())
  }
  // The body text is under the annotation's opaque fill, so the default index
  // leaves it out, exactly as the single stream did before the layers split.
  assert_eq(built.runs.map(fn(run) { (run.b, run.text) }), [])
  // include_hidden keeps it.
  doc.include_hidden = true
  let writer2 = @core.DocumentWriter::new()
  let built2 = doc.xdw_page_layers(doc.pages[0], 0, writer2, warnings) catch {
    e => abort("layers failed: " + e.to_string())
  }
  assert_eq(built2.runs.map(fn(run) { (run.b, run.text) }), [(0, "body text")])
}

///|
test "a page without annotations has only a body layer" {
  let doc = x_annotation_doc(
    [x_annotation_object(0, K_CONTENT, 0L, 0L, 21000L, 29700L, 0L, None)],
    [x_record_with_drawing(K_CONTENT, 4, x_text_emf("body text"), false)],
  )
  let writer = @core.DocumentWriter::new()
  let warnings : Array[String] = []
  let built = doc.xdw_page_layers(doc.pages[0], 0, writer, warnings) catch {
    e => abort("layers failed: " + e.to_string())
  }
  let opened = x_layers_bdf(built, writer)
  let page = opened.manifest.views[0].pages[0]
  assert_eq(page.layers.map(fn(layer) { layer.role }), ["body"])
  assert_eq(x_document_index(opened).map(fn(run) { run.b }), [0])
}

///|
test "a sticky note whose drawing carries no text is indexed from its text" {
  // The note draws only its rectangle; the text lives in the child text
  // object, which the page model reads into `XdwObject.text`.
  let doc = x_annotation_doc(
    [
      x_annotation_object(0, K_FUSEN, 1000L, 1000L, 5000L, 5000L, 0L, Some("sticky note text")),
    ],
    [x_record_with_drawing(K_FUSEN, 4, x_rect_emf(), true)],
  )
  let writer = @core.DocumentWriter::new()
  let warnings : Array[String] = []
  let built = doc.xdw_page_layers(doc.pages[0], 0, writer, warnings) catch {
    e => abort("layers failed: " + e.to_string())
  }
  assert_eq(built.runs.map(fn(run) { (run.b, run.text) }), [
    (1, "sticky note text"),
  ])
  // The index part has to be written even though the drawing drew no text:
  // otherwise the reader would rebuild an index without the note.
  assert_eq(built.saw_text, true)
  let opened = x_layers_bdf(built, writer)
  let page = opened.manifest.views[0].pages[0]
  assert_eq(page.layers.map(fn(layer) { layer.role }), ["body", "annotation"])
  // The stored text is drawn transparently, so the page looks the same but
  // the text layer and the index have a real run to point at.
  assert_eq(x_layer_text(opened, page.layers[1]), "sticky note text")
  let commands = @render.decode_commands(opened.part(page.layers[1].object)) catch {
    e => abort("decode failed: " + e.to_string())
  }
  let mut fill = -1
  let mut transparent_text = false
  for command in commands {
    match command {
      @render.FillColor(color) => fill = color
      @render.FillText(text, _, _, _) =>
        if text == "sticky note text" && fill == 0 {
          transparent_text = true
        }
      _ => ()
    }
  }
  assert_true(transparent_text)
  assert_eq(@core.index_plain_text(x_document_index(opened)), "sticky note text")
}

///|
test "an annotation with text but no drawing still reaches the index" {
  // A placement can carry a text object whose record has no drawing
  // attribute: `xdw_find_pages` still reads the stored text. The fallback
  // must reach the layer and the index even though there is no picture
  // stream to draw.
  let doc = x_annotation_doc(
    [
      x_annotation_object(0, K_TEXT, 1000L, 1000L, 5000L, 1000L, 0L, Some("orphan text")),
    ],
    [x_prop_record(4, K_TEXT, [])],
  )
  let writer = @core.DocumentWriter::new()
  let warnings : Array[String] = []
  let built = doc.xdw_page_layers(doc.pages[0], 0, writer, warnings) catch {
    e => abort("layers failed: " + e.to_string())
  }
  assert_eq(built.runs.map(fn(run) { (run.b, run.text) }), [(1, "orphan text")])
  let opened = x_layers_bdf(built, writer)
  let page = opened.manifest.views[0].pages[0]
  assert_eq(page.layers.map(fn(layer) { layer.role }), ["body", "annotation"])
  assert_eq(x_layer_text(opened, page.layers[1]), "orphan text")
  // The fallback is transparent, so the page looks the same.
  let commands = @render.decode_commands(opened.part(page.layers[1].object)) catch {
    e => abort("decode failed: " + e.to_string())
  }
  let mut fill = -1
  let mut transparent_text = false
  for command in commands {
    match command {
      @render.FillColor(color) => fill = color
      @render.FillText(text, _, _, _) =>
        if text == "orphan text" && fill == 0 {
          transparent_text = true
        }
      _ => ()
    }
  }
  assert_true(transparent_text)
  assert_eq(@core.index_plain_text(x_document_index(opened)), "orphan text")
}

///|
test "a rotated annotation with no drawing keeps its rotation" {
  let doc = x_annotation_doc(
    [
      x_annotation_object(0, K_TEXT, 1000L, 1000L, 5000L, 2000L, 90L, Some("rotated orphan")),
    ],
    [x_prop_record(4, K_TEXT, [])],
  )
  let writer = @core.DocumentWriter::new()
  let warnings : Array[String] = []
  let built = doc.xdw_page_layers(doc.pages[0], 0, writer, warnings) catch {
    e => abort("layers failed: " + e.to_string())
  }
  let opened = x_layers_bdf(built, writer)
  let page = opened.manifest.views[0].pages[0]
  let commands = @render.decode_commands(opened.part(page.layers[1].object)) catch {
    e => abort("decode failed: " + e.to_string())
  }
  let mut transform : (Double, Double, Double, Double, Double, Double)? = None
  for command in commands {
    match command {
      @render.Transform(a, b, c, d, e, f) => transform = Some((a, b, c, d, e, f))
      _ => ()
    }
  }
  let (a, b, c, d, _, _) = match transform {
    Some(value) => value
    None => abort("the rotated annotation emitted no transform")
  }
  // A quarter turn clockwise: (0, 1, -1, 0).
  assert_eq((a, b, c, d), (0.0, 1.0, -1.0, 0.0))
  assert_eq(built.runs.map(fn(run) { (run.b, run.text) }), [(1, "rotated orphan")])
  assert_eq(x_layer_text(opened, page.layers[1]), "rotated orphan")
}

///|
test "a sticky note whose drawing carries its text is not indexed twice" {
  let doc = x_annotation_doc(
    [
      x_annotation_object(0, K_FUSEN, 1000L, 1000L, 5000L, 5000L, 0L, Some("sticky text")),
    ],
    [x_record_with_drawing(K_FUSEN, 4, x_text_emf("sticky text"), true)],
  )
  let writer = @core.DocumentWriter::new()
  let warnings : Array[String] = []
  let built = doc.xdw_page_layers(doc.pages[0], 0, writer, warnings) catch {
    e => abort("layers failed: " + e.to_string())
  }
  // The drawn run is the only one: the stored text is not added again.
  assert_eq(built.runs.map(fn(run) { (run.b, run.text) }), [(1, "sticky text")])
}

///|
test "a sticky note's direct child text is read" {
  let records = [
    x_prop_record(0, K_PAGE, [
      x_attr(0x80, 5, x_num_item(21000L) + x_num_item(29700L)),
    ]),
    x_prop_record(1, K_PLACE, [
      x_attr(0x80, 52, x_num_item(1000L) + x_num_item(1000L)),
      x_attr(0x80, 51, x_defs()),
      x_attr(0x80, 101, x_num_item(5000L) + x_num_item(5000L)),
    ]),
    x_prop_record(2, K_FUSEN, [
      x_attr(0x80, 7, x_drawing_value(4, x_rect_emf(), true)),
    ]),
    x_prop_record(3, K_TEXT, [
      x_attr(0x80, 51, x_defs()),
      x_attr(0x80, 100, x_utf16le("child text")),
    ]),
  ]
  let doc = x_doc(records, [])
  let pages = xdw_find_pages(doc)
  assert_eq(pages.length(), 1)
  assert_eq(pages[0].objects.length(), 1)
  assert_eq(pages[0].objects[0].kind, K_FUSEN)
  assert_eq(pages[0].objects[0].text, Some("child text"))
}

///|
test "the parser keeps a text object that has no drawing" {
  // `xdw_find_pages` creates an object for every placement's first child
  // record; it does not require attribute 7. A record with `%Text(w` but no
  // drawing therefore reaches the page model with its text intact.
  let records = [
    x_prop_record(0, K_PAGE, [
      x_attr(0x80, 5, x_num_item(21000L) + x_num_item(29700L)),
    ]),
    x_prop_record(1, K_PLACE, [
      x_attr(0x80, 52, x_num_item(1000L) + x_num_item(1000L)),
      x_attr(0x80, 51, x_defs()),
      x_attr(0x80, 101, x_num_item(5000L) + x_num_item(1000L)),
    ]),
    x_prop_record(2, K_TEXT, [
      x_attr(0x80, 51, x_defs()),
      x_attr(0x80, 100, x_utf16le("orphan text")),
    ]),
  ]
  let doc = x_doc(records, [])
  let pages = xdw_find_pages(doc)
  assert_eq(pages.length(), 1)
  assert_eq(pages[0].objects.length(), 1)
  assert_eq(pages[0].objects[0].kind, K_TEXT)
  assert_eq(pages[0].objects[0].text, Some("orphan text"))
  let drawing = doc.drawing_of(pages[0].objects[0].record) catch {
    e => abort("drawing_of failed: " + e.to_string())
  }
  assert_true(drawing is None)
}

///|
test "a sticky note's stored text can be located by a search hit" {
  let doc = x_annotation_doc(
    [
      x_annotation_object(0, K_FUSEN, 1000L, 1000L, 5000L, 5000L, 0L, Some("sticky note text")),
    ],
    [x_record_with_drawing(K_FUSEN, 4, x_rect_emf(), true)],
  )
  let writer = @core.DocumentWriter::new()
  let warnings : Array[String] = []
  let built = doc.xdw_page_layers(doc.pages[0], 0, writer, warnings) catch {
    e => abort("layers failed: " + e.to_string())
  }
  let opened = x_layers_bdf(built, writer)
  let page = opened.manifest.views[0].pages[0]
  let runs = x_document_index(opened)
  let search = @core.TextSearch::new(runs)
  let hits = search.search("sticky")
  assert_eq(hits.length(), 1)
  let resources = @core.decode_object_resources(opened.part(page.layers[1].object)) catch {
    e => abort("decode failed: " + e.to_string())
  }
  let content = @render.extract_text(resources, fn(_) { None }) catch {
    e => abort("extract failed: " + e.to_string())
  }
  let rects = @render.locate_text_hit(
    hits[0],
    (a, b, ordinal) => {
      if a == 0 && b == 1 {
        for run in content.runs {
          if run.ordinal == ordinal {
            return Some(run)
          }
        }
      }
      None
    },
    fn(_, size, text) { size * text.length().to_double() * 0.5 },
  )
  assert_true(rects.length() > 0)
  assert_true(rects[0].width > 0.0)
}

///|
test "a text annotation is indexed once, from its drawing" {
  let doc = x_annotation_doc(
    [
      x_annotation_object(0, K_TEXT, 1000L, 1000L, 5000L, 1000L, 0L, Some("same text")),
    ],
    [x_record_with_drawing(K_TEXT, 4, x_text_emf("same text"), true)],
  )
  let writer = @core.DocumentWriter::new()
  let warnings : Array[String] = []
  let built = doc.xdw_page_layers(doc.pages[0], 0, writer, warnings) catch {
    e => abort("layers failed: " + e.to_string())
  }
  assert_eq(built.runs.length(), 1)
  assert_eq(built.runs[0].text, "same text")
  assert_eq(built.runs[0].b, 1)
}

///|
test "a rotated annotation keeps its rotation on the annotation layer" {
  let doc = x_annotation_doc(
    [
      x_annotation_object(0, K_TEXT, 1000L, 1000L, 5000L, 2000L, 90L, Some("rotated")),
    ],
    [x_record_with_drawing(K_TEXT, 4, x_text_emf("rotated"), true)],
  )
  let writer = @core.DocumentWriter::new()
  let warnings : Array[String] = []
  let built = doc.xdw_page_layers(doc.pages[0], 0, writer, warnings) catch {
    e => abort("layers failed: " + e.to_string())
  }
  let opened = x_layers_bdf(built, writer)
  let page = opened.manifest.views[0].pages[0]
  let commands = @render.decode_commands(opened.part(page.layers[1].object)) catch {
    e => abort("decode failed: " + e.to_string())
  }
  let mut transform : (Double, Double, Double, Double, Double, Double)? = None
  for command in commands {
    match command {
      @render.Transform(a, b, c, d, e, f) => transform = Some((a, b, c, d, e, f))
      _ => ()
    }
  }
  let (a, b, c, d, _, _) = match transform {
    Some(value) => value
    None => abort("the rotated annotation emitted no transform")
  }
  // A quarter turn clockwise: (0, 1, -1, 0).
  assert_eq((a, b, c, d), (0.0, 1.0, -1.0, 0.0))
  assert_eq(built.runs.map(fn(run) { (run.b, run.text) }), [(1, "rotated")])
}

///|
test "annotation text is normalized to one searchable run" {
  assert_eq(xdw_annotation_text("a\r\nb"), "a b")
  assert_eq(xdw_annotation_text("  a  b  "), "a b")
  assert_eq(xdw_annotation_text("a\u{3000}b"), "a b")
  assert_eq(xdw_annotation_text(""), "")
}

///|
test "page content and page forms stay in the body" {
  assert_eq(xdw_is_annotation(K_CONTENT), false)
  assert_eq(xdw_is_annotation(K_PAGEFORM), false)
  for kind in [K_TEXT, K_FUSEN, K_LINE, K_RECT, K_ELLIPSE, K_PICTURE, K_CUSTOM, K_STAMP, K_MARKER, K_POLYGON, K_RECEIVED, K_LINK, K_SIGNATURE, K_OLE] {
    assert_eq(xdw_is_annotation(kind), true)
  }
}

///|
test "a real annotation-only sample puts its text on the annotation layer" {
  let b = xdw_fixture_bytes("test_xdw_ver8").unwrap()
  let result = xdw_convert(b) catch {
    e => abort("convert failed: " + e.to_string())
  }
  let doc = @core.open_single(result.bdf) catch {
    e => abort("open failed: " + e.to_string())
  }
  let page = doc.manifest.views[0].pages[0]
  assert_eq(page.layers.map(fn(layer) { layer.role }), ["body", "annotation"])
  // The page has no page content, so the body layer draws nothing.
  assert_eq(x_layer_text(doc, page.layers[0]), "")
  assert_true(x_layer_text(doc, page.layers[1]).contains("Lorem ipsum. 吾輩は猫である。"))
  let runs = x_document_index(doc)
  assert_eq(runs.map(fn(run) { run.b }), [1])
  assert_eq(@core.index_plain_text(runs), "Lorem ipsum. 吾輩は猫である。")
}

///|
test "a real body-only sample keeps one body layer" {
  let b = xdw_fixture_bytes("koto-ku_r604kinyumihon").unwrap()
  let result = xdw_convert(b) catch {
    e => abort("convert failed: " + e.to_string())
  }
  let doc = @core.open_single(result.bdf) catch {
    e => abort("open failed: " + e.to_string())
  }
  for page in doc.manifest.views[0].pages {
    assert_eq(page.layers.map(fn(layer) { layer.role }), ["body"])
  }
  for run in x_document_index(doc) {
    assert_eq(run.b, 0)
  }
}
