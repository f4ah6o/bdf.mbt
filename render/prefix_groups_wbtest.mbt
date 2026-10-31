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
}
