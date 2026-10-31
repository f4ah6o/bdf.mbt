///|
fn check_pdf_metadata_text(input : Bytes, expected : Bytes) -> Unit raise {
  assert_eq(
    @utf8.encode(pdf_decode_text(input)),
    expected,
    msg="input \{input}",
  )
}
