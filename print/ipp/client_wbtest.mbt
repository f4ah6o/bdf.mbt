///|
test "ipp client requests" {
  let client = Client::new("ipp://printer.local/ipp/print", "alice")
  assert_eq(client.http_url, "http://printer.local:631/ipp/print")
  assert_eq(client.printer_uri, "ipp://printer.local:631/ipp/print")
  let first = client.request(OP_GET_PRINTER_ATTRIBUTES)
  assert_eq(first.request_id, 1)
  assert_eq(first.code, OP_GET_PRINTER_ATTRIBUTES)
  match first.attr(TAG_OPERATION, "printer-uri") {
    Some(attribute) => assert_eq(attribute.text(), client.printer_uri)
    None => fail("missing printer-uri")
  }
  match first.attr(TAG_OPERATION, "requesting-user-name") {
    Some(attribute) => assert_eq(attribute.text(), "alice")
    None => fail("missing requesting-user-name")
  }
  let attributes = client.get_printer_attributes([])
  let requested = match attributes.attr(TAG_OPERATION, "requested-attributes") {
    Some(attribute) => attribute
    None => {
      fail("missing requested-attributes")
      { name: "", values: [] }
    }
  }
  assert_true(requested.strings().length() > 50)
  assert_true(requested.has("printer-name"))
  let exact = client.get_printer_attributes(["printer-name", "printer-state"])
  match exact.attr(TAG_OPERATION, "requested-attributes") {
    Some(attribute) => assert_eq(attribute.strings(), ["printer-name", "printer-state"])
    None => fail("missing exact requested-attributes")
  }
  let validate = client.validate_job([attr("copies", [integer(2)])], "application/pdf")
  match validate.attr(TAG_OPERATION, "document-format") {
    Some(attribute) => assert_eq(attribute.text(), "application/pdf")
    None => fail("missing document-format")
  }
  match validate.attr(TAG_JOB, "copies") {
    Some(attribute) => assert_eq(attribute.int(), Some(2))
    None => fail("missing copies")
  }
  let create = client.create_job("report", [attr("copies", [integer(1)])])
  match create.attr(TAG_OPERATION, "job-name") {
    Some(attribute) => assert_eq(attribute.text(), "report")
    None => fail("missing job-name")
  }
  let send = client.send_document(7, "page.pdf", "application/pdf", true)
  match send.attr(TAG_OPERATION, "job-id") {
    Some(attribute) => assert_eq(attribute.int(), Some(7))
    None => fail("missing job-id")
  }
  match send.attr(TAG_OPERATION, "last-document") {
    Some(attribute) => assert_true(attribute.bool().unwrap_or(false))
    None => fail("missing last-document")
  }
  let print = client.print_job("report", "image/pwg-raster", [attr("sides", [keyword("one-sided")])])
  assert_eq(print.code, OP_PRINT_JOB)
  assert_true(print.attr(TAG_JOB, "sides") is Some(_))
  let encoded = print.encode()
  let decoded = decode(encoded)
  assert_eq(decoded.code, OP_PRINT_JOB)
  assert_eq(decoded.request_id, print.request_id)
}

///|
test "ipp made job status" {
  let response = new_response(STATUS_OK, 1, "", "")
  response.add(TAG_JOB, [
    attr("job-id", [integer(12)]),
    attr("job-state", [enum_value(JOB_PENDING)]),
    attr("job-name", [name("report")]),
  ])
  let job = make_job_status(response)
  assert_eq(job.id, 12)
  assert_eq(job.state, JOB_PENDING)
  assert_eq(job.name, "report")
}

///|
fn http_ipp_response(body : Bytes) -> Bytes {
  let head = @utf8.encode(
    "HTTP/1.1 200 OK\r\nContent-Type: application/ipp\r\nContent-Length: " +
    body.length().to_string() +
    "\r\n\r\n",
  )
  let out = head.to_array()
  for byte in body {
    out.push(byte)
  }
  Bytes::from_array(out)
}

