///|
test "Bravura notehead metrics and outline" {
  let glyph = @music.music_glyph("noteheadBlack").unwrap()
  assert_eq(glyph.codepoint, 57508)
  assert_eq(glyph.advance, 1.18)
  assert_eq(glyph.verbs.length(), 6)
  assert_eq(glyph.coordinates.length(), 26)
  assert_true(@music.music_glyph("missing") is None)
}
