///|
// Regression tests for drawing degradation: a drawing whose visual content
// is not drawn (a shape, group, chart or SmartArt without an embedded image
// or a text box) no longer fails the conversion. Upstream renders it; the
// port skips it, surfaces exactly one warning in the public result, and
// keeps docPr/@descr as the FIGURE mark of the skipped content. No shape is
// drawn, and malformed image references keep failing: a blip is an image
// even when it is broken. The documents are built as stored ZIP packages,
// so a test shows the WordprocessingML it uses.

///|
/// The note `docx_text_drawing` records for a skipped drawing, deduplicated
/// per walker and surfaced in the public conversion result.
const DOCX_DEGRADE_NOTE : String = "DOCX: a drawing without an embedded image or text box (shape, group, chart or SmartArt) was skipped"

///|
/// A minimal body document whose root also declares the wps shape and the
/// picture namespaces the fixtures below use.
fn docx_degrade_document(
  blocks : String,
  extra~ : Array[(String, Bytes)] = [],
  section~ : String = DOCX_TEST_SECTION,
) -> Bytes {
  let document = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"" +
    " xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"" +
    " xmlns:wp=\"http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing\"" +
    " xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\"" +
    " xmlns:pic=\"http://schemas.openxmlformats.org/drawingml/2006/picture\"" +
    " xmlns:wps=\"http://schemas.microsoft.com/office/word/2010/wordprocessingShape\">" +
    "<w:body>" +
    blocks +
    section +
    "</w:body></w:document>"
  let entries : Array[(String, Bytes)] = [
    ("word/document.xml", @utf8.encode(document)),
  ]
  for entry in extra {
    entries.push(entry)
  }
  docx_test_zip(entries)
}

///|
/// A `wps:wsp` shape drawing (no blip, no text box), inline or anchored, with
/// optional `docPr` alternative text.
fn docx_degrade_shape(doc_pr : String, anchored : Bool) -> String {
  let container = if anchored {
    "<wp:anchor distT=\"0\" distB=\"0\" distL=\"0\" distR=\"0\" behindDoc=\"0\" relativeHeight=\"1\">" +
    "<wp:simplePos x=\"0\" y=\"0\"/>" +
    "<wp:positionH relativeFrom=\"column\"><wp:posOffset>0</wp:posOffset></wp:positionH>" +
    "<wp:positionV relativeFrom=\"paragraph\"><wp:posOffset>0</wp:posOffset></wp:positionV>" +
    "<wp:extent cx=\"914400\" cy=\"914400\"/>"
  } else {
    "<wp:inline><wp:extent cx=\"914400\" cy=\"914400\"/>"
  }
  let close = if anchored { "</wp:anchor>" } else { "</wp:inline>" }
  "<w:p><w:r><w:drawing>" +
    container +
    doc_pr +
    "<a:graphic><a:graphicData uri=\"http://schemas.microsoft.com/office/word/2010/wordprocessingShape\">" +
    "<wps:wsp><wps:spPr><a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom></wps:spPr></wps:wsp>" +
    "</a:graphicData></a:graphic>" +
    close +
    "</w:drawing></w:r></w:p>"
}

///|
/// An inline `wps:wsp` with a text box, the shrink of upstream's basic.docx
/// the issue names: one paragraph of text.
fn docx_degrade_text_box(text : String) -> String {
  "<w:p><w:r><w:drawing><wp:inline>" +
    "<wp:extent cx=\"1828800\" cy=\"182880\"/>" +
    "<a:graphic><a:graphicData uri=\"http://schemas.microsoft.com/office/word/2010/wordprocessingShape\">" +
    "<wps:wsp><wps:txbx><w:txbxContent>" +
    "<w:p><w:r><w:t>" +
    text +
    "</w:t></w:r></w:p>" +
    "</w:txbxContent></wps:txbx></wps:wsp>" +
    "</a:graphicData></a:graphic>" +
    "</wp:inline></w:drawing></w:r></w:p>"
}

