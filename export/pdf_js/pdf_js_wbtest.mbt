///|
fn pdf_js_view(
  writer : @core.DocumentWriter,
  id : String,
  count : Int,
  text : String,
) -> Unit raise {
  let builder = @core.ObjectBuilder::new()
  let font = builder.add_font({
    hash: None,
    family: "Example",
    weight: 400,
    style: 0,
  })
  builder.font(font, 12.0F)
  if text != "" {
    builder.fill_text(text, 20.0F, 40.0F, 60.0F)
  }
  let object_hash = writer.add_part("obj", builder.encode())
  let pages : Array[Json] = []
  for _ in 0..<count {
    pages.push(
      Json::object({
        "w": Json::number(200.0),
        "h": Json::number(200.0),
        "layers": Json::array([
          Json::object({ "role": Json::string(""), "obj": Json::string(object_hash) }),
        ]),
      }),
    )
  }
  writer.add_view(
    Json::object({
      "id": Json::string(id),
      "kind": Json::string("fixed"),
      "pages": Json::array(pages),
    }),
  )
}

///|
/// A document of a view per entry: its id, its page count and the text
/// that its pages' object draws.
fn pdf_js_document(views : Array[(String, Int, String)]) -> Bytes raise {
  let writer = @core.DocumentWriter::new()
  for view in views {
    pdf_js_view(writer, view.0, view.1, view.2)
  }
  writer.write_single()
}

///|
fn pdf_js_report_ok(
  input : Bytes,
  options : String,
  fallback : Bytes,
) -> PdfJsReport {
  bdf_pdf_export(input, options, fallback)
}

///|
fn same_bytes(left : Bytes, right : Bytes) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for index in 0..<left.length() {
    if left[index] != right[index] {
      return false
    }
  }
  true
}

///|
fn pdf_js_has_warning(warnings : FixedArray[String], text : String) -> Bool {
  for warning in warnings {
    if warning == text {
      return true
    }
  }
  false
}

///|
fn pdf_js_warns_font(warnings : FixedArray[String]) -> Bool {
  for warning in warnings {
    if warning.contains("fallback font") {
      return true
    }
  }
  false
}

///|
fn pdf_js_lists(values : Array[String], value : String) -> Bool {
  for item in values {
    if item == value {
      return true
    }
  }
  false
}

///|
fn pdf_js_warnings_match(
  left : FixedArray[String],
  right : FixedArray[String],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for index in 0..<left.length() {
    if left[index] != right[index] {
      return false
    }
  }
  true
}

test "pdf_js writes a one-page document" {
  let input = pdf_js_document([("page1", 1, "Hello PDF")])
  let report = pdf_js_report_ok(input, "{}", b"")
  assert_true(report.ok)
  assert_eq(report.pages, 1)
  assert_true(report.fonts >= 1)
  assert_true(report.pdf.has_prefix(b"%PDF"))
  assert_true(report.pdf.to_string().contains("%%EOF"))
  assert_eq(report.warnings.length(), 0)
}

test "pdf_js keeps a deterministic fresh PDF per call" {
  let input = pdf_js_document([("page1", 2, "Hello PDF")])
  let before = pdf_js_report_ok(input, "{}", b"")
  let after = pdf_js_report_ok(input, "{}", b"")
  assert_true(before.ok && after.ok)
  assert_true(same_bytes(before.pdf, after.pdf))
  assert_true(pdf_js_warnings_match(before.warnings, after.warnings))
  assert_eq(before.pages, after.pages)
  assert_eq(before.fonts, after.fonts)
  assert_eq(before.error, "")
}

test "pdf_js does not modify the input" {
  let input = pdf_js_document([("page1", 1, "Hello PDF")])
  let before = @base64.encode(input)
  let report = pdf_js_report_ok(input, "{}", b"")
  assert_true(report.ok)
  assert_eq(@base64.encode(input), before)
  assert_false(same_bytes(report.pdf, input))
}

