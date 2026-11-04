///|
// Tests for the layout pieces the page and scroll views share: tables with
// real cells, columns, vertical sections and page fields. The documents are
// built as stored ZIP packages, so a test shows the WordprocessingML it uses.

///|
fn docx_test_le16(out : @buffer.Buffer, value : Int32) -> Unit {
  out.write_byte((value & 0xff).to_byte())
  out.write_byte(((value >> 8) & 0xff).to_byte())
}

///|
fn docx_test_le32(out : @buffer.Buffer, value : Int32) -> Unit {
  out.write_byte((value & 0xff).to_byte())
  out.write_byte(((value >> 8) & 0xff).to_byte())
  out.write_byte(((value >> 16) & 0xff).to_byte())
  out.write_byte(((value >> 24) & 0xff).to_byte())
}

///|
fn docx_test_zip(entries : Array[(String, Bytes)]) -> Bytes {
  let out = @buffer.Buffer()
  let offsets : Array[Int32] = []
  for entry in entries {
    let (name, data) = entry
    let encoded = @utf8.encode(name)
    offsets.push(out.length())
    docx_test_le32(out, 0x04034b50)
    docx_test_le16(out, 20)
    docx_test_le16(out, 0)
    docx_test_le16(out, 0)
    docx_test_le16(out, 0)
    docx_test_le16(out, 0)
    docx_test_le32(out, 0)
    docx_test_le32(out, data.length())
    docx_test_le32(out, data.length())
    docx_test_le16(out, encoded.length())
    docx_test_le16(out, 0)
    out.write_bytes(encoded)
    out.write_bytes(data)
  }
  let directory = out.length()
  for index, entry in entries {
    let (name, data) = entry
    let encoded = @utf8.encode(name)
    docx_test_le32(out, 0x02014b50)
    docx_test_le16(out, 20)
    docx_test_le16(out, 20)
    docx_test_le16(out, 0)
    docx_test_le16(out, 0)
    docx_test_le16(out, 0)
    docx_test_le16(out, 0)
    docx_test_le32(out, 0)
    docx_test_le32(out, data.length())
    docx_test_le32(out, data.length())
    docx_test_le16(out, encoded.length())
    docx_test_le16(out, 0)
    docx_test_le16(out, 0)
    docx_test_le16(out, 0)
    docx_test_le16(out, 0)
    docx_test_le32(out, 0)
    docx_test_le32(out, offsets[index])
    out.write_bytes(encoded)
  }
  let directory_size = out.length() - directory
  docx_test_le32(out, 0x06054b50)
  docx_test_le16(out, 0)
  docx_test_le16(out, 0)
  docx_test_le16(out, entries.length())
  docx_test_le16(out, entries.length())
  docx_test_le32(out, directory_size)
  docx_test_le32(out, directory)
  docx_test_le16(out, 0)
  out.to_bytes()
}

///|
const DOCX_TEST_SECTION : String = "<w:sectPr><w:pgSz w:w=\"12240\" w:h=\"15840\"/><w:pgMar w:top=\"1440\" w:right=\"1440\" w:bottom=\"1440\" w:left=\"1440\"/></w:sectPr>"

