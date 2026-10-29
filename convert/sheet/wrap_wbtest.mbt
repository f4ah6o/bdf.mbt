///|
test "wrapped lines preserve spaces and indicate explicit breaks" {
  let advance = (_ : Char, _ : Bool) => 1.0
  let lines = wrap_text("abc def\r\nx\n", 4.0, advance~)
  assert_eq(lines.length(), 4)
  assert_eq(lines[0].text, "abc ")
  assert_eq(lines[0].width, 3.0)
  assert_eq(lines[1].text, "def")
  assert_true(lines[1].wrapped)
  assert_true(lines[2].explicit)
  assert_eq(lines[3].text, "")
  assert_true(lines[3].explicit)
}

///|
test "Japanese punctuation stays with the preceding character" {
  let advance = (_ : Char, _ : Bool) => 1.0
  let lines = wrap_text("日本語、", 2.0, advance~)
  assert_eq(lines.length(), 2)
  assert_eq(lines[0].text, "日本")
  assert_eq(lines[1].text, "語、")
  assert_true(lines[1].cjk_wrap)
}
