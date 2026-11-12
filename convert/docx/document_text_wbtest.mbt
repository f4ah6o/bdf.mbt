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
      "<body><p><r><drawing/></r></p></body>", "<body><p><r><rPr/><rPr/></r></p></body>",
      "<body><p><r><tab><drawing/></tab></r></p></body>", "<body><sdt><sdtContent><p><pPr><sectPr/></pPr></p></sdtContent></sdt></body>",
      "<body><sectPr><bogus/></sectPr></body>",
    ] {
    let root = docx_text_xml(source)
    let walker : DocxTextWalker = {
      styles: docx_styles_from_xml("<styles/>"),
      blocks: [],
      paragraphs: [],
      section_index: 0,
      fields: [],
      bookmarks: Map([]),
      open_bookmarks: [],
      current_link: "",
      has_math: false,
      warnings: [],
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
test "DOCX anchor effect extents are parsed" {
  let root = docx_text_xml(
    "<wp:anchor xmlns:wp=\"http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing\">" +
    "<wp:effectExtent l=\"0\" t=\"0\" r=\"914400\" b=\"127000\"/></wp:anchor>",
  )
  let (_, _, anchor) = docx_text_anchor(root)
  assert_eq(anchor.effect_right, 72.0)
  assert_eq(anchor.effect_bottom, 10.0)
}

///|
test "DOCX resolved run properties are isolated between runs" {
  let styles = docx_styles_from_xml(
    "<styles><style type=\"paragraph\" styleId=\"p\" default=\"1\"><rPr><rFonts ascii=\"Parent\"/></rPr></style></styles>",
  )
  let body = docx_text_xml("<body><p><r><t>A</t></r><r><t>B</t></r></p></body>")
  let walker : DocxTextWalker = {
    styles,
    blocks: [],
    paragraphs: [],
    section_index: 0,
    fields: [],
    bookmarks: Map([]),
    open_bookmarks: [],
    current_link: "",
    has_math: false,
    warnings: [],
  }
  walker.blocks(body, false)
  let items = walker.paragraphs[0].items
  items[0].props.fonts[0] = "Changed"
  assert_eq(items[1].props.fonts[0], "Parent")
  assert_eq(walker.paragraphs[0].mark.fonts[0], "Parent")
}

///|
fn docx_mark_walker(styles : String, body : String) -> DocxTextWalker raise {
  let walker : DocxTextWalker = {
    styles: docx_styles_from_xml(styles),
    blocks: [],
    paragraphs: [],
    section_index: 0,
    fields: [],
    bookmarks: Map([]),
    open_bookmarks: [],
    current_link: "",
    has_math: false,
    warnings: [],
  }
  walker.blocks(docx_text_xml(body), false)
  walker
}

///|
test "DOCX paragraph mark reads direct run properties" {
  // Upstream resolves the paragraph mark like a run: the style chain plus
  // the direct w:pPr/w:rPr (wordproc/model.go paragraph()).
  let walker = docx_mark_walker(
    "<styles/>",
    "<body><p><pPr><rPr><sz val=\"60\"/><rFonts ascii=\"Mark\"/></rPr></pPr></p></body>",
  )
  let paragraph = walker.paragraphs[0]
  assert_eq(paragraph.items.length(), 0)
  assert_eq(paragraph.mark.size, 30.0)
  assert_eq(paragraph.mark.fonts[0], "Mark")
}

///|
test "DOCX paragraph mark sizing follows the resolver precedence" {
  // Document default 10pt, paragraph style 20pt, character default 24pt;
  // the direct w:pPr/w:rPr must win over all of them.
  let styles = "<styles>" +
    "<docDefaults><rPrDefault><rPr><sz val=\"20\"/></rPr></rPrDefault></docDefaults>" +
    "<style type=\"paragraph\" styleId=\"p\"><rPr><sz val=\"40\"/></rPr></style>" +
    "<style type=\"character\" styleId=\"c\" default=\"1\"><rPr><sz val=\"48\"/></rPr></style>" +
    "</styles>"
  let walker = docx_mark_walker(
    styles,
    "<body>" +
    "<p><pPr><pStyle val=\"p\"/></pPr></p>" +
    "<p><pPr><pStyle val=\"p\"/><rPr><sz val=\"60\"/></rPr></pPr></p>" +
    "</body>",
  )
  assert_eq(walker.paragraphs[0].mark.size, 24.0)
  assert_eq(walker.paragraphs[1].mark.size, 30.0)
}

///|
test "DOCX paragraph mark boundary sizes stay half-point exact" {
  for pair in [
      ("2", 1.0), ("40", 20.0), ("60", 30.0), ("1000", 500.0),
    ] {
    let walker = docx_mark_walker(
      "<styles/>",
      "<body><p><pPr><rPr><sz val=\"" + pair.0 + "\"/></rPr></pPr></p></body>",
    )
    assert_eq(
      walker.paragraphs[0].mark.size,
      pair.1,
      msg="mark sz " + pair.0,
    )
  }
  // szCs sizes the complex-script mark, not the layout one.
  let cs = docx_mark_walker(
    "<styles/>",
    "<body><p><pPr><rPr><szCs val=\"120\"/></rPr></pPr></p></body>",
  )
  assert_eq(cs.paragraphs[0].mark.size, 10.0)
  let both = docx_mark_walker(
    "<styles/>",
    "<body><p><pPr><rPr><sz val=\"60\"/><szCs val=\"120\"/></rPr></pPr></p></body>",
  )
  assert_eq(both.paragraphs[0].mark.size, 30.0)
}

///|
test "DOCX paragraph mark properties do not change run formatting" {
  let walker = docx_mark_walker(
    "<styles/>",
    "<body><p><pPr><rPr><sz val=\"60\"/><b/></rPr></pPr>" +
    "<r><rPr><sz val=\"24\"/></rPr><t>Big</t></r>" +
    "<r><t>Plain</t></r></p></body>",
  )
  let paragraph = walker.paragraphs[0]
  assert_eq(paragraph.mark.size, 30.0)
  assert_true((paragraph.mark.toggles & 1) != 0)
  assert_eq(paragraph.items[0].props.size, 12.0)
  assert_eq(paragraph.items[3].props.size, 10.0)
  assert_true((paragraph.items[3].props.toggles & 1) == 0)
}

///|
test "DOCX empty paragraph line height uses the mark size" {
  // The empty paragraph's only line gets its height from the mark.
  let walker = docx_mark_walker(
    "<styles/>",
    "<body><p><pPr><rPr><sz val=\"60\"/></rPr></pPr></p></body>",
  )
  let paragraph = walker.paragraphs[0]
  let mark_size = if paragraph.mark.size > 0.0 {
    paragraph.mark.size
  } else {
    10.0
  }
  let empty = docx_layout_paragraph(
    paragraph.items,
    paragraph.props,
    468.0,
    0.0,
    mark_size,
    false,
  )
  assert_eq(empty.lines.length(), 1)
  // Reference: a paragraph whose single run carries the same size, laid
  // out with the default mark (mirrors wordproc inline.go: empty lines use
  // the mark's ascent and descent).
  let reference = docx_mark_walker(
    "<styles/>",
    "<body><p><r><rPr><sz val=\"60\"/></rPr><t>A</t></r></p></body>",
  )
  let ref_paragraph = reference.paragraphs[0]
  let ref = docx_layout_paragraph(
    ref_paragraph.items,
    ref_paragraph.props,
    468.0,
    0.0,
    10.0,
    false,
  )
  assert_eq(ref.lines.length(), 1)
  assert_eq(empty.lines[0].height, ref.lines[0].height)
  assert_eq(empty.lines[0].height, 36.0)
}

///|
test "DOCX paragraph mark keeps the default character style" {
  // Upstream resolves the mark with runProps(styleID, "", ...): the mark is
  // bound to the document's default character style, and an rStyle inside
  // w:pPr/w:rPr selects nothing (wordproc/model.go paragraph()).
  let styles = "<styles>" +
    "<style type=\"character\" styleId=\"plain\" default=\"1\"><rPr><sz val=\"48\"/></rPr></style>" +
    "<style type=\"character\" styleId=\"markstyle\"><rPr><sz val=\"80\"/><rFonts ascii=\"Custom\"/></rPr></style>" +
    "</styles>"
  let walker = docx_mark_walker(
    styles,
    "<body><p><pPr><rPr><rStyle val=\"markstyle\"/><sz val=\"60\"/></rPr></pPr>" +
    "<r><rPr><rStyle val=\"markstyle\"/></rPr><t>A</t></r></p></body>",
  )
  let paragraph = walker.paragraphs[0]
  // The mark keeps the default character style (24pt base, default font)
  // with the direct size applied: 30pt, not markstyle's 40pt or its font.
  assert_eq(paragraph.mark.size, 30.0)
  assert_eq(paragraph.mark.fonts[0], "Times New Roman")
  // A text run still resolves its own rStyle.
  assert_eq(paragraph.items[0].props.size, 40.0)
  assert_eq(paragraph.items[0].props.fonts[0], "Custom")
}

///|
const DOCX_MARK_LABEL_NUMBERING : String = "<numbering>" +
  "<abstractNum abstractNumId=\"a\">" +
  "<lvl ilvl=\"0\"><numFmt val=\"decimal\"/><lvlText val=\"%1.\"/><start val=\"1\"/></lvl>" +
  "<lvl ilvl=\"1\"><numFmt val=\"bullet\"/><lvlText val=\"•\"/></lvl>" +
  "</abstractNum><num numId=\"n\"><abstractNumId val=\"a\"/></num></numbering>"

///|
test "DOCX numbering label drops mark underline, shading and highlight" {
  // Upstream makeLabel clears u, hasShd and highlight from the label
  // formatting (wordproc/model.go makeLabel).
  let walker = docx_mark_walker(
    "<styles/>",
    "<body><p><pPr><numPr><numId val=\"n\"/><ilvl val=\"0\"/></numPr>" +
    "<rPr><sz val=\"60\"/><u val=\"single\"/><highlight val=\"yellow\"/><i/></rPr></pPr>" +
    "<r><t>Item</t></r></p></body>",
  )
  docx_apply_numbering(walker.blocks, docx_numbering_from_xml(
    DOCX_MARK_LABEL_NUMBERING,
  ))
  let paragraph = walker.paragraphs[0]
  let label = paragraph.items[0]
  assert_eq(label.kind, "char")
  assert_eq(label.text, "1.")
  assert_eq(label.props.size, 30.0)
  assert_eq(label.props.underline, "none")
  assert_eq(label.props.highlight, "")
  assert_eq(label.props.has_shading, false)
  assert_true((label.props.toggles & 2) != 0)
  let tab = paragraph.items[1]
  assert_eq(tab.kind, "tab")
  assert_eq(tab.props.underline, "none")
  assert_eq(tab.props.highlight, "")
  // The mark itself keeps its decorations; only the label is cleaned.
  assert_eq(paragraph.mark.size, 30.0)
  assert_eq(paragraph.mark.underline, "single")
  assert_eq(paragraph.mark.highlight, "yellow")
  assert_true((paragraph.mark.toggles & 2) != 0)
  // A numbered run keeps its own formatting.
  assert_eq(paragraph.items[2].props.size, 10.0)
  assert_eq(paragraph.items[2].props.underline, "none")
}

///|
test "DOCX bullet label drops mark underline, shading and highlight" {
  let walker = docx_mark_walker(
    "<styles/>",
    "<body><p><pPr><numPr><numId val=\"n\"/><ilvl val=\"1\"/></numPr>" +
    "<rPr><sz val=\"60\"/><u val=\"single\"/><highlight val=\"yellow\"/></rPr></pPr>" +
    "<r><t>Item</t></r></p></body>",
  )
  docx_apply_numbering(walker.blocks, docx_numbering_from_xml(
    DOCX_MARK_LABEL_NUMBERING,
  ))
  let paragraph = walker.paragraphs[0]
  let label = paragraph.items[0]
  assert_eq(label.kind, "char")
  assert_eq(label.text, "•")
  assert_eq(label.props.size, 30.0)
  assert_eq(label.props.underline, "none")
  assert_eq(label.props.highlight, "")
  assert_eq(label.props.has_shading, false)
  let tab = paragraph.items[1]
  assert_eq(tab.kind, "tab")
  assert_eq(tab.props.underline, "none")
  assert_eq(paragraph.items[2].props.size, 10.0)
}

///|
fn docx_indent_mark_size(paragraph : DocxTextParagraph) -> Double {
  if paragraph.mark.size > 0.0 {
    paragraph.mark.size
  } else {
    10.0
  }
}

///|
test "DOCX character-unit indents set exact line coordinates" {
  // wordproc/inline.go indents(): hundredths of a character, scaled by the
  // paragraph mark's size, replace the point attributes when set.
  let walker = docx_mark_walker(
    "<styles/>",
    "<body><p><pPr><rPr><sz val=\"40\"/></rPr>" +
    "<ind left=\"720\" leftChars=\"200\" right=\"1080\" rightChars=\"150\"" +
    " firstLineChars=\"100\"/></pPr>" +
    "<r><t>AAAA</t></r></p></body>",  // 20pt mark: left 40, right 30, first 20
  )
  let paragraph = walker.paragraphs[0]
  assert_eq(paragraph.mark.size, 20.0)
  let layout = docx_layout_paragraph(
    paragraph.items,
    paragraph.props,
    120.0,
    0.0,
    docx_indent_mark_size(paragraph),
    false,
  )
  assert_eq(layout.lines.length(), 1)
  // The first line starts at left + first = 40 + 20 pt.
  assert_eq(layout.lines[0].items[0].x, 60.0)
  // Each plain 10pt 'A' advances 5.5pt.
  assert_eq(layout.lines[0].items[1].x, 65.5)
  assert_eq(layout.lines[0].items[3].x, 76.5)
}

///|
test "DOCX rightChars narrows the wrap edge" {
  // 1.5 characters of 20pt = 30pt of right indent: the line wraps at 42pt,
  // after seven 5.5pt 'A's, and the next line restarts at the left indent.
  let walker = docx_mark_walker(
    "<styles/>",
    "<body><p><pPr><rPr><sz val=\"40\"/></rPr><ind rightChars=\"150\"/></pPr>" +
    "<r><t>AAAAAAAAA</t></r></p></body>",
  )
  let paragraph = walker.paragraphs[0]
  let layout = docx_layout_paragraph(
    paragraph.items,
    paragraph.props,
    72.0,
    0.0,
    docx_indent_mark_size(paragraph),
    false,
  )
  assert_eq(layout.lines.length(), 2)
  assert_eq(layout.lines[0].items.length(), 7)
  assert_eq(layout.lines[0].items[6].x, 33.0)
  assert_eq(layout.lines[1].items[0].x, 0.0)
  assert_eq(layout.lines[1].items.length(), 2)
}

///|
test "DOCX character-unit indents scale by the styled mark size" {
  // The scale is the mark's resolved size: the paragraph style chain sets
  // it, and a direct w:pPr/w:rPr wins over the style.
  let styles = "<styles>" +
    "<docDefaults><rPrDefault><rPr><sz val=\"20\"/></rPr></rPrDefault></docDefaults>" +
    "<style type=\"paragraph\" styleId=\"p\"><rPr><sz val=\"40\"/></rPr></style>" +
    "</styles>"
  let walker = docx_mark_walker(
    styles,
    "<body>" +
    "<p><pPr><pStyle val=\"p\"/><ind leftChars=\"100\"/></pPr>" +
    "<r><t>A</t></r></p>" +
    "<p><pPr><pStyle val=\"p\"/><ind leftChars=\"100\"/><rPr><sz val=\"60\"/></rPr></pPr>" +
    "<r><t>A</t></r></p>" +
    "</body>",
  )
  // 20pt from the paragraph style: one character of 20pt = 20pt.
  let styled = walker.paragraphs[0]
  assert_eq(styled.mark.size, 20.0)
  let styled_layout = docx_layout_paragraph(
    styled.items,
    styled.props,
    72.0,
    0.0,
    docx_indent_mark_size(styled),
    false,
  )
  assert_eq(styled_layout.lines[0].items[0].x, 20.0)
  // 30pt from the direct w:pPr/w:rPr beats the style.
  let direct = walker.paragraphs[1]
  assert_eq(direct.mark.size, 30.0)
  let direct_layout = docx_layout_paragraph(
    direct.items,
    direct.props,
    72.0,
    0.0,
    docx_indent_mark_size(direct),
    false,
  )
  assert_eq(direct_layout.lines[0].items[0].x, 30.0)
}

///|
test "DOCX hangingChars and mixed char/pt indent precedence" {
  // A character-unit attribute replaces the point one; an explicit zero
  // falls back to the point attribute (wordproc/inline.go != 0 guards).
  let walker = docx_mark_walker(
    "<styles/>",
    "<body>" +
    // leftChars 50 = half a 20pt mark (10pt) beats left 36pt.
    "<p><pPr><ind left=\"720\" leftChars=\"50\"/><rPr><sz val=\"40\"/></rPr></pPr>" +
    "<r><t>A</t></r></p>" +
    // leftChars 0 keeps left 36pt.
    "<p><pPr><ind left=\"720\" leftChars=\"0\"/><rPr><sz val=\"40\"/></rPr></pPr>" +
    "<r><t>A</t></r></p>" +
    // hangingChars 200 = -2 marks (20pt): the first line starts at -40pt.
    "<p><pPr><ind hangingChars=\"200\"/><rPr><sz val=\"40\"/></rPr></pPr>" +
    "<r><t>A</t></r></p>" +
    // firstLineChars 0 keeps firstLine 18pt.
    "<p><pPr><ind firstLine=\"360\" firstLineChars=\"0\"/><rPr><sz val=\"40\"/></rPr></pPr>" +
    "<r><t>A</t></r></p>" +
    // hangingChars 150 = -1.5 marks (30pt) over the 18pt first-line point.
    "<p><pPr><ind firstLine=\"360\" hangingChars=\"150\"/><rPr><sz val=\"60\"/></rPr></pPr>" +
    "<r><t>A</t></r></p>" +
    "</body>",
  )
  let expected = [10.0, 36.0, -40.0, 18.0, -45.0]
  for i in 0..<expected.length() {
    let paragraph = walker.paragraphs[i]
    let layout = docx_layout_paragraph(
      paragraph.items,
      paragraph.props,
      120.0,
      0.0,
      docx_indent_mark_size(paragraph),
      false,
    )
    assert_eq(
      layout.lines[0].items[0].x,
      expected[i],
      msg="indent paragraph \\{i}",
    )
  }
}

///|
test "DOCX point-only indents keep their coordinates" {
  // No character-unit attributes: the point attributes keep doing exactly
  // what they did before the character-unit wiring.
  let walker = docx_mark_walker(
    "<styles/>",
    "<body><p><pPr><ind left=\"720\" firstLine=\"360\" right=\"540\"/></pPr>" +
    "<r><t>AAAAAAAA</t></r></p>" +
    "<p><r><t>A</t></r></p>" +
    "</body>",
  )
  let indented = walker.paragraphs[0]
  let indented_layout = docx_layout_paragraph(
    indented.items,
    indented.props,
    120.0,
    0.0,
    docx_indent_mark_size(indented),
    false,
  )
  // 36pt left + 18pt first line; the wrap edge sits at 120 - 27 = 93pt, so
  // the seventh A (ending at 92.5pt) fits and the eighth starts line two at
  // the 36pt left indent.
  assert_eq(indented_layout.lines.length(), 2)
  assert_eq(indented_layout.lines[0].items.length(), 7)
  assert_eq(indented_layout.lines[0].items[0].x, 54.0)
  assert_eq(indented_layout.lines[0].items[6].x, 87.0)
  assert_eq(indented_layout.lines[1].items.length(), 1)
  assert_eq(indented_layout.lines[1].items[0].x, 36.0)
  let plain = walker.paragraphs[1]
  let plain_layout = docx_layout_paragraph(
    plain.items,
    plain.props,
    120.0,
    0.0,
    docx_indent_mark_size(plain),
    false,
  )
  assert_eq(plain_layout.lines[0].items[0].x, 0.0)
}