///|
fn docx_test_docx(
  blocks : String,
  section : String,
  extra : Array[(String, Bytes)],
) -> Bytes {
  let document = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"" +
    " xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"" +
    " xmlns:wp=\"http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing\"" +
    " xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\"" +
    " xmlns:pic=\"http://schemas.openxmlformats.org/drawingml/2006/picture\">" +
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
fn docx_test_repeat(text : String, count : Int32) -> String {
  let out = StringBuilder()
  for _ in 0..<count {
    out.write_string(text)
  }
  out.to_string()
}

///|
fn docx_test_page_commands(
  result : DocxResult,
  view_id : String,
  page_index : Int32,
  role : String,
) -> Array[@render.Command] raise {
  let split = @core.single_to_split(result.bdf)
  let manifest = @core.parse_manifest(@utf8.decode(split.manifest))
  let document = @core.open_single(result.bdf)
  for view in manifest.views {
    if view.id != view_id {
      continue
    }
    let page = view.pages[page_index]
    for layer in page.layers {
      if layer.role == role {
        let resources = @core.decode_object_resources(
          document.part(layer.object),
        )
        return @render.compile_object(resources.object)
      }
    }
  }
  []
}

///|
fn docx_test_commands_text(commands : Array[@render.Command]) -> String {
  let text = StringBuilder()
  for command in commands {
    match command {
      @render.FillText(value, _, _, _) => text.write_string(value)
      _ => ()
    }
  }
  text.to_string()
}

///|
fn docx_test_table(document : DocxTextDocument) -> DocxTable raise {
  for block in document.blocks {
    match block {
      DocxTableBlock(table) => return table
      _ => ()
    }
  }
  fail("expected a table")
}

///|
test "DOCX table cell text wraps inside its grid column" {
  let cell_text = docx_test_repeat("word ", 40)
  let blocks = "<w:tbl><w:tblGrid><w:gridCol w:w=\"2000\"/><w:gridCol w:w=\"3000\"/></w:tblGrid>" +
    "<w:tr><w:tc><w:p><w:r><w:t>" +
    cell_text +
    "</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>B</w:t></w:r></w:p></w:tc></w:tr></w:tbl>"
  let document = docx_document_text(
    docx_test_docx(blocks, DOCX_TEST_SECTION, []),
  )
  let table = docx_test_table(document)
  assert_eq(table.rows[0].cells.length(), 2)
  let layout = docx_layout_table(table, 468.0, 0.0)
  let first = layout.rows[0].cells[0]
  assert_eq((first.x, first.w), (0.0, 100.0), msg="cell box")
  let second = layout.rows[0].cells[1]
  assert_eq((second.x, second.w), (100.0, 150.0), msg="second cell box")
  let mut wrapped = 0
  for block in first.blocks {
    match block {
      DocxCellLines(lines) => wrapped += lines.length()
      DocxCellNested(_) => ()
    }
  }
  assert_true(wrapped > 1, msg="cell text wraps")
  assert_true(
    layout.rows[0].height > 12.0,
    msg="row grows with the wrapped cell",
  )
  let commands = docx_test_page_commands(
    convert(docx_test_docx(blocks, DOCX_TEST_SECTION, [])),
    "pages",
    0,
    "body",
  )
  let mut first_x = -1.0
  let mut second_x = -1.0
  for command in commands {
    match command {
      @render.FillText(value, x, _, _) => {
        if value.has_prefix("word") && first_x < 0.0 {
          first_x = x
        }
        if value == "B" {
          second_x = x
        }
      }
      _ => ()
    }
  }
  assert_true((first_x - 77.4).abs() < 0.01, msg="wrapped cell x")
  assert_true((second_x - 177.4).abs() < 0.01, msg="neighbour cell x")
}

///|
test "DOCX table grid spans and vertical merges are laid out" {
  let blocks = "<w:tbl><w:tblGrid><w:gridCol w:w=\"1000\"/><w:gridCol w:w=\"1000\"/><w:gridCol w:w=\"1000\"/></w:tblGrid>" +
    "<w:tr><w:tc><w:tcPr><w:gridSpan w:val=\"2\"/></w:tcPr><w:p><w:r><w:t>A</w:t></w:r></w:p></w:tc>" +
    "<w:tc><w:p><w:r><w:t>B</w:t></w:r></w:p></w:tc></w:tr>" +
    "<w:tr><w:tc><w:tcPr><w:vMerge w:val=\"restart\"/></w:tcPr><w:p><w:r><w:t>C</w:t></w:r></w:p></w:tc>" +
    "<w:tc><w:p><w:r><w:t>D</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>E</w:t></w:r></w:p></w:tc></w:tr>" +
    "<w:tr><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p/></w:tc>" +
    "<w:tc><w:p><w:r><w:t>F</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>G</w:t></w:r></w:p></w:tc></w:tr></w:tbl>"
  let document = docx_document_text(
    docx_test_docx(blocks, DOCX_TEST_SECTION, []),
  )
  let table = docx_test_table(document)
  assert_eq(table.rows[0].cells[0].span, 2)
  assert_eq(table.rows[0].cells[1].col, 2)
  assert_eq(table.rows[1].cells[0].vmerge, "restart")
  assert_eq(table.rows[1].cells[0].row_span, 2)
  assert_eq(table.rows[2].cells[0].vmerge, "continue")
  let layout = docx_layout_table(table, 468.0, 0.0)
  assert_eq(layout.rows[0].cells[0].w, 100.0, msg="grid span width")
  assert_eq(layout.rows[0].cells[1].x, 100.0, msg="cell after span")
  let text = docx_test_commands_text(
    docx_test_page_commands(
      convert(docx_test_docx(blocks, DOCX_TEST_SECTION, [])),
      "pages",
      0,
      "body",
    ),
  )
  for expected in ["A", "B", "C", "D", "E", "F", "G"] {
    assert_true(text.contains(expected), msg="merged table cell " + expected)
  }
}

///|
test "DOCX table header rows repeat on later pages" {
  let mut rows = "<w:tr><w:trPr><w:tblHeader/></w:trPr><w:tc><w:p><w:r><w:t>H</w:t></w:r></w:p></w:tc></w:tr>"
  for i in 1..<20 {
    rows += "<w:tr><w:tc><w:p><w:r><w:t>R\{i}</w:t></w:r></w:p></w:tc></w:tr>"
  }
  let blocks = "<w:tbl><w:tblGrid><w:gridCol w:w=\"2000\"/></w:tblGrid>" +
    rows +
    "</w:tbl>"
  let section = "<w:sectPr><w:pgSz w:w=\"12240\" w:h=\"6000\"/><w:pgMar w:top=\"720\" w:right=\"1440\" w:bottom=\"720\" w:left=\"1440\"/></w:sectPr>"
  let result = convert(docx_test_docx(blocks, section, []))
  assert_true(result.pages >= 2, msg="table splits across pages")
  let second = docx_test_commands_text(
    docx_test_page_commands(result, "pages", 1, "body"),
  )
  assert_true(second.contains("H"), msg="header row repeats")
  assert_true(second.contains("R"), msg="data rows continue")
}

///|
test "DOCX sections flow through columns" {
  let mut blocks = ""
  for i in 0..<60 {
    blocks += "<w:p><w:r><w:t>Line \{i}</w:t></w:r></w:p>"
  }
  let two_columns = "<w:sectPr><w:pgSz w:w=\"11906\" w:h=\"16838\"/>" +
    "<w:pgMar w:top=\"1985\" w:right=\"1701\" w:bottom=\"1701\" w:left=\"1701\"/>" +
    "<w:cols w:num=\"2\" w:space=\"425\"/></w:sectPr>"
  let one_column = "<w:sectPr><w:pgSz w:w=\"11906\" w:h=\"16838\"/>" +
    "<w:pgMar w:top=\"1985\" w:right=\"1701\" w:bottom=\"1701\" w:left=\"1701\"/>" +
    "<w:cols w:space=\"425\"/></w:sectPr>"
  let columned = convert(docx_test_docx(blocks, two_columns, []))
  let plain = convert(docx_test_docx(blocks, one_column, []))
  assert_true(
    columned.pages < plain.pages,
    msg="columns hold more lines on a page",
  )
  let commands = docx_test_page_commands(columned, "pages", 0, "body")
  let mut first = false
  let mut second = false
  for command in commands {
    match command {
      @render.FillText(value, x, _, _) =>
        if value.has_prefix("Line") {
          if (x - 85.05).abs() < 0.05 {
            first = true
          }
          if (x - 308.275).abs() < 0.05 {
            second = true
          }
        }
      _ => ()
    }
  }
  assert_true(first, msg="first column at the left margin")
  assert_true(second, msg="second column after the column space")
}

///|
test "DOCX vertical sections turn the page content" {
  let mut blocks = ""
  for i in 0..<12 {
    blocks += "<w:p><w:r><w:t>縦書きの文書\{i}</w:t></w:r></w:p>"
  }
  let vertical = "<w:sectPr><w:pgSz w:w=\"11906\" w:h=\"16838\"/>" +
    "<w:pgMar w:top=\"1985\" w:right=\"1701\" w:bottom=\"1701\" w:left=\"1701\"/>" +
    "<w:textDirection w:val=\"tbRl\"/></w:sectPr>"
  let horizontal = "<w:sectPr><w:pgSz w:w=\"11906\" w:h=\"16838\"/>" +
    "<w:pgMar w:top=\"1985\" w:right=\"1701\" w:bottom=\"1701\" w:left=\"1701\"/></w:sectPr>"
  let result = convert(docx_test_docx(blocks, vertical, []))
  let commands = docx_test_page_commands(result, "pages", 0, "body")
  let mut transform = false
  for command in commands {
    match command {
      @render.Transform(a, b, c, d, e, f) =>
        if (a - 0.0).abs() < 0.001 &&
          (b - 1.0).abs() < 0.001 &&
          (c + 1.0).abs() < 0.001 &&
          (d - 0.0).abs() < 0.001 &&
          (e - 510.25).abs() < 0.01 &&
          (f - 99.25).abs() < 0.01 {
          transform = true
        }
      _ => ()
    }
  }
  assert_true(transform, msg="vertical body is turned by 90 degrees")
  let text = docx_test_commands_text(commands)
  assert_true(text.contains("縦書き"), msg="vertical text")
  let plain = convert(docx_test_docx(blocks, horizontal, []))
  let mut plain_transform = false
  for command in docx_test_page_commands(plain, "pages", 0, "body") {
    match command {
      @render.Transform(_, _, _, _, _, _) => plain_transform = true
      _ => ()
    }
  }
  assert_false(plain_transform, msg="horizontal body is not turned")
}

///|
fn docx_test_header_document(
  header : String,
  body : String,
  extra : Array[(String, Bytes)],
) -> Bytes {
  let section = "<w:sectPr><w:headerReference w:type=\"default\" r:id=\"rIdH\"/>" +
    "<w:pgSz w:w=\"12240\" w:h=\"15840\"/>" +
    "<w:pgMar w:top=\"1440\" w:right=\"1440\" w:bottom=\"1440\" w:left=\"1440\" w:header=\"720\" w:footer=\"720\"/></w:sectPr>"
  let rels = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
    "<Relationship Id=\"rIdH\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/header\" Target=\"header1.xml\"/>" +
    "</Relationships>"
  let entries : Array[(String, Bytes)] = [
    ("word/_rels/document.xml.rels", @utf8.encode(rels)),
    ("word/header1.xml", @utf8.encode(header)),
  ]
  for entry in extra {
    entries.push(entry)
  }
  docx_test_docx(body, section, entries)
}

///|
fn docx_test_header(root : String) -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<w:hdr xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"" +
  " xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"" +
  " xmlns:wp=\"http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing\"" +
  " xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\"" +
  " xmlns:pic=\"http://schemas.openxmlformats.org/drawingml/2006/picture\">" +
  root +
  "</w:hdr>"
}

