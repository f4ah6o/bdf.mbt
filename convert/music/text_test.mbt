///|
test "music text tracks CJK runs and fallback metrics" {
  let texter = MusicTexter::new(@db.Database::new())
  let line = texter.line("A日B", 10.0, false, false)
  inspect(line.width, content="21")
  inspect(line.ascent, content="9")
  inspect(line.runs.length(), content="3")
  assert_true(line.runs[1].cjk)
  inspect(texter.used_codepoints().length(), content="0")
}
