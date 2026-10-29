///|
test "font with no OpenType layout tables has no feature groups" {
  let file = load(small_font())
  assert_eq(file.faces()[0].feature_groups().length(), 0)
}
