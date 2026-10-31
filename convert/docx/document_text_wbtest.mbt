///|
fn docx_text_fixture(chunks : Array[String]) -> Bytes raise {
  let joined = StringBuilder()
  for chunk in chunks {
    joined.write_string(chunk)
  }
  let compressed = @base64.decode(joined.to_string()[:])
  @gzip.decompress(compressed[:])
}

///|
fn check_docx_document_text(
  chunks : Array[String],
  expected : Array[
    (
      Int32,
      String,
      Double,
      Double,
      Double,
      Double,
      Bool,
      Bool,
      Array[(String, String, Bool)],
    ),
  ],
  expected_sections : Array[(Double, Double, Double)],
) -> Unit raise {
  let document = docx_document_text(docx_text_fixture(chunks))
  assert_eq(document.part, "custom/document.xml")
  assert_eq(document.sections.length(), expected_sections.length())
  for i in 0..<expected_sections.length() {
    let section = document.sections[i]
    assert_eq(
      (section.width, section.height, section.left),
      expected_sections[i],
    )
  }
  assert_eq(document.paragraphs.length(), expected.length())
  for i in 0..<expected.length() {
    let p = document.paragraphs[i]
    let actual = (
      p.section_index,
      p.props.alignment,
      p.props.left,
      p.props.first,
      p.props.before,
      p.props.after,
      p.props.keep_next,
      p.props.snap_to_grid,
      p.items.map(fn(item) { (item.kind, item.text, item.clear) }),
    )
    assert_eq(actual, expected[i], msg="paragraph \{i}")
  }
}

///|
fn reject_docx_document_text(chunks : Array[String]) -> Unit raise {
  let data = docx_text_fixture(chunks)
  let rejected = try {
    ignore(docx_document_text(data))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "DOCX unsupported content is rejected" {
  for
    source in [
      "<body><p><r><drawing/></r></p></body>", "<body><p><r><fldChar fldCharType=\"begin\"/></r></p></body>",
      "<body><p><fldSimple instr=\"PAGE\"/></p></body>", "<body><p><r><rPr><vanish/></rPr><t>hidden</t></r></p></body>",
      "<body><p><r><rPr><caps/></rPr><t>case</t></r></p></body>", "<body><p><r><rPr><smallCaps/></rPr><t>case</t></r></p></body>",
      "<body><p><r><rPr><eastAsianLayout vert=\"1\"/></rPr><t>12</t></r></p></body>",
      "<body><p><r><rPr/><rPr/></r></p></body>", "<body><p><pPr><numPr><numId val=\"1\"/></numPr></pPr></p></body>",
      "<body><p><hyperlink><r><t>link</t></r></hyperlink></p></body>", "<body><p><r><tab><drawing/></tab></r></p></body>",
      "<body><sdt><sdtContent><p><pPr><sectPr/></pPr></p></sdtContent></sdt></body>",
      "<body><sectPr><pgBorders/></sectPr></body>",
    ] {
    let root = docx_text_xml(source)
    let walker : DocxTextWalker = {
      styles: docx_styles_from_xml("<styles/>"),
      paragraphs: [],
      section_index: 0,
    }
    let rejected = try {
      walker.blocks(root, false)
      false
    } catch {
      _ => true
    }
    assert_true(rejected, msg=source)
  }
}

///|
fn check_docx_styled_text(
  chunks : Array[String],
  expected : Array[
    (
      Int32,
      String,
      Double,
      Double,
      Double,
      DocxRunProps,
      Array[(String, String, Bool, DocxRunProps)],
    ),
  ],
) -> Unit raise {
  let document = docx_document_text(docx_text_fixture(chunks))
  assert_eq(document.paragraphs.length(), expected.length())
  for i in 0..<expected.length() {
    let p = document.paragraphs[i]
    let actual = (
      p.section_index,
      p.props.alignment,
      p.props.left,
      p.props.before,
      p.props.after,
      p.mark,
      p.items.map(fn(item) { (item.kind, item.text, item.clear, item.props) }),
    )
    assert_eq(actual, expected[i], msg="styled paragraph \{i}")
  }
}

///|
test "DOCX resolved run properties are isolated between runs" {
  let styles = docx_styles_from_xml(
    "<styles><style type=\"paragraph\" styleId=\"p\" default=\"1\"><rPr><rFonts ascii=\"Parent\"/></rPr></style></styles>",
  )
  let body = docx_text_xml("<body><p><r><t>A</t></r><r><t>B</t></r></p></body>")
  let walker : DocxTextWalker = { styles, paragraphs: [], section_index: 0, }
  walker.blocks(body, false)
  let items = walker.paragraphs[0].items
  items[0].props.fonts[0] = "Changed"
  assert_eq(items[1].props.fonts[0], "Parent")
  assert_eq(walker.paragraphs[0].mark.fonts[0], "Parent")
}