///|
/// An inline picture drawing whose blip embeds `id`.
fn docx_degrade_picture(id : String) -> String {
  "<w:p><w:r><w:drawing><wp:inline>" +
    "<wp:extent cx=\"914400\" cy=\"914400\"/>" +
    "<a:graphic><a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/picture\">" +
    "<pic:pic><pic:blipFill><a:blip r:embed=\"" +
    id +
    "\"/></pic:blipFill></pic:pic>" +
    "</a:graphicData></a:graphic>" +
    "</wp:inline></w:drawing></w:r></w:p>"
}

///|
/// The body paragraph below a degraded drawing: it must survive the drawing.
fn docx_degrade_body() -> String {
  "<w:p><w:r><w:t>Adjacent body text</w:t></w:r></w:p>"
}

///|
/// The kinds of the items of every paragraph block of `document`, in order.
fn docx_degrade_item_kinds(document : DocxTextDocument) -> Array[String] {
  let kinds : Array[String] = []
  for block in document.blocks {
    match block {
      DocxParaBlock(paragraph) =>
        for item in paragraph.items {
          kinds.push(item.kind)
        }
      DocxTableBlock(_) => ()
    }
  }
  kinds
}

///|
/// The FIGURE and END marks of `commands` as (kind name, payload) pairs.
fn docx_degrade_figure_marks(
  commands : Array[@render.Command],
) -> Array[(String, String)] {
  let marks : Array[(String, String)] = []
  for command in commands {
    match command {
      @render.Mark(kind, payload) =>
        if kind == @core.MARK_FIGURE.to_int() ||
          kind == @core.MARK_END.to_int() {
          let name = if kind == @core.MARK_FIGURE.to_int() {
            "figure"
          } else {
            "end"
          }
          marks.push((name, payload))
        }
      _ => ()
    }
  }
  marks
}

///|
/// The message of a failed conversion, empty when it succeeds.
fn docx_degrade_failure(data : Bytes) -> String {
  try {
    ignore(convert(data))
    ""
  } catch {
    DocxInvalid(message) => message
    InvalidDocx(message) => message
    _ => "other failure"
  }
}

///|
test "DOCX unsupported shape drawings degrade with one surfaced warning" {
  let blocks = docx_degrade_shape("", true) + docx_degrade_body()
  let result = convert(docx_degrade_document(blocks))
  let mut notes = 0
  for note in result.warnings {
    if note == DOCX_DEGRADE_NOTE {
      notes += 1
    }
  }
  assert_eq(notes, 1, msg="the skipped drawing warns exactly once")
  // The drawing contributes no text: the index holds only the body text.
  let document = @core.open_single(result.bdf)
  let split = @core.single_to_split(result.bdf)
  let manifest = @core.parse_manifest(@utf8.decode(split.manifest))
  let mut index_text = ""
  for view in manifest.views {
    match view.text_index {
      Some(hash) =>
        for run in @core.decode_text_index(document.part(hash)) {
          index_text += run.text
        }
      None => ()
    }
  }
  assert_true(index_text.contains("Adjacent body text"))
  assert_false(index_text.contains("was skipped"))
}

///|
/// A degraded drawing must not also become an image item: the image path
/// reads the item's text as an image relationship, and an empty one fails
/// the whole conversion when the image is drawn.
test "DOCX degraded shape drawings make one figure item and no image item" {
  let doc_pr = "<wp:docPr id=\"1\" name=\"Red rectangle\" descr=\"A red rectangle\"/>"
  let blocks = docx_degrade_shape(doc_pr, false)
  let data = docx_degrade_document(blocks)
  let document = docx_document_text(data)
  assert_eq(docx_degrade_item_kinds(document), ["figure"])
  // The whole conversion succeeds and keeps the alternative text.
  let result = convert(data)
  assert_true(result.warnings.contains(DOCX_DEGRADE_NOTE))
}