///|
test "ipp client transport" {
  let client = Client::new("ipp://printer.local/ipp/print", "alice")
  let request = client.get_printer_attributes(["printer-name"])
  let response = new_response(STATUS_OK, request.request_id, "", "")
  response.add(TAG_PRINTER, [attr("printer-name", [name("office")])])
  let body = response.encode()
  let http = http_ipp_response(body)
  let decoded = client.send(request, fn(_) { Some(http) })
  assert_eq(decoded.code, STATUS_OK)
  let printer = parse_printer(decoded)
  assert_eq(printer.name, "office")
  let failed = try {
    ignore(client.send(request, fn(_) { None }))
    false
  } catch {
    IppError(_) => true
  }
  assert_true(failed, msg="a failed transport")
  let bad_http = try {
    ignore(client.send(request, fn(_) { Some(@utf8.encode("HTTP/1.1 500 Error\r\n\r\n")) }))
    false
  } catch {
    IppError(_) => true
  }
  assert_true(bad_http, msg="an HTTP error without an IPP body")
}


///|
test "ipp client high-level operations" {
  let client = Client::new("ipp://printer.local/ipp/print", "alice")
  let printer_response = new_response(STATUS_OK, 1, "", "")
  printer_response.add(TAG_PRINTER, [
    attr("printer-name", [name("office")]),
    attr("document-format-supported", [mime_type("application/pdf")]),
  ])
  let printer_body = printer_response.encode()
  let printer = client.fetch_printer(fn(_) { Some(http_ipp_response(printer_body)) })
  assert_eq(printer.name, "office")
  assert_eq(printer.uri, client.printer_uri)
  assert_true(printer.supports("application/pdf"))
  let job_response = new_response(STATUS_OK, 1, "", "")
  job_response.add(TAG_JOB, [
    attr("job-id", [integer(3)]),
    attr("job-name", [name("report")]),
    attr("job-state", [enum_value(JOB_PENDING)]),
  ])
  let job_body = job_response.encode()
  let created = client.create("report", [], fn(_) { Some(http_ipp_response(job_body)) })
  assert_eq(created.id, 3)
  assert_eq(created.name, "report")
  let printed = client.print("report", "application/pdf", [], fn(_) { Some(http_ipp_response(job_body)) })
  assert_eq(printed.id, 3)
  let fetched = client.job(3, fn(_) { Some(http_ipp_response(job_body)) })
  assert_eq(fetched.state, JOB_PENDING)
  client.cancel(3, fn(_) { Some(http_ipp_response(job_body)) })
  let jobs_response = new_response(STATUS_OK, 1, "", "")
  jobs_response.add(TAG_JOB, [
    attr("job-id", [integer(1)]),
    attr("job-state", [enum_value(JOB_COMPLETED)]),
    attr("job-id", [integer(2)]),
    attr("job-state", [enum_value(JOB_PENDING)]),
  ])
  let jobs_body = jobs_response.encode()
  let jobs = client.jobs(fn(_) { Some(http_ipp_response(jobs_body)) })
  assert_eq(jobs.length(), 2)
  assert_eq(jobs[0].id, 1)
  assert_eq(jobs[0].state, JOB_COMPLETED)
  assert_eq(jobs[1].id, 2)
  let error_response = new_response(STATUS_CLIENT_ERROR_BAD_REQUEST, 1, "", "")
  error_response.add(TAG_OPERATION, [attr("status-message", [text("bad job")])])
  let error_body = error_response.encode()
  let failed = try {
    ignore(client.print("report", "application/pdf", [], fn(_) { Some(http_ipp_response(error_body)) }))
    false
  } catch {
    IppError(message) => message == "bad job"
    _ => false
  }
  assert_true(failed)
}


