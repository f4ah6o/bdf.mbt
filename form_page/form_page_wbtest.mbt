///|
// Tests of the bridge of the form page: the JSON that site/assets/form.js
// reads, made from the form module of bdf.mbt. The page itself (the form, the
// preview, the downloads) is tested in site/test.mjs.

///|
/// A text template of two names, one of them inside an object.
fn form_page_test_text() -> Bytes {
  @utf8.encode("No: {{no}}\nName: {{customer.name}}\n")
}

///|
/// A workbook of one sheet whose cells are `sheet_data`, as the converter
/// reads it (the same workbook that form/form_wbtest.mbt builds).
fn form_page_test_xlsx(sheet_data : String) -> Bytes raise {
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
/// A Word document of one paragraph, as the converter reads it.
fn form_page_test_docx(paragraph : String) -> Bytes raise {
  let content_types =
    #|<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>
  let rels =
    #|<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>
  let document =
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?><w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p><w:r><w:t>" +
    paragraph +
    "</w:t></w:r></w:p><w:sectPr/></w:body></w:document>"
  @ooxml.stored_zip([
    ("[Content_Types].xml", @utf8.encode(content_types)),
    ("_rels/.rels", @utf8.encode(rels)),
    ("word/document.xml", @utf8.encode(document)),
  ])
}

///|
/// A workbook of two names, one of them inside an object.
fn form_page_test_small_xlsx() -> Bytes raise {
  form_page_test_xlsx(
    "<row r=\"1\"><c r=\"A1\" t=\"inlineStr\"><is><t>{{no}}</t></is></c></row>" +
    "<row r=\"2\"><c r=\"A2\" t=\"inlineStr\"><is><t>{{customer.name}}</t></is></c></row>",
  )
}

///|
fn form_page_test_json(text : String) -> Json raise {
  @json.parse(text)
}

///|
/// The object of a reply of the bridge, which must have succeeded.
fn form_page_test_ok(text : String) -> Map[String, Json] raise {
  let object = match form_page_test_json(text) {
    Json::Object(object) => object
    _ => fail("the bridge did not return an object: " + text)
  }
  match object.get("ok") {
    Some(Json::True) => ()
    _ => fail("the bridge failed: " + text)
  }
  object
}

///|
/// The message of a reply of the bridge, which must have failed.
fn form_page_test_error(text : String) -> String raise {
  let object = match form_page_test_json(text) {
    Json::Object(object) => object
    _ => fail("the bridge did not return an object: " + text)
  }
  match object.get("ok") {
    Some(Json::False) => ()
    _ => fail("the bridge did not fail: " + text)
  }
  match object.get("error") {
    Some(Json::String(message)) => message
    _ => fail("the failure has no message: " + text)
  }
}

///|
fn form_page_test_string(object : Map[String, Json], name : String) -> String raise {
  match object.get(name) {
    Some(Json::String(value)) => value
    _ => fail("the reply has no text \"" + name + "\"")
  }
}

///|
fn form_page_test_bool(object : Map[String, Json], name : String) -> Bool raise {
  match object.get(name) {
    Some(Json::True) => true
    Some(Json::False) => false
    _ => fail("the reply has no boolean \"" + name + "\"")
  }
}

///|
fn form_page_test_number(object : Map[String, Json], name : String) -> Double raise {
  match object.get(name) {
    Some(Json::Number(value, ..)) => value
    _ => fail("the reply has no number \"" + name + "\"")
  }
}

///|
fn form_page_test_strings(object : Map[String, Json], name : String) -> Array[String] raise {
  match object.get(name) {
    Some(Json::Array(items)) => {
      let out : Array[String] = []
      for item in items {
        match item {
          Json::String(value) => out.push(value)
          _ => fail("the reply has a value that is not a text in \"" + name + "\"")
        }
      }
      out
    }
    _ => fail("the reply has no array \"" + name + "\"")
  }
}

///|
/// The bytes of a reply of the bridge, which holds them as base64.
fn form_page_test_bytes(object : Map[String, Json], name : String) -> Bytes raise {
  @base64.decode(form_page_test_string(object, name)) catch {
    _ => fail("the reply has no base64 in \"" + name + "\"")
  }
}

///|
/// The views of a reply of the bridge: their kind, title and pages.
fn form_page_test_views(object : Map[String, Json]) -> Array[(String, String, Int)] raise {
  let out : Array[(String, String, Int)] = []
  match object.get("views") {
    Some(Json::Array(items)) => {
      for item in items {
        let view = match item {
          Json::Object(view) => view
          _ => fail("a view is not an object")
        }
        let kind = match view.get("kind") {
          Some(Json::String(kind)) => kind
          _ => fail("a view has no kind")
        }
        let title = match view.get("title") {
          Some(Json::String(title)) => title
          _ => fail("a view has no title")
        }
        let pages = match view.get("pages") {
          Some(Json::Number(pages, ..)) => pages.to_int()
          _ => fail("a view has no pages")
        }
        out.push((kind, title, pages))
      }
    }
    _ => fail("the reply has no views")
  }
  out
}

///|
/// The text of the views of a document, as a reader of it sees it.
fn form_page_test_text_of(bdf : Bytes) -> String raise {
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
test "form page describes a text template" {
  let reply = form_page_test_ok(bdf_form_describe(form_page_test_text(), ""))
  assert_eq(form_page_test_string(reply, "format"), "text")
  assert_eq(form_page_test_strings(reply, "open").length(), 0)
  assert_eq(form_page_test_number(reply, "held"), 0.0)
  // no sample: the schema still names what the tags ask for
  let schema = form_page_test_json(form_page_test_string(reply, "schema"))
  let properties = match schema {
    Json::Object(object) =>
      match object.get("properties") {
        Some(Json::Object(properties)) => properties
        _ => fail("the schema has no properties")
      }
    _ => fail("the schema is not an object")
  }
  assert_true(properties.contains("no"), msg="the schema has no \"no\"")
  assert_true(properties.contains("customer"), msg="the schema has no \"customer\"")
  match properties.get("customer") {
    Some(Json::Object(customer)) =>
      match customer.get("properties") {
        Some(Json::Object(names)) =>
          assert_true(names.contains("name"), msg="the schema has no \"customer.name\"")
        _ => fail("the schema of \"customer\" has no properties")
      }
    _ => fail("the schema of \"customer\" is not an object")
  }
}

///|
test "form page describes a template with the sample that the page gives it" {
  let sample = "{\"no\":1024,\"customer\":{\"name\":\"ACME\"}}"
  let reply = form_page_test_ok(bdf_form_describe(form_page_test_text(), sample))
  // the sample comes back, so that the page shows the template filled with it
  match reply.get("sample") {
    Some(Json::Object(object)) => {
      assert_eq(object.get("no"), Some(Json::number(1024.0)))
      assert_eq(object.get("customer"), Some(Json::object({ "name": Json::string("ACME") })))
    }
    _ => fail("the reply has no sample")
  }
  // and it types the names of the schema
  let schema = form_page_test_json(form_page_test_string(reply, "schema"))
  let properties = match schema {
    Json::Object(object) =>
      match object.get("properties") {
        Some(Json::Object(properties)) => properties
        _ => fail("the schema has no properties")
      }
    _ => fail("the schema is not an object")
  }
  match properties.get("no") {
    Some(Json::Object(no)) => assert_eq(no.get("type"), Some(Json::string("number")))
    _ => fail("the schema of \"no\" is not an object")
  }
}

///|
test "form page fills a text template into a BDF that a reader opens" {
  let reply = form_page_test_ok(
    bdf_form_fill(
      form_page_test_text(),
      "{\"no\":1024,\"customer\":{\"name\":\"ACME\"}}",
      "[]",
      false,
    ),
  )
  let bdf = form_page_test_bytes(reply, "bdf")
  // the bytes are a document of BDF, not the source of the template
  assert_eq(bdf[0:4], b"bdf\x00")
  let document = @core.open_single(bdf)
  assert_true(document.manifest.views.length() > 0, msg="the BDF has no view")
  assert_true(document.manifest.views[0].pages.length() > 0, msg="the view has no page")
  let text = form_page_test_text_of(bdf)
  assert_true(text.contains("1024"), msg=text)
  assert_true(text.contains("ACME"), msg=text)
  assert_true(!text.contains("{{"), msg=text)
  assert_eq(form_page_test_bool(reply, "partial"), false)
  assert_eq(form_page_test_strings(reply, "open").length(), 0)
  // the text form is a page view: the page can write it as a PDF
  assert_true(form_page_test_number(reply, "pages") > 0.0, msg="the text fill has no page")
  let views = form_page_test_views(reply)
  assert_eq(views.length(), 1)
  assert_true(views[0].0 != "sheet", msg="the text fill is a sheet")
}

///|
test "form page fills a workbook into a BDF that a reader opens" {
  let reply = form_page_test_ok(
    bdf_form_fill(
      form_page_test_small_xlsx(),
      "{\"no\":\"A-1\",\"customer\":{\"name\":\"ACME\"}}",
      "[]",
      true,
    ),
  )
  let bdf = form_page_test_bytes(reply, "bdf")
  assert_eq(bdf[0:4], b"bdf\x00")
  let text = form_page_test_text_of(bdf)
  assert_true(text.contains("A-1"), msg=text)
  assert_true(text.contains("ACME"), msg=text)
  assert_eq(form_page_test_string(reply, "format"), "xlsx")
  // the workbook is a sheet view: it has no pages, so the page cannot write it as a PDF
  assert_eq(form_page_test_number(reply, "pages"), 0.0)
  let views = form_page_test_views(reply)
  assert_eq(views.length(), 1)
  assert_eq(views[0].0, "sheet")
  assert_eq(views[0].1, "Sheet1")
  assert_eq(views[0].2, 0)
}

///|
test "form page leaves the names that the page marks for another person" {
  // the page takes the names that it leaves out of the data before it fills
  // (withoutOpen of site/assets/form.js): a fill refuses data for a name that
  // it leaves open
  let reply = form_page_test_ok(
    bdf_form_fill(form_page_test_text(), "{\"no\":1024}", "[\"customer.name\"]", false),
  )
  assert_eq(form_page_test_bool(reply, "partial"), true)
  assert_eq(form_page_test_strings(reply, "open"), ["customer.name"])
  let bdf = form_page_test_bytes(reply, "bdf")
  let text = form_page_test_text_of(bdf)
  // what was given is in, and what was left is not
  assert_true(text.contains("1024"), msg=text)
  assert_true(!text.contains("ACME"), msg=text)
  // the page reads the partly filled form back: it says what is left
  let described = form_page_test_ok(bdf_form_describe(bdf, ""))
  assert_eq(form_page_test_strings(described, "open"), ["customer.name"])
  assert_eq(form_page_test_number(described, "held"), 1.0)
  // and another fill completes it
  let done = form_page_test_ok(
    bdf_form_fill(bdf, "{\"customer\":{\"name\":\"ACME\"}}", "[]", false),
  )
  assert_eq(form_page_test_bool(done, "partial"), false)
  let completed = form_page_test_text_of(form_page_test_bytes(done, "bdf"))
  assert_true(completed.contains("1024"), msg=completed)
  assert_true(completed.contains("ACME"), msg=completed)
}

///|
test "form page compiles a template into a .bdft that it reads back" {
  let reply = form_page_test_ok(
    bdf_form_compile(
      form_page_test_text(),
      "slip.txt",
      "{\"no\":1024,\"customer\":{\"name\":\"ACME\"}}",
    ),
  )
  let bdft = form_page_test_bytes(reply, "bdft")
  assert_eq(bdft[0:4], b"bdf\x00")
  // the compiled template is a template that the page opens like any other
  let described = form_page_test_ok(bdf_form_describe(bdft, ""))
  assert_eq(form_page_test_string(reply, "format"), "text")
  assert_eq(form_page_test_string(described, "format"), "text")
  // and it holds the sample that it was compiled with
  match described.get("sample") {
    Some(Json::Object(object)) => assert_eq(object.get("no"), Some(Json::number(1024.0)))
    _ => fail("the compiled template has no sample")
  }
  let filled = form_page_test_ok(bdf_form_fill(bdft, "{\"no\":7,\"customer\":{\"name\":\"B\"}}", "[]", false))
  let text = form_page_test_text_of(form_page_test_bytes(filled, "bdf"))
  assert_true(text.contains("7"), msg=text)
  assert_true(text.contains("B"), msg=text)
}

///|
test "form page compiles a template without a sample" {
  let reply = form_page_test_ok(bdf_form_compile(form_page_test_text(), "slip.txt", ""))
  let described = form_page_test_ok(bdf_form_describe(form_page_test_bytes(reply, "bdft"), ""))
  assert_eq(form_page_test_string(described, "format"), "text")
  match described.get("sample") {
    Some(Json::Null) | None => ()
    _ => fail("a template compiled without a sample has one")
  }
}

///|
test "form page reports a template that it cannot read" {
  let message = form_page_test_error(bdf_form_describe(b"not a template", ""))
  assert_true(message.length() > 0, msg="the failure has no message")
  // and the page shows it as it is, without a document
  let filled = form_page_test_error(bdf_form_fill(b"not a template", "{}", "[]", false))
  assert_true(filled.length() > 0, msg="the failure has no message")
}

///|
test "form page reports data that is not JSON" {
  let message = form_page_test_error(bdf_form_fill(form_page_test_text(), "{", "[]", false))
  assert_true(message.contains("JSON"), msg=message)
  let sample = form_page_test_error(bdf_form_describe(form_page_test_text(), "{"))
  assert_true(sample.contains("JSON"), msg=sample)
  let compiled = form_page_test_error(bdf_form_compile(form_page_test_text(), "slip.txt", "{"))
  assert_true(compiled.contains("JSON"), msg=compiled)
}

///|
test "form page reports a name that a strict fill does not have" {
  let message = form_page_test_error(
    bdf_form_fill(form_page_test_text(), "{\"no\":1}", "[]", true),
  )
  assert_true(message.contains("customer.name"), msg=message)
}

///|
test "form page fills what the page types, whatever the values are" {
  // the values that a person types into the form of the page: the fill puts
  // each of them in the document, and none of them is left as a tag
  let values : Array[(String, String)] = [
    ("", ""),
    ("0", "0"),
    ("007", "007"),
    ("a b", "a b"),
    ("日本語", "日本語"),
    ("line\nbreak", "line\nbreak"),
    ("{{no}}", "{{no}}"),
    ("\"quoted\"", "\"quoted\""),
  ]
  for (given, shown) in values {
    let data = Json::object({ "no": Json::string(given), "customer": Json::object({ "name": Json::string(given) }) })
    let reply = form_page_test_ok(bdf_form_fill(form_page_test_text(), data.stringify(), "[]", false))
    let text = form_page_test_text_of(form_page_test_bytes(reply, "bdf"))
    // a value of more than one line is a run of the text index for each line
    for line in shown.split("\n") {
      assert_true(text.contains(line), msg="\"" + given + "\" is not in: " + text)
    }
  }
}

///|
test "form page fills a number as a number" {
  let reply = form_page_test_ok(
    bdf_form_fill(form_page_test_text(), "{\"no\":1024,\"customer\":{\"name\":\"A\"}}", "[]", false),
  )
  let text = form_page_test_text_of(form_page_test_bytes(reply, "bdf"))
  // not "1024.0", as a number of JSON would print
  assert_true(text.contains("1024"), msg=text)
  assert_true(!text.contains("1024.0"), msg=text)
}

///|
test "form page describes a workbook with the names of its tags" {
  let reply = form_page_test_ok(bdf_form_describe(form_page_test_small_xlsx(), ""))
  assert_eq(form_page_test_string(reply, "format"), "xlsx")
  let schema = form_page_test_json(form_page_test_string(reply, "schema"))
  let properties = match schema {
    Json::Object(object) =>
      match object.get("properties") {
        Some(Json::Object(properties)) => properties
        _ => fail("the schema has no properties")
      }
    _ => fail("the schema is not an object")
  }
  assert_true(properties.contains("no"), msg="the schema has no \"no\"")
  assert_true(properties.contains("customer"), msg="the schema has no \"customer\"")
}

///|
test "form page recipe: the calls that the page shows compile and fill" {
  // the recipe of the page (how() of site/assets/form.js): Options::new takes
  // the data itself, and schema_of takes it as an optional
  let template = form_page_test_text()
  let data = form_page_test_json("{\"no\":1024,\"customer\":{\"name\":\"ACME\"}}")
  let schema = @form.schema_of(template, Some(data))
  assert_true(schema.contains("\"properties\""), msg=schema)
  let result = @form.fill(template, @form.Options::new(data=data))
  let text = form_page_test_text_of(result.bdf)
  assert_true(text.contains("ACME"), msg=text)
  let compiled = @form.compile(template, "slip.txt", @form.Options::new(data=data))
  assert_true(compiled.bdf.length() > 0)
  // the partly filled form of the recipe: the data does not give the name
  // that the fill leaves open
  let part = @form.fill(
    template,
    @form.Options::new(data=form_page_test_json("{\"no\":1024}"), open=["customer.name"]),
  )
  assert_true(part.partial is Some(_))
  let done = @form.fill(
    part.bdf,
    @form.Options::new(data=form_page_test_json("{\"customer\":{\"name\":\"ACME\"}}")),
  )
  let completed = form_page_test_text_of(done.bdf)
  assert_true(completed.contains("1024"), msg=completed)
  assert_true(completed.contains("ACME"), msg=completed)
}

// --- 生成する場合のテスト（種を決めた LCG） ---
//
// 手で並べた 8 つの値ではなく、種から作った値を何百も通す。種を決めて
// あるので、失敗した場合は同じ値をもう一度作れる。
//
//   生成器: state = (state * 75 + 74) % 65537（ZX81 の LCG、周期 65536）
//   種:     2026（読み戻し）、7（コンパイル）、99（記入途中）
//   件数:   200、100、100
//   不変条件:
//     - 記入した値の各行が、BDF のテキストから読み戻せる
//     - テンプレートのタグ（{{no}}・{{customer.name}}）は残らない
//     - コンパイルした .bdft を開き直して記入しても、値は読み戻せる
//     - 記入途中の .bdff は、残した名前を保ち、残りを記入すると
//       先に入れた値と後の値の両方が読み戻せる

///|
/// The values that a person types: letters, digits, the punctuation that a
/// template treats specially, and Japanese. No braces: a value of `{{no}}`
/// would be the tag itself, and the test of "no tag is left" could not tell
/// them apart (the unit test above covers braces).
let form_page_chars : Array[String] = [
  "a", "b", "Z", "0", "7", " ", "-", ".", ",", "(", ")", "/", ":", "|", "#", "%",
  "\"", "'", "&", "<", ">", "日", "本", "語", "あ", "ア", "漢", "字", "①", "→",
]

///|
/// A deterministic generator, so that a failing case can be made again.
struct FormPageGen {
  mut state : Int
}

///|
fn form_page_gen(seed : Int) -> FormPageGen {
  { state: seed }
}

///|
fn FormPageGen::next(gen : FormPageGen, bound : Int) -> Int {
  gen.state = (gen.state * 75 + 74) % 65537
  gen.state % bound
}

///|
/// A value of 0 to 24 characters, with no space at either end (the layout of
/// a text template trims those, and the test would not know what to expect).
fn FormPageGen::text(gen : FormPageGen) -> String {
  let len = gen.next(25)
  let mut out = ""
  for i in 0..<len {
    let mut c = form_page_chars[gen.next(form_page_chars.length())]
    if (i == 0 || i == len - 1) && c == " " {
      c = "x"
    }
    out = out + c
  }
  out
}

///|
/// The data of the text template with one value in both of its names.
fn form_page_test_data(value : String) -> String {
  Json::object({
    "no": Json::string(value),
    "customer": Json::object({ "name": Json::string(value) }),
  }).stringify()
}

///|
/// Every line of a value is in the text of the document.
fn form_page_test_holds(text : String, value : String, case : Int) -> Unit raise {
  for line in value.split("\n") {
    assert_true(
      text.contains(line),
      msg="case " + case.to_string() + ": \"" + value + "\" is not in: " + text,
    )
  }
}

///|
test "form page describes the format of a tag that entities escape" {
  let template = form_page_test_docx("{{amount | fmt:&quot;¥#,##0&quot;}}")
  let reply = form_page_test_ok(bdf_form_describe(template, ""))
  let schema = form_page_test_string(reply, "schema")
  assert_true(
    schema.contains("\"format\": \"¥#,##0\""),
    msg="the schema has no format: " + schema,
  )
  assert_true(
    !schema.contains("&quot;"),
    msg="the schema keeps the entity: " + schema,
  )
  // the compiled template keeps the same schema
  let compiled = form_page_test_ok(bdf_form_compile(template, "amounts.docx", ""))
  let bdft = form_page_test_bytes(compiled, "bdft")
  let described = form_page_test_ok(bdf_form_describe(bdft, ""))
  let compiled_schema = form_page_test_string(described, "schema")
  assert_true(
    compiled_schema.contains("\"format\": \"¥#,##0\""),
    msg="the compiled schema has no format: " + compiled_schema,
  )
}

///|
test "form page property: a value that the page types reads back from the BDF" {
  let gen = form_page_gen(2026)
  let template = form_page_test_text()
  let seen : Array[String] = []
  for i in 0..<200 {
    let value = gen.text()
    if !seen.contains(value) {
      seen.push(value)
    }
    let reply = form_page_test_ok(
      bdf_form_fill(template, form_page_test_data(value), "[]", false),
    )
    let text = form_page_test_text_of(form_page_test_bytes(reply, "bdf"))
    form_page_test_holds(text, value, i)
    // the tags of the template are gone
    assert_true(!text.contains("{{no}}"), msg="case " + i.to_string() + ": " + text)
    assert_true(!text.contains("{{customer.name}}"), msg="case " + i.to_string() + ": " + text)
  }
  // the generator makes many different values, not one repeated: a test that
  // passed on 200 empty values would prove nothing
  assert_true(
    seen.length() > 100,
    msg="the generator made " + seen.length().to_string() + " different values",
  )
}

///|
test "form page property: a compiled template fills with a value that reads back" {
  let gen = form_page_gen(7)
  let template = form_page_test_text()
  for i in 0..<100 {
    let sample = gen.text()
    let value = gen.text()
    let compiled = form_page_test_ok(
      bdf_form_compile(template, "slip.txt", form_page_test_data(sample)),
    )
    let bdft = form_page_test_bytes(compiled, "bdft")
    let described = form_page_test_ok(bdf_form_describe(bdft, ""))
    assert_eq(form_page_test_string(described, "format"), "text")
    let filled = form_page_test_ok(
      bdf_form_fill(bdft, form_page_test_data(value), "[]", false),
    )
    let text = form_page_test_text_of(form_page_test_bytes(filled, "bdf"))
    form_page_test_holds(text, value, i)
  }
}

///|
test "form page property: a partly filled form keeps what it holds and takes the rest" {
  let gen = form_page_gen(99)
  let template = form_page_test_text()
  for i in 0..<100 {
    let first = gen.text()
    let second = gen.text()
    let part = form_page_test_ok(
      bdf_form_fill(
        template,
        Json::object({ "no": Json::string(first) }).stringify(),
        "[\"customer.name\"]",
        false,
      ),
    )
    assert_eq(form_page_test_bool(part, "partial"), true)
    assert_eq(form_page_test_strings(part, "open"), ["customer.name"])
    let bdff = form_page_test_bytes(part, "bdf")
    // the page reads the partly filled form back: it says what is left
    let described = form_page_test_ok(bdf_form_describe(bdff, ""))
    assert_eq(form_page_test_strings(described, "open"), ["customer.name"])
    // and another fill completes it, keeping what the first one held
    let done = form_page_test_ok(
      bdf_form_fill(
        bdff,
        Json::object({ "customer": Json::object({ "name": Json::string(second) }) }).stringify(),
        "[]",
        false,
      ),
    )
    assert_eq(form_page_test_bool(done, "partial"), false)
    let text = form_page_test_text_of(form_page_test_bytes(done, "bdf"))
    form_page_test_holds(text, first, i)
    form_page_test_holds(text, second, i)
  }
}
