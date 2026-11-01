///|
fn ai_test_fixture(text : String) -> Bytes {
  @base64.decode(text, ignore_whitespace=true) catch {
    _ => b""
  }
}

///|
test "Illustrator kind distinguishes PDF, PostScript and other files" {
  assert_eq(kind(ai_test_fixture(ai_fixture_artboards)), "pdf")
  assert_eq(kind(ai_test_fixture(ai_fixture_legacy)), "ps")
  assert_eq(kind(ai_test_fixture(ai_fixture_nopdf)), "pdf")
  assert_eq(kind(b"%PDF-1.7\n"), "")
  assert_eq(kind(b"not a document"), "")
}

///|
test "Illustrator artboards convert through the PDF path" {
  let data = ai_test_fixture(ai_fixture_artboards)
  let result = convert(data)
  assert_eq(result.pages, 3)
  assert_eq(result.summary, "3 artboard(s)")
  let doc = @core.open_single(result.bdf)
  assert_eq(doc.manifest.views.length(), 1)
  assert_eq(doc.manifest.views[0].pages.length(), 3)
}

///|
test "PostScript based Illustrator files fail explicitly" {
  let error = try {
    ignore(convert(ai_test_fixture(ai_fixture_legacy)))
    ""
  } catch {
    AiInvalid(message) => message
  }
  assert_true(error.contains("PostScript-based Illustrator files"))
}

///|
test "Illustrator files without PDF content fail explicitly" {
  let error = try {
    ignore(convert(ai_test_fixture(ai_fixture_nopdf)))
    ""
  } catch {
    AiInvalid(message) => message
  }
  assert_true(error.contains("saved without PDF content"))
}

///|
test "Non-Illustrator data is rejected" {
  let error = try {
    ignore(convert(b"not an illustrator file"))
    ""
  } catch {
    AiInvalid(message) => message
  }
  assert_eq(error, "ai: not an Illustrator file")
}