///|
test "DOCX page fields are regenerated on each page" {
  let header = docx_test_header(
    "<w:p><w:r><w:t>Page </w:t></w:r>" +
    "<w:r><w:fldChar w:fldCharType=\"begin\"/></w:r>" +
    "<w:r><w:instrText> PAGE </w:instrText></w:r>" +
    "<w:r><w:fldChar w:fldCharType=\"separate\"/></w:r>" +
    "<w:r><w:t>9</w:t></w:r>" +
    "<w:r><w:fldChar w:fldCharType=\"end\"/></w:r>" +
    "<w:r><w:t> of </w:t></w:r>" +
    "<w:fldSimple w:instr=\" NUMPAGES \"><w:r><w:t>9</w:t></w:r></w:fldSimple></w:p>",
  )
  let body = "<w:p><w:r><w:t>One</w:t></w:r></w:p>" +
    "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>" +
    "<w:p><w:r><w:t>Two</w:t></w:r></w:p>"
  let result = convert(docx_test_header_document(header, body, []))
  assert_eq(result.pages, 2)
  let first = docx_test_commands_text(
    docx_test_page_commands(result, "pages", 0, "header"),
  )
  let second = docx_test_commands_text(
    docx_test_page_commands(result, "pages", 1, "header"),
  )
  assert_eq(first, "Page 1 of 2", msg="first page fields")
  assert_eq(second, "Page 2 of 2", msg="second page fields")
}

///|
test "DOCX header images are drawn on the page" {
  let header = docx_test_header(
    "<w:p><w:r><w:drawing><wp:inline>" +
    "<wp:extent cx=\"914400\" cy=\"914400\"/>" +
    "<a:graphic><a:graphicData><pic:pic><pic:blipFill>" +
    "<a:blip r:embed=\"rIdImg\"/>" +
    "</pic:blipFill></pic:pic></a:graphicData></a:graphic>" +
    "</wp:inline></w:drawing></w:r></w:p>",
  )
  let rels = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
    "<Relationship Id=\"rIdImg\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"media/logo.png\"/>" +
    "</Relationships>"
  let extra : Array[(String, Bytes)] = [
    ("word/_rels/header1.xml.rels", @utf8.encode(rels)),
    ("word/media/logo.png", b"not-a-real-png"),
  ]
  let result = convert(
    docx_test_header_document(
      header, "<w:p><w:r><w:t>Body</w:t></w:r></w:p>", extra,
    ),
  )
  let commands = docx_test_page_commands(result, "pages", 0, "header")
  let mut image = false
  for command in commands {
    match command {
      @render.Image(_, x, y, w, h) =>
        if (x - 72.0).abs() < 0.01 &&
          (y - 36.0).abs() < 0.01 &&
          (w - 72.0).abs() < 0.01 &&
          (h - 72.0).abs() < 0.01 {
          image = true
        }
      _ => ()
    }
  }
  assert_true(image, msg="header image placed at the header origin")
}

///|
test "DOCX numbering instances override the start of a level" {
  let numbering = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<w:numbering xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">" +
    "<w:abstractNum w:abstractNumId=\"0\"><w:lvl w:ilvl=\"0\">" +
    "<w:start w:val=\"1\"/><w:numFmt w:val=\"decimal\"/><w:lvlText w:val=\"%1.\"/>" +
    "</w:lvl></w:abstractNum>" +
    "<w:num w:numId=\"1\"><w:abstractNumId w:val=\"0\"/>" +
    "<w:lvlOverride w:ilvl=\"0\"><w:startOverride w:val=\"5\"/></w:lvlOverride>" +
    "</w:num></w:numbering>"
  let rels = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
    "<Relationship Id=\"rIdN\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering\" Target=\"numbering.xml\"/>" +
    "</Relationships>"
  let body = "<w:p><w:pPr><w:numPr><w:ilvl w:val=\"0\"/><w:numId w:val=\"1\"/></w:numPr></w:pPr><w:r><w:t>First</w:t></w:r></w:p>" +
    "<w:p><w:pPr><w:numPr><w:ilvl w:val=\"0\"/><w:numId w:val=\"1\"/></w:numPr></w:pPr><w:r><w:t>Second</w:t></w:r></w:p>"
  let entries : Array[(String, Bytes)] = [
    ("word/_rels/document.xml.rels", @utf8.encode(rels)),
    ("word/numbering.xml", @utf8.encode(numbering)),
  ]
  let document = docx_document_text(
    docx_test_docx(body, DOCX_TEST_SECTION, entries),
  )
  assert_eq(document.paragraphs.length(), 2)
  assert_eq(document.paragraphs[0].items[0].text, "5.")
  assert_eq(document.paragraphs[1].items[0].text, "6.")
}

///|
test "DOCX views selects the views to build" {
  let data = docx_test_docx(
    "<w:p><w:r><w:t>Hello</w:t></w:r></w:p>",
    DOCX_TEST_SECTION,
    [],
  )
  let both = convert(data)
  let both_split = @core.single_to_split(both.bdf)
  let both_manifest = @core.parse_manifest(@utf8.decode(both_split.manifest))
  assert_eq(both_manifest.views.length(), 2)
  let pages = convert(data, views="pages")
  let pages_split = @core.single_to_split(pages.bdf)
  let pages_manifest = @core.parse_manifest(@utf8.decode(pages_split.manifest))
  assert_eq(pages_manifest.views.length(), 1)
  assert_eq(pages_manifest.views[0].id, "pages")
  assert_eq(pages.pages, 1)
  assert_true(pages.summary.contains("1 page, 0 scroll strips"))
  let scroll = convert(data, views="scroll")
  let scroll_split = @core.single_to_split(scroll.bdf)
  let scroll_manifest = @core.parse_manifest(
    @utf8.decode(scroll_split.manifest),
  )
  assert_eq(scroll_manifest.views.length(), 1)
  assert_eq(scroll_manifest.views[0].id, "scroll")
  assert_eq(scroll.pages, 0)
  assert_true(scroll.summary.contains("0 pages, 1 scroll strip"))
  let rejected = try {
    ignore(convert(data, views="slides"))
    false
  } catch {
    DocxInvalid(message) => message.contains("invalid views")
    _ => false
  }
  assert_true(rejected, msg="invalid views are rejected")
}

///|
test "DOCX even headers are used when settings enable them" {
  let body = "<w:p><w:r><w:t>One</w:t></w:r></w:p>" +
    "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>" +
    "<w:p><w:r><w:t>Two</w:t></w:r></w:p>"
  let section = "<w:sectPr>" +
    "<w:headerReference w:type=\"default\" r:id=\"rIdD\"/>" +
    "<w:headerReference w:type=\"even\" r:id=\"rIdE\"/>" +
    "<w:pgSz w:w=\"12240\" w:h=\"15840\"/>" +
    "<w:pgMar w:top=\"1440\" w:right=\"1440\" w:bottom=\"1440\" w:left=\"1440\" w:header=\"720\" w:footer=\"720\"/></w:sectPr>"
  let rels = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
    "<Relationship Id=\"rIdD\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/header\" Target=\"header1.xml\"/>" +
    "<Relationship Id=\"rIdE\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/header\" Target=\"header2.xml\"/>" +
    "<Relationship Id=\"rIdS\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/>" +
    "</Relationships>"
  let settings = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<w:settings xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:evenAndOddHeaders/></w:settings>"
  let entries : Array[(String, Bytes)] = [
    ("word/_rels/document.xml.rels", @utf8.encode(rels)),
    (
      "word/header1.xml",
      @utf8.encode(
        docx_test_header("<w:p><w:r><w:t>DefaultHeader</w:t></w:r></w:p>"),
      ),
    ),
    (
      "word/header2.xml",
      @utf8.encode(
        docx_test_header("<w:p><w:r><w:t>EvenHeader</w:t></w:r></w:p>"),
      ),
    ),
    ("word/settings.xml", @utf8.encode(settings)),
  ]
  let result = convert(docx_test_docx(body, section, entries))
  assert_eq(result.pages, 2)
  let second = docx_test_commands_text(
    docx_test_page_commands(result, "pages", 1, "header"),
  )
  assert_eq(second, "EvenHeader")
}

