///|
test "PDF prefix sharing is a no-op for one page" {
  let object = @core.ObjectBuilder::new()
  object.fill_rect(0.0F, 0.0F, 10.0F, 10.0F)
  let pending = pdf_pending(object.encode(), [], [], [])
  let (staged, bodies, replaced, count, saved) = pdf_plan_shared([pending], [0])
  assert_eq(staged.length(), 0)
  assert_eq(bodies, [0])
  assert_true(replaced.is_empty())
  assert_eq(count, 0)
  assert_eq(saved, 0L)
}

///|
test "PDF pending objects reject child identity mismatch" {
  let object = @core.ObjectBuilder::new()
  object.fill_rect(0.0F, 0.0F, 10.0F, 10.0F)
  let rejected = try {
    ignore(pdf_pending(object.encode(), [1], [(0.0F, 0.0F, 1.0F, 1.0F)], []))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "PDF shared objects reject invalid font references" {
  let object = @core.ObjectBuilder::new()
  object.fill_rect(0.0F, 0.0F, 10.0F, 10.0F)
  let data = object.encode()
  let source = pdf_pending(data, [], [], [])
  let rewrite : @render.PrefixRewrite = { data, fonts: [0], children: [], }
  let rejected = try {
    ignore(pdf_rebind_shared(rewrite, source, None))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}