///|
test "DOCX docPr descr of a degraded drawing survives as figure alt text" {
  let doc_pr = "<wp:docPr id=\"1\" name=\"Red rectangle\" descr=\"A red rectangle\"/>"
  let blocks = docx_degrade_shape(doc_pr, false) + docx_degrade_body()
  let result = convert(docx_degrade_document(blocks))
  assert_true(result.warnings.contains(DOCX_DEGRADE_NOTE))
  let commands = docx_test_page_commands(result, "pages", 0, "body")
  let marks = docx_degrade_figure_marks(commands)
  assert_true(marks.contains(("figure", "A red rectangle")))
  assert_true(marks.contains(("end", "")))
  assert_true(docx_test_commands_text(commands).contains("Adjacent body text"))
  // The skip draws marks only: no image command stands where the shape was.
  let mut images = 0
  for command in commands {
    match command {
      @render.Image(_, _, _, _, _) => images += 1
      _ => ()
    }
  }
  assert_eq(images, 0, msg="the skipped shape draws no image")
}

///|
test "DOCX anchored shape drawings mark their alt text at the anchor" {
  let doc_pr = "<wp:docPr id=\"2\" name=\"Blue panel\" descr=\"A blue panel\"/>"
  let blocks = docx_degrade_shape(doc_pr, true) + docx_degrade_body()
  let result = convert(docx_degrade_document(blocks))
  assert_true(result.warnings.contains(DOCX_DEGRADE_NOTE))
  let commands = docx_test_page_commands(result, "pages", 0, "body")
  let marks = docx_degrade_figure_marks(commands)
  assert_true(marks.contains(("figure", "A blue panel")))
  assert_true(marks.contains(("end", "")))
  assert_true(docx_test_commands_text(commands).contains("Adjacent body text"))
}

///|
test "DOCX degraded inline shapes keep their figure mark in the scroll view" {
  let doc_pr = "<wp:docPr id=\"3\" name=\"Red rectangle\" descr=\"A red rectangle\"/>"
  let blocks = docx_degrade_shape(doc_pr, false) + docx_degrade_body()
  let result = convert(docx_degrade_document(blocks))
  let commands = docx_test_page_commands(result, "scroll", 0, "body")
  let marks = docx_degrade_figure_marks(commands)
  assert_true(marks.contains(("figure", "A red rectangle")))
  assert_true(marks.contains(("end", "")))
}

///|
test "DOCX text box drawings keep their extracted text" {
  let blocks = docx_degrade_text_box("A text box with centered text") +
    docx_degrade_body()
  let result = convert(docx_degrade_document(blocks))
  let commands = docx_test_page_commands(result, "pages", 0, "body")
  let text = docx_test_commands_text(commands)
  assert_true(text.contains("A text box with centered text"))
  assert_true(text.contains("Adjacent body text"))
  // A drawing with a text box is not a degrade.
  assert_false(result.warnings.contains(DOCX_DEGRADE_NOTE))
}

///|
test "DOCX picture drawings with a blip that names no image keep failing" {
  // The blip is an image part: a broken reference is a lost image, not a
  // drawing to skip.
  let blocks = docx_degrade_picture("") + docx_degrade_body()
  let failed = docx_degrade_failure(docx_degrade_document(blocks))
  assert_true(
    failed.contains("picture drawing with a missing image reference"),
    msg=failed,
  )
}

///|
test "DOCX picture drawings with an unknown relationship keep failing" {
  let blocks = docx_degrade_picture("rIdMissing") + docx_degrade_body()
  let failed = docx_degrade_failure(docx_degrade_document(blocks))
  // The failure surfaces when the image is drawn, not as a skip warning.
  assert_true(failed.contains("DOCX image relationship is missing"), msg=failed)
}

///|
test "DOCX picture drawings with a known relationship still draw" {
  let rels = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
    "<Relationship Id=\"rIdImg\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"media/logo.png\"/>" +
    "</Relationships>"
  let blocks = docx_degrade_picture("rIdImg") + docx_degrade_body()
  let result = convert(
    docx_degrade_document(
      blocks,
      extra=[
        ("word/_rels/document.xml.rels", @utf8.encode(rels)),
        ("word/media/logo.png", b"not-a-real-png"),
      ],
    ),
  )
  assert_false(result.warnings.contains(DOCX_DEGRADE_NOTE))
  let commands = docx_test_page_commands(result, "pages", 0, "body")
  let mut images = 0
  for command in commands {
    match command {
      @render.Image(_, _, _, _, _) => images += 1
      _ => ()
    }
  }
  assert_eq(images, 1, msg="the picture is drawn once")
  assert_true(docx_test_commands_text(commands).contains("Adjacent body text"))
}

