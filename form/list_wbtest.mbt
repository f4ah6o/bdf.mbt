///|
// Regression tests of the fill of lists, adapted from the templates of
// upstream: a section repeats the rows or paragraphs it covers, the options
// of a tag are applied, a list of values fills {{.}}, and a comment tag
// leaves nothing.

///|
fn form_test_part(data : Bytes, name : String) -> String raise {
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
fn form_test_count(text : String, needle : String) -> Int {
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
/// A Word document of a table of one paragraph per row, as the converter
/// reads it.
fn form_test_table_docx(rows : Array[String]) -> Bytes raise {
  let content_types =
    #|<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>
  let rels =
    #|<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>
  let mut body = "<w:tbl>"
  for row in rows {
    body = body +
      "<w:tr><w:tc><w:p><w:r><w:t>" +
      row +
      "</w:t></w:r></w:p></w:tc></w:tr>"
  }
  body = body + "</w:tbl>"
  let document =
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?><w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body>" +
    body +
    "<w:sectPr/></w:body></w:document>"
  @ooxml.stored_zip([
    ("[Content_Types].xml", @utf8.encode(content_types)),
    ("_rels/.rels", @utf8.encode(rels)),
    ("word/document.xml", @utf8.encode(document)),
  ])
}

///|
fn form_test_list_data() -> Json raise {
  form_test_json(
    "{\"items\":[{\"name\":\"a\",\"qty\":1},{\"name\":\"b\",\"qty\":2}]}",
  )
}

///|
test "form fills a list across the rows of a workbook" {
  let tpl = form_test_xlsx(
    form_test_row(1, form_test_cell("A1", "{{#items}}")) +
    form_test_row(2, form_test_cell("A2", "{{name}}")) +
    form_test_row(3, form_test_cell("A3", "{{/items}}")) +
    form_test_row(4, form_test_cell("A4", "end")),
  )
  let (filled, warnings) = @ooxml.fill_zip(tpl, form_test_list_data())
  assert_eq(warnings.length(), 0, msg=warnings.join("; "))
  let sheet = form_test_part(filled, "xl/worksheets/sheet1.xml")
  assert_eq(form_test_count(sheet, "<row"), 3, msg=sheet)
  assert_true(sheet.contains("<row r=\"2\">"), msg=sheet)
  assert_true(sheet.contains("<row r=\"3\">"), msg=sheet)
  assert_true(sheet.contains("<row r=\"4\">"), msg=sheet)
  assert_true(sheet.contains("r=\"A2\""), msg=sheet)
  assert_true(sheet.contains("r=\"A3\""), msg=sheet)
  assert_true(sheet.contains("r=\"A4\""), msg=sheet)
  assert_true(sheet.contains(">a<"), msg=sheet)
  assert_true(sheet.contains(">b<"), msg=sheet)
  assert_true(sheet.contains(">end<"), msg=sheet)
  assert_true(!sheet.contains("{{"), msg=sheet)
  // the filled workbook is a document that a reader opens
  let compiled = compile(tpl, "rows", Options::new())
  let result = fill(compiled.bdf, Options::new(data=form_test_list_data()))
  let text = form_test_text(result.bdf)
  assert_true(text.contains("a"), msg=text)
  assert_true(text.contains("b"), msg=text)
}

///|
test "form fills a list across the rows of a table" {
  let tpl = form_test_table_docx([
    "{{#items}}",
    "{{name}}",
    "{{/items}}",
  ])
  let (filled, warnings) = @ooxml.fill_zip(tpl, form_test_list_data())
  assert_eq(warnings.length(), 0, msg=warnings.join("; "))
  let document = form_test_part(filled, "word/document.xml")
  assert_eq(form_test_count(document, "<w:tr>"), 2, msg=document)
  assert_true(document.contains(">a<"), msg=document)
  assert_true(document.contains(">b<"), msg=document)
  assert_true(!document.contains("{{"), msg=document)
  let compiled = compile(tpl, "table", Options::new())
  let result = fill(compiled.bdf, Options::new(data=form_test_list_data()))
  let text = form_test_text(result.bdf)
  assert_true(text.contains("a"), msg=text)
  assert_true(text.contains("b"), msg=text)
}

///|
test "form applies the options of a tag" {
  let tpl = form_test_xlsx(
    form_test_row(1, form_test_cell("A1", "{{total | fmt:\"#,##0.00\"}}")) +
    form_test_row(2, form_test_cell("A2", "{{price | fmt:\"#,##0\"}}")),
  )
  let data = form_test_json("{\"total\":13200,\"price\":1200}")
  let (filled, warnings) = @ooxml.fill_zip(tpl, data)
  assert_eq(warnings.length(), 0, msg=warnings.join("; "))
  let sheet = form_test_part(filled, "xl/worksheets/sheet1.xml")
  assert_true(sheet.contains("13,200.00"), msg=sheet)
  assert_true(sheet.contains("1,200"), msg=sheet)
  // the fields of the template name the value, not the option
  let fields = fields(tpl)
  let names = @schema.names(fields, None)
  assert_true(names.contains("total"), msg=names.join(","))
  assert_true(names.contains("price"), msg=names.join(","))
}

///|
test "form fills the variables of a list" {
  let tpl = form_test_xlsx(
    form_test_row(
      1,
      form_test_cell("A1", "{{#items}}{{_index}}/{{_count}}/{{_first}}/{{_last}} {{/items}}"),
    ),
  )
  let (filled, warnings) = @ooxml.fill_zip(tpl, form_test_list_data())
  assert_eq(warnings.length(), 0, msg=warnings.join("; "))
  let sheet = form_test_part(filled, "xl/worksheets/sheet1.xml")
  assert_true(sheet.contains("1/2/TRUE/FALSE"), msg=sheet)
  assert_true(sheet.contains("2/2/FALSE/TRUE"), msg=sheet)
}

///|
test "form fills a list of values" {
  let tpl = form_test_xlsx(
    form_test_row(1, form_test_cell("A1", "{{#tags}}[{{.}}]{{/tags}}")),
  )
  let data = form_test_json("{\"tags\":[\"a\",\"b\"]}")
  let (filled, warnings) = @ooxml.fill_zip(tpl, data)
  assert_eq(warnings.length(), 0, msg=warnings.join("; "))
  let sheet = form_test_part(filled, "xl/worksheets/sheet1.xml")
  assert_true(sheet.contains("[a][b]"), msg=sheet)
}

///|
test "form removes comment tags" {
  let tpl = form_test_xlsx(
    form_test_row(1, form_test_cell("A1", "A{{! a note}}B")),
  )
  let (filled, warnings) = @ooxml.fill_zip(tpl, Json::object({}))
  assert_eq(warnings.length(), 0, msg=warnings.join("; "))
  let sheet = form_test_part(filled, "xl/worksheets/sheet1.xml")
  assert_true(sheet.contains(">AB<"), msg=sheet)
  assert_true(!sheet.contains("a note"), msg=sheet)
}

///|
test "form keeps the values of one fill apart from another" {
  let tpl = form_test_xlsx(
    form_test_row(1, form_test_cell("A1", "{{#items}}{{name}}{{/items}}")),
  )
  let compiled = compile(tpl, "twice", Options::new())
  let first = fill(
    compiled.bdf,
    Options::new(data=form_test_json("{\"items\":[{\"name\":\"first\"}]}")),
  )
  let second = fill(
    compiled.bdf,
    Options::new(data=form_test_json("{\"items\":[{\"name\":\"second\"}]}")),
  )
  let first_text = form_test_text(first.bdf)
  let second_text = form_test_text(second.bdf)
  assert_true(first_text.contains("first"), msg=first_text)
  assert_true(!first_text.contains("second"), msg=first_text)
  assert_true(second_text.contains("second"), msg=second_text)
  assert_true(!second_text.contains("first"), msg=second_text)
}

///|
test "form refuses a section that is not closed" {
  let tpl = form_test_xlsx(
    form_test_row(1, form_test_cell("A1", "{{#items}}")),
  )
  let message = form_test_fill_error(tpl, Options::new())
  assert_true(message.contains("is not closed"), msg=message)
  assert_true(message.contains("items"), msg=message)
}

///|
test "form strict reports a name that a list item lacks" {
  let tpl = form_test_xlsx(
    form_test_row(1, form_test_cell("A1", "{{#items}}{{name}}{{/items}}")),
  )
  let message = form_test_fill_error(
    tpl,
    Options::new(data=form_test_json("{\"items\":[{\"qty\":1}]}"), strict=true),
  )
  assert_true(message.contains("the data has no \"name\""), msg=message)
}

///|
test "form strict leaves a list that has no items alone" {
  let tpl = form_test_xlsx(
    form_test_row(1, form_test_cell("A1", "{{#items}}{{name}}{{/items}}")),
  )
  let compiled = compile(tpl, "empty", Options::new())
  let result = fill(
    compiled.bdf,
    Options::new(data=form_test_json("{\"items\":[]}"), strict=true),
  )
  assert_true(result.partial is None, msg="a complete fill")
}

///|
test "form strict reports a name that a table row lacks" {
  let tpl = form_test_table_docx(["{{#items}}", "{{name}}", "{{/items}}"])
  let message = form_test_fill_error(
    tpl,
    Options::new(data=form_test_json("{\"items\":[{\"qty\":1}]}"), strict=true),
  )
  assert_true(message.contains("the data has no \"name\""), msg=message)
}

///|
test "form keeps the rows of a sheet that no section repeats" {
  let tpl = form_test_xlsx(
    form_test_row(1, form_test_cell("A1", "{{no}}")) +
    form_test_row(10, form_test_cell("A10", "{{name}}")),
  )
  let data = form_test_json("{\"no\":1,\"name\":\"a\"}")
  let (filled, warnings) = @ooxml.fill_zip(tpl, data)
  assert_eq(warnings.length(), 0, msg=warnings.join("; "))
  let sheet = form_test_part(filled, "xl/worksheets/sheet1.xml")
  assert_true(sheet.contains("<row r=\"1\">"), msg=sheet)
  assert_true(sheet.contains("<row r=\"10\">"), msg=sheet)
  assert_true(sheet.contains("r=\"A10\""), msg=sheet)
  assert_true(!sheet.contains("<row r=\"2\">"), msg=sheet)
}

///|
/// A workbook of one sheet whose whole worksheet XML is `worksheet`, so that
/// a test can add merged cells or formulas beside the rows.
fn form_test_worksheet_xlsx(worksheet : String) -> Bytes raise {
  let content_types =
    #|<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>
  let rels =
    #|<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>
  let workbook =
    #|<?xml version="1.0"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets></workbook>
  let workbook_rels =
    #|<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>
  @ooxml.stored_zip([
    ("[Content_Types].xml", @utf8.encode(content_types)),
    ("_rels/.rels", @utf8.encode(rels)),
    ("xl/workbook.xml", @utf8.encode(workbook)),
    ("xl/_rels/workbook.xml.rels", @utf8.encode(workbook_rels)),
    ("xl/worksheets/sheet1.xml", @utf8.encode(worksheet)),
  ])
}

///|
/// A row of two cells, so that a section can open in one cell and close in
/// the other and repeat the row, as upstream's sections of rows do.
fn form_test_row2(index : Int, first : String, second : String) -> String {
  "<row r=\"" +
  index.to_string() +
  "\">" +
  form_test_cell("A" + index.to_string(), first) +
  form_test_cell("B" + index.to_string(), second) +
  "</row>"
}

///|
test "form keeps the gaps of the rows after a repeated section" {
  let tpl = form_test_xlsx(
    form_test_row2(1, "{{#items}}{{name}}", "{{/items}}") +
    form_test_row(5, form_test_cell("A5", "end")) +
    form_test_row(10, form_test_cell("A10", "tail")),
  )
  let (filled, warnings) = @ooxml.fill_zip(tpl, form_test_list_data())
  assert_eq(warnings.length(), 0, msg=warnings.join("; "))
  let sheet = form_test_part(filled, "xl/worksheets/sheet1.xml")
  assert_eq(form_test_count(sheet, "<row"), 4, msg=sheet)
  assert_true(sheet.contains("<row r=\"1\">"), msg=sheet)
  assert_true(sheet.contains("<row r=\"2\">"), msg=sheet)
  assert_true(sheet.contains("<row r=\"6\">"), msg=sheet)
  assert_true(sheet.contains("<row r=\"11\">"), msg=sheet)
  assert_true(sheet.contains("r=\"A6\""), msg=sheet)
  assert_true(sheet.contains("r=\"A11\""), msg=sheet)
}

///|
test "form keeps the row references of a fill that does not expand" {
  let tpl = form_test_xlsx(
    form_test_row(1, form_test_cell("A1", "title")) +
    form_test_row(5, form_test_cell("A5", "{{#items}}{{name}}{{/items}}")),
  )
  let data = form_test_json("{\"items\":[{\"name\":\"only\"}]}")
  let (filled, warnings) = @ooxml.fill_zip(tpl, data)
  assert_eq(warnings.length(), 0, msg=warnings.join("; "))
  let sheet = form_test_part(filled, "xl/worksheets/sheet1.xml")
  assert_true(sheet.contains("<row r=\"1\">"), msg=sheet)
  assert_true(sheet.contains("<row r=\"5\">"), msg=sheet)
  assert_true(sheet.contains("r=\"A5\""), msg=sheet)
  assert_true(!sheet.contains("<row r=\"2\">"), msg=sheet)
}

///|
test "form moves the merged cells of a sheet that a section repeats" {
  let tpl = form_test_worksheet_xlsx(
    "<?xml version=\"1.0\"?><worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData>" +
    form_test_row2(1, "{{#items}}{{name}}", "{{/items}}") +
    form_test_row(2, form_test_cell("A2", "end")) +
    "</sheetData><mergeCells count=\"1\"><mergeCell ref=\"A2:B2\"/></mergeCells></worksheet>",
  )
  let (filled, warnings) = @ooxml.fill_zip(tpl, form_test_list_data())
  assert_eq(warnings.length(), 0, msg=warnings.join("; "))
  let sheet = form_test_part(filled, "xl/worksheets/sheet1.xml")
  assert_true(sheet.contains("<mergeCell ref=\"A3:B3\"/>"), msg=sheet)
}

///|
test "form refuses merged cells across a repeated row" {
  let tpl = form_test_worksheet_xlsx(
    "<?xml version=\"1.0\"?><worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData>" +
    form_test_row2(1, "{{#items}}{{name}}", "{{/items}}") +
    "</sheetData><mergeCells count=\"1\"><mergeCell ref=\"A1:B1\"/></mergeCells></worksheet>",
  )
  let message = form_test_fill_error(tpl, Options::new(data=form_test_list_data()))
  assert_true(message.contains("merged cells"), msg=message)
  assert_true(message.contains("repeats"), msg=message)
}

///|
test "form refuses a formula when a section repeats rows" {
  let tpl = form_test_worksheet_xlsx(
    "<?xml version=\"1.0\"?><worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData>" +
    form_test_row2(1, "{{#items}}{{name}}", "{{/items}}") +
    form_test_row(2, "<c r=\"A2\"><f>1+1</f><v>2</v></c>") +
    "</sheetData></worksheet>",
  )
  let message = form_test_fill_error(tpl, Options::new(data=form_test_list_data()))
  assert_true(message.contains("formula"), msg=message)
  assert_true(message.contains("repeats"), msg=message)
}

///|
test "form fills repeated and nested lists" {
  let tpl = form_test_xlsx(
    form_test_row(1, form_test_cell("A1", "{{#groups}}{{name}}")) +
    form_test_row2(2, "{{#items}}{{name}}", "{{/items}}") +
    form_test_row(3, form_test_cell("A3", "{{/groups}}end")),
  )
  let data = form_test_json(
    "{\"groups\":[{\"name\":\"g1\",\"items\":[{\"name\":\"a\"},{\"name\":\"b\"}]},{\"name\":\"g2\",\"items\":[{\"name\":\"c\"}]}]}",
  )
  let (filled, warnings) = @ooxml.fill_zip(tpl, data)
  assert_eq(warnings.length(), 0, msg=warnings.join("; "))
  let sheet = form_test_part(filled, "xl/worksheets/sheet1.xml")
  assert_eq(form_test_count(sheet, "<row"), 7, msg=sheet)
  for want in ["g1", "g2", ">a<", ">b<", ">c<"] {
    assert_true(sheet.contains(want), msg=want + " in " + sheet)
  }
  for number in [1, 2, 3, 4, 5, 6, 7] {
    assert_true(
      sheet.contains("<row r=\"" + number.to_string() + "\">"),
      msg=sheet,
    )
  }
}

///|
test "form repeats the row of a list that spans its cells" {
  let tpl = form_test_xlsx(
    "<row r=\"1\">" +
    form_test_cell("A1", "{{#items}}{{_index}}") +
    form_test_cell("B1", "{{name}}") +
    form_test_cell("C1", "{{qty}}") +
    form_test_cell("D1", "{{price}}{{/items}}") +
    "</row>",
  )
  let data = form_test_json(
    "{\"items\":[{\"name\":\"a\",\"qty\":1,\"price\":10},{\"name\":\"b\",\"qty\":2,\"price\":20}]}",
  )
  let (filled, warnings) = @ooxml.fill_zip(tpl, data)
  assert_eq(warnings.length(), 0, msg=warnings.join("; "))
  let sheet = form_test_part(filled, "xl/worksheets/sheet1.xml")
  assert_eq(form_test_count(sheet, "<row"), 2, msg=sheet)
  assert_true(sheet.contains("<row r=\"1\">"), msg=sheet)
  assert_true(sheet.contains("<row r=\"2\">"), msg=sheet)
  assert_true(sheet.contains(">a<"), msg=sheet)
  assert_true(sheet.contains(">b<"), msg=sheet)
  assert_true(sheet.contains("r=\"A2\""), msg=sheet)
  assert_true(sheet.contains("r=\"D2\""), msg=sheet)
}

///|
test "form moves the dimension of a sheet that a section repeats" {
  let tpl = form_test_worksheet_xlsx(
    "<?xml version=\"1.0\"?><worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><dimension ref=\"A1:D10\"/><sheetData>" +
    form_test_row2(1, "{{#items}}{{name}}", "{{/items}}") +
    form_test_row(10, form_test_cell("A10", "tail")) +
    "</sheetData></worksheet>",
  )
  let (filled, warnings) = @ooxml.fill_zip(tpl, form_test_list_data())
  assert_eq(warnings.length(), 0, msg=warnings.join("; "))
  let sheet = form_test_part(filled, "xl/worksheets/sheet1.xml")
  assert_true(sheet.contains("<dimension ref=\"A1:D11\"/>"), msg=sheet)
  assert_true(sheet.contains("<row r=\"11\">"), msg=sheet)
}
