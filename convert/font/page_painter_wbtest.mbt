///|
test "specimen page rejects a font program from another face" {
  let file = load(small_font())
  let face = file.faces()[0]
  let programs : SpecimenFacePrograms = {
    face_index: 1,
    glyph_font: None,
    sample_font: None,
    sample: face.sample_plan(""),
    outlined: true,
  }
  let texter = SpecimenTexter::new(@db.Database::new())
  let fonts = texter.embed(@core.DocumentWriter::new())
  let scroll = ScrollLayout::new().finish()
  let failed = try {
    ignore(
      SpecimenPagePainter::new(face, programs, texter, fonts, scroll, 500.0),
    )
    false
  } catch {
    InvalidFontInput(_) => true
    _ => false
  }
  assert_true(failed)
}
