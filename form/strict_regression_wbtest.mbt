///|
test "strict form rejects missing workbook values" {
  let error = form_test_fill_error(
    form_test_small_xlsx(),
    Options::new(data=form_test_json("{}"), strict=true),
  )
  assert_true(error != "", msg="strict fill accepted missing workbook fields")
}