///|
test "ipp print with a PDF document" {
  let client = Client::new("ipp://printer.local/ipp/print", "alice")
  let response = new_response(STATUS_OK, 1, "", "")
  response.add(TAG_JOB, [
    attr("job-id", [integer(9)]),
    attr("job-state", [enum_value(JOB_PENDING)]),
  ])
  let http = http_ipp_response(response.encode())
  let captured : Array[Bytes] = []
  let job = client.print_pdf("%PDF-1.4 test", b"%PDF-1.4\nbody", fn(bytes) {
    captured.push(bytes)
    Some(http)
  })
  assert_eq(job.id, 9)
  assert_eq(captured.length(), 1)
  let request = captured[0]
  assert_true(request.find(b"POST /ipp/print HTTP/1.1"[:]) is Some(_))
  assert_true(request.find(b"%PDF-1.4"[:]) is Some(_))
  assert_true(request.find(b"body"[:]) is Some(_))
}


///|
test "ipp print data" {
  let client = Client::new("ipp://printer.local/ipp/print", "alice")
  let response = new_response(STATUS_OK, 1, "", "")
  response.add(TAG_JOB, [
    attr("job-id", [integer(10)]),
    attr("job-state", [enum_value(JOB_PENDING)]),
  ])
  let http = http_ipp_response(response.encode())
  let captured : Array[Bytes] = []
  let job = client.print_data(
    "raster",
    "image/pwg-raster",
    b"RaS2 raster",
    fn(bytes) {
      captured.push(bytes)
      Some(http)
    },
  )
  assert_eq(job.id, 10)
  assert_true(captured[0].find(b"RaS2"[:]) is Some(_))
  assert_true(captured[0].find(b"image/pwg-raster"[:]) is Some(_))
}


///|
test "ipp decode prefix leaves a document" {
  let request = new_request(OP_PRINT_JOB, 3, "", "")
  let body = request.encode()
  let combined = body.to_array()
  for byte in b"%PDF-1.7" {
    combined.push(byte)
  }
  let (message, consumed) = decode_prefix(Bytes::from_array(combined))
  assert_eq(message.code, OP_PRINT_JOB)
  assert_eq(consumed, body.length())
  assert_eq(Bytes::from_array(combined[consumed:].to_array()), b"%PDF-1.7")
}


///|
test "ipp get jobs" {
  let client = Client::new("ipp://printer.local/ipp/print", "alice")
  let response = new_response(STATUS_OK, 1, "", "")
  response.add(TAG_JOB, [
    attr("job-id", [integer(2)]),
    attr("job-uri", [uri("ipp://printer.local/jobs/2")]),
    attr("job-state", [enum_value(JOB_COMPLETED)]),
  ])
  response.add(TAG_JOB, [
    attr("job-id", [integer(3)]),
    attr("job-uri", [uri("ipp://printer.local/jobs/3")]),
    attr("job-state", [enum_value(JOB_PENDING)]),
  ])
  let http = http_ipp_response(response.encode())
  let jobs = client.get_jobs("all", true, fn(_bytes) { Some(http) })
  assert_eq(jobs.length(), 2)
  assert_eq(jobs[0].id, 2)
  assert_eq(jobs[0].state, JOB_COMPLETED)
  assert_eq(jobs[1].id, 3)
}


///|
test "ipp print format helpers" {
  let client = Client::new("ipp://printer.local/ipp/print", "alice")
  let response = new_response(STATUS_OK, 1, "", "")
  response.add(TAG_JOB, [
    attr("job-id", [integer(12)]),
    attr("job-state", [enum_value(JOB_PENDING)]),
  ])
  let http = http_ipp_response(response.encode())
  let captured : Array[Bytes] = []
  let job = client.print_pwg("raster", b"RaS2", fn(bytes) {
    captured.push(bytes)
    Some(http)
  })
  assert_eq(job.id, 12)
  assert_true(captured[0].find(b"image/pwg-raster"[:]) is Some(_))
  let urf = client.print_urf("urf", b"UNIRAST", fn(bytes) {
    captured.push(bytes)
    Some(http)
  })
  assert_eq(urf.id, 12)
  assert_true(captured[1].find(b"image/urf"[:]) is Some(_))
  let pclm = client.print_pclm("pclm", b"%PDF", fn(bytes) {
    captured.push(bytes)
    Some(http)
  })
  assert_eq(pclm.id, 12)
  assert_true(captured[2].find(b"application/PCLm"[:]) is Some(_))
}

