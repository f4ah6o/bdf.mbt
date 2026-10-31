///|
fn check_prefix_split(
  data : Bytes,
  instruction : Int32,
  offset : Int32,
  expected_prefix : Bytes,
  expected_rest : Bytes,
  prefix_fonts : Array[Int32],
  rest_fonts : Array[Int32],
  prefix_children : Array[Int32],
  rest_children : Array[Int32],
) -> Unit raise {
  let source = @core.decode_object_resources(data)
  let result = split_prefix(
    source,
    [(1.0F, 2.0F, 3.0F, 4.0F), (5.0F, 6.0F, 7.0F, 8.0F)],
    { instruction, offset, },
  )
  assert_eq(result.prefix.encode(), expected_prefix, msg="Go prefix bytes")
  assert_eq(result.rest.encode(), expected_rest, msg="Go rest bytes")
  assert_eq(result.prefix_fonts, prefix_fonts)
  assert_eq(result.rest_fonts, rest_fonts)
  assert_eq(result.prefix_children, prefix_children)
  assert_eq(result.rest_children, rest_children)
}

///|
test "invalid prefix split is rejected" {
  let obj = @core.ObjectBuilder::new()
  obj.save()
  obj.fill_rect(0.0F, 0.0F, 1.0F, 1.0F)
  obj.restore()
  let source = @core.decode_object_resources(obj.encode())
  let rejected = try {
    ignore(split_prefix(source, [], { instruction: 1, offset: 1, }))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "prefix replay rejects a missing font resource" {
  let object = @core.ObjectBuilder::new()
  let font = object.add_font({
    hash: None,
    family: "serif",
    weight: 400,
    style: 0,
  })
  object.font(font, 12.0F)
  object.fill_rect(0.0F, 0.0F, 1.0F, 1.0F)
  let source = @core.decode_object_resources(object.encode())
  let damaged = { ..source, fonts: [], }
  let rejected = try {
    ignore(split_prefix(damaged, [], { instruction: 1, offset: 6, }))
    false
  } catch {
    InvalidReference(_) => true
    _ => false
  }
  assert_true(rejected)
}

///|
test "prefix replay rejects missing child bounds" {
  let object = @core.ObjectBuilder::new()
  let child = object.add_object(
    "00000000000000000000000000000000",
    (0.0F, 0.0F, 1.0F, 1.0F),
  )
  object.use_object(child)
  object.fill_rect(0.0F, 0.0F, 1.0F, 1.0F)
  let source = @core.decode_object_resources(object.encode())
  let rejected = try {
    ignore(split_prefix(source, [], { instruction: 1, offset: 2, }))
    false
  } catch {
    InvalidReference(_) => true
    _ => false
  }
  assert_true(rejected)
}
