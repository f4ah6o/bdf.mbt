///|
fn test_server() -> Server {
  Server::new(
    "ipp://printer.local:631/ipp/print",
    [
      @ipp.attr("printer-name", [@ipp.name("Test Printer")]),
      @ipp.attr("printer-state", [@ipp.enum_value(@ipp.PRINTER_IDLE)]),
      @ipp.attr("printer-is-accepting-jobs", [@ipp.boolean(true)]),
      @ipp.attr("document-format-supported", [
        @ipp.mime_type("application/pdf"),
        @ipp.mime_type("image/pwg-raster"),
      ]),
      @ipp.attr("copies-supported", [@ipp.range(1, 99)]),
      @ipp.attr("copies-default", [@ipp.integer(1)]),
    ],
  )
}

///|
test "ipp server printer attributes" {
  let server = test_server()
  let client = @ipp.Client::new("ipp://printer.local/ipp/print", "alice")
  let response = server.handle(client.get_printer_attributes([]))
  assert_eq(response.code, @ipp.STATUS_OK)
  assert_eq(response.request_id, 1)
  let printer = @ipp.parse_printer(response)
  assert_eq(printer.name, "Test Printer")
  assert_true(printer.supports("application/pdf"))
  let filtered = server.handle(client.get_printer_attributes(["printer-name"]))
  let group = match filtered.group(@ipp.TAG_PRINTER) {
    Some(group) => group
    None => fail("missing printer group")
  }
  assert_eq(group.attrs.length(), 1)
  assert_eq(group.attrs[0].name, "printer-name")
  let template = server.handle(client.get_printer_attributes(["job-template"]))
  let group = match template.group(@ipp.TAG_PRINTER) {
    Some(group) => group
    None => fail("missing printer group")
  }
  assert_true(group.get("copies-supported") is Some(_))
  assert_true(group.get("printer-name") is None)
}

///|
test "ipp server jobs" {
  let server = test_server()
  let client = @ipp.Client::new("ipp://printer.local/ipp/print", "alice")
  let validate = server.handle(client.validate_job([], "application/pdf"))
  assert_eq(validate.code, @ipp.STATUS_OK)
  let created = server.handle(client.create_job("report", []))
  let job = @ipp.make_job_status(created)
  assert_eq(job.id, 1)
  assert_eq(job.name, "report")
  assert_eq(job.state, @ipp.JOB_PENDING)
  assert_eq(job.uri, "ipp://printer.local:631/ipp/print/jobs/1")
  let got = server.handle(client.request(@ipp.OP_GET_JOB_ATTRIBUTES))
  assert_eq(got.code, @ipp.STATUS_CLIENT_ERROR_NOT_FOUND)
  let get_request = client.request(@ipp.OP_GET_JOB_ATTRIBUTES)
  get_request.add(@ipp.TAG_OPERATION, [@ipp.attr("job-id", [@ipp.integer(1)])])
  let got = server.handle(get_request)
  assert_eq(@ipp.make_job_status(got).state, @ipp.JOB_PENDING)
  let cancel_request = client.request(@ipp.OP_CANCEL_JOB)
  cancel_request.add(@ipp.TAG_OPERATION, [@ipp.attr("job-id", [@ipp.integer(1)])])
  let canceled = server.handle(cancel_request)
  assert_eq(@ipp.make_job_status(canceled).state, @ipp.JOB_CANCELED)
  let jobs_request = client.request(@ipp.OP_GET_JOBS)
  jobs_request.add(@ipp.TAG_OPERATION, [
    @ipp.attr("which-jobs", [@ipp.keyword("all")]),
  ])
  let jobs = server.handle(jobs_request)
  assert_eq(jobs.code, @ipp.STATUS_OK)
  assert_eq(@ipp.make_job_status(jobs).id, 1)
  let print = server.handle(client.print_job("second", "application/pdf", []))
  assert_eq(@ipp.make_job_status(print).id, 2)
  let unsupported = server.handle(client.request(@ipp.OP_GET_PRINTER_SUPPORTED_VALUES))
  assert_eq(unsupported.code, @ipp.STATUS_SERVER_ERROR_OPERATION_NOT_SUPPORTED)
}

