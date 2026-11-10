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

///|
test "ooxml renumbers a row and a cell with a greater-than in a double-quoted attribute" {
  let body = refs_sheet(
    "<row r=\"1\" custom=\"a>b\">" +
    refs_cell("A1", "{{#items}}{{name}}") +
    refs_cell("B1", "{{/items}}") +
    "</row>" +
    "<row r=\"2\" custom=\"a>b\"><c r=\"A2\" custom=\"a>b\" t=\"inlineStr\"><is><t>tail</t></is></c></row>",
  )
  let tpl = refs_xlsx([("Sheet1", body)], "")
  let filled = refs_fill(tpl, refs_items())
  let sheet = refs_part(filled, "xl/worksheets/sheet1.xml")
  assert_true(sheet.contains("<row r=\"3\" custom=\"a>b\">"), msg=sheet)
  assert_true(
    sheet.contains("<c r=\"A3\" custom=\"a>b\" t=\"inlineStr\">"),
    msg=sheet,
  )
  assert_true(!sheet.contains("<c r=\"A2\" custom=\"a>b\""), msg=sheet)
}

///|
test "ooxml renumbers a row and a cell with a greater-than in a single-quoted attribute" {
  let body = refs_sheet(
    "<row r='1' custom='a>b'>" +
    refs_cell("A1", "{{#items}}{{name}}") +
    refs_cell("B1", "{{/items}}") +
    "</row>" +
    "<row r='2' custom='a>b'><c r='A2' custom='a>b' t='inlineStr'><is><t>tail</t></is></c></row>",
  )
  let tpl = refs_xlsx([("Sheet1", body)], "")
  let filled = refs_fill(tpl, refs_items())
  let sheet = refs_part(filled, "xl/worksheets/sheet1.xml")
  assert_true(sheet.contains("<row r='3' custom='a>b'>"), msg=sheet)
  assert_true(
    sheet.contains("<c r='A3' custom='a>b' t='inlineStr'>"),
    msg=sheet,
  )
}

///|
test "ooxml moves a merge with a greater-than in an attribute" {
  let body = refs_sheet(
    refs_row(
      1,
      refs_cell("A1", "{{#items}}{{name}}") + refs_cell("B1", "{{/items}}"),
    ) +
    refs_row(2, refs_cell("A2", "tail")),
  ) +
    "<mergeCells count=\"1\"><mergeCell ref=\"A2:B2\" custom=\"a>b\"/></mergeCells>"
  let tpl = refs_xlsx([("Sheet1", body)], "")
  let filled = refs_fill(tpl, refs_items())
  let sheet = refs_part(filled, "xl/worksheets/sheet1.xml")
  assert_true(
    sheet.contains("<mergeCell ref=\"A3:B3\" custom=\"a>b\"/>"),
    msg=sheet,
  )
}

///|
test "ooxml keeps a greater-than attribute when no section repeats rows" {
  let body = refs_sheet(
    "<row r=\"1\" custom=\"a>b\"><c r=\"A1\" custom='a>b' t=\"inlineStr\"><is><t>one</t></is></c></row>",
  )
  let tpl = refs_xlsx([("Sheet1", body)], "")
  let filled = refs_fill(tpl, refs_empty())
  assert_eq(
    refs_part(filled, "xl/worksheets/sheet1.xml"),
    refs_part(tpl, "xl/worksheets/sheet1.xml"),
  )
}

///|
test "ooxml renumbers namespaced rows and cells" {
  let body = refs_sheet(
    "<x:row r=\"1\">" +
    "<x:c r=\"A1\" t=\"inlineStr\"><is><t>{{#items}}{{name}}</t></is></x:c>" +
    "<x:c r=\"B1\" t=\"inlineStr\"><is><t>{{/items}}</t></is></x:c>" +
    "</x:row>" +
    "<x:row r=\"2\"><x:c r=\"A2\" t=\"inlineStr\"><is><t>tail</t></is></x:c></x:row>",
  )
  let tpl = refs_xlsx(
    [("Sheet1", body)],
    "",
    ns=" xmlns:x=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"",
  )
  let filled = refs_fill(tpl, refs_items())
  let sheet = refs_part(filled, "xl/worksheets/sheet1.xml")
  assert_true(sheet.contains("<x:row r=\"3\">"), msg=sheet)
  assert_true(sheet.contains("<x:c r=\"A3\""), msg=sheet)
  assert_true(!sheet.contains("{{"), msg=sheet)
}

