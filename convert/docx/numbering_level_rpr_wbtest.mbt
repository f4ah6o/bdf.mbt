///|
fn docx_level_test_numbering(level : String, replacement : String) -> String {
  "<numbering><abstractNum abstractNumId=\"a\"><lvl ilvl=\"0\">" +
  "<numFmt val=\"bullet\"/><lvlText val=\"•\"/>" +
  level +
  "</lvl></abstractNum><num numId=\"n\"><abstractNumId val=\"a\"/>" +
  replacement +
  "</num></numbering>"
}

///|
fn docx_level_test_walker(mark : String) -> DocxTextWalker raise {
  docx_mark_walker(
    "<styles/>",
    "<body><p><pPr><numPr><numId val=\"n\"/><ilvl val=\"0\"/></numPr>" +
    "<rPr>" +
    mark +
    "</rPr></pPr><r><t>Body</t></r></p></body>",
  )
}

///|
test "DOCX list level properties override mark only on label" {
  let walker = docx_level_test_walker(
    "<rFonts ascii=\"Mark\"/><sz val=\"60\"/><b/><u val=\"single\"/><highlight val=\"yellow\"/>",
  )
  let levels = docx_numbering_from_xml(
    docx_level_test_numbering(
      "<rPr><rFonts ascii=\"Level\"/><sz val=\"24\"/><b val=\"0\"/><i/><color val=\"AABBCC\"/><u val=\"double\" color=\"FF0000\"/><highlight val=\"green\"/></rPr>",
      "",
    ),
  )
  docx_apply_numbering(walker.blocks, levels)
  let p = walker.paragraphs[0]
  let label = p.items[0].props
  assert_eq(label.fonts[0], "Level")
  assert_eq(label.size, 12.0)
  assert_eq(label.toggles & 1, 0)
  assert_eq(label.toggles & 2, 2)
  assert_eq(label.color, 0xaabbccffU)
  assert_eq(label.underline, "none")
  assert_eq(label.highlight, "")
  assert_eq(p.mark.fonts[0], "Mark")
  assert_eq(p.mark.size, 30.0)
  assert_eq(p.mark.toggles & 1, 1)
  assert_eq(p.mark.underline, "single")
  assert_eq(p.items[2].props.size, 10.0)
}

///|
test "DOCX level overrides replace rPr but startOverride preserves it" {
  let walker = docx_level_test_walker("<sz val=\"60\"/>")
  let numbering = docx_numbering_from_xml(
    docx_level_test_numbering(
      "<rPr><sz val=\"24\"/><b/></rPr>", "<lvlOverride ilvl=\"0\"><startOverride val=\"4\"/><lvl ilvl=\"0\"><numFmt val=\"decimal\"/><lvlText val=\"%1.\"/><rPr><sz val=\"36\"/><i/></rPr></lvl></lvlOverride>",
    ),
  )
  docx_apply_numbering(walker.blocks, numbering)
  let label = walker.paragraphs[0].items[0]
  assert_eq(label.text, "4.")
  assert_eq(label.props.size, 18.0)
  assert_eq(label.props.toggles & 1, 0)
  assert_eq(label.props.toggles & 2, 2)
  let start_walker = docx_level_test_walker("<sz val=\"60\"/>")
  let start_only = docx_numbering_from_xml(
    docx_level_test_numbering(
      "<rPr><sz val=\"24\"/><b/></rPr>", "<lvlOverride ilvl=\"0\"><startOverride val=\"4\"/></lvlOverride>",
    ),
  )
  docx_apply_numbering(start_walker.blocks, start_only)
  assert_eq(start_walker.paragraphs[0].items[0].props.size, 12.0)
  assert_eq(start_walker.paragraphs[0].items[0].props.toggles & 1, 1)
}