///|
test "ipp server http" {
  let server = test_server()
  let client = @ipp.Client::new("ipp://printer.local/ipp/print", "alice")
  let request = client.get_printer_attributes(["printer-name"])
  let body = request.encode()
  let http_request = @ipp.http_request(client.http_url, body)
  let response_bytes = server.handle_http(http_request.encode())
  let http = @ipp.parse_http_response(response_bytes)
  assert_eq(http.status, 200)
  assert_eq(http.reason, "OK")
  let response = @ipp.decode(http.body)
  assert_eq(response.code, @ipp.STATUS_OK)
  assert_eq(@ipp.parse_printer(response).name, "Test Printer")
  let cut = try {
    ignore(server.handle_http(@utf8.encode("POST /ipp/print HTTP/1.1")))
    false
  } catch {
    @ipp.IppError(_) => true
  }
  assert_true(cut, msg="a request without headers")
}


///|
test "ipp server print job document" {
  let server = test_server()
  let client = @ipp.Client::new("ipp://printer.local/ipp/print", "alice")
  let request = client.print_job("document", "application/pdf", [])
  let body = request.encode().to_array()
  for byte in b"%PDF-1.7" {
    body.push(byte)
  }
  let http = @ipp.http_request(client.http_url, Bytes::from_array(body)).encode()
  let response_bytes = server.handle_http(http)
  let http_response = @ipp.parse_http_response(response_bytes)
  let response = @ipp.decode(http_response.body)
  let job = @ipp.make_job_status(response)
  assert_eq(job.id, 1)
  assert_eq(job.state, @ipp.JOB_COMPLETED)
  assert_eq(job.impressions, 1)
  assert_eq(server.jobs[0].document, b"%PDF-1.7")
}


///|
test "ipp server get jobs filters" {
  let server = test_server()
  let client = @ipp.Client::new("ipp://printer.local/ipp/print", "alice")
  ignore(server.handle(client.create_job("pending", [])))
  let print = client.print_job("done", "application/pdf", [])
  ignore(server.handle_with_document(print, b"%PDF-1.7"))
  let all_request = client.request(@ipp.OP_GET_JOBS)
  all_request.add(@ipp.TAG_OPERATION, [@ipp.attr("which-jobs", [@ipp.keyword("all")])])
  let all = server.handle(all_request)
  assert_eq(@ipp.jobs_from_response(all).length(), 2)
  let completed_request = client.request(@ipp.OP_GET_JOBS)
  completed_request.add(@ipp.TAG_OPERATION, [
    @ipp.attr("which-jobs", [@ipp.keyword("completed")]),
  ])
  let completed = @ipp.jobs_from_response(server.handle(completed_request))
  assert_eq(completed.length(), 1)
  assert_eq(completed[0].name, "done")
  assert_eq(completed[0].state, @ipp.JOB_COMPLETED)
  let pending_request = client.request(@ipp.OP_GET_JOBS)
  let pending = @ipp.jobs_from_response(server.handle(pending_request))
  assert_eq(pending.length(), 1)
  assert_eq(pending[0].name, "pending")
  let limited = client.request(@ipp.OP_GET_JOBS)
  limited.add(@ipp.TAG_OPERATION, [
    @ipp.attr("which-jobs", [@ipp.keyword("all")]),
    @ipp.attr("limit", [@ipp.integer(1)]),
  ])
  assert_eq(@ipp.jobs_from_response(server.handle(limited)).length(), 1)
  let other = @ipp.Client::new("ipp://printer.local/ipp/print", "bob")
  let mine_request = other.request(@ipp.OP_GET_JOBS)
  mine_request.add(@ipp.TAG_OPERATION, [
    @ipp.attr("which-jobs", [@ipp.keyword("all")]),
    @ipp.attr("my-jobs", [@ipp.boolean(true)]),
  ])
  assert_eq(@ipp.jobs_from_response(server.handle(mine_request)).length(), 0)
}


///|
test "ipp server job state reasons" {
  let server = test_server()
  let client = @ipp.Client::new("ipp://printer.local/ipp/print", "alice")
  let created = server.handle(client.create_job("first", []))
  assert_eq(
    created.attr(@ipp.TAG_JOB, "job-state-reasons").unwrap().text(),
    "none",
  )
  let cancel = client.request(@ipp.OP_CANCEL_JOB)
  cancel.add(@ipp.TAG_OPERATION, [@ipp.attr("job-id", [@ipp.integer(1)])])
  let canceled = server.handle(cancel)
  assert_eq(
    canceled.attr(@ipp.TAG_JOB, "job-state-reasons").unwrap().text(),
    "job-canceled-by-user",
  )
  let print = server.handle_with_document(
    client.print_job("second", "application/pdf", []),
    b"%PDF-1.7",
  )
  assert_eq(
    print.attr(@ipp.TAG_JOB, "job-state-reasons").unwrap().text(),
    "job-completed-successfully",
  )
}


