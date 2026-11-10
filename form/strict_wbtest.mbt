///|
// Regression tests of strict fills, adapted from the strict tests of
// converter/xlsx, converter/docx, converter/pptx, converter/pdfform,
// converter/pdfme and converter/textform of upstream: a name that the data
// does not have is an error, a name inside a branch that is not taken is not
// asked for, and a name that is filled already is not filled again.

///|
/// The strings of the objects of a document, as a reader of it sees them.
fn form_test_strings(bdf : Bytes) -> String raise {
  let document = @core.open_single(bdf)
  let out = StringBuilder()
  for part in document.manifest.parts {
    if part.kind == "obj" {
      let resources = @core.decode_object_resources(document.part(part.hash))
      for text in resources.object.strings {
        out.write_string(text)
        out.write_char('\n')
      }
    }
  }
  out.to_string()
}

///|
/// A presentation of one slide with a tag, as the converter reads it.
fn form_test_pptx() -> Bytes raise {
  let content_types =
    #|<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/><Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/></Types>
  let rels =
    #|<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/></Relationships>
  let presentation =
    #|<?xml version="1.0"?><p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><p:sldIdLst><p:sldId id="256" r:id="rId1"/></p:sldIdLst><p:sldSz cx="12192000" cy="6858000"/></p:presentation>
  let presentation_rels =
    #|<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/></Relationships>
  let slide =
    #|<?xml version="1.0"?><p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><p:cSld><p:spTree><p:sp><p:txBody><a:p><a:r><a:t>{{name}}</a:t></a:r></a:p></p:txBody></p:sp></p:spTree></p:cSld></p:sld>
  @ooxml.stored_zip([
    ("[Content_Types].xml", @utf8.encode(content_types)),
    ("_rels/.rels", @utf8.encode(rels)),
    ("ppt/presentation.xml", @utf8.encode(presentation)),
    ("ppt/_rels/presentation.xml.rels", @utf8.encode(presentation_rels)),
    ("ppt/slides/slide1.xml", @utf8.encode(slide)),
  ])
}

///|
/// A workbook of a value and of the two branches of a condition, each with a
/// name of its own.
fn form_test_branch_xlsx() -> Bytes raise {
  form_test_xlsx(
    form_test_row(1, form_test_cell("A1", "{{no}}")) +
    form_test_row(2, form_test_cell("A2", "{{#paid}}{{bonus}}{{/paid}}")) +
    form_test_row(3, form_test_cell("A3", "{{^paid}}{{penalty}}{{/paid}}")),
  )
}

///|
/// A workbook of a list of objects.
fn form_test_list_xlsx() -> Bytes raise {
  form_test_xlsx(
    form_test_row(1, form_test_cell("A1", "{{#items}}{{name}}{{/items}}")),
  )
}

///|
/// A PDF whose one field is named by the parts of an object.
fn form_test_nested_pdf() -> Bytes {
  form_test_pdf([
    "<< /Type /Catalog /Pages 2 0 R /AcroForm << /Fields [4 0 R] >> >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 100] /Annots [4 0 R] >>",
    "<< /Type /Annot /Subtype /Widget /FT /Tx /T (applicant.name) /Rect [10 20 100 40] /F 4 /P 3 0 R /DA (/Helv 11 Tf 0 g) /V () >>",
  ])
}

///|
/// A template of pdfme of a text, a table and a code that the designer left
/// read only.
fn form_test_pdfme() -> Bytes {
  @utf8.encode(
    "{\"basePdf\":{\"width\":100,\"height\":50},\"schemas\":[[{\"name\":\"name\",\"type\":\"text\",\"content\":\"\",\"position\":{\"x\":10,\"y\":10},\"width\":50,\"height\":10},{\"name\":\"lines\",\"type\":\"table\",\"position\":{\"x\":10,\"y\":25},\"width\":80,\"height\":20,\"head\":[\"item\",\"qty\"]},{\"name\":\"code\",\"type\":\"qrcode\",\"readOnly\":true,\"content\":\"HELLO\",\"position\":{\"x\":70,\"y\":10},\"width\":20,\"height\":20}]]}",
  )
}