///|
test "DOCX list level theme font resolves against the document theme" {
  let walker = docx_level_test_walker("<rFonts ascii=\"Mark\"/>")
  let theme = @ooxml.default_theme_fonts()
  theme.major.latin = "Synthetic Major"
  let numbering = docx_numbering_from_xml(
    docx_level_test_numbering(
      "<rPr><rFonts asciiTheme=\"majorAscii\"/></rPr>", "",
    ),
  )
  docx_apply_numbering(walker.blocks, numbering, theme_fonts=theme)
  assert_eq(walker.paragraphs[0].items[0].props.fonts[0], "Synthetic Major")
  assert_eq(walker.paragraphs[0].mark.fonts[0], "Mark")
}

///|
test "DOCX symbol-font bullets map to Unicode and keep mark fonts" {
  let walker = docx_level_test_walker(
    "<rFonts ascii=\"Mark\"/><sz val=\"28\"/>",
  )
  let xml = "<numbering><abstractNum abstractNumId=\"a\"><lvl ilvl=\"0\">" +
    "<numFmt val=\"bullet\"/><lvlText val=\"\u{f0b7}\"/>" +
    "<rPr><rFonts ascii=\"Symbol\"/><sz val=\"36\"/></rPr></lvl></abstractNum>" +
    "<num numId=\"n\"><abstractNumId val=\"a\"/></num></numbering>"
  docx_apply_numbering(walker.blocks, docx_numbering_from_xml(xml))
  let label = walker.paragraphs[0].items[0]
  assert_eq(label.text, "•")
  assert_eq(label.props.fonts[0], "Mark")
  assert_eq(label.props.size, 18.0)
  assert_eq(
    docx_numbering_map_symbol("Wingdings", "\u{f06c}\u{f0fc}"),
    "●✔",
  )
  assert_eq(docx_numbering_map_symbol("Webdings", "\u{f06c}"), "\u{f06c}")
}

///|
fn docx_level_property(half_points : Int32, bold : Bool) -> Bool raise {
  let walker = docx_level_test_walker("<sz val=\"60\"/><b/>")
  let level = "<rPr><sz val=\"" +
    half_points.to_string() +
    "\"/><b val=\"" +
    (if bold { "1" } else { "0" }) +
    "\"/></rPr>"
  docx_apply_numbering(
    walker.blocks,
    docx_numbering_from_xml(docx_level_test_numbering(level, "")),
  )
  let p = walker.paragraphs[0]
  p.items[0].props.size == half_points.to_double() / 2.0 &&
  ((p.items[0].props.toggles & 1) != 0) == bold &&
  p.mark.size == 30.0 &&
  (p.mark.toggles & 1) != 0 &&
  p.items[2].props.size == 10.0
}

///|
test "DOCX generated level formatting stays isolated from paragraph mark" {
  @quickcheck.check((size_byte : Byte) => {
    let half_points = size_byte.to_int() + 1
    try
      docx_level_property(half_points, true) &&
      docx_level_property(half_points, false)
    catch {
      _ => false
    }
  })
}

///|
test "DOCX package renders list-level size independently of body" {
  let numbering = "<w:numbering xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">" +
    "<w:abstractNum w:abstractNumId=\"0\"><w:lvl w:ilvl=\"0\">" +
    "<w:numFmt w:val=\"decimal\"/><w:lvlText w:val=\"%1.\"/>" +
    "<w:rPr><w:sz w:val=\"48\"/><w:u w:val=\"single\" w:color=\"FF0000\"/>" +
    "<w:eastAsianLayout w:combine=\"1\"/></w:rPr></w:lvl></w:abstractNum>" +
    "<w:num w:numId=\"1\"><w:abstractNumId w:val=\"0\"/></w:num></w:numbering>"
  let rels = "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
    "<Relationship Id=\"n\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering\" Target=\"numbering.xml\"/>" +
    "</Relationships>"
  let body = "<w:p><w:pPr><w:numPr><w:numId w:val=\"1\"/></w:numPr>" +
    "<w:rPr><w:sz w:val=\"60\"/></w:rPr></w:pPr><w:r><w:t>Body</w:t></w:r></w:p>"
  let data = docx_test_docx(body, DOCX_TEST_SECTION, [
    ("word/_rels/document.xml.rels", @utf8.encode(rels)),
    ("word/numbering.xml", @utf8.encode(numbering)),
  ])
  let document = docx_document_text(data)
  assert_eq(document.paragraphs[0].items[0].props.size, 24.0)
  assert_eq(document.paragraphs[0].mark.size, 30.0)
  let result = convert(data)
  assert_true(
    result.warnings.contains(
      "DOCX list label eastAsianLayout combine is not supported",
    ),
  )
  let commands = docx_test_page_commands(result, "pages", 0, "body")
  let mut current_size = 0.0
  let mut label_size = 0.0
  for command in commands {
    match command {
      @render.Font(_, size) => current_size = size
      @render.FillText(text, _, _, _) =>
        if text.contains("1") {
          label_size = current_size
        }
      _ => ()
    }
  }
  assert_eq(label_size, 24.0)
}

