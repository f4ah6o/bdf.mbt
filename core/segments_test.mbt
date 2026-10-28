///|
test "segment declaration validates page numbers" {
  assert_eq(
    parse_segment("{\"segment\":{\"view\":\"pages\",\"from\":3,\"to\":6}}"),
    Some({ view: "pages", from: 3, to: 6, }),
  )
  assert_eq(parse_segment("{}"), None)
  for
    text in [
      "{\"segment\":{\"view\":\"pages\",\"from\":-1,\"to\":3}}", "{\"segment\":{\"view\":\"pages\",\"from\":0.5,\"to\":3}}",
      "{\"segment\":{\"from\":0,\"to\":3}}",
    ] {
    let mut rejected = false
    ignore(parse_segment(text)) catch {
      _ => rejected = true
    }
    assert_true(rejected)
  }
}
