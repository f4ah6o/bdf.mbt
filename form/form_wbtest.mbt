///|
// Regression tests of the form package, adapted from form/form_test.go of
// upstream: what a template is, compiling it, filling it, and the names that
// its tags look up.

///|
fn form_test_cell(at : String, text : String) -> String {
  "<c r=\"" + at + "\" t=\"inlineStr\"><is><t>" + text + "</t></is></c>"
}

///|
fn form_test_row(index : Int, cells : String) -> String {
  "<row r=\"" + index.to_string() + "\">" + cells + "</row>"
}

///|
/// A workbook of one sheet whose cells are `sheet_data`, as the converter
/// reads it.
fn form_test_xlsx(sheet_data : String) -> Bytes raise {
  let content_types =
    #|<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>
  let rels =
    #|<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>
  let workbook =
    #|<?xml version="1.0"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets></workbook>
  let workbook_rels =
    #|<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>
  let sheet =
    "<?xml version=\"1.0\"?><worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData>" +
    sheet_data +
    "</sheetData></worksheet>"
  @ooxml.stored_zip([
    ("[Content_Types].xml", @utf8.encode(content_types)),
    ("_rels/.rels", @utf8.encode(rels)),
    ("xl/workbook.xml", @utf8.encode(workbook)),
    ("xl/_rels/workbook.xml.rels", @utf8.encode(workbook_rels)),
    ("xl/worksheets/sheet1.xml", @utf8.encode(sheet)),
  ])
}

