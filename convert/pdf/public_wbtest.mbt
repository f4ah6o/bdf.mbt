///|
test "PDF public API detects and converts a page" {
  let data = pdf_test_pdf([
    b"<< /Type /Catalog /Pages 2 0 R >>",
    b"<< /Type /Pages /Kids [3 0 R] /Count 1 /MediaBox [0 0 200 200] >>",
    b"<< /Type /Page /Parent 2 0 R /Contents 4 0 R >>",
    pdf_test_stream("", b"0 0 200 200 re f"),
  ])
  assert_true(detect(data), msg="PDF public detect")
  let result = convert(data, no_text_index=true)
  assert_eq(result.format, "pdf")
  assert_eq(result.pages, 1)
  assert_true(result.bdf.length() > 0)
}

///|
test "PDF public detect accepts an offset header" {
  assert_true(detect(b"junk\\n%PDF-1.7\\n"))
}

///|
test "PDF public API reports unsupported content" {
  let rejected = try {
    ignore(convert(b"%PDF-1.7\\nnot a real pdf", no_text_index=true))
    false
  } catch {
    PdfFailure(message) => message != ""
    _ => false
  }
  assert_true(rejected)
}
