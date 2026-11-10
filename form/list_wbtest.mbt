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
