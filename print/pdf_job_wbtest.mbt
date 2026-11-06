///|
fn print_sample_bdf() -> Bytes raise {
  let writer = @core.DocumentWriter::new()
  let builder = @core.ObjectBuilder::new()
  let font = builder.add_font({
    hash: None,
    family: "Example",
    weight: 400,
    style: 0,
  })
  builder.font(font, 12.0F)
  builder.fill_text("Hello print", 20.0F, 40.0F, 80.0F)
  let object_hash = writer.add_part("obj", builder.encode())
  writer.add_view(
    Json::object({
      "id": Json::string("page1"),
      "kind": Json::string("fixed"),
      "pages": Json::array([
        Json::object({
          "w": Json::number(200.0),
          "h": Json::number(200.0),
          "layers": Json::array([
            Json::object({
              "role": Json::string(""),
              "obj": Json::string(object_hash),
            }),
          ]),
        }),
      ]),
    }),
  )
  writer.write_single()
}

///|
fn print_http_response(body : Bytes) -> Bytes {
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
test "print a BDF document as PDF" {
  let bdf = print_sample_bdf()
  let pdf = bdf_pdf(bdf)
  assert_eq(pdf.pages, 1)
  assert_true(pdf.bytes.has_prefix(b"%PDF-1.7"))
  let client = @ipp.Client::new("ipp://printer.local/ipp/print", "alice")
  let response = @ipp.new_response(@ipp.STATUS_OK, 1, "", "")
  response.add(@ipp.TAG_JOB, [
    @ipp.attr("job-id", [@ipp.integer(4)]),
    @ipp.attr("job-state", [@ipp.enum_value(@ipp.JOB_PENDING)]),
  ])
  let http = print_http_response(response.encode())
  let captured : Array[Bytes] = []
  let job = print_bdf(client, bdf, "report", fn(bytes) {
    captured.push(bytes)
    Some(http)
  })
  assert_eq(job.id, 4)
  assert_eq(captured.length(), 1)
  assert_true(captured[0].find(b"%PDF-1.7"[:]) is Some(_))
}
