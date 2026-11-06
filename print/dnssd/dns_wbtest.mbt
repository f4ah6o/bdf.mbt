///|
test "dns query" {
  let query = encode_query(7, [
    { name: "_ipp._tcp.local", typ: TYPE_PTR, class_: CLASS_IN },
  ])
  let decoded = decode(query)
  assert_eq(decoded.id, 7)
  assert_eq(decoded.flags, 0)
  assert_eq(decoded.questions.length(), 1)
  assert_eq(decoded.questions[0].name, "_ipp._tcp.local")
  assert_eq(decoded.questions[0].typ, TYPE_PTR)
  assert_eq(decoded.answers.length(), 0)
}

///|
test "dns response" {
  let answers : Array[Record] = [
    {
      name: "_ipp._tcp.local",
      typ: TYPE_PTR,
      class_: CLASS_IN,
      ttl: 4500,
      data: RecordData::Ptr("Office._ipp._tcp.local"),
    },
    {
      name: "Office._ipp._tcp.local",
      typ: TYPE_SRV,
      class_: CLASS_FLUSH,
      ttl: 4500,
      data: RecordData::Srv(0, 0, 631, "printer.local"),
    },
    {
      name: "Office._ipp._tcp.local",
      typ: TYPE_TXT,
      class_: CLASS_FLUSH,
      ttl: 4500,
      data: RecordData::Txt([@utf8.encode("rp=/ipp/print"), @utf8.encode("pdl=application/pdf")]),
    },
    {
      name: "printer.local",
      typ: TYPE_A,
      class_: CLASS_FLUSH,
      ttl: 120,
      data: RecordData::A(Bytes::from_array([192, 0, 2, 10])),
    },
  ]
  let response = encode_response(9, [], answers)
  let decoded = decode(response)
  assert_eq(decoded.id, 9)
  assert_eq(decoded.answers.length(), 4)
  match decoded.answers[0].data {
    Ptr(name) => assert_eq(name, "Office._ipp._tcp.local")
    _ => fail("PTR")
  }
  match decoded.answers[1].data {
    Srv(priority, weight, port, host) => {
      assert_eq(priority, 0)
      assert_eq(weight, 0)
      assert_eq(port, 631)
      assert_eq(host, "printer.local")
    }
    _ => fail("SRV")
  }
  match decoded.answers[2].data {
    Txt(values) => {
      assert_eq(values.length(), 2)
      assert_eq(@utf8.decode_lossy(values[0]), "rp=/ipp/print")
    }
    _ => fail("TXT")
  }
  match decoded.answers[3].data {
    A(address) => assert_eq(address.to_array().map(fn(b) { b.to_int() }), [192, 0, 2, 10])
    _ => fail("A")
  }
  assert_eq(decoded.answers[1].class_, CLASS_FLUSH)
  let cut = try {
    ignore(decode(Bytes::from_array([0, 1, 2])))
    false
  } catch {
    DnsError(_) => true
  }
  assert_true(cut, msg="a cut header")
}
