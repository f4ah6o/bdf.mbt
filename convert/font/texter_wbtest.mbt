///|
test "specimen labels split by script and wrap at spaces" {
  let texter = SpecimenTexter::new(@db.Database::new())
  let line = texter.line("AあB", 10.0, false)
  assert_eq(line.width, 21.0)
  assert_eq(line.runs.map(r => r.text), ["A", "あ", "B"])
  assert_eq(line.runs.map(r => r.lang), ["", "ja", ""])
  assert_eq(texter.fit("hello", 10.0, false, 12.0), "h…")
  assert_eq(texter.wrap("alpha beta", 10.0, false, 30.0), ["alpha", "beta"])
  let (faces, missing) = texter.usage()
  assert_eq(faces.length(), 0)
  assert_eq(missing.length(), 0)
}
