///|
test "CSV language follows encoding and kana or hangul counts" {
  assert_eq(guess_language("漢字", "Shift_JIS"), "ja")
  assert_eq(guess_language("漢字", "EUC-KR"), "ko")
  assert_eq(guess_language("漢字", "GB18030"), "zh-CN")
  assert_eq(guess_language("漢字", "BIG5"), "zh-TW")
  assert_eq(guess_language("かな한", "UTF-8"), "ja")
  assert_eq(guess_language("か한국", "UTF-8"), "ko")
  assert_eq(guess_language("漢字", "UTF-8"), "")
  assert_eq(guess_language("ー", "UTF-8"), "")
}
