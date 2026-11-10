///|
// Focused repros of the review findings 6, 7, 10, 11, 12 and 14. Each test
// asserts the behaviour of upstream (form/*.go and converter/*) and fails
// with the actual value when the port differs.

///|
fn details_with_template(bdf : Bytes, template : Template) -> Bytes raise {
  let document = @core.open_single(bdf)
  let manifest = @core.manifest_json(bdf)
  let meta = match manifest {
    Json::Object(object) =>
      match object.get("meta") {
        Some(value) => value
        None => Json::empty_object()
      }
    _ => Json::empty_object()
  }
  let writer = @core.DocumentWriter::new(meta~)
  for part in document.manifest.parts {
    if part.kind == PART_TEMPLATE {
      continue
    }
    ignore(writer.add_part(part.kind, document.part(part.hash)))
  }
  match manifest {
    Json::Object(object) => {
      match object.get("views") {
        Some(Json::Array(views)) =>
          for view in views {
            writer.add_view(view)
          }
        _ => ()
      }
      match object.get("tables") {
        Some(Json::Array(tables)) =>
          for table in tables {
            writer.add_table(table)
          }
        _ => ()
      }
    }
    _ => ()
  }
  ignore(
    writer.add_part(
      PART_TEMPLATE,
      @utf8.encode(template.to_json().stringify()),
    ),
  )
  writer.write_single()
}

///|
fn details_part_bytes(bdf : Bytes, kind : String) -> Bytes? raise {
  let document = @core.open_single(bdf)
  for part in document.manifest.parts {
    if part.kind == kind {
      return Some(document.part(part.hash))
    }
  }
  None
}

///|
fn details_part(bdf : Bytes, kind : String) -> Json? raise {
  let document = @core.open_single(bdf)
  for part in document.manifest.parts {
    if part.kind == kind {
      let data = document.part(part.hash)
      return Some(@json.parse(@utf8.decode_lossy(data[:])))
    }
  }
  None
}

///|
test "details text number format" {
  let tpl = @utf8.encode("N: {{n | fmt:\"#,##0.0\"}}\n")
  let result = fill(tpl, Options::new(data=form_test_json("{\"n\":1234.5}")))
  let text = form_test_text(result.bdf)
  assert_true(text.contains("1,234.5"), msg=text)
}

///|
test "details text date format" {
  let tpl = @utf8.encode("D: {{d | fmt:\"yyyy-mm-dd\"}}\n")
  let result = fill(
    tpl,
    Options::new(data=form_test_json("{\"d\":\"2024-01-02\"}")),
  )
  let text = form_test_text(result.bdf)
  assert_true(text.contains("2024-01-02"), msg=text)
}

///|
test "details text text section" {
  let tpl = @utf8.encode("S: {{s | fmt:\"@!\"}}\n")
  let result = fill(tpl, Options::new(data=form_test_json("{\"s\":\"abc\"}")))
  let text = form_test_text(result.bdf)
  assert_true(text.contains("abc!"), msg=text)
}

///|
test "details text warnings" {
  let tpl = @utf8.encode("N: {{no}}\n")
  let result = fill(tpl, Options::new(data=form_test_json("{}")))
  let told = result.warnings.join("\n")
  assert_true(told.contains("line 1: the data has no \"no\""), msg=told)
}

///|
test "details pdf pushbutton" {
  let tpl = form_test_pdf([
    "<< /Type /Catalog /Pages 2 0 R /AcroForm << /Fields [4 0 R 5 0 R] >> >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 100] /Annots [4 0 R 5 0 R] >>",
    "<< /Type /Annot /Subtype /Widget /FT /Tx /T (name) /Rect [10 20 100 40] /F 4 /P 3 0 R /DA (/Helv 11 Tf 0 g) /V () >>",
    "<< /Type /Annot /Subtype /Widget /FT /Btn /Ff 65536 /T (press) /Rect [10 50 100 70] /F 4 /P 3 0 R /DA (/Helv 11 Tf 0 g) /V () >>",
  ])
  let fields = @pdf.inspect(tpl)
  let names = fields.map(fn(field) { field.name }).join(",")
  assert_eq(names, "name")
}