test "pdf_js writes only the selected views" {
  let input = pdf_js_document([("a", 2, "Hello"), ("b", 3, "Hello")])
  let selected = pdf_js_report_ok(input, "{\"views\":[\"b\"]}", b"")
  assert_true(selected.ok)
  assert_eq(selected.pages, 3)
  let both = pdf_js_report_ok(input, "{\"views\":[\"a\",\"b\"]}", b"")
  assert_true(both.ok)
  assert_eq(both.pages, 5)
  let every = pdf_js_report_ok(input, "{}", b"")
  assert_true(every.ok)
  assert_eq(every.pages, 5)
}

test "pdf_js passes the writer's warnings through unchanged" {
  let input = pdf_js_document([("a", 1, "Hello"), ("empty", 0, "")])
  let report = pdf_js_report_ok(input, "{\"tagged\":true}", b"")
  assert_true(report.ok)
  assert_eq(report.pages, 1)
  let mut saw_tagged = false
  let mut saw_empty = false
  for warning in report.warnings {
    if warning == "tagged PDF structure is not written yet" {
      saw_tagged = true
    }
    if warning == "view empty has no pages" {
      saw_empty = true
    }
  }
  assert_true(saw_tagged)
  assert_true(saw_empty)
}

test "pdf_js rejects an empty input" {
  let report = pdf_js_report_ok(b"", "{}", b"")
  assert_false(report.ok)
  assert_true(report.error.contains("empty"))
  assert_eq(report.pages, 0)
}

test "pdf_js rejects a broken BDF" {
  let report = pdf_js_report_ok(b"this is not a BDF document at all...", "{}", b"")
  assert_false(report.ok)
  assert_true(report.error.contains("could not be read"))
  assert_eq(report.pdf.length(), 0)
}

test "pdf_js rejects a view the document does not have" {
  let input = pdf_js_document([("a", 1, "Hello")])
  let report = pdf_js_report_ok(input, "{\"views\":[\"a\",\"nope\"]}", b"")
  assert_false(report.ok)
  assert_true(report.error.contains("no view named \"nope\""))
}

test "pdf_js rejects a selection of views that hold no page" {
  let input = pdf_js_document([("sheet", 0, "")])
  let report = pdf_js_report_ok(input, "{\"views\":[\"sheet\"]}", b"")
  assert_false(report.ok)
  assert_true(report.error.contains("no page"))
}

test "pdf_js rejects options of the wrong shape" {
  let input = pdf_js_document([("a", 1, "Hello")])
  for options in [
      "[]",
      "{ not json",
      "{\"views\":\"a\"}",
      "{\"views\":[3]}",
      "{\"tagged\":\"yes\"}",
      "{\"compress\":1}",
    ] {
    let report = pdf_js_report_ok(input, options, b"")
    assert_false(report.ok)
    assert_eq(report.pdf.length(), 0)
    assert_eq(report.pages, 0)
  }
  let empty_options = pdf_js_report_ok(input, "   ", b"")
  assert_true(empty_options.ok)
}

test "pdf_js warns when the fallback font cannot be read" {
  let input = pdf_js_document([("a", 1, "ようこそ")])
  let broken : Bytes = b"not really a font program"
  let report = pdf_js_report_ok(input, "{}", broken)
  assert_true(report.ok)
  let mut saw_font_warning = false
  for warning in report.warnings {
    if warning.contains("fallback font") {
      saw_font_warning = true
    }
  }
  assert_true(saw_font_warning)
}

test "pdf_js stays quiet without a fallback font" {
  // a document whose text owes no font gets no warning about fonts
  let input = pdf_js_document([("a", 1, "Hello PDF")])
  let report = pdf_js_report_ok(input, "{}", b"")
  assert_true(report.ok)
  for warning in report.warnings {
    assert_false(warning.contains("fallback font"))
  }
  // but text beyond the PDF standard font is not hidden behind a "?":
  // the writer's warning of the silent loss travels to the caller too
  let japanese = pdf_js_document([("a", 1, "日本語")])
  let warned = pdf_js_report_ok(japanese, "{}", b"")
  assert_true(warned.ok)
  assert_true(
    pdf_js_has_warning(
      warned.warnings,
      "text without a font of its own is drawn with the PDF standard font, which has no glyph for: 日本語",
    ),
  )
}