///|
test "ipp server counts PWG pages" {
  let server = test_server()
  let client = @ipp.Client::new("ipp://printer.local/ipp/print", "alice")
  let page : @raster.Page = { ..@raster.Page::new(2, 1, 300, 300, @raster.SGRAY_8) }
  let writer = @raster.Writer::new()
  writer.start_page(page)
  writer.write_row(Bytes::from_array([1, 2]))
  let pwg = writer.close()
  let response = server.handle_with_document(
    client.print_job("raster", "image/pwg-raster", []),
    pwg,
  )
  let job = @ipp.make_job_status(response)
  assert_eq(job.state, @ipp.JOB_COMPLETED)
  assert_eq(job.impressions, 1)
  let bad = server.handle_with_document(
    client.print_job("broken", "image/pwg-raster", []),
    b"RaS2broken",
  )
  let broken = @ipp.make_job_status(bad)
  assert_eq(broken.state, @ipp.JOB_ABORTED)
  assert_eq(
    bad.attr(@ipp.TAG_JOB, "job-state-reasons").unwrap().text(),
    "job-aborted-by-system",
  )
}

///|
test "ipp server accepts job URIs" {
  let server = test_server()
  let client = @ipp.Client::new("ipp://printer.local/ipp/print", "alice")
  let created = server.handle(client.create_job("report", []))
  let job = @ipp.make_job_status(created)
  let get_request = client.request(@ipp.OP_GET_JOB_ATTRIBUTES)
  get_request.add(@ipp.TAG_OPERATION, [@ipp.attr("job-uri", [@ipp.uri(job.uri)])])
  let got = server.handle(get_request)
  assert_eq(got.code, @ipp.STATUS_OK)
  assert_eq(@ipp.make_job_status(got).id, job.id)
  let cancel_request = client.request(@ipp.OP_CANCEL_JOB)
  cancel_request.add(@ipp.TAG_OPERATION, [@ipp.attr("job-uri", [@ipp.uri(job.uri)])])
  let canceled = server.handle(cancel_request)
  assert_eq(@ipp.make_job_status(canceled).state, @ipp.JOB_CANCELED)
}

///|
test "ipp server counts URF pages" {
  let server = test_server()
  let client = @ipp.Client::new("ipp://printer.local/ipp/print", "alice")
  let page : @raster.Page = { ..@raster.Page::new(2, 1, 300, 300, @raster.SGRAY_8) }
  let writer = @raster.Writer::new_urf(1)
  writer.start_page(page)
  writer.write_row(Bytes::from_array([1, 2]))
  let urf = writer.close()
  let response = server.handle_with_document(
    client.print_job("urf", "image/urf", []),
    urf,
  )
  let job = @ipp.make_job_status(response)
  assert_eq(job.state, @ipp.JOB_COMPLETED)
  assert_eq(job.impressions, 1)
}

///|
test "ipp server counts PDF pages" {
  let server = test_server()
  let client = @ipp.Client::new("ipp://printer.local/ipp/print", "alice")
  let pdf = @base64.decode(
    "JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgPj4KZW5kb2JqCjIgMCBvYmoKPDwgL1R5cGUgL1BhZ2VzIC9LaWRzIFszIDAgUl0gL0NvdW50IDEgPj4KZW5kb2JqCjMgMCBvYmoKPDwgL1R5cGUgL1BhZ2UgL1BhcmVudCAyIDAgUiAvTWVkaWFCb3ggWzAgMCAyMDAgMTAwXSAvQ29udGVudHMgNCAwIFIgPj4KZW5kb2JqCjQgMCBvYmoKPDwgL0xlbmd0aCAxOCA+PgpzdHJlYW0KMC41IDAuNSAxMCAxMCByZSBmCmVuZHN0cmVhbQplbmRvYmoKeHJlZgowIDUKMDAwMDAwMDAwMCA2NTUzNSBmIAowMDAwMDAwMDA5IDAwMDAwIG4gCjAwMDAwMDAwNTggMDAwMDAgbiAKMDAwMDAwMDExNSAwMDAwMCBuIAowMDAwMDAwMjAyIDAwMDAwIG4gCnRyYWlsZXIKPDwgL1NpemUgNSAvUm9vdCAxIDAgUiA+PgpzdGFydHhyZWYKMjcwCiUlRU9GCg==",
  )
  let response = server.handle_with_document(
    client.print_job("pdf", "application/pdf", []),
    pdf,
  )
  let job = @ipp.make_job_status(response)
  assert_eq(job.state, @ipp.JOB_COMPLETED)
  assert_eq(job.impressions, 1)
}

