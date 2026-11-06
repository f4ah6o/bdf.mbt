///|
test "dns-sd advertisement" {
  let service : Advertisement = {
    instance: "Office",
    service_type: "_ipp._tcp",
    port: 631,
    host: "printer.local",
    addresses: ["192.0.2.10"],
    txt: [("rp", "/ipp/print"), ("pdl", "application/pdf,image/pwg-raster")],
    subtypes: ["_print", "_universal"],
  }
  let records = advertisement_records(service)
  assert_eq(records.length(), 6)
  let response = encode_response(5, [], records)
  let decoded = decode(response)
  assert_eq(decoded.answers.length(), 6)
  match decoded.answers[0].data {
    Ptr(name) => assert_eq(name, "Office._ipp._tcp.local")
    _ => fail("PTR")
  }
  match decoded.answers[1].data {
    Srv(_, _, port, host) => {
      assert_eq(port, 631)
      assert_eq(host, "printer.local")
    }
    _ => fail("SRV")
  }
  match decoded.answers[2].data {
    Txt(values) => assert_eq(@utf8.decode_lossy(values[0]), "rp=/ipp/print")
    _ => fail("TXT")
  }
  match decoded.answers[3].data {
    A(address) => assert_eq(address.to_array().map(fn(b) { b.to_int() }), [192, 0, 2, 10])
    _ => fail("A")
  }
  assert_eq(decoded.answers[4].name, "_print._sub._ipp._tcp.local")
  assert_eq(instance_name("Office._ipp._tcp.local", "_ipp._tcp"), "Office")
  let question = service_question("_ipp._tcp")
  assert_eq(question.name, "_ipp._tcp.local")
  let bad = try {
    ignore(advertisement_records({ ..service, port: 0 }))
    false
  } catch {
    DnsError(_) => true
  }
  assert_true(bad, msg="an empty advertisement")
}

///|
test "dns-sd advertises IPv6" {
  let service : Advertisement = {
    instance: "Office",
    service_type: "_ipp._tcp",
    port: 631,
    host: "printer.local",
    addresses: ["2001:db8::1"],
    txt: [("rp", "/ipp/print")],
    subtypes: [],
  }
  let records = advertisement_records(service)
  let decoded = decode(encode_response(6, [], records))
  let mut address = Bytes::new(0)
  for record in decoded.answers {
    match record.data {
      Aaaa(bytes) => address = bytes
      _ => ()
    }
  }
  assert_eq(address.length(), 16)
  assert_eq(address[0].to_int(), 0x20)
  assert_eq(address[1].to_int(), 0x01)
  assert_eq(address[2].to_int(), 0x0d)
  assert_eq(address[3].to_int(), 0xb8)
  assert_eq(address[15].to_int(), 0x01)
  let found = discover(decoded, "_ipp._tcp")
  assert_eq(found[0].url, "ipp://printer.local:631/ipp/print")
  let bad = try {
    ignore(advertisement_records({ ..service, addresses: ["2001:::1"] }))
    false
  } catch {
    DnsError(_) => true
  }
  assert_true(bad, msg="a broken IPv6 address")
}

