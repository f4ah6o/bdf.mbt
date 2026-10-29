///|
test "font paths use lexical Unicode order" {
  assert_true(csv_path_compare("a-long-font.ttf", "z.ttf") < 0)
  assert_true(csv_path_compare("font.ttf", "font2.ttf") < 0)
  assert_true(csv_path_compare("z.ttf", "é.ttf") < 0)
  assert_true(csv_path_compare("\u{e000}", "\u{10000}") < 0)
  assert_eq(csv_path_compare("same", "same"), 0)
}