///|
/// A Word document of one paragraph per tag, as the converter reads it.
fn form_test_docx(paragraphs : Array[String]) -> Bytes raise {
  let content_types =
    #|<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>
  let rels =
    #|<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>
  let mut body = ""
  for paragraph in paragraphs {
    body = body + "<w:p><w:r><w:t>" + paragraph + "</w:t></w:r></w:p>"
  }
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
/// The text of the views of a document, as a reader of it sees it.
fn form_test_text(bdf : Bytes) -> String raise {
  let document = @core.open_single(bdf)
  let mut text = ""
  for view in document.manifest.views {
    match view.text_index {
      Some(hash) => {
        for run in @core.decode_text_index(document.part(hash)) {
          text = text + run.text
        }
      }
      None => ()
    }
  }
  text
}

///|
fn form_test_json(text : String) -> Json raise {
  @json.parse(text)
}

///|
/// The properties of a JSON Schema, or none when it has none.
fn form_test_properties(schema : Json) -> Map[String, Json] {
  match schema {
    Json::Object(object) =>
      match object.get("properties") {
        Some(Json::Object(properties)) => properties
        _ => Map([])
      }
    _ => Map([])
  }
}

///|
fn form_test_fill_error(data : Bytes, options : Options) -> String {
  try {
    ignore(fill(data, options))
    ""
  } catch {
    FormError(message) => message
  }
}

///|
fn form_test_compile_error(
  data : Bytes,
  name : String,
  options : Options,
) -> String {
  try {
    ignore(compile(data, name, options))
    ""
  } catch {
    FormError(message) => message
  }
}

///|
fn form_test_read_error(data : Bytes) -> String {
  try {
    ignore(read_template(data))
    ""
  } catch {
    FormError(message) => message
  }
}

///|
/// The workbook of `form-fixed.xlsx` of upstream: a value, a date, a name in
/// an object, a number, a formatted number, a condition, a memo, a picture, a
/// QR code, a list, a name that the data may lack, and a barcode.
fn form_test_fixed_xlsx() -> Bytes raise {
  let rows =
    form_test_row(1, form_test_cell("A1", "{{no}}")) +
    form_test_row(2, form_test_cell("A2", "{{date}}")) +
    form_test_row(3, form_test_cell("A3", "{{customer.name}}")) +
    form_test_row(4, form_test_cell("A4", "{{amount}}")) +
    form_test_row(5, form_test_cell("A5", "{{total | fmt:\"#,##0.00\"}}")) +
    form_test_row(6, form_test_cell("A6", "{{#paid}}x{{/paid}}{{^paid}}y{{/paid}}")) +
    form_test_row(7, form_test_cell("A7", "{{memo}}")) +
    form_test_row(8, form_test_cell("A8", "{{%photo}}")) +
    form_test_row(9, form_test_cell("A9", "{{%url | qr}}")) +
    form_test_row(10, form_test_cell("A10", "{{#tags}}{{.}}{{/tags}}")) +
    form_test_row(11, form_test_cell("A11", "{{missing}}")) +
    form_test_row(12, form_test_cell("A12", "{{%jan | barcode:jan}}"))
  form_test_xlsx(rows)
}

///|
/// The data of `form-fixed.json` of upstream.
fn form_test_fixed_data() -> Json raise {
  form_test_json(
    "{\"no\":1024,\"date\":\"2026-10-13\",\"customer\":{\"name\":\"ACME\"},\"amount\":12000,\"total\":13200,\"paid\":true,\"memo\":\"Thank you.\\nSecond line\",\"photo\":\"stamp.png\",\"url\":\"https://example.com/c/1024\",\"jan\":\"4901234567894\",\"tags\":[\"a\",\"b\",\"c\"],\"missing\":\"\"}",
  )
}

///|
test "form compiles and fills a workbook" {
  let tpl = form_test_fixed_xlsx()
  let compiled = compile(tpl, "form-fixed", Options::new())
  assert_eq(compiled.template.format, FORMAT_XLSX)
  assert_eq(compiled.template.name, "form-fixed")
  assert_eq(compiled.template.version, TEMPLATE_VERSION)
  assert_true(compiled.template.source != "", msg="the hash of the template")
  assert_true(compiled.template.schema is Some(_), msg="the schema")
  assert_true(!compiled.template.is_partial(), msg="a compiled template")
  let (template, source) = read_template(compiled.bdf)
  assert_eq(template.format, FORMAT_XLSX)
  assert_eq(template.name, "form-fixed")
  assert_true(template.digest != "", msg="the digest of the description")
  assert_true(source == tpl, msg="the template is held as it was")
  let result = fill(compiled.bdf, Options::new(data=form_test_fixed_data()))
  assert_true(result.partial is None, msg="a complete fill")
  assert_eq(result.format, FORMAT_XLSX)
  let text = form_test_text(result.bdf)
  assert_true(text.contains("1024"), msg=text)
  assert_true(text.contains("ACME"), msg=text)
}

///|
test "form compiles a template with a sample" {
  let tpl = form_test_fixed_xlsx()
  let sample = form_test_json("{\"no\":7,\"customer\":{\"name\":\"Sample\"}}")
  let compiled = compile(tpl, "sampled", Options::new(data=sample))
  assert_true(compiled.template.sample is Some(_), msg="the sample")
  let text = form_test_text(compiled.bdf)
  assert_true(text.contains("7"), msg=text)
  assert_true(text.contains("Sample"), msg=text)
  let (format, described) = describe(compiled.bdf)
  assert_eq(format, FORMAT_XLSX)
  assert_true(described is Some(_), msg="the sample is described")
}

///|
test "form reads the fields of a template" {
  let tpl = form_test_fixed_xlsx()
  let fields = fields(tpl)
  let names = @schema.names(fields, None)
  for want in [
    "no", "date", "customer.name", "amount", "total", "paid", "memo", "photo",
    "url", "tags", "missing", "jan",
  ] {
    assert_true(names.contains(want), msg=want + " in " + names.join(","))
  }
  assert_true(!names.contains("customer"), msg="customer is an object")
  let mut no_at = ""
  for field in fields {
    if field.name == "no" {
      no_at = field.at.join(",")
    }
  }
  assert_eq(no_at, "Sheet1!A1")
}

///|
test "form describes a template" {
  let tpl = form_test_fixed_xlsx()
  let (format, sample) = describe(tpl)
  assert_eq(format, FORMAT_XLSX)
  assert_true(sample is None, msg="a template has no sample")
}

///|
test "form makes the schema of a template" {
  let tpl = form_test_fixed_xlsx()
  let schema = schema_of(tpl, None)
  assert_true(schema.contains("\"properties\""), msg=schema)
  assert_true(schema.contains("\"customer\""), msg=schema)
  assert_true(schema.has_suffix("\n"), msg="a trailing newline")
  let sampled = schema_of(tpl, Some(form_test_json("{\"no\":1}")))
  assert_true(sampled.contains("\"no\""), msg=sampled)
}

///|
test "form refuses what is not a template" {
  let message = form_test_fill_error(@utf8.encode("hello"), Options::new())
  assert_true(message.contains("is not an Excel workbook"), msg=message)
  let compiled = form_test_compile_error(
    @utf8.encode("hello"),
    "",
    Options::new(),
  )
  assert_true(compiled.contains("is not an Excel workbook"), msg=compiled)
  let empty = form_test_fill_error(b"", Options::new())
  assert_true(empty.contains("is not an Excel workbook"), msg=empty)
}

///|
test "form refuses to compile a compiled template" {
  let compiled = compile(form_test_fixed_xlsx(), "form-fixed", Options::new())
  let message = form_test_compile_error(compiled.bdf, "", Options::new())
  assert_true(message.contains("compiled template already"), msg=message)
}

///|
test "form refuses a document that is not a compiled template" {
  let writer = @core.DocumentWriter::new()
  ignore(writer.add_part(PART_SOURCE, @utf8.encode("hello")))
  let message = form_test_read_error(writer.write_single())
  assert_true(message.contains("it has no \"tpl\" part"), msg=message)
}

///|
test "form refuses a description that is not JSON" {
  let writer = @core.DocumentWriter::new()
  ignore(writer.add_part(PART_TEMPLATE, @utf8.encode("not json")))
  let message = form_test_read_error(writer.write_single())
  assert_true(message.contains("is not JSON"), msg=message)
}

///|
test "form refuses a description of another version" {
  let tpl = form_test_fixed_xlsx()
  let compiled = compile(tpl, "form-fixed", Options::new())
  let description = compiled.template.to_json()
  match description {
    Json::Object(object) => object["version"] = Json::number(2.0)
    _ => fail("the description is not an object")
  }
  let writer = @core.DocumentWriter::new()
  ignore(writer.add_part(PART_TEMPLATE, @utf8.encode(description.stringify())))
  ignore(writer.add_part(PART_SOURCE, tpl))
  let message = form_test_read_error(writer.write_single())
  assert_true(message.contains("is of version 2"), msg=message)
  assert_true(message.contains("compile the template again"), msg=message)
}

///|
test "form refuses a description that does not name its template" {
  let tpl = form_test_fixed_xlsx()
  let compiled = compile(tpl, "form-fixed", Options::new())
  let description = compiled.template.to_json()
  match description {
    Json::Object(object) => object["source"] = Json::string("")
    _ => fail("the description is not an object")
  }
  let writer = @core.DocumentWriter::new()
  ignore(writer.add_part(PART_TEMPLATE, @utf8.encode(description.stringify())))
  ignore(writer.add_part(PART_SOURCE, tpl))
  let message = form_test_read_error(writer.write_single())
  assert_true(message.contains("does not name its template"), msg=message)
}

///|
test "form refuses a compiled template that does not hold its template" {
  let tpl = form_test_fixed_xlsx()
  let compiled = compile(tpl, "form-fixed", Options::new())
  let writer = @core.DocumentWriter::new()
  ignore(
    writer.add_part(
      PART_TEMPLATE,
      @utf8.encode(compiled.template.to_json().stringify()),
    ),
  )
  let message = form_test_read_error(writer.write_single())
  assert_true(
    message.contains("does not hold its template of the compiled template"),
    msg=message,
  )
}

///|
test "form refuses a damaged template part" {
  let tpl = form_test_fixed_xlsx()
  let compiled = compile(tpl, "form-fixed", Options::new())
  let document = @core.open_single(compiled.bdf)
  let mut found : @core.Part? = None
  for part in document.manifest.parts {
    if part.kind == PART_TEMPLATE {
      found = Some(part)
    }
  }
  let part = match found {
    Some(part) => part
    None => fail("the compiled template has no description")
  }
  let start = document.header.manifest_offset +
    document.header.manifest_length +
    part.offset
  let damaged : FixedArray[Byte] = FixedArray::make(
    compiled.bdf.length(),
    b'\x00',
  )
  for i in 0..<compiled.bdf.length() {
    damaged[i] = compiled.bdf[i]
  }
  damaged[start] = damaged[start] ^ 1
  let message = form_test_read_error(Bytes::from_array(damaged))
  assert_true(message.has_prefix("form: "), msg=message)
  assert_true(!message.contains("BdfError"), msg=message)
}

///|
test "form refuses a template that is larger than 256 MiB" {
  let big = Bytes::make(MAX_TEMPLATE_SIZE + 1, b'x')
  let message = form_test_compile_error(big, "", Options::new())
  assert_true(message.contains("larger than 256 MiB"), msg=message)
}

///|
test "form fills a Word document" {
  let tpl = form_test_docx(["{{no}}", "{{customer.name}}", "{{memo}}"])
  let compiled = compile(tpl, "letter", Options::new())
  assert_eq(compiled.template.format, FORMAT_DOCX)
  let result = fill(
    compiled.bdf,
    Options::new(
      data=form_test_json(
        "{\"no\":\"A-1\",\"customer\":{\"name\":\"ACME\"},\"memo\":\"Hello\"}",
      ),
    ),
  )
  assert_true(result.partial is None, msg="a complete fill")
  let text = form_test_text(result.bdf)
  assert_true(text.contains("A-1"), msg=text)
  assert_true(text.contains("ACME"), msg=text)
  assert_true(text.contains("Hello"), msg=text)
  assert_true(!text.contains("{{"), msg=text)
}

///|
test "form fills a text template" {
  let tpl = @utf8.encode("No: {{no}}\nName: {{customer.name}}\n")
  let compiled = compile(tpl, "note", Options::new())
  assert_eq(compiled.template.format, FORMAT_TEXT)
  let result = fill(
    compiled.bdf,
    Options::new(
      data=form_test_json("{\"no\":\"A-1\",\"customer\":{\"name\":\"ACME\"}}"),
    ),
  )
  assert_true(result.partial is None, msg="a complete fill")
  let text = form_test_text(result.bdf)
  assert_true(text.contains("No: A-1"), msg=text)
  assert_true(text.contains("Name: ACME"), msg=text)
}

///|
test "form fills a text template strictly" {
  let tpl = @utf8.encode("No: {{no}}\n")
  let message = form_test_fill_error(
    tpl,
    Options::new(data=form_test_json("{}"), strict=true),
  )
  assert_true(message.contains("the data has no \"no\""), msg=message)
}

///|
/// A workbook of two tags, for the tests that only need a name in an object.
fn form_test_small_xlsx() -> Bytes raise {
  form_test_xlsx(
    form_test_row(1, form_test_cell("A1", "{{no}}")) +
    form_test_row(2, form_test_cell("A2", "{{customer.name}}")),
  )
}

///|
/// The kinds of the parts of a document.
fn form_test_kinds(bdf : Bytes) -> Array[String] raise {
  @core.open_single(bdf).manifest.parts.map(fn(part) { part.kind })
}

///|
test "form compiles and fills every format into a usable document" {
  let templates : Array[(String, Bytes, String, String)] = [
    (
      FORMAT_XLSX,
      form_test_small_xlsx(),
      "{\"no\":\"A-1\"}",
      "customer.name",
    ),
    (
      FORMAT_DOCX,
      form_test_docx(["{{no}}", "{{customer.name}}"]),
      "{\"no\":\"A-1\"}",
      "customer.name",
    ),
    (
      FORMAT_PDF,
      form_test_contract_pdf(),
      "{\"party_a\":\"Taro Yamada\"}",
      "party_b",
    ),
    (
      FORMAT_TEXT,
      @utf8.encode("No: {{no}}\nName: {{customer.name}}\n"),
      "{\"no\":\"A-1\"}",
      "customer.name",
    ),
  ]
  for entry in templates {
    let (format, tpl, data, open) = entry
    let compiled = compile(tpl, "form", Options::new())
    assert_eq(compiled.template.format, format)
    let document = @core.open_single(compiled.bdf)
    assert_true(document.manifest.views.length() > 0, msg=format + ": views")
    let kinds = form_test_kinds(compiled.bdf)
    assert_true(kinds.contains(PART_SOURCE), msg=format + ": src")
    assert_true(kinds.contains(PART_TEMPLATE), msg=format + ": tpl")
    let (template, source) = read_template(compiled.bdf)
    assert_eq(template.format, format)
    assert_true(source == tpl, msg=format + ": the template is held")
    // a partly filled form of it is a document too, and holds the template
    let res = fill(
      compiled.bdf,
      Options::new(data=form_test_json(data), open=[open]),
    )
    assert_true(res.partial is Some(_), msg=format + ": partly filled")
    let form = @core.open_single(res.bdf)
    assert_true(
      form.manifest.views.length() > 0,
      msg=format + ": views of the form",
    )
    let form_kinds = form_test_kinds(res.bdf)
    assert_true(form_kinds.contains(PART_SOURCE), msg=format + ": src of the form")
    assert_true(
      form_kinds.contains(PART_TEMPLATE),
      msg=format + ": tpl of the form",
    )
    let (described, form_source) = read_template(res.bdf)
    assert_true(described.is_partial(), msg=format + ": the form is partial")
    assert_true(
      form_source == tpl,
      msg=format + ": the form holds the template",
    )
    assert_eq(described.open.join(","), open)
  }
}

///|
test "form keeps the signatures of a description and does not check them" {
  let tpl = form_test_small_xlsx()
  let compiled = compile(tpl, "form", Options::new())
  let description = compiled.template.to_json()
  match description {
    Json::Object(object) =>
      object["signed"] = Json::array([Json::string("c2lnbmF0dXJl")])
    _ => fail("the description is not an object")
  }
  let writer = @core.DocumentWriter::new()
  ignore(writer.add_part(PART_TEMPLATE, @utf8.encode(description.stringify())))
  ignore(writer.add_part(PART_SOURCE, tpl))
  let signed = writer.write_single()
  let (template, _) = read_template(signed)
  assert_eq(template.signed.join(","), "c2lnbmF0dXJl")
  // a fill keeps the signatures as they were read: this port makes no
  // signatures and checks none
  let res = fill(
    signed,
    Options::new(data=form_test_json("{\"no\":\"A-1\"}"), open=["customer.name"]),
  )
  let partial = match res.partial {
    Some(value) => value
    None => fail("the fill is not partly filled")
  }
  assert_eq(partial.signed.join(","), "c2lnbmF0dXJl")
  let (again, _) = read_template(res.bdf)
  assert_eq(again.signed.join(","), "c2lnbmF0dXJl")
}

///|
test "form refuses a ZIP that is not a document of Office" {
  let zipped = @ooxml.stored_zip([("hello.txt", @utf8.encode("hello"))])
  let message = form_test_fill_error(zipped, Options::new())
  assert_true(message.contains("is not an Excel workbook"), msg=message)
}

///|
test "form refuses a PDF without form fields" {
  let pdf = form_test_pdf([
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 100] >>",
  ])
  let message = form_test_fill_error(pdf, Options::new(open=["name"]))
  assert_true(message.contains("no form fields"), msg=message)
}
