///|
test "Go border color component formatting" {
  assert_eq(xlsx_go_color_component(0.0), "0")
  assert_eq(xlsx_go_color_component(0.0001), "0.0001")
  assert_eq(xlsx_go_color_component(0.00001), "1e-05")
  assert_eq(xlsx_go_color_component(0.000001), "1e-06")
  assert_eq(xlsx_go_color_component(0.000000123456789), "1.23456789e-07")
  assert_eq(xlsx_go_color_component(-0.00001), "-1e-05")
}
