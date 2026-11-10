///|
// Regression tests of how a template is found: the samples that detection
// reads are cut at 1024 bytes and at MAX_TEXT_HEAD, and a character of UTF-8
// that a cut splits must not make a text template a file that is not one.

///|
/// A string of `count` copies of `unit`.
fn form_test_repeat(unit : String, count : Int) -> String {
  let builder = StringBuilder()
  for _ in 0..<count {
    builder.write_string(unit)
  }
  builder.to_string()
}

///|
test "form reads a text template whose character the 1024-byte sample cuts" {
  // 341 characters of three bytes end at byte 1023, so the 1024-byte sample
  // cuts the 342nd
  let tpl = @utf8.encode(form_test_repeat("あ", 342) + "{{name}}\n")
  assert_eq(tpl.length(), 342 * 3 + 9)
  let names = fields(tpl).map(fn(field) { field.name }).join(",")
  assert_eq(names, "name")
  let result = fill(
    tpl,
    Options::new(data=form_test_json("{\"name\":\"ACME\"}")),
  )
  assert_eq(result.format, FORMAT_TEXT)
  let rendered = form_test_text(result.bdf)
  assert_true(rendered.contains("ACME"), msg=rendered)
}

///|
test "form reads a text template whose character the 1 MiB sample cuts" {
  // the tag is in the sample, and the character at byte MAX_TEXT_HEAD is cut
  let tpl = @utf8.encode("{{name}}\n" + form_test_repeat("あ", 349523))
  assert_true(tpl.length() > MAX_TEXT_HEAD, msg="a template larger than the sample")
  let (format, sample) = describe(tpl)
  assert_eq(format, FORMAT_TEXT)
  assert_true(sample is None, msg="a template of text has no sample")
}

///|
test "form reads a tagged text template" {
  let tpl = @utf8.encode("No: {{no}}\n")
  assert_eq(fields(tpl).map(fn(field) { field.name }).join(","), "no")
  let result = fill(tpl, Options::new(data=form_test_json("{\"no\":\"A-1\"}")))
  assert_eq(result.format, FORMAT_TEXT)
  let rendered = form_test_text(result.bdf)
  assert_true(rendered.contains("No: A-1"), msg=rendered)
}

///|
test "form refuses text that is not UTF-8" {
  let message = form_test_fill_error(b"\xff\xfe{{name}}", Options::new())
  assert_true(message.contains("is not an Excel workbook"), msg=message)
  let cut = form_test_fill_error(b"\x80\x80{{name}}", Options::new())
  assert_true(cut.contains("is not an Excel workbook"), msg=cut)
}

///|
test "form refuses a text template that is not UTF-8 after its sample" {
  // the sample is text with a tag, and the byte that is not UTF-8 is past it:
  // the fill reads the whole template and refuses it
  let tpl = @utf8.encode("{{name}}\n" + form_test_repeat("a", 1048600)) + b"\xff"
  assert_true(tpl.length() > MAX_TEXT_HEAD, msg="a template larger than the sample")
  let message = form_test_fill_error(
    tpl,
    Options::new(data=form_test_json("{\"name\":\"x\"}")),
  )
  assert_true(message.contains("not text of UTF-8"), msg=message)
}

///|
test "form refuses text with a NUL byte" {
  let message = form_test_fill_error(
    @utf8.encode("a\u{0}{{name}}"),
    Options::new(),
  )
  assert_true(message.contains("is not an Excel workbook"), msg=message)
}

///|
test "form reads a ZIP as a package, not as text" {
  // the head of the package is text with a tag, and is still a package
  let zipped = @ooxml.stored_zip([("hello.txt", @utf8.encode("{{name}}"))])
  let message = form_test_fill_error(zipped, Options::new())
  assert_true(message.contains("is not an Excel workbook"), msg=message)
}

///|
test "form reads a PDF as a PDF" {
  let (format, _) = describe(form_test_contract_pdf())
  assert_eq(format, FORMAT_PDF)
}
