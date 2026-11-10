///|
// Regression tests of the references that live outside the worksheet a
// section repeats: a drawing anchor, a defined name, a formula of another
// sheet, a merge over a dropped row, a row break and a self-closing formula.
// A reference is either moved with the rows or refused before conversion;
// a sheet whose rows do not move keeps every reference untouched.

///|
fn refs_part(data : Bytes, name : String) -> String raise {
  let archive = @zip.open_zip(data)
  let mut text = ""
  for entry in archive.entries {
    if entry.name == name {
      text = @utf8.decode_lossy(archive.read(entry, 1048576)[:])
    }
  }
  text
}

///|
fn refs_cell(at : String, text : String) -> String {
  "<c r=\"" + at + "\" t=\"inlineStr\"><is><t>" + text + "</t></is></c>"
}

///|
fn refs_row(index : Int, cells : String) -> String {
  "<row r=\"" + index.to_string() + "\">" + cells + "</row>"
}

///|
fn refs_sheet(body : String) -> String {
  "<sheetData>" + body + "</sheetData>"
}

///|
/// A workbook of the given sheets, each a `(name, body)` pair, and the given
/// `definedNames` element.
fn refs_xlsx(
  sheets : Array[(String, String)],
  defined_names : String,
  ns~ : String = "",
) -> Bytes raise {
  let content_types = StringBuilder()
  content_types.write_string(
    #|<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>|#,
  )
  let workbook_sheets = StringBuilder()
  let workbook_rels = StringBuilder()
  let entries : Array[(String, Bytes)] = []
  let mut index = 0
  for sheet in sheets {
    let (name, body) = sheet
    index += 1
    let number = index.to_string()
    let part = "xl/worksheets/sheet" + number + ".xml"
    content_types.write_string(
      "<Override PartName=\"/" +
      part +
      "\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>",
    )
    workbook_sheets.write_string(
      "<sheet name=\"" +
      name +
      "\" sheetId=\"" +
      number +
      "\" r:id=\"rId" +
      number +
      "\"/>",
    )
    workbook_rels.write_string(
      "<Relationship Id=\"rId" +
      number +
      "\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet" +
      number +
      ".xml\"/>",
    )
    entries.push((
      part,
      @utf8.encode(
        "<?xml version=\"1.0\"?><worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"" +
        ns +
        ">" +
        body +
        "</worksheet>",
      ),
    ))
  }
  content_types.write_string("</Types>")
  let workbook =
    "<?xml version=\"1.0\"?><workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><sheets>" +
    workbook_sheets.to_string() +
    "</sheets>" +
    defined_names +
    "</workbook>"
  let rels =
    #|<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>|#
  let workbook_rels_text =
    "<?xml version=\"1.0\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
    workbook_rels.to_string() +
    "</Relationships>"
  let all : Array[(String, Bytes)] = [
    ("[Content_Types].xml", @utf8.encode(content_types.to_string())),
    ("_rels/.rels", @utf8.encode(rels)),
    ("xl/workbook.xml", @utf8.encode(workbook)),
    ("xl/_rels/workbook.xml.rels", @utf8.encode(workbook_rels_text)),
  ]
  for entry in entries {
    all.push(entry)
  }
  stored_zip(all)
}

///|
fn refs_items() -> Json raise {
  @json.parse("{\"items\":[{\"name\":\"a\"},{\"name\":\"b\"}]}")
}

///|
fn refs_empty() -> Json raise {
  @json.parse("{}")
}

///|
fn refs_fill(data : Bytes, values : Json) -> Bytes raise {
  let (filled, _) = fill_zip(data, values)
  filled
}

///|
fn refs_fill_error(data : Bytes, values : Json) -> String {
  try {
    ignore(fill_zip(data, values))
    ""
  } catch {
    OoxmlError(message) => message
  }
}

///|
/// The list sheet of the review: row 1 opens and closes the section, row 2 is
/// a plain row and row 3 is the tail.
fn refs_list_sheet(extra : String) -> String {
  refs_sheet(
    refs_row(
      1,
      refs_cell("A1", "{{#items}}{{name}}") + refs_cell("B1", "{{/items}}"),
    ) +
    refs_row(2, refs_cell("A2", "x")) +
    refs_row(3, refs_cell("A3", "tail")),
  ) +
  extra
}