///|
/// A template of pdfme of a text of two variables.
fn form_test_pdfme_variables() -> Bytes {
  @utf8.encode(
    "{\"basePdf\":{\"width\":100,\"height\":50},\"schemas\":[[{\"name\":\"mv\",\"type\":\"multiVariableText\",\"text\":\"{first} {last}\",\"variables\":[\"first\",\"last\"],\"position\":{\"x\":10,\"y\":10},\"width\":80,\"height\":10}]]}",
  )
}

///|
test "form strict fills a workbook whose data is complete" {
  let result = fill(
    form_test_small_xlsx(),
    Options::new(
      data=form_test_json("{\"no\":\"A-1\",\"customer\":{\"name\":\"ACME\"}}"),
      strict=true,
    ),
  )
  let text = form_test_text(result.bdf)
  assert_true(text.contains("A-1"), msg=text)
  assert_true(text.contains("ACME"), msg=text)
  assert_eq(result.warnings.length(), 0)
}

///|
test "form strict reads the names of objects" {
  let message = form_test_fill_error(
    form_test_small_xlsx(),
    Options::new(
      data=form_test_json("{\"no\":\"A-1\",\"customer\":{}}"),
      strict=true,
    ),
  )
  assert_true(message.contains("the data has no \"customer.name\""), msg=message)
  // the object itself is not a value of the name
  let shallow = form_test_fill_error(
    form_test_small_xlsx(),
    Options::new(data=form_test_json("{\"no\":\"A-1\",\"customer\":\"ACME\"}"), strict=true),
  )
  assert_true(shallow.contains("the data has no \"customer.name\""), msg=shallow)
}

///|
test "form strict takes null for a value" {
  let result = fill(
    form_test_small_xlsx(),
    Options::new(
      data=form_test_json("{\"no\":null,\"customer\":{\"name\":null}}"),
      strict=true,
    ),
  )
  let text = form_test_text(result.bdf)
  assert_true(!text.contains("{{"), msg=text)
  assert_eq(result.warnings.length(), 0)
}

///|
test "form strict does not ask for the names of a branch that is not taken" {
  // the branch of the condition that is not taken is dropped before its tags
  // are looked up, so its names are not of the data
  let taken = fill(
    form_test_branch_xlsx(),
    Options::new(
      data=form_test_json("{\"no\":\"A-1\",\"paid\":true,\"bonus\":\"B\"}"),
      strict=true,
    ),
  )
  let text = form_test_text(taken.bdf)
  assert_true(text.contains("B"), msg=text)
  assert_true(!text.contains("{{"), msg=text)
  let other = fill(
    form_test_branch_xlsx(),
    Options::new(
      data=form_test_json("{\"no\":\"A-1\",\"paid\":false,\"penalty\":\"P\"}"),
      strict=true,
    ),
  )
  let other_text = form_test_text(other.bdf)
  assert_true(other_text.contains("P"), msg=other_text)
  // the name of the branch that is taken is of the data
  let missing = form_test_fill_error(
    form_test_branch_xlsx(),
    Options::new(data=form_test_json("{\"no\":\"A-1\",\"paid\":true}"), strict=true),
  )
  assert_true(missing.contains("the data has no \"bonus\""), msg=missing)
}

///|
test "form strict asks for the name of a condition" {
  // the name of a condition is looked up before the branch is chosen, as
  // upstream does
  let message = form_test_fill_error(
    form_test_branch_xlsx(),
    Options::new(data=form_test_json("{\"no\":\"A-1\"}"), strict=true),
  )
  assert_true(message.contains("the data has no \"paid\""), msg=message)
}

///|
test "form strict reads the names of the items of a list" {
  let result = fill(
    form_test_list_xlsx(),
    Options::new(
      data=form_test_json("{\"items\":[{\"name\":\"a\"},{\"name\":\"b\"}]}"),
      strict=true,
    ),
  )
  let text = form_test_text(result.bdf)
  assert_true(text.contains("a"), msg=text)
  assert_true(text.contains("b"), msg=text)
  let message = form_test_fill_error(
    form_test_list_xlsx(),
    Options::new(data=form_test_json("{\"items\":[{\"name\":\"a\"},{}]}"), strict=true),
  )
  assert_true(message.contains("the data has no \"name\""), msg=message)
}

