///|
fn check_pdf_dash_keys(a : Double, b : Double, expected : Bool) -> Unit raise {
  assert_eq(
    pdf_dash_key([a], 0.0) == pdf_dash_key([b], 0.0),
    expected,
    msg="\{a} vs \{b}",
  )
}
