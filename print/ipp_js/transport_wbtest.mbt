///|
extern "js" fn install_fake_fetch(body : Bytes) -> Unit =
  #|(body) => {
  #|  globalThis.fetch = async () => new Response(body, {
  #|    status: 200,
  #|    statusText: 'OK',
  #|    headers: { 'Content-Type': 'application/ipp' },
  #|  });
  #|}

///|
extern "js" fn install_failing_fetch() -> Unit =
  #|() => { globalThis.fetch = async () => { throw new Error('offline'); }; }

///|
async test "fetch transport sends an IPP request" {
  let client = @ipp.Client::new("ipp://printer.local/ipp/print", "alice")
  let request = client.get_printer_attributes(["printer-name"])
  let response = @ipp.new_response(@ipp.STATUS_OK, request.request_id, "", "")
  response.add(@ipp.TAG_PRINTER, [@ipp.attr("printer-name", [@ipp.name("office")])])
  install_fake_fetch(response.encode())
  let answer = send_async(client, request)
  assert_eq(answer.code, @ipp.STATUS_OK)
  let printer = @ipp.parse_printer(answer)
  assert_eq(printer.name, "office")
  install_failing_fetch()
  let failed = try {
    ignore(send_async(client, request))
    false
  } catch {
    @ipp.IppError(_) => true
    _ => false
  }
  assert_true(failed, msg="a failed fetch")
}

///|
extern "js" fn install_capturing_fetch(response : Bytes) -> Unit =
  #|(response) => {
  #|  globalThis.__ippBody = null;
  #|  globalThis.fetch = async (_url, options) => {
  #|    globalThis.__ippBody = options.body;
  #|    return new Response(response, {
  #|      status: 200,
  #|      statusText: 'OK',
  #|      headers: { 'Content-Type': 'application/ipp' },
  #|    });
  #|  };
  #|}

///|
extern "js" fn captured_body() -> Bytes =
  #|() => globalThis.__ippBody

///|
async test "fetch transport prints a PDF" {
  let client = @ipp.Client::new("ipp://printer.local/ipp/print", "alice")
  let response = @ipp.new_response(@ipp.STATUS_OK, 1, "", "")
  response.add(@ipp.TAG_JOB, [
    @ipp.attr("job-id", [@ipp.integer(8)]),
    @ipp.attr("job-state", [@ipp.enum_value(@ipp.JOB_PENDING)]),
  ])
  install_capturing_fetch(response.encode())
  let job = print_pdf_async(client, "report", b"%PDF-1.7 test body")
  assert_eq(job.id, 8)
  assert_true(captured_body().find(b"%PDF-1.7"[:]) is Some(_))
}


///|
async test "fetch transport lists jobs" {
  let client = @ipp.Client::new("ipp://printer.local/ipp/print", "alice")
  let response = @ipp.new_response(@ipp.STATUS_OK, 1, "", "")
  response.add(@ipp.TAG_JOB, [
    @ipp.attr("job-id", [@ipp.integer(2)]),
    @ipp.attr("job-uri", [@ipp.uri("ipp://printer.local/jobs/2")]),
    @ipp.attr("job-state", [@ipp.enum_value(@ipp.JOB_COMPLETED)]),
  ])
  install_fake_fetch(response.encode())
  let jobs = get_jobs_async(client, "all", true)
  assert_eq(jobs.length(), 1)
  assert_eq(jobs[0].id, 2)
  assert_eq(jobs[0].state, @ipp.JOB_COMPLETED)
}

