///|
// Regression tests of the XML reading of a worksheet: a row or a cell written
// across lines, with spaces around `=`, with single quotes or self-closing is
// renumbered like any other, and a sheet whose rows do not move is left byte
// for byte. The parts that anchor to the cells of a sheet whose rows move are
// refused instead of left stale.

///|
fn xml_count(text : String, needle : String) -> Int {
  let mut count = 0
  let mut pos = 0
  while pos < text.length() {
    match text[pos:].find(needle) {
      Some(index) => {
        count += 1
        pos = pos + index + needle.length()
      }
      None => break
    }
  }
  count
}

///|
fn xml_add_part(data : Bytes, name : String, text : String) -> Bytes raise {
  let archive = @zip.open_zip(data)
  let entries : Array[(String, Bytes)] = []
  let mut replaced = false
  for entry in archive.entries {
    if entry.name == name {
      entries.push((name, @utf8.encode(text)))
      replaced = true
    } else {
      entries.push((entry.name, archive.read(entry, 1048576)))
    }
  }
  if !replaced {
    entries.push((name, @utf8.encode(text)))
  }
  stored_zip(entries)
}

///|
fn xml_rels(kind : String, target : String) -> String {
  "<?xml version=\"1.0\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/" +
  kind +
  "\" Target=\"" +
  target +
  "\"/></Relationships>"
}

///|
test "ooxml renumbers a row written across lines without a duplicate attribute" {
  let body = refs_sheet(
    "<row\nr=\"1\">" +
    refs_cell("A1", "{{#items}}{{name}}") +
    refs_cell("B1", "{{/items}}") +
    "</row>" +
    "<row\nr=\"2\">" +
    refs_cell("A2", "tail") +
    "</row>",
  )
  let tpl = refs_xlsx([("Sheet1", body)], "")
  let filled = refs_fill(tpl, refs_items())
  let sheet = refs_part(filled, "xl/worksheets/sheet1.xml")
  assert_eq(xml_count(sheet, "<row\nr=\"1\">"), 1, msg=sheet)
  assert_eq(xml_count(sheet, "<row\nr=\"2\">"), 1, msg=sheet)
  assert_eq(xml_count(sheet, "<row\nr=\"3\">"), 1, msg=sheet)
  assert_true(!sheet.contains("r=\"1\" r="), msg=sheet)
  assert_true(!sheet.contains("r=\"2\" r="), msg=sheet)
  assert_true(!sheet.contains("r=\"3\" r="), msg=sheet)
}

///|
test "ooxml renumbers a cell written across lines" {
  let body = refs_sheet(
    refs_row(
      1,
      refs_cell("A1", "{{#items}}{{name}}") + refs_cell("B1", "{{/items}}"),
    ) +
    "<row r=\"2\"><c\nr=\"A2\" t=\"inlineStr\"><is><t>tail</t></is></c></row>",
  )
  let tpl = refs_xlsx([("Sheet1", body)], "")
  let filled = refs_fill(tpl, refs_items())
  let sheet = refs_part(filled, "xl/worksheets/sheet1.xml")
  assert_true(sheet.contains("<c\nr=\"A3\""), msg=sheet)
  assert_true(!sheet.contains("<c\nr=\"A2\""), msg=sheet)
}

///|
test "ooxml renumbers a row and a cell with spaces around the equals sign" {
  let body = refs_sheet(
    "<row r = \"1\">" +
    refs_cell("A1", "{{#items}}{{name}}") +
    refs_cell("B1", "{{/items}}") +
    "</row>" +
    "<row r = \"2\"><c r = \"A2\" t=\"inlineStr\"><is><t>tail</t></is></c></row>",
  )
  let tpl = refs_xlsx([("Sheet1", body)], "")
  let filled = refs_fill(tpl, refs_items())
  let sheet = refs_part(filled, "xl/worksheets/sheet1.xml")
  assert_true(sheet.contains("<row r = \"3\">"), msg=sheet)
  assert_true(sheet.contains("<c r = \"A3\""), msg=sheet)
}

