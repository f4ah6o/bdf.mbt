///|
// Regression tests of partly filled forms, adapted from form/partial_test.go
// of upstream: a fill that leaves names of the data open makes a .bdff of the
// values it holds, which another fill completes into the form that the
// template filled with all of the data at once is.

///|
fn form_test_pdf_pad(value : Int) -> String {
  let text = value.to_string()
  let mut out = ""
  for _ in 0..<(10 - text.length()) {
    out = out + "0"
  }
  out + text
}

///|
/// A classic PDF of the objects, with the cross-reference table that the
/// offsets of the objects ask for.
fn form_test_pdf(objects : Array[String]) -> Bytes {
  let mut out = "%PDF-1.4\n"
  let offsets : Array[Int] = []
  for i, body in objects {
    offsets.push(out.length())
    out = out + (i + 1).to_string() + " 0 obj\n" + body + "\nendobj\n"
  }
  let xref = out.length()
  out = out +
    "xref\n0 " +
    (objects.length() + 1).to_string() +
    "\n0000000000 65535 f \n"
  for offset in offsets {
    out = out + form_test_pdf_pad(offset) + " 00000 n \n"
  }
  out = out +
    "trailer\n<< /Size " +
    (objects.length() + 1).to_string() +
    " /Root 1 0 R >>\nstartxref\n" +
    xref.to_string() +
    "\n%%EOF\n"
  @utf8.encode(out)
}

///|
/// A contract of two parties, each with a name to fill in.
fn form_test_contract_pdf() -> Bytes {
  form_test_pdf([
    "<< /Type /Catalog /Pages 2 0 R /AcroForm << /Fields [4 0 R 5 0 R] >> >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 100] /Annots [4 0 R 5 0 R] >>",
    "<< /Type /Annot /Subtype /Widget /FT /Tx /T (party_a) /TU (Name of party A) /Rect [10 20 100 40] /F 4 /P 3 0 R /DA (/Helv 11 Tf 0 g) /V () >>",
    "<< /Type /Annot /Subtype /Widget /FT /Tx /T (party_b) /TU (Name of party B) /Rect [10 50 100 70] /F 4 /P 3 0 R /DA (/Helv 11 Tf 0 g) /V () >>",
  ])
}

///|
test "form drops the warnings of the names it leaves open" {
  let warnings = [
    "the data has no \"customer.name\"; give it (null for none), or leave it open",
    "the data has no \"memo\"; give it (null for none), or leave it open",
    "the data has no \"no\"; give it (null for none), or leave it open",
  ]
  let kept = without_open(warnings, ["customer.name", "memo"])
  assert_eq(kept.length(), 1)
  assert_true(kept[0].contains("\"no\""), msg=kept[0])
}

