///|
/// The width of a character in the cells of a text form: half width, full
/// width, or none for a combining mark.
test "east asian width counts the cells of a text form" {
  // ASCII is one cell, and the controls take none.
  assert_eq(@db.east_asian_width('A', false), 1)
  assert_eq(@db.east_asian_width(' ', false), 1)
  assert_eq(@db.east_asian_width('\n', false), 0)
  assert_eq(@db.east_asian_width('\u{7f}', false), 0)
  // Japanese is two cells, whatever the option.
  assert_eq(@db.east_asian_width('日', false), 2)
  assert_eq(@db.east_asian_width('日', true), 2)
  assert_eq(@db.east_asian_width('ｱ', false), 1)
  assert_eq(@db.east_asian_width('　', false), 2)
  // A combining mark takes no cell of its own.
  assert_eq(@db.east_asian_width('\u{0301}', false), 0)
  assert_eq(@db.east_asian_width('\u{200b}', false), 0)
}

///|
/// The box drawing of a form is ambiguous in East Asia: one cell by default,
/// two when the template says so.
test "east asian width follows the ambiguous option" {
  for c in ['│', '─', '┌', '└', '┼', '█', '■'] {
    assert_eq(@db.east_asian_width(c, false), 1)
    assert_eq(@db.east_asian_width(c, true), 2)
  }
  // A character that is not ambiguous keeps its width.
  assert_eq(@db.east_asian_width('A', true), 1)
  assert_eq(@db.east_asian_width('日', true), 2)
}
