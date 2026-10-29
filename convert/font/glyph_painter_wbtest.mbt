///|
test "embedded glyph painter rejects invalid indices before drawing" {
  let file = load(small_font())
  let object = @core.ObjectBuilder::new()
  let embedded : @core.Font = {
    hash: Some("00000000000000000000000000000000"),
    family: "",
    weight: 400,
    style: 0,
  }
  let painter = file.faces()[0].glyph_painter(object, embedded=Some(embedded))
  let before = object.encode()
  let failed = try {
    ignore(painter.draw([2], [0.0], 0.0, 0.0, 12.0, ""))
    false
  } catch {
    InvalidFontInput(_) => true
    _ => false
  }
  assert_true(failed)
  assert_eq(object.encode(), before)
  assert_false(painter.draw([], [], 0.0, 0.0, 12.0, ""))
  assert_true(painter.draw([1], [0.0], 0.0, 0.0, 12.0, "A"))
}

///|
test "language matching uses Unicode simple folding, not full lowercase" {
  assert_true(specimen_equal_fold("ſ", "S"))
  assert_true(specimen_equal_fold("ẞ", "ß"))
  assert_true(specimen_equal_fold("K", "k"))
  assert_false(specimen_equal_fold("İ", "i"))
  assert_false(specimen_equal_fold("ﬃ", "ffi"))
}

///|
test "specimen coordinates sanitize non-finite values" {
  assert_eq(specimen_f32(0.0 / 0.0), 0.0F)
  assert_eq(specimen_f32(1.0 / 0.0), 0.0F)
}
