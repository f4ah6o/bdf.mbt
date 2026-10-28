///|
test "page bodies and continuous settings are retained" {
  let document = @core.parse_manifest(
    "{\"bdf\":1,\"parts\":[],\"views\":[{\"id\":\"book\",\"kind\":\"flow\",\"direction\":\"rtl\",\"continuous\":{\"gap\":-2.5},\"pages\":[{\"w\":100,\"h\":200,\"body\":{\"x\":-5,\"y\":8,\"w\":80,\"h\":150},\"layers\":[]},{\"w\":20,\"h\":30,\"layers\":[]}]}]}",
  )
  let view = document.views[0]
  assert_eq(view.direction, "rtl")
  assert_eq(view.continuous_gap, Some(-2.5))
  assert_eq(
    view.pages[0].body,
    Some({ x: -5.0, y: 8.0, width: 80.0, height: 150.0, }),
  )
  assert_eq(view.pages[1].body, None)
}

///|
test "invalid body rectangles and continuous gaps are rejected" {
  let cases = [
    "\"body\":null", "\"body\":{\"x\":16777217,\"y\":0,\"w\":1,\"h\":1}", "\"body\":{\"x\":0,\"y\":0,\"w\":-1,\"h\":1}",
    "\"body\":{\"x\":0,\"y\":0,\"w\":1}",
  ]
  for extra in cases {
    let page = "{\"w\":10,\"h\":10,\"layers\":[]," + extra + "}"
    let input = "{\"bdf\":1,\"parts\":[],\"views\":[{\"id\":\"v\",\"kind\":\"flow\",\"pages\":[" +
      page +
      "]}]}"
    let mut rejected = false
    ignore(@core.parse_manifest(input)) catch {
      _ => rejected = true
    }
    assert_true(rejected)
  }
  for continuous in ["null", "{}", "{\"gap\":16777217}", "{\"gap\":\"x\"}"] {
    let input = "{\"bdf\":1,\"parts\":[],\"views\":[{\"id\":\"v\",\"kind\":\"flow\",\"continuous\":" +
      continuous +
      ",\"pages\":[]}]}"
    let mut rejected = false
    ignore(@core.parse_manifest(input)) catch {
      _ => rejected = true
    }
    assert_true(rejected)
  }
}
