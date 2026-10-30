///|
test "XLSX border color order matches Go RGB tuples" {
  assert_true(xlsx_grid_border_color_compare(0x000099ffU, 0x000000ffU) < 0)
  assert_true(xlsx_grid_border_color_compare(0x000034ffU, 0x000033ffU) < 0)
  assert_true(xlsx_grid_border_color_compare(0x010000ffU, 0x000000ffU) > 0)
}
