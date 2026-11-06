///|
test "ipp printer URLs" {
  let cases : Array[(String, String, String)] = [
    (
      "ipp://printer.local/ipp/print",
      "http://printer.local:631/ipp/print",
      "ipp://printer.local:631/ipp/print",
    ),
    (
      "ipps://192.0.2.1/ipp/print",
      "https://192.0.2.1:631/ipp/print",
      "ipps://192.0.2.1:631/ipp/print",
    ),
    (
      "ipp://localhost:8631/printers/office",
      "http://localhost:8631/printers/office",
      "ipp://localhost:8631/printers/office",
    ),
    (
      "http://[fe80::1%25en0]:631/ipp/print",
      "http://[fe80::1%25en0]:631/ipp/print",
      "ipp://[fe80::1%25en0]:631/ipp/print",
    ),
    ("ipp://host", "http://host:631/", "ipp://host:631/"),
  ]
  for entry in cases {
    let (input, http_url, printer_uri) = entry
    let (got_http, got_printer) = parse_url(input)
    assert_eq(got_http, http_url)
    assert_eq(got_printer, printer_uri)
  }
  for bad in ["lpd://host/queue", "ipp:///nohost", "://"] {
    let failed = try {
      ignore(parse_url(bad))
      false
    } catch {
      IppError(_) => true
    }
    assert_true(failed, msg=bad)
  }
}
