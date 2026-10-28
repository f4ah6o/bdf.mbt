///|
test "converter correlates worker requests and replies" {
  let client = Client::new()
  let first = client.request(Convert, ConvertOptions::new())
  let second = client.request(Open, ConvertOptions::new())
  assert_eq(first.id, 1)
  assert_eq(second.id, 2)
  client.reply(second.id, true, "")
  assert_eq(client.status(2), Some(Completed))
  assert_eq(client.status(1), Some(Waiting))
}

///|
test "converter termination invalidates pending work" {
  let client = Client::new()
  ignore(client.request(Convert, ConvertOptions::new()))
  client.terminate()
  assert_eq(client.status(1), Some(Failed("converter terminated")))
  let mut rejected = false
  try {
    ignore(client.request(Open, ConvertOptions::new()))
  } catch {
    _ => rejected = true
  }
  assert_eq(rejected, true)
}