///|
test "ooxml keeps a namespaced sheet when no section repeats rows" {
  let body = refs_sheet(
    "<x:row r=\"1\"><x:c r=\"A1\" t=\"inlineStr\"><is><t>one</t></is></x:c></x:row>",
  )
  let tpl = refs_xlsx(
    [("Sheet1", body)],
    "",
    ns=" xmlns:x=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"",
  )
  let filled = refs_fill(tpl, refs_empty())
  assert_eq(
    refs_part(filled, "xl/worksheets/sheet1.xml"),
    refs_part(tpl, "xl/worksheets/sheet1.xml"),
  )
}

///|
test "ooxml refuses a calculation chain when a section repeats rows" {
  let tpl = refs_xlsx([("Sheet1", refs_list_sheet(""))], "")
  let with_chain = xml_add_part(
    tpl,
    "xl/calcChain.xml",
    #|<?xml version="1.0"?><calcChain xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><c r="A1" i="1"/></calcChain>
  )
  let message = refs_fill_error(with_chain, refs_items())
  assert_true(message.contains("calculation chain"), msg=message)
}

///|
test "ooxml refuses a form control when a section repeats rows" {
  let tpl = refs_xlsx([("Sheet1", refs_list_sheet(""))], "")
  let with_control = xml_add_part(
    tpl,
    "xl/worksheets/_rels/sheet1.xml.rels",
    xml_rels("ctrlProp", "../ctrlProps/ctrlProp1.xml"),
  )
  let message = refs_fill_error(with_control, refs_items())
  assert_true(message.contains("form control"), msg=message)
}

///|
test "ooxml refuses a rich value when a section repeats rows" {
  let tpl = refs_xlsx([("Sheet1", refs_list_sheet(""))], "")
  let with_rich = xml_add_part(
    tpl,
    "xl/worksheets/_rels/sheet1.xml.rels",
    xml_rels("richValueRel", "../richData/richValueRel.xml"),
  )
  let message = refs_fill_error(with_rich, refs_items())
  assert_true(message.contains("rich value"), msg=message)
}

///|
test "ooxml refuses a web extension when a section repeats rows" {
  let tpl = refs_xlsx([("Sheet1", refs_list_sheet(""))], "")
  let with_web = xml_add_part(
    tpl,
    "xl/worksheets/_rels/sheet1.xml.rels",
    xml_rels("webextension", "../webextensions/webextension1.xml"),
  )
  let message = refs_fill_error(with_web, refs_items())
  assert_true(message.contains("web extension"), msg=message)
}

///|
test "ooxml keeps a calculation chain when no section repeats rows" {
  let body = refs_sheet(refs_row(1, refs_cell("A1", "one")))
  let tpl = refs_xlsx([("Sheet1", body)], "")
  let with_chain = xml_add_part(
    tpl,
    "xl/calcChain.xml",
    #|<?xml version="1.0"?><calcChain xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><c r="A1" i="1"/></calcChain>
  )
  let filled = refs_fill(with_chain, refs_empty())
  assert_eq(
    refs_part(filled, "xl/worksheets/sheet1.xml"),
    refs_part(tpl, "xl/worksheets/sheet1.xml"),
  )
}

///|
test "ooxml renumbers a row with a greater-than before the row number" {
  let body = refs_sheet(
    "<row custom=\"a>b\" r=\"1\">" +
    refs_cell("A1", "{{#items}}{{name}}") +
    refs_cell("B1", "{{/items}}") +
    "</row>" +
    "<row custom='a>b' r='2'><c custom=\"a>b\" r=\"A2\" t=\"inlineStr\"><is><t>tail</t></is></c></row>",
  )
  let tpl = refs_xlsx([("Sheet1", body)], "")
  let filled = refs_fill(tpl, refs_items())
  let sheet = refs_part(filled, "xl/worksheets/sheet1.xml")
  assert_true(sheet.contains("<row custom='a>b' r='3'>"), msg=sheet)
  assert_true(
    sheet.contains("<c custom=\"a>b\" r=\"A3\" t=\"inlineStr\">"),
    msg=sheet,
  )
}

///|
test "ooxml refuses a prefixed merge when a section repeats rows" {
  let body = refs_list_sheet("") +
    "<x:mergeCells count=\"1\"><x:mergeCell ref=\"A2:B2\"/></x:mergeCells>"
  let tpl = refs_xlsx(
    [("Sheet1", body)],
    "",
    ns=" xmlns:x=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"",
  )
  let message = refs_fill_error(tpl, refs_items())
  assert_true(message.contains("prefixed"), msg=message)
  assert_true(message.contains("mergeCell"), msg=message)
}

///|
test "ooxml refuses a prefixed dimension when a section repeats rows" {
  let body = "<x:dimension ref=\"A1:B3\"/>" + refs_list_sheet("")
  let tpl = refs_xlsx(
    [("Sheet1", body)],
    "",
    ns=" xmlns:x=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"",
  )
  let message = refs_fill_error(tpl, refs_items())
  assert_true(message.contains("prefixed"), msg=message)
  assert_true(message.contains("dimension"), msg=message)
}

