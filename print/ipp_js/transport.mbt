///|
// The fetch transport of the IPP client for JavaScript.
extern "js" fn fetch_ipp(url : String, body : Bytes) -> @js_async.Promise[Bytes] =
  #|(url, body) => fetch(url, {
  #|  method: 'POST',
  #|  headers: { 'Content-Type': 'application/ipp' },
  #|  body
  #|}).then(async response => {
  #|  const body = new Uint8Array(await response.arrayBuffer());
  #|  const encoder = new TextEncoder();
  #|  const contentType = response.headers.get('content-type') ?? 'application/ipp';
  #|  const head = encoder.encode(
  #|    'HTTP/1.1 ' + response.status + ' ' + response.statusText + '\r\n' +
  #|    'Content-Type: ' + contentType + '\r\n' +
  #|    'Content-Length: ' + body.length + '\r\n\r\n'
  #|  );
  #|  const out = new Uint8Array(head.length + body.length);
  #|  out.set(head);
  #|  out.set(body, head.length);
  #|  return out;
  #|});

///|
/// Post an IPP request from JavaScript and decode the printer's answer.
pub async fn send_async(
  client : @ipp.Client,
  message : @ipp.Message,
) -> @ipp.Message raise @ipp.IppError {
  let body = message.encode()
  let request = @ipp.http_request(client.http_url, body)
  let response_bytes = try {
    fetch_ipp(client.http_url, request.encode()).wait()
  } catch {
    _ => {
      @ipp.fail("ipp: fetch failed")
      Bytes::new(0)
    }
  }
  let response = @ipp.parse_http_response(response_bytes)
  if response.status < 200 || response.status >= 300 {
    if response.body.length() == 0 {
      @ipp.fail("ipp: HTTP status " + response.status.to_string())
    }
  }
  @ipp.decode(response.body)
}

///|
pub async fn fetch_printer_async(
  client : @ipp.Client,
) -> @ipp.Printer raise @ipp.IppError {
  let response = send_async(client, client.get_printer_attributes([]))
  @ipp.check_response(response) catch {
    @ipp.StatusError(_, text) => @ipp.fail(text)
  }
  let printer = @ipp.parse_printer(response)
  { ..printer, uri: client.printer_uri }
}

///|
/// Post an IPP request with a document after it (Print-Job, Send-Document).
pub async fn send_document_async(
  client : @ipp.Client,
  message : @ipp.Message,
  document : Bytes,
) -> @ipp.Message raise @ipp.IppError {
  let head = message.encode()
  let body = head.to_array()
  for byte in document {
    body.push(byte)
  }
  let request = @ipp.http_request(client.http_url, Bytes::from_array(body))
  let response_bytes = try {
    fetch_ipp(client.http_url, request.encode()).wait()
  } catch {
    _ => {
      @ipp.fail("ipp: fetch failed")
      Bytes::new(0)
    }
  }
  let response = @ipp.parse_http_response(response_bytes)
  if response.status < 200 || response.status >= 300 {
    if response.body.length() == 0 {
      @ipp.fail("ipp: HTTP status " + response.status.to_string())
    }
  }
  @ipp.decode(response.body)
}

///|
/// Print a PDF document through fetch.
pub async fn print_pdf_async(
  client : @ipp.Client,
  name_value : String,
  document : Bytes,
) -> @ipp.JobStatus raise @ipp.IppError {
  let request = client.print_job(name_value, "application/pdf", [])
  let response = send_document_async(client, request, document)
  @ipp.check_response(response) catch {
    @ipp.StatusError(_, text) => @ipp.fail(text)
  }
  @ipp.make_job_status(response)
}


///|
pub async fn get_jobs_async(
  client : @ipp.Client,
  which : String,
  mine : Bool,
) -> Array[@ipp.JobStatus] raise @ipp.IppError {
  let request = client.request(@ipp.OP_GET_JOBS)
  let attrs : Array[@ipp.Attribute] = []
  if which != "" {
    attrs.push(@ipp.attr("which-jobs", [@ipp.keyword(which)]))
  }
  if mine {
    attrs.push(@ipp.attr("my-jobs", [@ipp.boolean(true)]))
  }
  attrs.push(@ipp.attr("requested-attributes", [
    @ipp.keyword("job-id"),
    @ipp.keyword("job-uri"),
  ]))
  request.add(@ipp.TAG_OPERATION, attrs)
  let response = send_async(client, request)
  @ipp.check_response(response) catch {
    @ipp.StatusError(_, text) => @ipp.fail(text)
  }
  @ipp.jobs_from_response(response)
}

