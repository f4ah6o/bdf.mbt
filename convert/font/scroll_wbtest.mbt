///|
test "scroll cuts at boundaries and resolves anchors on the next page" {
  let layout = ScrollLayout::new()
  layout.add(988.0)
  layout.anchor("cut")
  layout.add(300.0)
  layout.anchor("end")
  let plan = layout.finish()
  assert_eq(plan.strips.length(), 2)
  assert_eq(plan.strips[0].height, 1024.0)
  assert_eq(plan.strips[1].bands[0], (1, 0.0))
  assert_eq(plan.anchor_page("cut"), Some(2))
  assert_eq(plan.anchor_page("end"), Some(2))
  assert_eq(plan.anchor_page("missing"), None)
}

///|
test "scroll keeps headings together and suppresses tiny trailing pages" {
  let layout = ScrollLayout::new()
  layout.add(988.0, keep=true)
  layout.add(300.0)
  layout.add(100.0)
  let plan = layout.finish()
  assert_eq(plan.strips.length(), 1)
  layout.anchor("later")
  assert_eq(plan.anchor_page("later"), None)
}