///|
test "DOCX list label caps and small caps follow resolved level properties" {
  for small in [false, true] {
    let walker = docx_level_test_walker("<sz val=\"60\"/>")
    let flag = if small { "<smallCaps/>" } else { "<caps/>" }
    let xml = docx_level_test_numbering(
      "<rPr><sz val=\"40\"/>" + flag + "</rPr>",
      "",
    ).replace(old="•", new="Ab")
    docx_apply_numbering(walker.blocks, docx_numbering_from_xml(xml))
    let p = walker.paragraphs[0]
    let layout = docx_layout_paragraph(
      p.items,
      p.props,
      300.0,
      0.0,
      30.0,
      false,
    )
    assert_eq(layout.lines[0].items[0].text, "A")
    assert_eq(layout.lines[0].items[1].text, "B")
    assert_eq(layout.lines[0].items[0].size, 20.0)
    assert_eq(layout.lines[0].items[1].size, if small { 16.0 } else { 20.0 })
    assert_eq(p.mark.size, 30.0)
    assert_eq(p.items[2].props.toggles & 12, 0)
  }
}

///|
test "DOCX list combine degrades with warning and preserves other attributes" {
  let walker = docx_level_test_walker("")
  let warnings : Array[String] = []
  let numbering = docx_numbering_from_xml(
    docx_level_test_numbering(
      "<rPr><eastAsianLayout combine=\"1\" vert=\"1\" vertCompress=\"1\"/></rPr>",
      "",
    ),
  )
  docx_apply_numbering(walker.blocks, numbering, warnings~)
  let label = walker.paragraphs[0].items[0]
  assert_eq(label.text, "•")
  assert_true(label.props.tcy)
  assert_true(label.props.tcy_fit)
  assert_eq(warnings, [
    "DOCX list label eastAsianLayout combine is not supported",
  ])
  assert_false(walker.paragraphs[0].mark.tcy)
}

///|
test "DOCX label inherits mark caps and respects explicit level off" {
  for small in [false, true] {
    for disable in [false, true] {
      let mark = if small { "<smallCaps/>" } else { "<caps/>" }
      let level = if disable {
        if small {
          "<rPr><smallCaps val=\"0\"/></rPr>"
        } else {
          "<rPr><caps val=\"0\"/></rPr>"
        }
      } else {
        ""
      }
      let walker = docx_level_test_walker(mark)
      let xml = docx_level_test_numbering(level, "").replace(
        old="•",
        new="Ab",
      )
      docx_apply_numbering(walker.blocks, docx_numbering_from_xml(xml))
      let p = walker.paragraphs[0]
      let label = p.items[0]
      assert_eq(label.text, if !small && !disable { "AB" } else { "Ab" })
      assert_eq(label.small_caps, small && !disable)
      assert_true((p.mark.toggles & (if small { 8 } else { 4 })) != 0)
      assert_eq(p.items[2].props.toggles & 12, 0)
    }
  }
}
