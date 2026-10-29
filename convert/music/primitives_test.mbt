///|
test "drawing skyline tracks glyph and line extents" {
  let d = @music.MusicDrawing::new()
  d.rect(0.0, 1.0, 4.0, 0.2)
  d.line(2.0, -1.0, 3.0, 2.0, 0.4, 0.0)
  assert_eq(d.skyline(2.0, 3.0, 0.0, true), -1.2)
  assert_eq(d.skyline(2.0, 3.0, 4.0, false), 4.0)
  assert_eq(d.primitives().length(), 2)
}

///|
test "tie curve is a closed cubic outline" {
  let c = @music.music_curve(0.0, 0.0, 4.0, 0.0, -1.0, 0.2, 0.4)
  assert_eq(c.verbs, b"\x00\x03\x01\x03\x04")
  assert_eq(c.coordinates.length(), 16)
  let (x0, y0, x1, y1) = c.bounds()
  assert_eq(x0, 0.0)
  assert_eq(x1, 4.0)
  assert_true(y0 < 0.0 && y1 > 0.0)
}