///|
test "ooxml refuses a prefixed row break when a section repeats rows" {
  let body = refs_list_sheet("") +
    "<x:rowBreaks count=\"1\"><x:brk id=\"3\" max=\"16383\" man=\"1\"/></x:rowBreaks>"
  let tpl = refs_xlsx(
    [("Sheet1", body)],
    "",
    ns=" xmlns:x=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"",
  )
  let message = refs_fill_error(tpl, refs_items())
  assert_true(message.contains("prefixed"), msg=message)
  assert_true(message.contains("rowBreaks"), msg=message)
}

///|
test "ooxml refuses a prefixed sheet when a section repeats rows" {
  let tpl = refs_xlsx([("Sheet1", refs_list_sheet(""))], "")
  let workbook =
    "<?xml version=\"1.0\"?><x:workbook xmlns:x=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><x:sheets><x:sheet name=\"Sheet1\" sheetId=\"1\" r:id=\"rId1\"/></x:sheets></x:workbook>"
  let with_prefixed = xml_add_part(tpl, "xl/workbook.xml", workbook)
  let message = refs_fill_error(with_prefixed, refs_items())
  assert_true(message.contains("prefixed"), msg=message)
  assert_true(message.contains("<sheet>"), msg=message)
}

///|
test "ooxml refuses a prefixed defined name when a section repeats rows" {
  let tpl = refs_xlsx([("Sheet1", refs_list_sheet(""))], "")
  let workbook =
    "<?xml version=\"1.0\"?><workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" xmlns:x=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheets><sheet name=\"Sheet1\" sheetId=\"1\" r:id=\"rId1\"/></sheets><x:definedNames><x:definedName name=\"tail\">Sheet1!$A$3</x:definedName></x:definedNames></workbook>"
  let with_prefixed = xml_add_part(tpl, "xl/workbook.xml", workbook)
  let message = refs_fill_error(with_prefixed, refs_items())
  assert_true(message.contains("prefixed"), msg=message)
  assert_true(message.contains("definedName"), msg=message)
}

///|
test "ooxml refuses a prefixed relationship when a section repeats rows" {
  let tpl = refs_xlsx([("Sheet1", refs_list_sheet(""))], "")
  let rels =
    "<?xml version=\"1.0\"?><x:Relationships xmlns:x=\"http://schemas.openxmlformats.org/package/2006/relationships\"><x:Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/></x:Relationships>"
  let with_prefixed = xml_add_part(tpl, "xl/_rels/workbook.xml.rels", rels)
  let message = refs_fill_error(with_prefixed, refs_items())
  assert_true(message.contains("prefixed"), msg=message)
  assert_true(message.contains("Relationship"), msg=message)
}

///|
test "ooxml keeps prefixed worksheet references when no section repeats rows" {
  let body = "<x:dimension ref=\"A1:B1\"/>" +
    refs_sheet(
      "<x:row r=\"1\"><x:c r=\"A1\" t=\"inlineStr\"><is><t>one</t></is></x:c></x:row>",
    ) +
    "<x:mergeCells count=\"1\"><x:mergeCell ref=\"A1:B1\"/></x:mergeCells>" +
    "<x:rowBreaks count=\"1\"><x:brk id=\"1\" max=\"16383\" man=\"1\"/></x:rowBreaks>"
  let tpl = refs_xlsx(
    [("Sheet1", body)],
    "",
    ns=" xmlns:x=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"",
  )
  let filled = refs_fill(tpl, refs_empty())
  assert_eq(
    refs_part(filled, "xl/worksheets/sheet1.xml"),
    refs_part(tpl, "xl/worksheets/sheet1.xml"),
  )
}

///|
test "ooxml keeps a prefixed workbook and rels when no section repeats rows" {
  let tpl = refs_xlsx(
    [("Sheet1", refs_sheet(refs_row(1, refs_cell("A1", "one"))))],
    "",
  )
  let workbook =
    "<?xml version=\"1.0\"?><x:workbook xmlns:x=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><x:sheets><x:sheet name=\"Sheet1\" sheetId=\"1\" r:id=\"rId1\"/></x:sheets></x:workbook>"
  let rels =
    "<?xml version=\"1.0\"?><x:Relationships xmlns:x=\"http://schemas.openxmlformats.org/package/2006/relationships\"><x:Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/></x:Relationships>"
  let with_prefixed = xml_add_part(tpl, "xl/workbook.xml", workbook)
  let with_prefixed = xml_add_part(
    with_prefixed,
    "xl/_rels/workbook.xml.rels",
    rels,
  )
  let filled = refs_fill(with_prefixed, refs_empty())
  assert_eq(
    refs_part(filled, "xl/workbook.xml"),
    refs_part(with_prefixed, "xl/workbook.xml"),
  )
}

