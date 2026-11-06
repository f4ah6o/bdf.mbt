///|
test "mdns probe and announce" {
  let service : Advertisement = {
    instance: "Office",
    service_type: "_ipp._tcp",
    port: 631,
    host: "printer.local",
    addresses: ["192.0.2.10"],
    txt: [("rp", "/ipp/print")],
    subtypes: [],
  }
  let probe = decode(probe_message(1, service))
  assert_eq(probe.flags, 0)
  assert_eq(probe.questions.length(), 2)
  assert_eq(probe.questions[0].name, "Office._ipp._tcp.local")
  assert_eq(probe.questions[0].typ, TYPE_ANY)
  assert_eq(probe.questions[1].name, "printer.local")
  let announce = decode(announce_message(2, service))
  assert_eq(announce.flags, 0x8400)
  assert_eq(announce.answers.length(), 4)
  assert_eq(announce.id, 2)
}
