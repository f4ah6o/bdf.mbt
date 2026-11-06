///|
test "dns-sd discovery" {
  let service : Advertisement = {
    instance: "Office",
    service_type: "_ipp._tcp",
    port: 631,
    host: "printer.local",
    addresses: ["192.0.2.10"],
    txt: [("rp", "/ipp/print"), ("pdl", "application/pdf")],
    subtypes: [],
  }
  let records = advertisement_records(service)
  let message = decode(encode_response(1, [], records))
  let found = discover(message, "_ipp._tcp")
  assert_eq(found.length(), 1)
  let printer = found[0]
  assert_eq(printer.name, "Office")
  assert_eq(printer.host, "printer.local")
  assert_eq(printer.port, 631)
  assert_eq(printer.addresses, ["192.0.2.10"])
  assert_eq(printer.txt["rp"], "/ipp/print")
  assert_eq(printer.url, "ipp://printer.local:631/ipp/print")
  assert_true(!printer.secure)
  let secure : Advertisement = {
    ..service,
    service_type: "_ipps._tcp",
    port: 8631,
  }
  let secure_message = decode(encode_response(2, [], advertisement_records(secure)))
  let secure_found = discover(secure_message, "_ipps._tcp")
  assert_true(secure_found[0].secure)
  assert_eq(secure_found[0].url, "ipps://printer.local:8631/ipp/print")
  assert_eq(discover(message, "_ipps._tcp").length(), 0)
}

///|
test "dns-sd browse over a transport" {
  let service : Advertisement = {
    instance: "Office",
    service_type: "_ipp._tcp",
    port: 631,
    host: "printer.local",
    addresses: ["192.0.2.10"],
    txt: [("rp", "/ipp/print")],
    subtypes: [],
  }
  let answer = encode_response(1, [], advertisement_records(service))
  let mut asked = false
  let found = browse("_ipp._tcp", fn(query) {
    let message = decode(query) catch { _ => return None }
    if message.questions.length() == 1 &&
      message.questions[0].name == "_ipp._tcp.local" {
      asked = true
    }
    Some(answer)
  })
  assert_true(asked)
  assert_eq(found.length(), 1)
  assert_eq(found[0].name, "Office")
  assert_eq(browse("_ipps._tcp", fn(_query) { None }).length(), 0)
}