///|
test "DOCX scroll view draws table cells in place" {
  let blocks = "<w:tbl><w:tblGrid><w:gridCol w:w=\"2000\"/><w:gridCol w:w=\"3000\"/></w:tblGrid>" +
    "<w:tr><w:tc><w:p><w:r><w:t>A</w:t></w:r></w:p></w:tc>" +
    "<w:tc><w:p><w:r><w:t>B</w:t></w:r></w:p></w:tc></w:tr></w:tbl>"
  let result = convert(
    docx_test_docx(blocks, DOCX_TEST_SECTION, []),
    views="scroll",
  )
  assert_eq(result.pages, 0)
  let split = @core.single_to_split(result.bdf)
  let manifest = @core.parse_manifest(@utf8.decode(split.manifest))
  assert_eq(manifest.views.length(), 1)
  let view = manifest.views[0]
  assert_eq(view.id, "scroll")
  assert_eq(view.pages[0].width, 540.0, msg="scroll width includes its margin")
  let document = @core.open_single(result.bdf)
  let hash = match view.text_index {
    Some(value) => value
    None => ""
  }
  let text = StringBuilder()
  for run in @core.decode_text_index(document.part(hash)) {
    text.write_string(run.text)
  }
  assert_true(text.to_string().contains("A"), msg="scroll table cell A")
  assert_true(text.to_string().contains("B"), msg="scroll table cell B")
}

///|
test "DOCX text indexes number the stories of a page in order" {
  let result = convert(docx_story_fixture())
  let split = @core.single_to_split(result.bdf)
  let manifest = @core.parse_manifest(@utf8.decode(split.manifest))
  let document = @core.open_single(result.bdf)
  let pages = manifest.views[0]
  let hash = match pages.text_index {
    Some(value) => value
    None => fail("missing text index")
  }
  let layers : Map[Int32, Bool] = Map([])
  for run in @core.decode_text_index(document.part(hash)) {
    layers[run.b] = true
  }
  assert_true(layers.contains(0), msg="header layer index")
  assert_true(layers.contains(1), msg="footer layer index")
  assert_true(layers.contains(2), msg="body layer index")
  assert_eq(layers.length(), 3)
  // A footer-only page numbers its footer and body from zero.
  let section = "<w:sectPr><w:footerReference w:type=\"default\" r:id=\"rIdF\"/>" +
    "<w:pgSz w:w=\"12240\" w:h=\"15840\"/>" +
    "<w:pgMar w:top=\"1440\" w:right=\"1440\" w:bottom=\"1440\" w:left=\"1440\" w:footer=\"720\"/></w:sectPr>"
  let rels = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
    "<Relationship Id=\"rIdF\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer\" Target=\"footer1.xml\"/>" +
    "</Relationships>"
  let extra : Array[(String, Bytes)] = [
    ("word/_rels/document.xml.rels", @utf8.encode(rels)),
    (
      "word/footer1.xml",
      @utf8.encode(
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
        "<w:ftr xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">" +
        "<w:p><w:r><w:t>Footer</w:t></w:r></w:p></w:ftr>",
      ),
    ),
  ]
  let only_footer = convert(
    docx_test_docx("<w:p><w:r><w:t>Body</w:t></w:r></w:p>", section, extra),
  )
  let footer_split = @core.single_to_split(only_footer.bdf)
  let footer_manifest = @core.parse_manifest(
    @utf8.decode(footer_split.manifest),
  )
  let footer_document = @core.open_single(only_footer.bdf)
  let footer_hash = match footer_manifest.views[0].text_index {
    Some(value) => value
    None => fail("missing text index")
  }
  let footer_layers : Map[Int32, Bool] = Map([])
  for run in @core.decode_text_index(footer_document.part(footer_hash)) {
    footer_layers[run.b] = true
  }
  assert_true(footer_layers.contains(0), msg="footer-only footer index")
  assert_true(footer_layers.contains(1), msg="footer-only body index")
  assert_eq(footer_layers.length(), 2)
}

///|
// Floating drawings: a wp:anchor with a wrap; the tests below build the
// packages they convert.
fn docx_test_float_rels() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
  "<Relationship Id=\"rIdImg\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"media/float.png\"/>" +
  "</Relationships>"
}

///|
fn docx_test_float_docx(blocks : String) -> Bytes {
  docx_test_docx(
    blocks,
    DOCX_TEST_SECTION,
    [
      ("word/_rels/document.xml.rels", @utf8.encode(docx_test_float_rels())),
      ("word/media/float.png", b"not-a-real-png"),
    ],
  )
}

///|
fn docx_test_float(
  attrs : String,
  position : String,
  wrap : String,
  extent : String,
) -> String {
  "<w:r><w:drawing><wp:anchor " +
  attrs +
  ">" +
  "<wp:simplePos x=\"0\" y=\"0\"/>" +
  position +
  "<wp:extent " +
  extent +
  "/>" +
  wrap +
  "<a:graphic><a:graphicData><pic:pic><pic:blipFill>" +
  "<a:blip r:embed=\"rIdImg\"/>" +
  "</pic:blipFill></pic:pic></a:graphicData></a:graphic>" +
  "</wp:anchor></w:drawing></w:r>"
}

///|
fn docx_test_float_in_column() -> String {
  "<wp:positionH relativeFrom=\"column\"><wp:align>left</wp:align></wp:positionH>" +
  "<wp:positionV relativeFrom=\"paragraph\"><wp:posOffset>0</wp:posOffset></wp:positionV>"
}

