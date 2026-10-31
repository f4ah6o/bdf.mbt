///|
fn check_pdf_metadata_date(input : String, expected : String) -> Unit raise {
  assert_eq(pdf_metadata_date(input), expected, msg=input)
}
