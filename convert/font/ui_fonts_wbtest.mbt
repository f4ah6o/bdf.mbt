///|
test "UI font records fall back to the requested family when no fonts exist" {
  let texter = SpecimenTexter::new(@db.Database::new())
  let run = texter.line("Hello", 12.0, true).runs[0]
  let document = @core.DocumentWriter::new()
  let fonts = texter.embed(document)
  assert_eq(fonts.hashes.length(), 0)
  assert_eq(fonts.warnings.length(), 0)
  let record = texter.font_record(run.choice, fonts)
  assert_eq(record.hash, None)
  assert_eq(record.family, "\"Arial\", sans-serif")
  assert_eq(record.weight, 700)
}