///|
test "ooxml refuses a prefixed hyperlink when a section repeats rows" {
  let body = refs_list_sheet("") +
    "<x:hyperlinks><x:hyperlink ref=\"A2\" r:id=\"rId9\"/></x:hyperlinks>"
  let tpl = refs_xlsx(
    [("Sheet1", body)],
    "",
    ns=" xmlns:x=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"",
  )
  let message = refs_fill_error(tpl, refs_items())
  assert_true(message.contains("prefixed"), msg=message)
  assert_true(message.contains("hyperlink"), msg=message)
}

///|
test "ooxml refuses a prefixed drawing when a section repeats rows" {
  let body = refs_list_sheet("") + "<x:drawing r:id=\"rId9\"/>"
  let tpl = refs_xlsx(
    [("Sheet1", body)],
    "",
    ns=" xmlns:x=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"",
  )
  let message = refs_fill_error(tpl, refs_items())
  assert_true(message.contains("prefixed"), msg=message)
  assert_true(message.contains("drawing"), msg=message)
}

///|
test "ooxml refuses unsupported worksheet elements when a section repeats rows" {
  for name in [
    "oleObject",
    "control",
    "sortState",
    "protectedRange",
    "ignoredError",
  ] {
    for prefix in ["", "x:"] {
      let body = refs_list_sheet("") + "<" + prefix + name + " ref=\"A2\"/>"
      let tpl = refs_xlsx(
        [("Sheet1", body)],
        "",
        ns=" xmlns:x=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"",
      )
      let message = refs_fill_error(tpl, refs_items())
      assert_true(
        message.contains("<" + name + ">"),
        msg=prefix + name + ": " + message,
      )
    }
  }
}

///|
test "ooxml refuses workbook cell watches and custom sheet views when a section repeats rows" {
  for name in ["cellWatch", "customSheetView"] {
    for prefix in ["", "x:"] {
      let tpl = refs_xlsx([("Sheet1", refs_list_sheet(""))], "")
      let workbook =
        "<?xml version=\"1.0\"?><workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" xmlns:x=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheets><sheet name=\"Sheet1\" sheetId=\"1\" r:id=\"rId1\"/></sheets><" +
        prefix +
        name +
        " r=\"A1\"/></workbook>"
      let with_part = xml_add_part(tpl, "xl/workbook.xml", workbook)
      let message = refs_fill_error(with_part, refs_items())
      assert_true(
        message.contains("<" + name + ">"),
        msg=prefix + name + ": " + message,
      )
    }
  }
}

///|
test "ooxml refuses opaque workbook parts when a section repeats rows" {
  for part in [
    "xl/metadata.xml",
    "xl/model/item.xml",
    "customXml/item1.xml",
    "xl/vbaProject.bin",
  ] {
    let tpl = refs_xlsx([("Sheet1", refs_list_sheet(""))], "")
    let with_part = xml_add_part(tpl, part, "<x/>")
    let message = refs_fill_error(with_part, refs_items())
    assert_true(message.contains(part), msg=part + ": " + message)
  }
}

///|
test "ooxml keeps unsupported elements and opaque parts when no section repeats rows" {
  let body = refs_sheet(refs_row(1, refs_cell("A1", "one"))) +
    "<oleObject ref=\"A1\"/><control ref=\"A1\"/><sortState ref=\"A1\"/>" +
    "<protectedRange sqref=\"A1\"/><ignoredError sqref=\"A1\"/>"
  let tpl = refs_xlsx([("Sheet1", body)], "")
  let workbook =
    "<?xml version=\"1.0\"?><workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><sheets><sheet name=\"Sheet1\" sheetId=\"1\" r:id=\"rId1\"/></sheets><cellWatch r=\"A1\"/><customSheetView guid=\"1\"/></workbook>"
  let tpl = xml_add_part(tpl, "xl/workbook.xml", workbook)
  let tpl = xml_add_part(tpl, "xl/metadata.xml", "<metadata/>")
  let tpl = xml_add_part(tpl, "customXml/item1.xml", "<root/>")
  let tpl = xml_add_part(tpl, "xl/vbaProject.bin", "macro")
  let filled = refs_fill(tpl, refs_empty())
  assert_eq(
    refs_part(filled, "xl/worksheets/sheet1.xml"),
    refs_part(tpl, "xl/worksheets/sheet1.xml"),
  )
}
