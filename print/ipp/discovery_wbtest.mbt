///|
test "dns-sd txt records" {
  let entries : Array[(String, String)] = [
    ("rp", "/ipp/print"),
    ("pdl", "application/pdf,image/pwg-raster"),
    ("ty", "Office Printer"),
    ("note", ""),
  ]
  let data = encode_txt(entries)
  let txt = decode_txt(data)
  assert_eq(txt["rp"], "/ipp/print")
  assert_eq(txt["pdl"], "application/pdf,image/pwg-raster")
  assert_eq(txt["ty"], "Office Printer")
  assert_eq(txt["note"], "")
  let cut = try {
    ignore(decode_txt(Bytes::from_array([10, 1])))
    false
  } catch {
    IppError(_) => true
  }
  assert_true(cut, msg="a cut TXT record")
}

///|
test "dns-sd service" {
  let txt : Map[String, String] = Map([])
  txt["rp"] = "/ipp/print"
  txt["pdl"] = "application/pdf,image/urf"
  let service : Service = {
    name: "Office",
    host: "printer.local",
    port: 631,
    txt,
    secure: false,
    local_printer: false,
    url: "",
  }
  assert_eq(service.formats(), ["application/pdf", "image/urf"])
  assert_eq(service_url(service), "ipp://printer.local:631/ipp/print")
  let secure : Service = {
    ..service,
    host: "192.0.2.10",
    port: 8631,
    secure: true,
  }
  assert_eq(service_url(secure), "ipps://192.0.2.10:8631/ipp/print")
  let ipv6 : Service = { ..service, host: "fe80::1", port: 631 }
  assert_eq(service_url(ipv6), "ipp://[fe80::1]:631/ipp/print")
  let no_pdl : Service = { ..service, txt: Map([]), host: "host" }
  assert_eq(no_pdl.formats(), [])
}