///|
fn docx_test_image_at(
  commands : Array[@render.Command],
  x : Double,
  y : Double,
) -> Bool {
  for command in commands {
    match command {
      @render.Image(_, ix, iy, _, _) =>
        if (ix - x).abs() < 0.01 && (iy - y).abs() < 0.01 {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
test "DOCX text wraps on the right of a left floating picture" {
  let text = docx_test_repeat("word ", 120)
  let blocks = "<w:p>" +
    docx_test_float(
      "distT=\"0\" distB=\"0\" distL=\"0\" distR=\"114300\" behindDoc=\"0\" relativeHeight=\"1\"",
      docx_test_float_in_column(),
      "<wp:wrapSquare wrapText=\"right\"/>",
      "cx=\"914400\" cy=\"914400\"",
    ) +
    "<w:r><w:t xml:space=\"preserve\">" +
    text +
    "</w:t></w:r></w:p>"
  let result = convert(docx_test_float_docx(blocks))
  let commands = docx_test_page_commands(result, "pages", 0, "body")
  assert_true(
    docx_test_image_at(commands, 72.0, 72.0),
    msg="left float sits at the column's left edge and the first line's top",
  )
  let mut first = -1.0
  let mut wrapped = false
  let mut below = false
  for command in commands {
    match command {
      @render.FillText(_, x, y, _) => {
        if first < 0.0 {
          first = x
        }
        if (x - 153.0).abs() < 0.01 && y < 144.0 {
          wrapped = true
        }
        if (x - 72.0).abs() < 0.01 && y > 144.0 {
          below = true
        }
      }
      _ => ()
    }
  }
  assert_true(
    (first - 153.0).abs() < 0.01,
    msg="the first line starts after the picture and its right distance",
  )
  assert_true(wrapped, msg="lines beside the picture are shortened")
  assert_true(below, msg="lines below the picture use the full column")
  assert_eq(result.pages, 1)
}

///|
test "DOCX text stops at the left of a right floating picture" {
  let text = docx_test_repeat("word ", 120)
  let blocks = "<w:p>" +
    docx_test_float(
      "distT=\"0\" distB=\"0\" distL=\"114300\" distR=\"0\" behindDoc=\"0\" relativeHeight=\"1\"",
      "<wp:positionH relativeFrom=\"column\"><wp:align>right</wp:align></wp:positionH>" +
      "<wp:positionV relativeFrom=\"paragraph\"><wp:posOffset>0</wp:posOffset></wp:positionV>",
      "<wp:wrapSquare wrapText=\"left\"/>",
      "cx=\"914400\" cy=\"914400\"",
    ) +
    "<w:r><w:t xml:space=\"preserve\">" +
    text +
    "</w:t></w:r></w:p>"
  let result = convert(docx_test_float_docx(blocks))
  let commands = docx_test_page_commands(result, "pages", 0, "body")
  assert_true(
    docx_test_image_at(commands, 468.0, 72.0),
    msg="right float sits at the column's right edge",
  )
  let mut first = -1.0
  let mut wrapped = false
  let mut over = false
  for command in commands {
    match command {
      @render.FillText(_, x, y, advance) => {
        if first < 0.0 {
          first = x
        }
        if y < 144.0 {
          if x + advance > 459.01 {
            over = true
          }
          if (x - 72.0).abs() < 0.01 && advance > 300.0 {
            wrapped = true
          }
        }
      }
      _ => ()
    }
  }
  assert_true(
    (first - 72.0).abs() < 0.01,
    msg="the first line starts at the column's left edge",
  )
  assert_true(wrapped, msg="lines beside the picture are shortened")
  assert_false(over, msg="no line runs into the picture or its left distance")
}

///|
test "DOCX text skips the band of a top-and-bottom floating picture" {
  let text = docx_test_repeat("word ", 40)
  let blocks = "<w:p>" +
    docx_test_float(
      "distT=\"0\" distB=\"0\" distL=\"0\" distR=\"0\" behindDoc=\"0\" relativeHeight=\"1\"",
      "<wp:positionH relativeFrom=\"margin\"><wp:align>center</wp:align></wp:positionH>" +
      "<wp:positionV relativeFrom=\"paragraph\"><wp:posOffset>0</wp:posOffset></wp:positionV>",
      "<wp:wrapTopAndBottom/>",
      "cx=\"2540000\" cy=\"635000\"",
    ) +
    "<w:r><w:t xml:space=\"preserve\">" +
    text +
    "</w:t></w:r></w:p>"
  let result = convert(docx_test_float_docx(blocks))
  let commands = docx_test_page_commands(result, "pages", 0, "body")
  assert_true(
    docx_test_image_at(commands, 206.0, 72.0),
    msg="the picture is centered in the margins",
  )
  let mut first_y = -1.0
  let mut inside = false
  for command in commands {
    match command {
      @render.FillText(_, _, y, _) => {
        if first_y < 0.0 {
          first_y = y
        }
        if y > 72.0 && y < 122.0 {
          inside = true
        }
      }
      _ => ()
    }
  }
  assert_true(
    (first_y - 132.0).abs() < 0.01,
    msg="the first line starts below the picture's band",
  )
  assert_false(inside, msg="no line is drawn inside the band")
}

///|
test "DOCX behind-doc pictures are drawn under the text and in-front ones over it" {
  let blocks = "<w:p>" +
    docx_test_float(
      "distT=\"0\" distB=\"0\" distL=\"0\" distR=\"0\" behindDoc=\"1\" relativeHeight=\"1\"",
      "<wp:positionH relativeFrom=\"page\"><wp:posOffset>1270000</wp:posOffset></wp:positionH>" +
      "<wp:positionV relativeFrom=\"page\"><wp:posOffset>1270000</wp:posOffset></wp:positionV>",
      "<wp:wrapNone/>",
      "cx=\"914400\" cy=\"914400\"",
    ) +
    docx_test_float(
      "distT=\"0\" distB=\"0\" distL=\"0\" distR=\"0\" behindDoc=\"0\" relativeHeight=\"2\"",
      "<wp:positionH relativeFrom=\"page\"><wp:posOffset>2540000</wp:posOffset></wp:positionH>" +
      "<wp:positionV relativeFrom=\"page\"><wp:posOffset>2540000</wp:posOffset></wp:positionV>",
      "<wp:wrapNone/>",
      "cx=\"914400\" cy=\"914400\"",
    ) +
    "<w:r><w:t>OVERLAP</w:t></w:r></w:p>"
  let result = convert(docx_test_float_docx(blocks))
  let commands = docx_test_page_commands(result, "pages", 0, "body")
  let mut behind = -1
  let mut text = -1
  let mut front = -1
  for index, command in commands {
    match command {
      @render.Image(_, x, _, _, _) =>
        if (x - 100.0).abs() < 0.01 {
          behind = index
        } else if (x - 200.0).abs() < 0.01 {
          front = index
        }
      @render.FillText(_, _, _, _) =>
        if text < 0 {
          text = index
        }
      _ => ()
    }
  }
  assert_true(behind >= 0, msg="behind-doc picture is drawn")
  assert_true(front >= 0, msg="in-front picture is drawn")
  assert_true(text > behind, msg="the behind-doc picture is drawn under the text")
  assert_true(front > text, msg="the in-front picture is drawn over the text")
}

///|
test "DOCX floating picture moves to the next page when it does not fit" {
  let body = StringBuilder()
  for i in 0..<47 {
    body.write_string(
      "<w:p><w:r><w:t>Filler " + i.to_string() + "</w:t></w:r></w:p>",
    )
  }
  body.write_string(
    "<w:p>" +
    docx_test_float(
      "distT=\"0\" distB=\"0\" distL=\"0\" distR=\"0\" behindDoc=\"0\" relativeHeight=\"1\"",
      docx_test_float_in_column(),
      "<wp:wrapSquare wrapText=\"right\"/>",
      "cx=\"914400\" cy=\"3810000\"",
    ) +
    "<w:r><w:t>Floated paragraph</w:t></w:r></w:p>",
  )
  let result = convert(docx_test_float_docx(body.to_string()))
  assert_eq(result.pages, 2)
  let first = docx_test_page_commands(result, "pages", 0, "body")
  let second = docx_test_page_commands(result, "pages", 1, "body")
  assert_false(
    docx_test_image_at(first, 72.0, 72.0),
    msg="the picture is not left on the full page",
  )
  assert_false(
    docx_test_commands_text(first).contains("Floated paragraph"),
    msg="the paragraph goes with its picture",
  )
  assert_true(
    docx_test_image_at(second, 72.0, 72.0),
    msg="the picture stands at the top of the next page",
  )
  assert_true(
    docx_test_commands_text(second).contains("Floated paragraph"),
    msg="the paragraph is laid out beside its picture",
  )
}

///|
test "DOCX inline drawings stay in the line" {
  let blocks = "<w:p>" +
    "<w:r><w:t xml:space=\"preserve\">Before </w:t></w:r>" +
    "<w:r><w:drawing><wp:inline>" +
    "<wp:extent cx=\"457200\" cy=\"457200\"/>" +
    "<a:graphic><a:graphicData><pic:pic><pic:blipFill>" +
    "<a:blip r:embed=\"rIdImg\"/>" +
    "</pic:blipFill></pic:pic></a:graphicData></a:graphic>" +
    "</wp:inline></w:drawing></w:r>" +
    "<w:r><w:t xml:space=\"preserve\"> after</w:t></w:r></w:p>"
  let result = convert(docx_test_float_docx(blocks))
  let commands = docx_test_page_commands(result, "pages", 0, "body")
  assert_true(
    docx_test_image_at(commands, 104.5, 72.0),
    msg="the inline picture follows the text in the line",
  )
  let mut before = -1.0
  let mut after = -1.0
  let mut same_line = false
  for command in commands {
    match command {
      @render.FillText(value, x, y, _) => {
        if value == "Before " {
          before = x
        } else if value == " after" {
          after = x
          same_line = (y - 82.0).abs() < 0.01
        }
      }
      _ => ()
    }
  }
  assert_true(
    (before - 72.0).abs() < 0.01,
    msg="the text before the picture is at the line's start",
  )
  assert_true(
    (after - 140.5).abs() < 0.01,
    msg="the text after the picture continues in the line",
  )
  assert_true(same_line, msg="the line is not broken around the picture")
}

///|
fn docx_keep_lines_fixture(keep : Bool) -> Bytes raise {
  let mut body = ""
  for _ in 0..<44 {
    body += "<w:p><w:r><w:t>filler</w:t></w:r></w:p>"
  }
  let props = if keep { "<w:pPr><w:keepLines/></w:pPr>" } else { "" }
  body += "<w:p>" + props + "<w:r><w:t>" +
    docx_test_repeat("KEEPWORD ", 30) + "</w:t></w:r></w:p>"
  docx_test_docx(body, DOCX_TEST_SECTION, [])
}

///|
fn docx_keep_pages(result : DocxResult) -> Array[Int32] raise {
  let doc = @core.open_single(result.bdf)
  let view = doc.manifest.views[0]
  let hash = match view.text_index {
    Some(value) => value
    None => return []
  }
  let pages : Array[Int32] = []
  for run in @core.decode_text_index(doc.part(hash)) {
    if run.text.contains("KEEPWORD") && !pages.contains(run.a) {
      pages.push(run.a)
    }
  }
  pages
}

fn docx_keep_next_fixture(keep : Bool) -> Bytes raise {
  let keep_prop = if keep { "<w:keepNext/>" } else { "" }
  let props = "<w:pPr><w:spacing w:before=\"12360\"/>" + keep_prop +
    "</w:pPr>"
  let body = "<w:p>" + props +
    "<w:r><w:rPr><w:sz w:val=\"40\"/></w:rPr><w:t>KEEPWITH</w:t></w:r></w:p>" +
    "<w:p><w:r><w:t>" + docx_test_repeat("NEXTWORD ", 20) +
    "</w:t></w:r></w:p>"
  docx_test_docx(body, DOCX_TEST_SECTION, [])
}

///|
fn docx_marker_pages(result : DocxResult, marker : String) -> Array[Int32] raise {
  let doc = @core.open_single(result.bdf)
  let view = doc.manifest.views[0]
  let hash = match view.text_index {
    Some(value) => value
    None => return []
  }
  let pages : Array[Int32] = []
  for run in @core.decode_text_index(doc.part(hash)) {
    if run.text.contains(marker) && !pages.contains(run.a) {
      pages.push(run.a)
    }
  }
  pages
}

fn docx_table_width_fixture(with_width : Bool) -> Bytes raise {
  let width = if with_width {
    "<w:tblPr><w:tblW w:w=\"5000\" w:type=\"dxa\"/></w:tblPr>"
  } else {
    "<w:tblPr/>"
  }
  let table = "<w:tbl>" + width +
    "<w:tblGrid><w:gridCol w:w=\"1000\"/><w:gridCol w:w=\"1000\"/></w:tblGrid>" +
    "<w:tr><w:tc><w:tcPr><w:tcW w:w=\"1000\" w:type=\"dxa\"/></w:tcPr><w:p><w:r><w:t>LEFT</w:t></w:r></w:p></w:tc>" +
    "<w:tc><w:tcPr><w:tcW w:w=\"1000\" w:type=\"dxa\"/></w:tcPr><w:p><w:r><w:t>RIGHT</w:t></w:r></w:p></w:tc></w:tr></w:tbl>"
  docx_test_docx(table, DOCX_TEST_SECTION, [])
}

///|
fn docx_text_x_prefix(commands : Array[@render.Command], wanted : String) -> Double {
  for command in commands {
    match command {
      FillText(text, x, _, _) => if text.has_prefix(wanted) {
        return x
      }
      _ => ()
    }
  }
  0.0
}

///|
fn docx_text_x(commands : Array[@render.Command], wanted : String) -> Double {
  for command in commands {
    match command {
      FillText(text, x, _, _) => if text == wanted {
        return x
      }
      _ => ()
    }
  }
  0.0
}

test "DOCX custom table style supplies borders and shading" {
  let styles = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<w:styles xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">" +
    "<w:style w:type=\"table\" w:styleId=\"GridStyle\"><w:tblPr><w:tblBorders>" +
    "<w:top w:val=\"single\" w:sz=\"8\" w:color=\"000000\"/>" +
    "<w:left w:val=\"single\" w:sz=\"8\" w:color=\"000000\"/>" +
    "<w:bottom w:val=\"single\" w:sz=\"8\" w:color=\"000000\"/>" +
    "<w:right w:val=\"single\" w:sz=\"8\" w:color=\"000000\"/>" +
    "<w:insideH w:val=\"single\" w:sz=\"8\" w:color=\"000000\"/>" +
    "<w:insideV w:val=\"single\" w:sz=\"8\" w:color=\"000000\"/>" +
    "</w:tblBorders></w:tblPr><w:tcPr><w:shd w:fill=\"EEEEEE\"/></w:tcPr></w:style>" +
    "</w:styles>"
  let rels = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
    "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/>" +
    "</Relationships>"
  let table = "<w:tbl><w:tblPr><w:tblStyle w:val=\"GridStyle\"/></w:tblPr>" +
    "<w:tblGrid><w:gridCol w:w=\"2000\"/></w:tblGrid>" +
    "<w:tr><w:tc><w:p><w:r><w:t>STYLED</w:t></w:r></w:p></w:tc></w:tr></w:tbl>"
  let content_types = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">" +
    "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>" +
    "<Default Extension=\"xml\" ContentType=\"application/xml\"/>" +
    "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>" +
    "<Override PartName=\"/word/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml\"/>" +
    "</Types>"
  let data = docx_test_docx(table, DOCX_TEST_SECTION, [
    ("[Content_Types].xml", @utf8.encode(content_types)),
    ("word/styles.xml", @utf8.encode(styles)),
    ("word/_rels/document.xml.rels", @utf8.encode(rels)),
  ])
  let result = convert(data)
  let commands = docx_test_page_commands(result, "pages", 0, "body")
  let mut black = false
  let mut grey = false
  let mut fills = 0
  for command in commands {
    match command {
      FillColor(value) => {
        if value == 0x000000ff {
          black = true
        } else if value.to_uint() == 0xeeeeeeffU {
          grey = true
        }
      }
      FillRect(_, _, _, _) => fills += 1
      _ => ()
    }
  }
  assert_true(black)
  assert_true(grey)
  assert_true(fills > 0)
}

test "DOCX table style conditional first row and band shading" {
  let styles = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<w:styles xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">" +
    "<w:style w:type=\"table\" w:styleId=\"BandStyle\"><w:tblPr/>" +
    "<w:tblStylePr w:type=\"firstRow\"><w:rPr><w:color w:val=\"FFFFFF\"/></w:rPr><w:tcPr><w:shd w:fill=\"FF0000\"/></w:tcPr></w:tblStylePr>" +
    "<w:tblStylePr w:type=\"band1Horz\"><w:tcPr><w:shd w:fill=\"0000FF\"/></w:tcPr></w:tblStylePr>" +
    "</w:style></w:styles>"
  let rels = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
    "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/>" +
    "</Relationships>"
  let content_types = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">" +
    "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>" +
    "<Default Extension=\"xml\" ContentType=\"application/xml\"/>" +
    "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>" +
    "<Override PartName=\"/word/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml\"/>" +
    "</Types>"
  let table = "<w:tbl><w:tblPr><w:tblStyle w:val=\"BandStyle\"/>" +
    "<w:tblLook w:firstRow=\"1\" w:lastRow=\"0\" w:firstColumn=\"0\" w:lastColumn=\"0\" w:noHBand=\"0\" w:noVBand=\"1\"/></w:tblPr>" +
    "<w:tblGrid><w:gridCol w:w=\"4000\"/></w:tblGrid>" +
    "<w:tr><w:tc><w:p><w:r><w:t>ONE</w:t></w:r></w:p></w:tc></w:tr>" +
    "<w:tr><w:tc><w:p><w:r><w:t>TWO</w:t></w:r></w:p></w:tc></w:tr></w:tbl>"
  let data = docx_test_docx(table, DOCX_TEST_SECTION, [
    ("[Content_Types].xml", @utf8.encode(content_types)),
    ("word/styles.xml", @utf8.encode(styles)),
    ("word/_rels/document.xml.rels", @utf8.encode(rels)),
  ])
  let commands = docx_test_page_commands(convert(data), "pages", 0, "body")
  let mut red = false
  let mut blue = false
  let mut white = false
  for command in commands {
    match command {
      FillColor(value) =>
        if value.to_uint() == 0xff0000ffU {
          red = true
        } else if value.to_uint() == 0x0000ffffU {
          blue = true
        } else if value.to_uint() == 0xffffffffU {
          white = true
        }
      _ => ()
    }
  }
  assert_true(red)
  assert_true(blue)
  assert_true(white)
}

test "DOCX table style corner cells override row and column parts" {
  let styles = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<w:styles xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">" +
    "<w:style w:type=\"table\" w:styleId=\"CornerStyle\"><w:tblPr/>" +
    "<w:tblStylePr w:type=\"firstRow\"><w:tcPr><w:shd w:fill=\"FF0000\"/></w:tcPr></w:tblStylePr>" +
    "<w:tblStylePr w:type=\"nwCell\"><w:tcPr><w:shd w:fill=\"00FF00\"/></w:tcPr></w:tblStylePr>" +
    "</w:style></w:styles>"
  let rels = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
    "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/>" +
    "</Relationships>"
  let content_types = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">" +
    "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>" +
    "<Default Extension=\"xml\" ContentType=\"application/xml\"/>" +
    "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>" +
    "<Override PartName=\"/word/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml\"/>" +
    "</Types>"
  let table = "<w:tbl><w:tblPr><w:tblStyle w:val=\"CornerStyle\"/>" +
    "<w:tblLook w:firstRow=\"1\" w:firstColumn=\"1\"/></w:tblPr>" +
    "<w:tblGrid><w:gridCol w:w=\"2000\"/><w:gridCol w:w=\"2000\"/></w:tblGrid>" +
    "<w:tr><w:tc><w:p><w:r><w:t>A</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>B</w:t></w:r></w:p></w:tc></w:tr>" +
    "<w:tr><w:tc><w:p><w:r><w:t>C</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>D</w:t></w:r></w:p></w:tc></w:tr></w:tbl>"
  let data = docx_test_docx(table, DOCX_TEST_SECTION, [
    ("[Content_Types].xml", @utf8.encode(content_types)),
    ("word/styles.xml", @utf8.encode(styles)),
    ("word/_rels/document.xml.rels", @utf8.encode(rels)),
  ])
  let commands = docx_test_page_commands(convert(data), "pages", 0, "body")
  let mut red = false
  let mut green = false
  for command in commands {
    match command {
      FillColor(value) =>
        if value.to_uint() == 0xff0000ffU {
          red = true
        } else if value.to_uint() == 0x00ff00ffU {
          green = true
        }
      _ => ()
    }
  }
  assert_true(red)
  assert_true(green)
}

test "DOCX PAGEREF resolves the bookmark page" {
  let blocks = "<w:p><w:bookmarkStart w:id=\"0\" w:name=\"Target\"/><w:r><w:t>TARGET</w:t></w:r></w:p>" +
    "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>" +
    "<w:p><w:r><w:fldChar w:fldCharType=\"begin\"/></w:r>" +
    "<w:r><w:instrText xml:space=\"preserve\"> PAGEREF Target \\* MERGEFORMAT </w:instrText></w:r>" +
    "<w:r><w:fldChar w:fldCharType=\"separate\"/></w:r>" +
    "<w:r><w:t>9</w:t></w:r>" +
    "<w:r><w:fldChar w:fldCharType=\"end\"/></w:r></w:p>"
  let result = convert(docx_test_docx(blocks, DOCX_TEST_SECTION, []))
  let commands = docx_test_page_commands(result, "pages", 1, "body")
  let text = StringBuilder()
  for command in commands {
    match command {
      FillText(value, _, _, _) => text.write_string(value)
      _ => ()
    }
  }
  assert_true(text.to_string().contains("1"))
  assert_true(!text.to_string().contains("9"))
}

test "DOCX column separators are drawn between columns" {
  let section = "<w:sectPr><w:cols w:num=\"2\" w:space=\"720\" w:sep=\"1\"/>" +
    "<w:pgSz w:w=\"12240\" w:h=\"15840\"/><w:pgMar w:top=\"1440\" w:right=\"1440\" w:bottom=\"1440\" w:left=\"1440\"/></w:sectPr>"
  let blocks = docx_test_repeat(
    "<w:p><w:r><w:t>column text</w:t></w:r></w:p>", 8,
  )
  let commands = docx_test_page_commands(
    convert(docx_test_docx(blocks, section, [])), "pages", 0, "body",
  )
  let mut separators = 0
  for command in commands {
    match command {
      FillRect(_, _, width, _) =>
        if (width - 0.5).abs() < 0.01 {
          separators += 1
        }
      _ => ()
    }
  }
  assert_true(separators > 0)
}

test "DOCX header tables are laid out" {
  let header = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<w:hdr xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" " +
    "xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
    "<w:tbl><w:tblPr><w:tblBorders>" +
    "<w:top w:val=\"single\" w:sz=\"8\" w:color=\"000000\"/>" +
    "<w:left w:val=\"single\" w:sz=\"8\" w:color=\"000000\"/>" +
    "<w:bottom w:val=\"single\" w:sz=\"8\" w:color=\"000000\"/>" +
    "<w:right w:val=\"single\" w:sz=\"8\" w:color=\"000000\"/>" +
    "</w:tblBorders></w:tblPr><w:tblGrid><w:gridCol w:w=\"4000\"/></w:tblGrid>" +
    "<w:tr><w:tc><w:p><w:r><w:t>HEADCELL</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:hdr>"
  let rels = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
    "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/header\" Target=\"header1.xml\"/>" +
    "</Relationships>"
  let content_types = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">" +
    "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>" +
    "<Default Extension=\"xml\" ContentType=\"application/xml\"/>" +
    "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>" +
    "<Override PartName=\"/word/header1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml\"/>" +
    "</Types>"
  let section = "<w:sectPr><w:headerReference w:type=\"default\" r:id=\"rId1\"/>" +
    "<w:pgSz w:w=\"12240\" w:h=\"15840\"/><w:pgMar w:top=\"1440\" w:right=\"1440\" w:bottom=\"1440\" w:left=\"1440\"/></w:sectPr>"
  let data = docx_test_docx(
    "<w:p><w:r><w:t>BODY</w:t></w:r></w:p>",
    section,
    [
      ("[Content_Types].xml", @utf8.encode(content_types)),
      ("word/header1.xml", @utf8.encode(header)),
      ("word/_rels/document.xml.rels", @utf8.encode(rels)),
    ],
  )
  let commands = docx_test_page_commands(convert(data), "pages", 0, "header")
  let text = StringBuilder()
  let mut fills = 0
  for command in commands {
    match command {
      FillText(value, _, _, _) => text.write_string(value)
      FillRect(_, _, _, _) => fills += 1
      _ => ()
    }
  }
  assert_true(text.to_string().contains("HEADCELL"))
  assert_true(fills > 0)
}

test "DOCX TableGrid style supplies missing cell borders" {
  let table = "<w:tbl><w:tblPr><w:tblStyle w:val=\"TableGrid\"/></w:tblPr>" +
    "<w:tblGrid><w:gridCol w:w=\"2000\"/></w:tblGrid>" +
    "<w:tr><w:tc><w:p><w:r><w:t>GRID</w:t></w:r></w:p></w:tc></w:tr></w:tbl>"
  let result = convert(docx_test_docx(table, DOCX_TEST_SECTION, []))
  let commands = docx_test_page_commands(result, "pages", 0, "body")
  let mut black = false
  let mut fills = 0
  for command in commands {
    match command {
      FillColor(0x000000ff) => black = true
      FillRect(_, _, _, _) => fills += 1
      _ => ()
    }
  }
  assert_true(black)
  assert_true(fills > 0)
}

fn docx_table_autofit_fixture(autofit : Bool) -> Bytes raise {
  let layout = if autofit {
    "<w:tblLayout w:type=\"autofit\"/>"
  } else {
    ""
  }
  let table = "<w:tbl><w:tblPr>" + layout +
    "</w:tblPr><w:tblGrid><w:gridCol w:w=\"1000\"/><w:gridCol w:w=\"1000\"/></w:tblGrid>" +
    "<w:tr><w:tc><w:p><w:r><w:t>LEFTLEFTLEFTLEFTLEFTLEFT</w:t></w:r></w:p></w:tc>" +
    "<w:tc><w:p><w:r><w:t>RIGHT</w:t></w:r></w:p></w:tc></w:tr></w:tbl>"
  docx_test_docx(table, DOCX_TEST_SECTION, [])
}

test "DOCX autofit table distributes columns by content" {
  let fixed = convert(docx_table_autofit_fixture(false))
  let auto = convert(docx_table_autofit_fixture(true))
  let fixed_commands = docx_test_page_commands(fixed, "pages", 0, "body")
  let auto_commands = docx_test_page_commands(auto, "pages", 0, "body")
  let fixed_gap = docx_text_x_prefix(fixed_commands, "R") -
    docx_text_x_prefix(fixed_commands, "L")
  let auto_gap = docx_text_x_prefix(auto_commands, "R") -
    docx_text_x_prefix(auto_commands, "L")
  assert_true(fixed_gap > 0.0 && auto_gap > fixed_gap + 20.0)
}

test "DOCX table width scales the grid columns" {
  let plain = convert(docx_table_width_fixture(false))
  let wide = convert(docx_table_width_fixture(true))
  let plain_commands = docx_test_page_commands(plain, "pages", 0, "body")
  let wide_commands = docx_test_page_commands(wide, "pages", 0, "body")
  let plain_gap = docx_text_x(plain_commands, "RIGHT") -
    docx_text_x(plain_commands, "LEFT")
  let wide_gap = docx_text_x(wide_commands, "RIGHT") -
    docx_text_x(wide_commands, "LEFT")
  assert_true(plain_gap > 0.0 && wide_gap > plain_gap + 20.0)
}

test "DOCX keepNext keeps the next paragraph on the page" {
  let plain = convert(docx_keep_next_fixture(false))
  let keep = convert(docx_keep_next_fixture(true))
  let plain_first = docx_marker_pages(plain, "KEEPWITH")
  let plain_next = docx_marker_pages(plain, "NEXTWORD")
  let keep_first = docx_marker_pages(keep, "KEEPWITH")
  let keep_next = docx_marker_pages(keep, "NEXTWORD")
  assert_true(!plain_first.is_empty() && !plain_next.is_empty())
  assert_true(plain_first[0] < plain_next[0])
  assert_true(!keep_first.is_empty() && !keep_next.is_empty())
  assert_eq(keep_first[0], keep_next[0])
}

test "DOCX keepLines does not split a paragraph across pages" {
  let plain = convert(docx_keep_lines_fixture(false))
  let keep = convert(docx_keep_lines_fixture(true))
  let plain_pages = docx_keep_pages(plain)
  let keep_pages = docx_keep_pages(keep)
  assert_true(!keep_pages.is_empty())
  assert_eq(keep_pages.length(), 1)
  assert_true(keep_pages[0] >= plain_pages[0])
}

test "DOCX page borders are drawn in a background layer" {
  let section = "<w:sectPr><w:pgSz w:w=\"12240\" w:h=\"15840\"/>" +
    "<w:pgMar w:top=\"1440\" w:right=\"1440\" w:bottom=\"1440\" w:left=\"1440\"/>" +
    "<w:pgBorders w:offsetFrom=\"text\">" +
    "<w:top w:val=\"single\" w:sz=\"8\" w:space=\"4\" w:color=\"FF0000\"/>" +
    "<w:left w:val=\"single\" w:sz=\"8\" w:space=\"4\" w:color=\"FF0000\"/>" +
    "<w:bottom w:val=\"single\" w:sz=\"8\" w:space=\"4\" w:color=\"FF0000\"/>" +
    "<w:right w:val=\"single\" w:sz=\"8\" w:space=\"4\" w:color=\"FF0000\"/>" +
    "</w:pgBorders></w:sectPr>"
  let data = docx_test_docx(
    "<w:p><w:r><w:t>Border</w:t></w:r></w:p>", section, [],
  )
  let result = convert(data)
  let doc = @core.open_single(result.bdf)
  let view = doc.manifest.views[0]
  let page = view.pages[0]
  let mut background = ""
  for layer in page.layers {
    if layer.role == "background" {
      background = layer.object
    }
  }
  assert_true(background != "", msg="DOCX page border background layer")
  let mut red = 0
  let mut strokes = 0
  for command in @render.decode_commands(doc.part(background)) {
    match command {
      StrokeColor(0xff0000ff) => red += 1
      StrokePath(_) => strokes += 1
      _ => ()
    }
  }
  assert_eq(red, 4)
  assert_eq(strokes, 4)
}