///|
test "ooxml keeps the references of a sheet whose rows do not move" {
  let body = refs_sheet(
    refs_row(1, refs_cell("A1", "one")) +
    refs_row(5, refs_cell("A5", "five") + "<c r=\"B5\"><f>1+1</f></c>") +
    refs_row(10, refs_cell("A10", "ten")),
  ) +
    "<mergeCells count=\"1\"><mergeCell ref=\"A5:B5\"/></mergeCells>" +
    "<rowBreaks count=\"1\" manualBreakCount=\"1\"><brk id=\"3\" max=\"16383\" man=\"1\"/></rowBreaks>" +
    "<drawing r:id=\"rId1\"/>"
  let tpl = refs_xlsx(
    [("Sheet1", body)],
    "<definedNames><definedName name=\"tail\">Sheet1!$A$10</definedName></definedNames>",
  )
  let filled = refs_fill(tpl, refs_empty())
  assert_eq(
    refs_part(filled, "xl/worksheets/sheet1.xml"),
    refs_part(tpl, "xl/worksheets/sheet1.xml"),
  )
  assert_eq(
    refs_part(filled, "xl/workbook.xml"),
    refs_part(tpl, "xl/workbook.xml"),
  )
}

///|
test "ooxml refuses a drawing anchor when a section repeats rows" {
  let tpl = refs_xlsx(
    [("Sheet1", refs_list_sheet("<drawing r:id=\"rId1\"/>"))],
    "",
  )
  let message = refs_fill_error(tpl, refs_items())
  assert_true(message.contains("drawing"), msg=message)
  assert_true(message.contains("anchors"), msg=message)
}

///|
test "ooxml moves a defined name with the rows of its sheet" {
  let tpl = refs_xlsx(
    [("Sheet1", refs_list_sheet(""))],
    "<definedNames><definedName name=\"tail\">Sheet1!$A$3</definedName></definedNames>",
  )
  let filled = refs_fill(tpl, refs_items())
  let workbook = refs_part(filled, "xl/workbook.xml")
  assert_true(workbook.contains("Sheet1!$A$4"), msg=workbook)
  assert_true(!workbook.contains("Sheet1!$A$3"), msg=workbook)
}

///|
test "ooxml moves a defined name range with the rows of its sheet" {
  let tpl = refs_xlsx(
    [("Sheet1", refs_list_sheet(""))],
    "<definedNames><definedName name=\"tail\">Sheet1!$A$3:$B$3</definedName></definedNames>",
  )
  let filled = refs_fill(tpl, refs_items())
  let workbook = refs_part(filled, "xl/workbook.xml")
  assert_true(workbook.contains("Sheet1!$A$4:$B$4"), msg=workbook)
}

///|
test "ooxml refuses a defined name over a dropped row" {
  let body = refs_sheet(
    refs_row(1, refs_cell("A1", "head")) +
    refs_row(
      2,
      refs_cell("A2", "{{#items}}{{name}}") + refs_cell("B2", "{{/items}}"),
    ) +
    refs_row(3, refs_cell("A3", "tail")),
  )
  let tpl = refs_xlsx(
    [("Sheet1", body)],
    "<definedNames><definedName name=\"gone\">Sheet1!$A$2</definedName></definedNames>",
  )
  let message = refs_fill_error(tpl, refs_empty())
  assert_true(message.contains("defined name"), msg=message)
  assert_true(message.contains("drops"), msg=message)
}

///|
test "ooxml refuses a formula of another sheet that names a moved sheet" {
  let other = refs_sheet(
    refs_row(1, "<c r=\"A1\"><f>Sheet2!A3</f></c>"),
  )
  let tpl = refs_xlsx(
    [("Sheet1", other), ("Sheet2", refs_list_sheet(""))],
    "",
  )
  let message = refs_fill_error(tpl, refs_items())
  assert_true(message.contains("formula"), msg=message)
  assert_true(message.contains("Sheet2"), msg=message)
}

