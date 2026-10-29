///|
test "UI painter draws aligned labels with system-font fallback" {
  let file = load(small_font())
  let object = @core.ObjectBuilder::new()
  let painter = file.faces()[0].glyph_painter(object)
  let texter = SpecimenTexter::new(@db.Database::new())
  let line = texter.line("A", 10.0, false)
  let fonts = texter.embed(@core.DocumentWriter::new())
  let ui = SpecimenUIPainter::new(painter, texter, fonts)
  let width = ui.label(line, 100.0, 40.0, 0x1f1f1fffU, 1)
  assert_eq(width, 5.5)
  assert_true(object.encode().length() > 32)
}
