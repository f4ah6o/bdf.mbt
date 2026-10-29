///|
test "repeated face shares its glyph font while retaining each sample" {
  let file = load(small_font())
  let doc = @core.DocumentWriter::new()
  let programs = file.prepare_programs(doc, "1,1", "")
  assert_eq(programs.faces.length(), 2)
  assert_eq(programs.font_parts, 3)
  assert_eq(programs.outlined, 0)
  assert_eq(
    programs.faces[0].glyph_font.unwrap().hash,
    programs.faces[1].glyph_font.unwrap().hash,
  )
  assert_true(programs.faces[0].sample_font is Some(_))
  assert_true(programs.faces[1].sample_font is Some(_))
}