///|
test "ooxml refuses a quoted formula of another sheet that names a moved sheet" {
  let other = refs_sheet(
    refs_row(1, "<c r=\"A1\"><f>'Sheet 2'!A3</f></c>"),
  )
  let tpl = refs_xlsx(
    [("Sheet1", other), ("Sheet 2", refs_list_sheet(""))],
    "",
  )
  let message = refs_fill_error(tpl, refs_items())
  assert_true(message.contains("formula"), msg=message)
  assert_true(message.contains("Sheet 2"), msg=message)
}

///|
test "ooxml keeps a formula of another sheet that names an unmoved sheet" {
  let other = refs_sheet(
    refs_row(1, "<c r=\"A1\"><f>Sheet2!A3</f></c>"),
  )
  let tpl = refs_xlsx(
    [("Sheet1", other), ("Sheet2", refs_sheet(refs_row(3, refs_cell("A3", "x"))))],
    "",
  )
  let filled = refs_fill(tpl, refs_empty())
  let sheet = refs_part(filled, "xl/worksheets/sheet1.xml")
  assert_true(sheet.contains("Sheet2!A3"), msg=sheet)
}

///|
test "ooxml refuses a merge over a row that a section drops" {
  let body = refs_sheet(
    refs_row(1, refs_cell("A1", "head")) +
    refs_row(
      2,
      refs_cell("A2", "{{#items}}{{name}}") + refs_cell("B2", "{{/items}}"),
    ) +
    refs_row(3, refs_cell("A3", "x")) +
    refs_row(4, refs_cell("A4", "tail")),
  ) + "<mergeCells count=\"1\"><mergeCell ref=\"A2:B2\"/></mergeCells>"
  let tpl = refs_xlsx([("Sheet1", body)], "")
  let message = refs_fill_error(tpl, refs_empty())
  assert_true(message.contains("merged cells"), msg=message)
  assert_true(message.contains("drops"), msg=message)
}

///|
test "ooxml moves a row break with the rows of its sheet" {
  let tpl = refs_xlsx(
    [("Sheet1", refs_list_sheet(
      "<rowBreaks count=\"1\" manualBreakCount=\"1\"><brk id=\"3\" max=\"16383\" man=\"1\"/></rowBreaks>",
    ))],
    "",
  )
  let filled = refs_fill(tpl, refs_items())
  let sheet = refs_part(filled, "xl/worksheets/sheet1.xml")
  assert_true(sheet.contains("<brk id=\"4\""), msg=sheet)
  assert_true(!sheet.contains("<brk id=\"3\""), msg=sheet)
}

///|
test "ooxml refuses a row break after a repeated row" {
  let tpl = refs_xlsx(
    [("Sheet1", refs_list_sheet(
      "<rowBreaks count=\"1\" manualBreakCount=\"1\"><brk id=\"1\" max=\"16383\" man=\"1\"/></rowBreaks>",
    ))],
    "",
  )
  let message = refs_fill_error(tpl, refs_items())
  assert_true(message.contains("row break"), msg=message)
  assert_true(message.contains("repeats"), msg=message)
}

///|
test "ooxml refuses a self-closing formula when a section repeats rows" {
  let body = refs_sheet(
    refs_row(
      1,
      refs_cell("A1", "{{#items}}{{name}}") +
      refs_cell("B1", "{{/items}}") +
      "<c r=\"C1\"><f/></c>",
    ) +
    refs_row(2, refs_cell("A2", "tail")),
  )
  let tpl = refs_xlsx([("Sheet1", body)], "")
  let message = refs_fill_error(tpl, refs_items())
  assert_true(message.contains("formula"), msg=message)
}

///|
test "ooxml refuses a chart that names a moved sheet" {
  let tpl = refs_xlsx([("Sheet1", refs_list_sheet(""))], "")
  let chart =
    #|<?xml version="1.0"?><c:chartSpace xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart"><c:chart><c:plotArea><c:barChart><c:ser><c:val><c:numRef><c:f>Sheet1!$A$1:$A$3</c:f></c:numRef></c:val></c:ser></c:barChart></c:plotArea></c:chart></c:chartSpace>
  let archive = @zip.open_zip(tpl)
  let entries : Array[(String, Bytes)] = []
  for entry in archive.entries {
    entries.push((entry.name, archive.read(entry, 1048576)))
  }
  entries.push(("xl/charts/chart1.xml", @utf8.encode(chart)))
  let with_chart = stored_zip(entries)
  let message = refs_fill_error(with_chart, refs_items())
  assert_true(message.contains("chart"), msg=message)
  assert_true(message.contains("Sheet1"), msg=message)
}

