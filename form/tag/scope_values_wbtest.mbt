///|
test "form values and variables render" {
  assert_eq(value_text(Json::string("x"), "", None), "x")
  assert_eq(value_text(Json::boolean(true), "", None), "TRUE")
  assert_eq(value_text(Json::boolean(false), "", None), "FALSE")
  assert_eq(value_text(Json::number(2.5), "", None), "2.5")
  assert_eq(value_text(Json::null(), "", None), "")
  let formatted = value_text(
    Json::number(1234.0),
    "#,##0",
    Some(fn(_, format) { "format:" + format }),
  )
  assert_eq(formatted, "format:#,##0")
  let vars = vars(0, 2, true)
  assert_eq(vars["_index"], Json::number(1.0))
  assert_eq(vars["_count"], Json::number(2.0))
  assert_eq(vars["_first"], Json::boolean(true))
  assert_eq(vars["_last"], Json::boolean(false))
  assert_eq(vars["_page"], Json::number(1.0))
  assert_eq(vars["_pages"], Json::number(2.0))
  assert_eq(normalize(Json::object({})), Json::object({}))
}
