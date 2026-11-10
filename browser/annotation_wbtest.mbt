///|
extern "js" fn annotation_test_request(roles : String) -> RenderRequest =
  #|(roles) => ({ roles: roles.split(",") })

///|
extern "js" fn annotation_test_request_all() -> RenderRequest =
  #|() => ({})

///|
test "the render worker shows annotations only when the request asks for them" {
  let all = annotation_test_request_all()
  assert_true(render_request_role(all, "body"))
  assert_true(render_request_role(all, "annotation"))
  let body_only = annotation_test_request("body")
  assert_true(render_request_role(body_only, "body"))
  assert_false(render_request_role(body_only, "annotation"))
  let annotations_only = annotation_test_request("annotation")
  assert_false(render_request_role(annotations_only, "body"))
  assert_true(render_request_role(annotations_only, "annotation"))
}