///|
test "ipp server counts multiple PDF pages" {
  let server = test_server()
  let client = @ipp.Client::new("ipp://printer.local/ipp/print", "alice")
  let pdf = @base64.decode(
    "JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgPj4KZW5kb2JqCjIgMCBvYmoKPDwgL1R5cGUgL1BhZ2VzIC9LaWRzIFszIDAgUiA0IDAgUl0gL0NvdW50IDIgPj4KZW5kb2JqCjMgMCBvYmoKPDwgL1R5cGUgL1BhZ2UgL1BhcmVudCAyIDAgUiAvTWVkaWFCb3ggWzAgMCAyMDAgMTAwXSAvQ29udGVudHMgNSAwIFIgPj4KZW5kb2JqCjQgMCBvYmoKPDwgL1R5cGUgL1BhZ2UgL1BhcmVudCAyIDAgUiAvTWVkaWFCb3ggWzAgMCAzMDAgMTUwXSAvQ29udGVudHMgNiAwIFIgPj4KZW5kb2JqCjUgMCBvYmoKPDwgL0xlbmd0aCAxOCA+PgpzdHJlYW0KMC41IDAuNSAxMCAxMCByZSBmCmVuZHN0cmVhbQplbmRvYmoKNiAwIG9iago8PCAvTGVuZ3RoIDE4ID4+CnN0cmVhbQowLjIgMC4yIDIwIDIwIHJlIGYKZW5kc3RyZWFtCmVuZG9iagp4cmVmCjAgNwowMDAwMDAwMDAwIDY1NTM1IGYgCjAwMDAwMDAwMDkgMDAwMDAgbiAKMDAwMDAwMDA1OCAwMDAwMCBuIAowMDAwMDAwMTIxIDAwMDAwIG4gCjAwMDAwMDAyMDggMDAwMDAgbiAKMDAwMDAwMDI5NSAwMDAwMCBuIAowMDAwMDAwMzYzIDAwMDAwIG4gCnRyYWlsZXIKPDwgL1NpemUgNyAvUm9vdCAxIDAgUiA+PgpzdGFydHhyZWYKNDMxCiUlRU9GCg==",
  )
  let response = server.handle_with_document(
    client.print_job("pdf2", "application/pdf", []),
    pdf,
  )
  let job = @ipp.make_job_status(response)
  assert_eq(job.state, @ipp.JOB_COMPLETED)
  assert_eq(job.impressions, 2)
}

///|
test "ipp server accepts a send-document request" {
  let server = test_server()
  let client = @ipp.Client::new("ipp://printer.local/ipp/print", "alice")
  ignore(server.handle(client.create_job("report", [])))
  let request = client.send_document(1, "report.pdf", "application/pdf", true)
  let response = server.handle_with_document(request, b"%PDF-1.7")
  let job = @ipp.make_job_status(response)
  assert_eq(job.id, 1)
  assert_eq(job.state, @ipp.JOB_COMPLETED)
  assert_eq(job.impressions, 1)
  assert_eq(server.jobs[0].document, b"%PDF-1.7")
}

///|
test "ipp server appends send-document chunks" {
  let server = test_server()
  let client = @ipp.Client::new("ipp://printer.local/ipp/print", "alice")
  ignore(server.handle(client.create_job("chunks", [])))
  let first = client.send_document(1, "report.pdf", "application/pdf", false)
  let partial = server.handle_with_document(first, b"%PDF-1.")
  let partial_job = @ipp.make_job_status(partial)
  assert_eq(partial_job.state, @ipp.JOB_PROCESSING)
  assert_eq(server.jobs[0].document, b"%PDF-1.")
  let last = client.send_document(1, "report.pdf", "application/pdf", true)
  let done = server.handle_with_document(last, b"7")
  let job = @ipp.make_job_status(done)
  assert_eq(job.state, @ipp.JOB_COMPLETED)
  assert_eq(job.impressions, 1)
  assert_eq(server.jobs[0].document, b"%PDF-1.7")
}

///|
test "ipp server filters requested job attributes" {
  let server = test_server()
  let client = @ipp.Client::new("ipp://printer.local/ipp/print", "alice")
  ignore(server.handle(client.create_job("filtered", [])))
  let request = client.request(@ipp.OP_GET_JOB_ATTRIBUTES)
  request.add(@ipp.TAG_OPERATION, [
    @ipp.attr("job-id", [@ipp.integer(1)]),
    @ipp.attr("requested-attributes", [@ipp.keyword("job-state")]),
  ])
  let response = server.handle(request)
  let group = match response.group(@ipp.TAG_JOB) {
    Some(group) => group
    None => fail("missing job group")
  }
  assert_eq(group.attrs.length(), 1)
  assert_eq(group.attrs[0].name, "job-state")
}