///|
test "form tells the names that the data has not, without strict" {
  let result = fill(form_test_small_xlsx(), Options::new(data=form_test_json("{}")))
  let mut told = ""
  for warning in result.warnings {
    told = told + warning + "\n"
  }
  assert_true(told.contains("the data has no \"no\"; it is left empty"), msg=told)
  assert_true(
    told.contains("the data has no \"customer.name\"; it is left empty"),
    msg=told,
  )
}

///|
test "form strict fills a Word document" {
  let tpl = form_test_docx(["{{no}}", "{{customer.name}}"])
  let message = form_test_fill_error(
    tpl,
    Options::new(data=form_test_json("{\"no\":\"A-1\"}"), strict=true),
  )
  assert_true(message.contains("the data has no \"customer.name\""), msg=message)
  let result = fill(
    tpl,
    Options::new(
      data=form_test_json("{\"no\":\"A-1\",\"customer\":{\"name\":\"ACME\"}}"),
      strict=true,
    ),
  )
  let text = form_test_text(result.bdf)
  assert_true(text.contains("ACME"), msg=text)
}

///|
test "form strict fills a presentation" {
  let tpl = form_test_pptx()
  let message = form_test_fill_error(
    tpl,
    Options::new(data=form_test_json("{}"), strict=true),
  )
  assert_true(message.contains("the data has no \"name\""), msg=message)
  let result = fill(
    tpl,
    Options::new(data=form_test_json("{\"name\":\"Alice\"}"), strict=true),
  )
  assert_eq(result.format, FORMAT_PPTX)
  // the slide holds the value
  let filled = @pptx.fill_bytes(
    tpl,
    @utf8.encode("{\"name\":\"Alice\"}"),
    strict=true,
  )
  let archive = @zip.open_zip(filled)
  let mut slide = ""
  for entry in archive.entries {
    if entry.name == "ppt/slides/slide1.xml" {
      slide = @utf8.decode_lossy(archive.read(entry, 65536)[:])
    }
  }
  assert_true(slide.contains("Alice"), msg=slide)
  assert_true(!slide.contains("{{name}}"), msg=slide)
}

///|
test "form strict fills the fields of a PDF" {
  let tpl = form_test_contract_pdf()
  let message = form_test_fill_error(
    tpl,
    Options::new(data=form_test_json("{\"party_a\":\"A\"}"), strict=true),
  )
  assert_true(message.contains("the data has no \"party_b\""), msg=message)
  ignore(
    fill(
      tpl,
      Options::new(
        data=form_test_json("{\"party_a\":\"A\",\"party_b\":\"B\"}"),
        strict=true,
      ),
    ),
  )
  // the values of the fields of a form are not drawn in the page: they are
  // read back from the form
  let filled = @pdf.fill_pdf(
    tpl,
    @utf8.encode("{\"party_a\":\"A\",\"party_b\":\"B\"}"),
    strict=true,
  )
  let mut values = ""
  for field in @pdf.read_fields(filled) {
    values = values + field.name + "=" + field.value + "\n"
  }
  assert_true(values.contains("party_a=A"), msg=values)
  assert_true(values.contains("party_b=B"), msg=values)
}

///|
test "form strict reads the names of the fields of a PDF in objects" {
  let tpl = form_test_nested_pdf()
  let message = form_test_fill_error(
    tpl,
    Options::new(data=form_test_json("{\"applicant\":{}}"), strict=true),
  )
  assert_true(message.contains("the data has no \"applicant.name\""), msg=message)
  ignore(
    fill(
      tpl,
      Options::new(
        data=form_test_json("{\"applicant\":{\"name\":\"ACME\"}}"),
        strict=true,
      ),
    ),
  )
  let filled = @pdf.fill_pdf(
    tpl,
    @utf8.encode("{\"applicant\":{\"name\":\"ACME\"}}"),
    strict=true,
  )
  let mut values = ""
  for field in @pdf.read_fields(filled) {
    values = values + field.name + "=" + field.value + "\n"
  }
  assert_true(values.contains("applicant.name=ACME"), msg=values)
}