///|
test "ooxml refuses a prefixed self-closing formula when a section repeats rows" {
  let body = refs_sheet(
    refs_row(
      1,
      refs_cell("A1", "{{#items}}{{name}}") +
      refs_cell("B1", "{{/items}}") +
      "<c r=\"C1\"><x:f/></c>",
    ) +
    refs_row(2, refs_cell("A2", "tail")),
  )
  let tpl = refs_xlsx([("Sheet1", body)], "")
  let message = refs_fill_error(tpl, refs_items())
  assert_true(message.contains("formula"), msg=message)
}

///|
test "ooxml refuses a prefixed formula of another sheet that names a moved sheet" {
  let other = refs_sheet(
    refs_row(1, "<c r=\"A1\"><x:f>Sheet2!A3</x:f></c>"),
  )
  let tpl = refs_xlsx(
    [("Sheet1", other), ("Sheet2", refs_list_sheet(""))],
    "",
  )
  let message = refs_fill_error(tpl, refs_items())
  assert_true(message.contains("formula"), msg=message)
  assert_true(message.contains("Sheet2"), msg=message)
}

///|
test "ooxml moves a defined name that starts with an equals sign" {
  let tpl = refs_xlsx(
    [("Sheet1", refs_list_sheet(""))],
    "<definedNames><definedName name=\"tail\">=Sheet1!$A$3</definedName></definedNames>",
  )
  let filled = refs_fill(tpl, refs_items())
  let workbook = refs_part(filled, "xl/workbook.xml")
  assert_true(workbook.contains("=Sheet1!$A$4"), msg=workbook)
}

///|
test "ooxml refuses a 3D formula of another sheet that names a moved sheet" {
  let other = refs_sheet(
    refs_row(1, "<c r=\"A1\"><f>SUM(Sheet2:Sheet3!A3)</f></c>"),
  )
  let tpl = refs_xlsx(
    [
      ("Sheet1", other),
      ("Sheet2", refs_list_sheet("")),
      ("Sheet3", refs_sheet(refs_row(1, refs_cell("A1", "x")))),
    ],
    "",
  )
  let message = refs_fill_error(tpl, refs_items())
  assert_true(message.contains("formula"), msg=message)
}

///|
test "ooxml refuses a 3D defined name that names a moved sheet" {
  let tpl = refs_xlsx(
    [
      ("Sheet1", refs_list_sheet("")),
      ("Sheet2", refs_sheet(refs_row(1, refs_cell("A1", "x")))),
    ],
    "<definedNames><definedName name=\"all\">Sheet1:Sheet2!$A$1</definedName></definedNames>",
  )
  let message = refs_fill_error(tpl, refs_items())
  assert_true(message.contains("defined name"), msg=message)
}

///|
test "ooxml refuses a lower-case formula of another sheet that names a moved sheet" {
  let other = refs_sheet(
    refs_row(1, "<c r=\"A1\"><f>sheet2!A3</f></c>"),
  )
  let tpl = refs_xlsx(
    [("Sheet1", other), ("Sheet2", refs_list_sheet(""))],
    "",
  )
  let message = refs_fill_error(tpl, refs_items())
  assert_true(message.contains("formula"), msg=message)
}

///|
test "ooxml refuses a pivot cache that names a moved sheet" {
  let tpl = refs_xlsx([("Sheet1", refs_list_sheet(""))], "")
  let archive = @zip.open_zip(tpl)
  let entries : Array[(String, Bytes)] = []
  for entry in archive.entries {
    entries.push((entry.name, archive.read(entry, 1048576)))
  }
  entries.push((
    "xl/pivotCache/pivotCacheDefinition1.xml",
    @utf8.encode(
      #|<?xml version="1.0"?><pivotCacheDefinition xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><cacheSource type="worksheet"><worksheetSource sheet="Sheet1" ref="A1:B3"/></cacheSource></pivotCacheDefinition>
    ),
  ))
  let with_pivot = stored_zip(entries)
  let message = refs_fill_error(with_pivot, refs_items())
  assert_true(message.contains("pivot"), msg=message)
}
