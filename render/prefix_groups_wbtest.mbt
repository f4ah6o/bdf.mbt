///|
fn check_prefix_groups(
  data : Array[Bytes],
  expected_keys : Array[Array[String]],
  min_bytes : Int32,
  expected_groups : Array[Array[(Int32, Int32, Int32)]],
) -> Unit raise {
  let objects = data.map(fn(value) { @core.decode_object_resources(value) })
  for i, object in objects {
    let candidates = prefix_candidates(object)
    assert_eq(candidates.map(fn(value) { value.key }), expected_keys[i])
  }
  let groups = select_prefix_groups(objects, min_bytes)
  let result = groups.map(fn(group) {
    group.members.map(fn(member) {
      (member.object, member.cut.instruction, member.cut.offset)
    })
  })
  assert_eq(result, expected_groups)
  let sources = objects.map(fn(object) {
    {
      resources: object,
      child_bounds: object.object.objects.map(fn(_) { (0.0F, 0.0F, 0.0F, 0.0F) }),
    }
  })
  let plans = plan_shared_prefixes(sources, min_bytes)
  assert_eq(plans.length(), expected_groups.length())
  for i, plan in plans {
    assert_eq(plan.source, expected_groups[i][0].0)
    assert_eq(
      plan.members.map(fn(member) { (member.source, member.saved) }),
      expected_groups[i].map(fn(member) { (member.0, member.2) }),
    )
  }
}