///|
/// The page counts of the document the property-based check draws options
/// over: a two-page view, a one-page view with Japanese text and a sheet
/// view with no page.
let pdf_js_pages : Array[(String, Int)] = [
  ("v1", 2),
  ("v2", 1),
  ("sheet", 0),
]

///|
/// Deterministic property-based check of the bridge's contract: a seeded
/// LCG draws option combinations over a fixed document, and every draw
/// must keep the invariants — the report agrees with whether the
/// requested views exist and hold a page, the page count is the sum of
/// the requested views' pages, the PDF is written only on success, and
/// the same draw repeats identically. The garbage font draws must warn:
/// the writer's font failures surface instead of a silent success.
test "pdf_js keeps its contract over drawn options" {
  let input = pdf_js_document([
    ("v1", 2, "Hello PDF"),
    ("v2", 1, "ようこそ"),
    ("sheet", 0, ""),
  ])
  fn draw(state : Int64) -> Int64 {
    (state * 6364136223846793005L + 1442695040888963407L) &
    0x7fffffffffffffffL
  }
  fn bit(state : Int64, shift : Int) -> Bool {
    ((state >> shift).to_int() & 1) == 1
  }
  let mut state : Int64 = 0x2545F4914F6CDD1DL
  for _ in 0..<25 {
    state = draw(state)
    let views : Array[String] = []
    let mut expected : Int = 0
    let mut valid = true
    for index, view in pdf_js_pages {
      if bit(state, index * 2) {
        views.push(view.0)
        expected += view.1
      }
    }
    if bit(state, 27) {
      views.push("missing")
      valid = false
    }
    if views.length() == 0 {
      expected = 3
    }
    let tagged = bit(state, 28)
    let garbage_font = bit(state, 29)
    let options = Json::object({
      "views": Json::array(views.map(view => Json::string(view))),
      "tagged": Json::boolean(tagged),
    }).stringify()
    let fallback : Bytes = if garbage_font { b"not a font" } else { b"" }
    let report = pdf_js_report_ok(input, options, fallback)
    let ok_expected = valid && expected > 0
    assert_eq(report.ok, ok_expected)
    let saw_tagged = pdf_js_has_warning(
        report.warnings,
        "tagged PDF structure is not written yet",
      )
    let saw_empty_view = pdf_js_has_warning(
        report.warnings,
        "view sheet has no pages",
      )
    let saw_font = pdf_js_warns_font(report.warnings)
    let sheet_requested = views.length() == 0 ||
        pdf_js_lists(views, "sheet")
    let text_requested = views.length() == 0 ||
        pdf_js_lists(views, "v1") ||
        pdf_js_lists(views, "v2")
    if ok_expected {
      assert_eq(report.pages, expected)
      assert_true(report.pdf.has_prefix(b"%PDF"))
      assert_eq(report.error, "")
      assert_eq(saw_tagged, tagged)
      assert_eq(saw_empty_view, sheet_requested)
      assert_eq(saw_font, garbage_font && text_requested)
    } else {
      assert_eq(report.pdf.length(), 0)
      assert_eq(report.pages, 0)
      assert_true(report.error.length() > 0)
      assert_eq(report.warnings.length(), 0)
    }
    // determinism: the same draw repeats with the very same report
    let repeat = pdf_js_report_ok(input, options, fallback)
    assert_eq(repeat.ok, report.ok)
    assert_true(same_bytes(repeat.pdf, report.pdf))
    assert_true(pdf_js_warnings_match(repeat.warnings, report.warnings))
    assert_eq(repeat.pages, report.pages)
    assert_eq(repeat.fonts, report.fonts)
  }
}
