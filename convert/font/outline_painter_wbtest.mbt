///|
test "outline painter validates glyph offsets before changing the object" {
  let file = load(small_font())
  let object = @core.ObjectBuilder::new()
  let painter = file.faces()[0].outline_painter(object)
  let before = object.encode()
  let failed = try {
    ignore(painter.draw([0], [], 0.0, 0.0, 12.0, ""))
    false
  } catch {
    InvalidFontInput(_) => true
    _ => false
  }
  assert_true(failed)
  assert_eq(object.encode(), before)
  assert_false(painter.draw([], [], 0.0, 0.0, 12.0, ""))
  assert_eq(object.encode(), before)
}
