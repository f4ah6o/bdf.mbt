///|
test "Go Unicode lowercase table" {
  for (from, to) in xlsx_go_lowercase {
    let source = String::from_array([from.to_char().unwrap()])
    let expected = String::from_array([to.to_char().unwrap()])
    assert_eq(xlsx_go_lower(source), expected)
  }
  assert_eq(xlsx_go_lower("ΣςİIK𐐀日本語"), "σςiik𐐨日本語")
  assert_eq(xlsx_go_lower("\u{10ffff}"), "\u{10ffff}")
}
