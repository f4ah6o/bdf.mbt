///|
test "object builder writes deduplicated text and automatic bounds" {
  let builder = ObjectBuilder::new()
  let font = builder.add_font({
    hash: None,
    family: "Example",
    weight: 400,
    style: 0,
  })
  builder.font(font, 12.0F)
  builder.fill_text("\u{feff}hello", 10.0F, 20.0F, 30.0F)
  builder.stroke_text("hello", -5.0F, 4.0F, -2.0F)
  let data = builder.encode()
  let decoded = decode_object_resources(data)
  assert_eq(decoded.object.bbox, (-7.0, 4.0, 47.0, 16.0))
  assert_eq(decoded.object.strings, ["hello"])
  assert_eq(decoded.fonts[0].family, "Example")
  assert_eq(decoded.object.ops[0], b'\x1a')
}

///|
test "object builder rejects invalid resources and references" {
  let builder = ObjectBuilder::new()
  let bad = builder.add_path(Inline({ verbs: b"\x00", coordinates: [], }))
  let rejected = try {
    builder.fill_path(bad, 0)
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  let bad_font = try {
    builder.font(0, 12.0F)
    false
  } catch {
    _ => true
  }
  assert_true(bad_font)
}
