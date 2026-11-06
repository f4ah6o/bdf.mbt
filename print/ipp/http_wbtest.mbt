///|
test "ipp http request" {
  let body = Bytes::from_array([1, 2, 3])
  let request = http_request("http://printer.local:631/ipp/print?x=1", body)
  assert_eq(request.method, "POST")
  assert_eq(request.target, "/ipp/print?x=1")
  assert_eq(request.host, "printer.local:631")
  let data = request.encode()
  let text = @utf8.decode_lossy(data)
  assert_true(text.contains("POST /ipp/print?x=1 HTTP/1.1"))
  assert_true(text.contains("Host: printer.local:631"))
  assert_true(text.contains("Content-Type: application/ipp"))
  assert_true(text.contains("Content-Length: 3"))
  assert_true(text.has_suffix("\r\n\r\n\u{1}\u{2}\u{3}"))
  let no_host = try {
    ignore(http_request("ipp:///x", Bytes::new(0)))
    false
  } catch {
    IppError(_) => true
  }
  assert_true(no_host, msg="no host")
}

///|
test "ipp http response" {
  let data = @utf8.encode(
    "HTTP/1.1 200 OK\r\nContent-Type: application/ipp\r\nContent-Length: 3\r\n\r\nabc",
  )
  let response = parse_http_response(data)
  assert_eq(response.status, 200)
  assert_eq(response.reason, "OK")
  assert_eq(response.headers.length(), 2)
  assert_eq(response.body.to_array().map(fn(byte) { byte.to_int() }), [97, 98, 99])
  let bad = try {
    ignore(parse_http_response(@utf8.encode("HTTP/1.1 200 OK")))
    false
  } catch {
    IppError(_) => true
  }
  assert_true(bad, msg="no header end")
}