///|
test "form fills a workbook in two steps" {
  let tpl = form_test_fixed_xlsx()
  let compiled = compile(tpl, "form-fixed", Options::new())
  let bdft = compiled.bdf
  let direct = fill(bdft, Options::new(data=form_test_fixed_data()))
  assert_true(direct.partial is None, msg="a complete fill is not partly filled")

  // the sender fills what is theirs
  let mine = form_test_json(
    "{\"no\":1024,\"date\":\"2026-10-13\",\"amount\":12000,\"total\":13200,\"paid\":true,\"photo\":\"stamp.png\",\"url\":\"https://example.com/c/1024\",\"jan\":\"4901234567894\",\"tags\":[\"a\",\"b\",\"c\"],\"missing\":\"\"}",
  )
  let res = fill(bdft, Options::new(data=mine, open=["customer.name", "memo"]))
  for warning in res.warnings {
    assert_true(
      !warning.contains("customer.name") && !warning.contains("memo"),
      msg=warning,
    )
  }
  let partial = match res.partial {
    Some(partial) => partial
    None => fail("the fill is not partly filled")
  }
  assert_eq(partial.open.join(","), "customer.name,memo")
  assert_true(partial.from != "", msg="the compiled template it is from")
  assert_eq(partial.name, "form-fixed")
  assert_eq(partial.format, FORMAT_XLSX)
  let filled = match partial.filled {
    Some(Json::Object(filled)) => filled
    _ => fail("the form holds no values")
  }
  assert_true(
    !filled.contains("customer"),
    msg="the form holds a name it leaves open",
  )
  let text = form_test_text(res.bdf)
  assert_true(text.contains("1024"), msg=text)
  assert_true(!text.contains("ACME"), msg=text)
  assert_true(!text.contains("Thank you"), msg=text)

  // the schema asks for what is left to fill in
  let schema = match partial.schema {
    Some(value) => value
    None => fail("the form has no schema")
  }
  let properties = form_test_properties(schema)
  assert_eq(properties.keys().to_array().length(), 2)
  let customer = match properties.get("customer") {
    Some(value) => form_test_properties(value)
    None => fail("the schema has no customer")
  }
  assert_eq(customer.keys().to_array().length(), 1)
  assert_true(customer.contains("name"), msg="customer.name")

  let bdff = res.bdf
  let open_schema = schema_of(bdff, None)
  assert_true(!open_schema.contains("\"jan\""), msg=open_schema)
  assert_true(open_schema.contains("\"memo\""), msg=open_schema)
  let refused = form_test_compile_error(bdff, "", Options::new())
  assert_true(refused.contains("partly filled"), msg=refused)

  // the other party fills in the rest
  let theirs = form_test_json(
    "{\"customer\":{\"name\":\"ACME\"},\"memo\":\"Thank you.\\nSecond line\"}",
  )
  let done = fill(bdff, Options::new(data=theirs))
  assert_true(done.partial is None, msg="the completed form is not partly filled")
  assert_true(
    done.bdf == direct.bdf,
    msg="the completed form is not the form filled at once",
  )

  // in two steps: a partly filled form of a partly filled form
  let step = fill(
    bdff,
    Options::new(
      data=form_test_json("{\"memo\":\"Thank you.\\nSecond line\"}"),
      open=[OPEN_ALL],
    ),
  )
  let step_partial = match step.partial {
    Some(value) => value
    None => fail("the second step is not partly filled")
  }
  assert_eq(step_partial.open.join(","), "customer.name")
  assert_eq(step_partial.from, partial.from)
  let last = fill(
    step.bdf,
    Options::new(data=form_test_json("{\"customer\":{\"name\":\"ACME\"}}")),
  )
  assert_true(
    last.bdf == direct.bdf,
    msg="the form completed in steps is not the form filled at once",
  )

  // the data may give only the names that the form leaves open
  for c in [
    (
      "{\"no\":1,\"customer\":{\"name\":\"x\"},\"memo\":\"x\"}",
      [],
      "\"no\" is filled already",
    ),
    (
      "{\"other\":1,\"customer\":{\"name\":\"x\"},\"memo\":\"x\"}",
      [],
      "does not leave \"other\" open",
    ),
    (
      "{\"memo\":\"x\"}",
      [],
      "has no \"customer.name\", which the form leaves open",
    ),
    ("{\"memo\":\"x\"}", ["no"], "\"no\" is filled already"),
    (
      "{\"customer\":\"x\",\"memo\":\"x\"}",
      [],
      "\"customer\" of the data is not an object",
    ),
    (
      "{\"memo\":\"x\"}",
      ["customer.name", "memo"],
      "gives \"memo\", which it leaves open",
    ),
  ] {
    let message = form_test_fill_error(
      bdff,
      Options::new(data=form_test_json(c.0), open=c.1),
    )
    assert_true(message.contains(c.2), msg=c.0 + " -> " + message)
  }
}

///|
test "form leaves open the names of a list" {
  let rows =
    form_test_row(1, form_test_cell("A1", "{{no}}")) +
    form_test_row(2, form_test_cell("A2", "{{customer}}")) +
    form_test_row(3, form_test_cell("A3", "{{note}}")) +
    form_test_row(
      4,
      form_test_cell("A4", "{{#items}}{{name}} {{qty}} {{price}}{{/items}}"),
    )
  let tpl = form_test_xlsx(rows)
  let all = "{\"no\":\"A-7\",\"customer\":\"ACME\",\"note\":\"Thank you.\",\"items\":[{\"name\":\"Item 01\",\"qty\":2,\"price\":100}]}"
  for c in [
    (all, ["items.name"], "\"items.name\" is not a name of the data"),
    (all, ["nothing"], "\"nothing\" is not a name"),
    (all, ["items"], "gives \"items\", which it leaves open"),
    (
      "{\"customer\":\"ACME\",\"note\":\"Thank you.\"}",
      ["items"],
      "has no \"no\"; give it",
    ),
  ] {
    let message = form_test_fill_error(
      tpl,
      Options::new(data=form_test_json(c.0), open=c.1),
    )
    assert_true(message.contains(c.2), msg=c.0 + " -> " + message)
  }
  let res = fill(
    tpl,
    Options::new(
      data=form_test_json(
        "{\"no\":\"A-7\",\"customer\":\"ACME\",\"note\":\"Thank you.\"}",
      ),
      open=["items"],
    ),
  )
  let partial = match res.partial {
    Some(value) => value
    None => fail("the fill is not partly filled")
  }
  assert_eq(partial.from, "")
  assert_eq(partial.format, FORMAT_XLSX)
  assert_eq(partial.open.join(","), "items")
  // a partly filled form of a partly filled form of a template has no
  // compiled template either
  let again = fill(
    res.bdf,
    Options::new(data=form_test_json("{}"), open=["items"]),
  )
  let again_partial = match again.partial {
    Some(value) => value
    None => fail("the second step is not partly filled")
  }
  assert_eq(again_partial.from, "")
}