///|
test "details pdf field at" {
  let tpl = form_test_pdf([
    "<< /Type /Catalog /Pages 2 0 R /AcroForm << /Fields [4 0 R] >> >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 100] /Annots [4 0 R] >>",
    "<< /Type /Annot /Subtype /Widget /FT /Tx /T (name) /Rect [10 20 100 40] /F 4 /P 3 0 R /DA (/Helv 11 Tf 0 g) /V () >>",
  ])
  let fields = @pdf.inspect(tpl)
  assert_eq(fields[0].at.join(","), "page 1")
}

///|
test "details pdf field at second page" {
  let tpl = form_test_pdf([
    "<< /Type /Catalog /Pages 2 0 R /AcroForm << /Fields [6 0 R] >> >>",
    "<< /Type /Pages /Kids [3 0 R 5 0 R] /Count 2 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 100] /Annots [] >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 100] /Annots [6 0 R] >>",
    "<< /Type /Annot /Subtype /Widget /FT /Tx /T (name) /Rect [10 20 100 40] /F 4 /P 5 0 R /DA (/Helv 11 Tf 0 g) /V () >>",
  ])
  let fields = @pdf.inspect(tpl)
  assert_eq(fields[0].at.join(","), "page 2")
}

///|
test "details pdf strict checkbox" {
  let tpl = form_test_pdf([
    "<< /Type /Catalog /Pages 2 0 R /AcroForm << /Fields [4 0 R] >> >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 100] /Annots [4 0 R] >>",
    "<< /Type /Annot /Subtype /Widget /FT /Btn /T (agree) /Rect [10 20 100 40] /F 4 /P 3 0 R /DA (/Helv 11 Tf 0 g) /V /Off >>",
  ])
  let message = try {
    ignore(@pdf.fill_pdf(tpl, @utf8.encode("{}"), strict=true))
    ""
  } catch {
    @pdf.PdfFillError(message) => message
  }
  assert_true(message.contains("the data has no \"agree\""), msg=message)
}

///|
test "details pdf strict radio" {
  let tpl = form_test_pdf([
    "<< /Type /Catalog /Pages 2 0 R /AcroForm << /Fields [4 0 R] >> >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 100] /Annots [4 0 R] >>",
    "<< /Type /Annot /Subtype /Widget /FT /Btn /Ff 32768 /T (plan) /Rect [10 20 100 40] /F 4 /P 3 0 R /DA (/Helv 11 Tf 0 g) /V /Off /Opt [(basic) (pro)] >>",
  ])
  let message = try {
    ignore(@pdf.fill_pdf(tpl, @utf8.encode("{}"), strict=true))
    ""
  } catch {
    @pdf.PdfFillError(message) => message
  }
  assert_true(message.contains("the data has no \"plan\""), msg=message)
}

///|
test "details signed completion" {
  let compiled = compile(form_test_small_xlsx(), "form", Options::new())
  let first = fill(
    compiled.bdf,
    Options::new(data=form_test_json("{\"no\":\"A-1\"}"), open=["customer.name"]),
  )
  let partial = match first.partial {
    Some(value) => value
    None => fail("the fill is not partly filled")
  }
  let signed : Template = { ..partial, signed: ["AAAA"] }
  let bdf = details_with_template(first.bdf, signed)
  let done = fill(
    bdf,
    Options::new(data=form_test_json("{\"customer\":{\"name\":\"ACME\"}}")),
  )
  let record = match details_part(done.bdf, PART_FILL) {
    Some(value) => value
    None => fail("the completed form has no record of its values")
  }
  let object = match record {
    Json::Object(object) => object
    _ => fail("the record is not an object")
  }
  assert_eq(object["version"].stringify(), "1")
  assert_eq(object["format"].stringify(), "\"xlsx\"")
  assert_eq(
    object["source"].stringify(),
    "\"" + @core.hash_of(form_test_small_xlsx()) + "\"",
  )
  let description = match details_part_bytes(compiled.bdf, PART_TEMPLATE) {
    Some(value) => value
    None => fail("the compiled template has no description")
  }
  assert_eq(
    object["from"].stringify(),
    "\"" + @core.sha256_hex(description) + "\"",
  )
  let filled = object["filled"].stringify()
  assert_true(filled.contains("\"ACME\""), msg=filled)
  assert_true(filled.contains("\"A-1\""), msg=filled)
  assert_true(object["signed"].stringify().contains("AAAA"))
}