///|
test "ooxml renumbers a row and a cell with single quotes" {
  let body = refs_sheet(
    "<row r='1'>" +
    refs_cell("A1", "{{#items}}{{name}}") +
    refs_cell("B1", "{{/items}}") +
    "</row>" +
    "<row r='2'><c r='A2' t='inlineStr'><is><t>tail</t></is></c></row>",
  )
  let tpl = refs_xlsx([("Sheet1", body)], "")
  let filled = refs_fill(tpl, refs_items())
  let sheet = refs_part(filled, "xl/worksheets/sheet1.xml")
  assert_true(sheet.contains("<row r='3'>"), msg=sheet)
  assert_true(sheet.contains("<c r='A3'"), msg=sheet)
}

///|
test "ooxml renumbers a self-closing row and cell" {
  let body = refs_sheet(
    refs_row(
      1,
      refs_cell("A1", "{{#items}}{{name}}") + refs_cell("B1", "{{/items}}"),
    ) +
    "<row r=\"2\"><c r=\"A2\"/></row>",
  )
  let tpl = refs_xlsx([("Sheet1", body)], "")
  let filled = refs_fill(tpl, refs_items())
  let sheet = refs_part(filled, "xl/worksheets/sheet1.xml")
  assert_true(sheet.contains("<row r=\"3\">"), msg=sheet)
  assert_true(sheet.contains("<c r=\"A3\"/>"), msg=sheet)
}

///|
test "ooxml keeps a sheet written across lines when no section repeats rows" {
  let body = refs_sheet(
    "<row\nr=\"1\">" +
    refs_cell("A1", "one") +
    "</row>" +
    "<row r = '5'><c\nr = \"A5\"/></row>",
  )
  let tpl = refs_xlsx([("Sheet1", body)], "")
  let filled = refs_fill(tpl, refs_empty())
  assert_eq(
    refs_part(filled, "xl/worksheets/sheet1.xml"),
    refs_part(tpl, "xl/worksheets/sheet1.xml"),
  )
}

///|
test "ooxml refuses a comment when a section repeats rows" {
  let tpl = refs_xlsx([("Sheet1", refs_list_sheet(""))], "")
  let with_comment = xml_add_part(
    tpl,
    "xl/worksheets/_rels/sheet1.xml.rels",
    xml_rels("comments", "../comments1.xml"),
  )
  let message = refs_fill_error(with_comment, refs_items())
  assert_true(message.contains("comment"), msg=message)
}

///|
test "ooxml refuses a VML drawing when a section repeats rows" {
  let tpl = refs_xlsx([("Sheet1", refs_list_sheet(""))], "")
  let with_vml = xml_add_part(
    tpl,
    "xl/worksheets/_rels/sheet1.xml.rels",
    xml_rels("vmlDrawing", "../drawings/vmlDrawing1.vml"),
  )
  let message = refs_fill_error(with_vml, refs_items())
  assert_true(message.contains("VML"), msg=message)
}

///|
test "ooxml refuses a sparkline when a section repeats rows" {
  let body = refs_list_sheet("") +
    "<extLst><ext uri=\"{05C60535-1F16-4fd2-B633-F4F36F0B64E0}\"><x14:sparklineGroups xmlns:x14=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/main\"><x14:sparklineGroup><x14:sparklines><x14:sparkline><xm:f>Sheet1!A1:A3</xm:f><xm:sqref>B1</xm:sqref></x14:sparkline></x14:sparklines></x14:sparklineGroup></x14:sparklineGroups></ext></extLst>"
  let tpl = refs_xlsx([("Sheet1", body)], "")
  let message = refs_fill_error(tpl, refs_items())
  assert_true(message.contains("sparkline"), msg=message)
}