///|
test "DOCX drawings without a container remain invalid" {
  let blocks = "<w:p><w:r><w:drawing/></w:r></w:p>" + docx_degrade_body()
  let failed = docx_degrade_failure(docx_degrade_document(blocks))
  assert_true(
    failed.contains("unsupported DOCX content: drawing"),
    msg="the failure explains the unsupported drawing",
  )
}

///|
test "DOCX repeated unsupported drawings warn once" {
  let blocks = docx_degrade_shape("", false) +
    docx_degrade_shape("", false) +
    docx_degrade_body()
  let result = convert(docx_degrade_document(blocks))
  let mut notes = 0
  for note in result.warnings {
    if note == DOCX_DEGRADE_NOTE {
      notes += 1
    }
  }
  assert_eq(notes, 1, msg="the deduplicated note appears once")
}

///|
/// The alternative text is kept as marks, not as text: the index a reader
/// searches must hold the body alone.
test "DOCX figure alt text stays out of the text index" {
  let doc_pr = "<wp:docPr id=\"1\" name=\"Red rectangle\" descr=\"A red rectangle\"/>"
  let blocks = docx_degrade_shape(doc_pr, false) + docx_degrade_body()
  let result = convert(docx_degrade_document(blocks))
  let document = @core.open_single(result.bdf)
  let split = @core.single_to_split(result.bdf)
  let manifest = @core.parse_manifest(@utf8.decode(split.manifest))
  let mut index_text = ""
  for view in manifest.views {
    match view.text_index {
      Some(hash) =>
        for run in @core.decode_text_index(document.part(hash)) {
          index_text += run.text
        }
      None => ()
    }
  }
  assert_true(index_text.contains("Adjacent body text"))
  assert_false(
    index_text.contains("A red rectangle") || index_text.contains("Red rectangle"),
    msg="marks carry the alt text, the index does not",
  )
}

///|
test "DOCX unsupported shape drawings in table cells warn too" {
  let table = "<w:tbl><w:tr><w:tc>" +
    docx_degrade_shape("", false) +
    "</w:tc></w:tr></w:tbl>"
  let blocks = table + docx_degrade_body()
  let result = convert(docx_degrade_document(blocks))
  assert_true(result.warnings.contains(DOCX_DEGRADE_NOTE))
  assert_true(docx_test_commands_text(
    docx_test_page_commands(result, "pages", 0, "body"),
  ).contains("Adjacent body text"))
}

///|
test "DOCX unsupported shape drawings in headers warn too" {
  let rels = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
    "<Relationship Id=\"rIdH\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/header\" Target=\"header1.xml\"/>" +
    "</Relationships>"
  let header = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<w:hdr xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"" +
    " xmlns:wp=\"http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing\"" +
    " xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\"" +
    " xmlns:wps=\"http://schemas.microsoft.com/office/word/2010/wordprocessingShape\">" +
    docx_degrade_shape("", false) +
    "</w:hdr>"
  let section = "<w:sectPr><w:headerReference w:type=\"default\" r:id=\"rIdH\"/>" +
    "<w:pgSz w:w=\"12240\" w:h=\"15840\"/>" +
    "<w:pgMar w:top=\"1440\" w:right=\"1440\" w:bottom=\"1440\" w:left=\"1440\"/></w:sectPr>"
  let result = convert(
    docx_degrade_document(
      docx_degrade_body(),
      extra=[
        ("word/_rels/document.xml.rels", @utf8.encode(rels)),
        ("word/header1.xml", @utf8.encode(header)),
      ],
      section~,
    ),
  )
  assert_true(result.warnings.contains(DOCX_DEGRADE_NOTE))
}