///|
test "form fills a PDF in two steps" {
  let tpl = form_test_contract_pdf()
  let compiled = compile(tpl, "contract", Options::new())
  assert_eq(compiled.template.format, FORMAT_PDF)
  let direct = fill(
    tpl,
    Options::new(
      data=form_test_json("{\"party_a\":\"Taro Yamada\",\"party_b\":\"ACME\"}"),
    ),
  )
  assert_true(direct.partial is None, msg="a complete fill")
  let res = fill(
    tpl,
    Options::new(
      data=form_test_json("{\"party_a\":\"Taro Yamada\"}"),
      open=["party_b"],
    ),
  )
  let partial = match res.partial {
    Some(value) => value
    None => fail("the fill is not partly filled")
  }
  assert_eq(partial.open.join(","), "party_b")
  assert_eq(partial.format, FORMAT_PDF)
  let schema = match partial.schema {
    Some(value) => value
    None => fail("the form has no schema")
  }
  let properties = form_test_properties(schema)
  assert_true(properties.contains("party_b"), msg=schema.stringify())
  assert_true(!properties.contains("party_a"), msg=schema.stringify())
  let done = fill(
    res.bdf,
    Options::new(data=form_test_json("{\"party_b\":\"ACME\"}")),
  )
  assert_true(done.partial is None, msg="the completed form")
  assert_true(
    done.bdf == direct.bdf,
    msg="the completed contract is not the contract filled at once",
  )
  // the values are written into the PDF, which the converter reads as a
  // document of pages: it does not draw the values into the page content
  let held = match partial.filled {
    Some(Json::Object(held)) => held
    _ => fail("the form holds no values")
  }
  assert_true(held.contains("party_a"), msg="the value of party A")
  assert_true(!held.contains("party_b"), msg="a name it leaves open")
  let open_schema = schema_of(res.bdf, None)
  assert_true(open_schema.contains("\"party_b\""), msg=open_schema)
  assert_true(!open_schema.contains("\"party_a\""), msg=open_schema)
}

///|
test "form fills a text template in two steps" {
  let tpl = @utf8.encode("No: {{no}}\nName: {{customer.name}}\nMemo: {{memo}}\n")
  let direct = fill(
    tpl,
    Options::new(
      data=form_test_json(
        "{\"no\":\"A-1\",\"customer\":{\"name\":\"ACME\"},\"memo\":\"Hello\"}",
      ),
    ),
  )
  assert_true(direct.partial is None, msg="a complete fill")
  let res = fill(
    tpl,
    Options::new(
      data=form_test_json("{\"no\":\"A-1\"}"),
      open=["customer.name", "memo"],
    ),
  )
  let partial = match res.partial {
    Some(value) => value
    None => fail("the fill is not partly filled")
  }
  assert_eq(partial.open.join(","), "customer.name,memo")
  assert_eq(partial.format, FORMAT_TEXT)
  let text = form_test_text(res.bdf)
  assert_true(text.contains("No: A-1"), msg=text)
  assert_true(!text.contains("ACME"), msg=text)
  let done = fill(
    res.bdf,
    Options::new(
      data=form_test_json("{\"customer\":{\"name\":\"ACME\"},\"memo\":\"Hello\"}"),
    ),
  )
  assert_true(done.partial is None, msg="the completed form")
  assert_true(
    done.bdf == direct.bdf,
    msg="the completed note is not the note filled at once",
  )
}

///|
test "form fills a Word document in two steps" {
  let tpl = form_test_docx(["{{no}}", "{{customer.name}}", "{{memo}}"])
  let direct = fill(
    tpl,
    Options::new(
      data=form_test_json(
        "{\"no\":\"A-1\",\"customer\":{\"name\":\"ACME\"},\"memo\":\"Hello\"}",
      ),
    ),
  )
  assert_true(direct.partial is None, msg="a complete fill")
  let res = fill(
    tpl,
    Options::new(
      data=form_test_json("{\"no\":\"A-1\"}"),
      open=["customer.name", "memo"],
    ),
  )
  let partial = match res.partial {
    Some(value) => value
    None => fail("the fill is not partly filled")
  }
  assert_eq(partial.open.join(","), "customer.name,memo")
  assert_eq(partial.format, FORMAT_DOCX)
  let text = form_test_text(res.bdf)
  assert_true(text.contains("A-1"), msg=text)
  assert_true(!text.contains("ACME"), msg=text)
  let done = fill(
    res.bdf,
    Options::new(
      data=form_test_json("{\"customer\":{\"name\":\"ACME\"},\"memo\":\"Hello\"}"),
    ),
  )
  assert_true(done.partial is None, msg="the completed form")
  assert_true(
    done.bdf == direct.bdf,
    msg="the completed letter is not the letter filled at once",
  )
  let done_text = form_test_text(done.bdf)
  assert_true(done_text.contains("ACME"), msg=done_text)
  assert_true(done_text.contains("Hello"), msg=done_text)
}