///|
test "ooxml refuses a slicer when a section repeats rows" {
  let tpl = refs_xlsx([("Sheet1", refs_list_sheet(""))], "")
  let with_slicer = xml_add_part(
    tpl,
    "xl/worksheets/_rels/sheet1.xml.rels",
    xml_rels("slicer", "../slicers/slicer1.xml"),
  )
  let message = refs_fill_error(with_slicer, refs_items())
  assert_true(message.contains("slicer"), msg=message)
}

///|
test "ooxml refuses an external link when a section repeats rows" {
  let tpl = refs_xlsx([("Sheet1", refs_list_sheet(""))], "")
  let rels =
    "<?xml version=\"1.0\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/><Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/externalLink\" Target=\"externalLinks/externalLink1.xml\"/></Relationships>"
  let with_link = xml_add_part(tpl, "xl/_rels/workbook.xml.rels", rels)
  let message = refs_fill_error(with_link, refs_items())
  assert_true(message.contains("external link"), msg=message)
}

///|
test "ooxml keeps a comment when no section repeats rows" {
  let body = refs_sheet(refs_row(1, refs_cell("A1", "one")))
  let tpl = refs_xlsx([("Sheet1", body)], "")
  let with_comment = xml_add_part(
    tpl,
    "xl/worksheets/_rels/sheet1.xml.rels",
    xml_rels("comments", "../comments1.xml"),
  )
  let filled = refs_fill(with_comment, refs_empty())
  assert_eq(
    refs_part(filled, "xl/worksheets/sheet1.xml"),
    refs_part(tpl, "xl/worksheets/sheet1.xml"),
  )
}

///|
test "ooxml keeps an external link when no section repeats rows" {
  let body = refs_sheet(refs_row(1, refs_cell("A1", "one")))
  let tpl = refs_xlsx([("Sheet1", body)], "")
  let rels =
    "<?xml version=\"1.0\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/><Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/externalLink\" Target=\"externalLinks/externalLink1.xml\"/></Relationships>"
  let with_link = xml_add_part(tpl, "xl/_rels/workbook.xml.rels", rels)
  let filled = refs_fill(with_link, refs_empty())
  assert_eq(
    refs_part(filled, "xl/workbook.xml"),
    refs_part(tpl, "xl/workbook.xml"),
  )
}

///|
test "ooxml refuses a pivot table when a section repeats rows" {
  let tpl = refs_xlsx([("Sheet1", refs_list_sheet(""))], "")
  let with_pivot = xml_add_part(
    tpl,
    "xl/worksheets/_rels/sheet1.xml.rels",
    xml_rels("pivotTable", "../pivotTables/pivotTable1.xml"),
  )
  let message = refs_fill_error(with_pivot, refs_items())
  assert_true(message.contains("pivot table"), msg=message)
}

///|
test "ooxml keeps the other attributes of a row and a cell" {
  let body = refs_sheet(
    "<row r=\"1\" spans=\"1:2\" x14ac:dyDescent=\"0.25\">" +
    refs_cell("A1", "{{#items}}{{name}}") +
    refs_cell("B1", "{{/items}}") +
    "</row>" +
    "<row r=\"2\" spans=\"1:2\"><c r=\"A2\" s=\"1\" t=\"inlineStr\"><is><t>tail</t></is></c></row>",
  )
  let tpl = refs_xlsx([("Sheet1", body)], "")
  let filled = refs_fill(tpl, refs_items())
  let sheet = refs_part(filled, "xl/worksheets/sheet1.xml")
  assert_true(
    sheet.contains("<row r=\"1\" spans=\"1:2\" x14ac:dyDescent=\"0.25\">"),
    msg=sheet,
  )
  assert_true(
    sheet.contains("<row r=\"2\" spans=\"1:2\" x14ac:dyDescent=\"0.25\">"),
    msg=sheet,
  )
  assert_true(sheet.contains("<row r=\"3\" spans=\"1:2\">"), msg=sheet)
  assert_true(sheet.contains("<c r=\"A3\" s=\"1\" t=\"inlineStr\">"), msg=sheet)
}