///|
test "form strict fills a template of pdfme" {
  let tpl = form_test_pdfme()
  let message = form_test_fill_error(
    tpl,
    Options::new(data=form_test_json("{}"), strict=true),
  )
  assert_true(message.contains("the data has no \"name\""), msg=message)
  // the code that the designer left read only is not of the data
  let result = fill(
    tpl,
    Options::new(data=form_test_json("{\"name\":\"Alice\",\"lines\":[]}"), strict=true),
  )
  let text = form_test_strings(result.bdf)
  assert_true(text.contains("Alice"), msg=text)
}

///|
test "form strict takes the variables of a field of pdfme" {
  let tpl = form_test_pdfme_variables()
  let message = form_test_fill_error(
    tpl,
    Options::new(data=form_test_json("{}"), strict=true),
  )
  assert_true(message.contains("the data has no \"mv\""), msg=message)
  // a variable of the field is a value of the field
  let result = fill(
    tpl,
    Options::new(data=form_test_json("{\"first\":\"Ada\"}"), strict=true),
  )
  let text = form_test_strings(result.bdf)
  assert_true(text.contains("Ada"), msg=text)
}

///|
test "form strict leaves the names that a fill leaves open" {
  let compiled = compile(form_test_small_xlsx(), "form", Options::new())
  let result = fill(
    compiled.bdf,
    Options::new(
      data=form_test_json("{\"no\":\"A-1\"}"),
      strict=true,
      open=["customer.name"],
    ),
  )
  let partial = match result.partial {
    Some(value) => value
    None => fail("the fill is not partly filled")
  }
  assert_eq(partial.open.join(","), "customer.name")
  for warning in result.warnings {
    assert_true(!warning.contains("customer.name"), msg=warning)
  }
}

///|
test "form strict completes a partly filled form" {
  let compiled = compile(form_test_small_xlsx(), "form", Options::new())
  let first = fill(
    compiled.bdf,
    Options::new(data=form_test_json("{\"no\":\"A-1\"}"), open=["customer.name"]),
  )
  let direct = fill(
    compiled.bdf,
    Options::new(
      data=form_test_json("{\"no\":\"A-1\",\"customer\":{\"name\":\"ACME\"}}"),
    ),
  )
  let done = fill(
    first.bdf,
    Options::new(
      data=form_test_json("{\"customer\":{\"name\":\"ACME\"}}"),
      strict=true,
    ),
  )
  assert_true(done.partial is None, msg="the completed form is not partly filled")
  assert_true(
    done.bdf == direct.bdf,
    msg="the completed form is not the form filled at once",
  )
}

///|
test "form strict does not fill a value that is filled already" {
  let compiled = compile(form_test_small_xlsx(), "form", Options::new())
  let first = fill(
    compiled.bdf,
    Options::new(data=form_test_json("{\"no\":\"A-1\"}"), open=["customer.name"]),
  )
  let message = form_test_fill_error(
    first.bdf,
    Options::new(
      data=form_test_json("{\"no\":\"B-2\",\"customer\":{\"name\":\"ACME\"}}"),
      strict=true,
    ),
  )
  assert_true(message.contains("\"no\" is filled already"), msg=message)
}

///|
test "form strict checks the sample of a compiled template" {
  let message = form_test_compile_error(
    form_test_small_xlsx(),
    "form",
    Options::new(data=form_test_json("{\"no\":\"A-1\"}"), strict=true),
  )
  assert_true(message.contains("the data has no \"customer.name\""), msg=message)
  let compiled = compile(
    form_test_small_xlsx(),
    "form",
    Options::new(data=form_test_json("{\"no\":\"A-1\"}")),
  )
  assert_eq(compiled.template.name, "form")
}

///|
test "form strict is off for the sample of a template of pdfme" {
  // the sample of a template of pdfme is what its designer left in its
  // fields, which is not the data of the fill
  let message = form_test_compile_error(
    form_test_pdfme(),
    "form",
    Options::new(strict=true),
  )
  assert_eq(message, "")
}
