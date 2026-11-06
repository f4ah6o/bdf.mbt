///|
pub(all) struct Job {
  id : Int
  uri : String
  name : String
  user : String
  mut state : Int
  mut document : Bytes
  mut impressions : Int
  copies : Int
  attrs : Array[@ipp.Attribute]
}

///|
pub(all) struct Server {
  printer_name : String
  printer_uri : String
  printer_attrs : Array[@ipp.Attribute]
  jobs : Array[Job]
  mut next_job : Int
}

///|
pub fn Server::new(
  printer_uri : String,
  printer_attrs : Array[@ipp.Attribute],
) -> Server {
  let name = match @ipp.find_attr(printer_attrs, "printer-name") {
    Some(attribute) => attribute.text()
    None => "bdf"
  }
  {
    printer_name: name,
    printer_uri,
    printer_attrs,
    jobs: [],
    next_job: 1,
  }
}

///|
fn response_for(request : @ipp.Message, status : Int) -> @ipp.Message {
  let charset = match request.attr(@ipp.TAG_OPERATION, "attributes-charset") {
    Some(attribute) => attribute.text()
    None => "utf-8"
  }
  let language = match request.attr(@ipp.TAG_OPERATION, "attributes-natural-language") {
    Some(attribute) => attribute.text()
    None => "en"
  }
  let response = @ipp.new_response(status, request.request_id, charset, language)
  response.major = request.major
  response.minor = request.minor
  response
}

///|
fn state_reason(state : Int) -> String {
  if state == @ipp.JOB_COMPLETED {
    "job-completed-successfully"
  } else if state == @ipp.JOB_CANCELED {
    "job-canceled-by-user"
  } else if state == @ipp.JOB_ABORTED {
    "job-aborted-by-system"
  } else if state == @ipp.JOB_PROCESSING {
    "job-printing"
  } else {
    "none"
  }
}

///|
fn job_attrs(server : Server, job : Job) -> Array[@ipp.Attribute] {
  [
    @ipp.attr("job-id", [@ipp.integer(job.id)]),
    @ipp.attr("job-uri", [@ipp.uri(job.uri)]),
    @ipp.attr("job-name", [@ipp.name(job.name)]),
    @ipp.attr("job-state", [@ipp.enum_value(job.state)]),
    @ipp.attr("job-state-reasons", [@ipp.keyword(state_reason(job.state))]),
    @ipp.attr("job-printer-uri", [@ipp.uri(server.printer_uri)]),
    @ipp.attr("job-originating-user-name", [@ipp.name(job.user)]),
    @ipp.attr("job-impressions-completed", [@ipp.integer(job.impressions)]),
    @ipp.attr("copies", [@ipp.integer(job.copies)]),
  ]
}

///|
fn Server::find_job(self : Server, id : Int) -> Job? {
  for job in self.jobs {
    if job.id == id {
      return Some(job)
    }
  }
  None
}

///|
fn Server::create_job(self : Server, request : @ipp.Message) -> Job {
  let id = self.next_job
  self.next_job += 1
  let name = match request.attr(@ipp.TAG_OPERATION, "job-name") {
    Some(attribute) => attribute.text()
    None => "job-" + id.to_string()
  }
  let user = match request.attr(@ipp.TAG_OPERATION, "requesting-user-name") {
    Some(attribute) => attribute.text()
    None => ""
  }
  let job : Job = {
    id,
    uri: self.printer_uri + "/jobs/" + id.to_string(),
    name,
    user,
    state: @ipp.JOB_PENDING,
    document: Bytes::new(0),
    impressions: 0,
    copies: request_copies(request),
    attrs: [],
  }
  self.jobs.push(job)
  job
}

///|
fn request_job_id(request : @ipp.Message) -> Int {
  match request.attr(@ipp.TAG_OPERATION, "job-id") {
    Some(attribute) => attribute.int().unwrap_or(-1)
    None =>
      match request.attr(@ipp.TAG_OPERATION, "job-uri") {
        Some(attribute) => {
          let uri = attribute.text()
          let mut start = 0
          for i in 0..<uri.length() {
            if uri[i].to_char().unwrap() == '/' {
              start = i + 1
            }
          }
          if start >= uri.length() {
            -1
          } else {
            @string.parse_int(uri[start:].to_owned()) catch {
              _ => -1
            }
          }
        }
        None => -1
      }
  }
}

///|
fn pdf_page_count(data : Bytes) -> Int {
  let result = @pdf.convert(data) catch {
    _ => return 0
  }
  result.pages
}

///|
fn request_copies(request : @ipp.Message) -> Int {
  match request.attr(@ipp.TAG_OPERATION, "copies") {
    Some(attribute) => attribute.int().unwrap_or(1)
    None =>
      match request.attr(@ipp.TAG_JOB, "copies") {
        Some(attribute) => attribute.int().unwrap_or(1)
        None => 1
      }
  }
}

///|
fn Server::copies_supported(self : Server, request : @ipp.Message) -> Bool {
  let copies = request_copies(request)
  if copies <= 0 {
    return false
  }
  match @ipp.find_attr(self.printer_attrs, "copies-supported") {
    Some(attribute) => {
      let ranges = attribute.ranges()
      if ranges.is_empty() {
        true
      } else {
        ranges.any(fn(range) { copies >= range.0 && copies <= range.1 })
      }
    }
    None => true
  }
}

///|
fn Server::format_supported(self : Server, format : String) -> Bool {
  if format == "" {
    return true
  }
  match @ipp.find_attr(self.printer_attrs, "document-format-supported") {
    Some(attribute) => attribute.has(format)
    None => false
  }
}

///|
fn filter_job_attrs(attrs : Array[@ipp.Attribute], requested : Array[String]) -> Array[@ipp.Attribute] {
  if requested.is_empty() || requested.contains("all") || requested.contains("job-template") {
    return attrs
  }
  attrs.filter(fn(attribute) { requested.contains(attribute.name) })
}

///|
fn requested_job_attrs(
  server : Server,
  request : @ipp.Message,
  job : Job,
) -> Array[@ipp.Attribute] {
  let requested = match request.attr(@ipp.TAG_OPERATION, "requested-attributes") {
    Some(attribute) => attribute.strings()
    None => []
  }
  filter_job_attrs(job_attrs(server, job), requested)
}

///|
fn append_document(current : Bytes, next : Bytes) -> Bytes {
  if current.length() == 0 {
    return next
  }
  let buffer = @buffer.Buffer()
  buffer.write_bytes(current)
  buffer.write_bytes(next)
  buffer.to_bytes()
}

///|
/// Handle one IPP request for the server's printer.
pub fn Server::handle_with_document(
  self : Server,
  request : @ipp.Message,
  document : Bytes,
) -> @ipp.Message {
  if request.code == @ipp.OP_GET_PRINTER_ATTRIBUTES {
    let response = response_for(request, @ipp.STATUS_OK)
    let requested = match request.attr(@ipp.TAG_OPERATION, "requested-attributes") {
      Some(attribute) => attribute.strings()
      None => ["all"]
    }
    let filtered = @ipp.filter(
      self.printer_attrs,
      requested,
      @ipp.printer_groups(self.printer_attrs),
    )
    response.add(@ipp.TAG_PRINTER, filtered)
    response
  } else if request.code == @ipp.OP_VALIDATE_JOB {
    let format = match request.attr(@ipp.TAG_OPERATION, "document-format") {
      Some(attribute) => attribute.text()
      None => ""
    }
    response_for(
      request,
      if self.format_supported(format) && self.copies_supported(request) {
        @ipp.STATUS_OK
      } else {
        @ipp.STATUS_CLIENT_ERROR_BAD_REQUEST
      },
    )
  } else if request.code == @ipp.OP_CREATE_JOB {
    if !self.copies_supported(request) {
      return response_for(request, @ipp.STATUS_CLIENT_ERROR_BAD_REQUEST)
    }
    let job = self.create_job(request)
    let response = response_for(request, @ipp.STATUS_OK)
    response.add(@ipp.TAG_JOB, requested_job_attrs(self, request, job))
    response
  } else if request.code == @ipp.OP_PRINT_JOB {
    let format = match request.attr(@ipp.TAG_OPERATION, "document-format") {
      Some(attribute) => attribute.text()
      None => ""
    }
    if !self.copies_supported(request) ||
      (document.length() > 0 && !self.format_supported(format)) {
      return response_for(request, @ipp.STATUS_CLIENT_ERROR_BAD_REQUEST)
    }
    let job = self.create_job(request)
    if document.length() > 0 {
      job.document = document
      let format = match request.attr(@ipp.TAG_OPERATION, "document-format") {
        Some(attribute) => attribute.text()
        None => ""
      }
      let raster_pages = if format.contains("pwg") || document.has_prefix(b"RaS2") {
        @raster.read(document) catch {
          _ => {
            job.state = @ipp.JOB_ABORTED
            job.impressions = 0
            let response = response_for(request, @ipp.STATUS_OK)
            response.add(@ipp.TAG_JOB, requested_job_attrs(self, request, job))
            return response
          }
        }
      } else if format.contains("urf") || document.has_prefix(b"UNIRAST") {
        @raster.read_urf(document) catch {
          _ => {
            job.state = @ipp.JOB_ABORTED
            job.impressions = 0
            let response = response_for(request, @ipp.STATUS_OK)
            response.add(@ipp.TAG_JOB, requested_job_attrs(self, request, job))
            return response
          }
        }
      } else {
        []
      }
      if raster_pages.length() > 0 {
        job.state = @ipp.JOB_COMPLETED
        job.impressions = raster_pages.length()
      } else {
        let pdf_pages = if format.contains("pdf") ||
          document.has_prefix(b"%PDF-") {
          pdf_page_count(document)
        } else {
          0
        }
        job.state = @ipp.JOB_COMPLETED
        job.impressions = if pdf_pages > 0 { pdf_pages } else { 1 }
      }
    }
    let response = response_for(request, @ipp.STATUS_OK)
    response.add(@ipp.TAG_JOB, requested_job_attrs(self, request, job))
    response
  } else if request.code == @ipp.OP_SEND_DOCUMENT {
    let id = request_job_id(request)
    match self.find_job(id) {
      Some(job) => {
        if @ipp.job_state_done(job.state) {
          return response_for(request, @ipp.STATUS_CLIENT_ERROR_NOT_POSSIBLE)
        }
        let last = match request.attr(@ipp.TAG_OPERATION, "last-document") {
          Some(attribute) => attribute.bool().unwrap_or(true)
          None => true
        }
        let format = match request.attr(@ipp.TAG_OPERATION, "document-format") {
          Some(attribute) => attribute.text()
          None => ""
        }
        if !self.copies_supported(request) ||
          (document.length() > 0 && !self.format_supported(format)) {
          return response_for(request, @ipp.STATUS_CLIENT_ERROR_BAD_REQUEST)
        }
        if document.length() > 0 {
          job.document = append_document(job.document, document)
          if !last {
            job.state = @ipp.JOB_PROCESSING
            let response = response_for(request, @ipp.STATUS_OK)
            response.add(@ipp.TAG_JOB, requested_job_attrs(self, request, job))
            return response
          }
          let raster_pages = if format.contains("pwg") ||
            job.document.has_prefix(b"RaS2") {
            @raster.read(job.document) catch {
              _ => {
                job.state = @ipp.JOB_ABORTED
                job.impressions = 0
                let response = response_for(request, @ipp.STATUS_OK)
                response.add(@ipp.TAG_JOB, requested_job_attrs(self, request, job))
                return response
              }
            }
          } else if format.contains("urf") ||
            job.document.has_prefix(b"UNIRAST") {
            @raster.read_urf(job.document) catch {
              _ => {
                job.state = @ipp.JOB_ABORTED
                job.impressions = 0
                let response = response_for(request, @ipp.STATUS_OK)
                response.add(@ipp.TAG_JOB, requested_job_attrs(self, request, job))
                return response
              }
            }
          } else {
            []
          }
          if raster_pages.length() > 0 {
            job.state = @ipp.JOB_COMPLETED
            job.impressions = raster_pages.length()
          } else {
            let pdf_pages = if format.contains("pdf") ||
              job.document.has_prefix(b"%PDF-") {
              pdf_page_count(job.document)
            } else {
              0
            }
            job.state = @ipp.JOB_COMPLETED
            job.impressions = if pdf_pages > 0 { pdf_pages } else { 1 }
          }
        }
        let response = response_for(request, @ipp.STATUS_OK)
        response.add(@ipp.TAG_JOB, requested_job_attrs(self, request, job))
        response
      }
      None => response_for(request, @ipp.STATUS_CLIENT_ERROR_NOT_FOUND)
    }
  } else if request.code == @ipp.OP_GET_JOB_ATTRIBUTES {
    let id = request_job_id(request)
    match self.find_job(id) {
      Some(job) => {
        let response = response_for(request, @ipp.STATUS_OK)
        response.add(@ipp.TAG_JOB, requested_job_attrs(self, request, job))
        response
      }
      None => response_for(request, @ipp.STATUS_CLIENT_ERROR_NOT_FOUND)
    }
  } else if request.code == @ipp.OP_CANCEL_JOB {
    let id = request_job_id(request)
    match self.find_job(id) {
      Some(job) => {
        if @ipp.job_state_done(job.state) {
          return response_for(request, @ipp.STATUS_CLIENT_ERROR_NOT_POSSIBLE)
        }
        job.state = @ipp.JOB_CANCELED
        let response = response_for(request, @ipp.STATUS_OK)
        response.add(@ipp.TAG_JOB, requested_job_attrs(self, request, job))
        response
      }
      None => response_for(request, @ipp.STATUS_CLIENT_ERROR_NOT_FOUND)
    }
  } else if request.code == @ipp.OP_GET_JOBS {
    let response = response_for(request, @ipp.STATUS_OK)
    let which = match request.attr(@ipp.TAG_OPERATION, "which-jobs") {
      Some(attribute) => attribute.text()
      None => "not-completed"
    }
    let valid_which = [
      "all", "completed", "not-completed", "aborted", "canceled", "pending",
      "processing",
    ]
    if !valid_which.contains(which) {
      return response_for(request, @ipp.STATUS_CLIENT_ERROR_BAD_REQUEST)
    }
    let my_jobs = match request.attr(@ipp.TAG_OPERATION, "my-jobs") {
      Some(attribute) => attribute.bool().unwrap_or(false)
      None => false
    }
    let user = match request.attr(@ipp.TAG_OPERATION, "requesting-user-name") {
      Some(attribute) => attribute.text()
      None => ""
    }
    let limit = match request.attr(@ipp.TAG_OPERATION, "limit") {
      Some(attribute) => attribute.int().unwrap_or(0)
      None => 0
    }
    if limit < 0 {
      return response_for(request, @ipp.STATUS_CLIENT_ERROR_BAD_REQUEST)
    }
    let requested = match request.attr(@ipp.TAG_OPERATION, "requested-attributes") {
      Some(attribute) => attribute.strings()
      None => []
    }
    let mut added = 0
    for job in self.jobs {
      let done = @ipp.job_state_done(job.state)
      let take = if which == "completed" {
        job.state == @ipp.JOB_COMPLETED
      } else if which == "aborted" {
        job.state == @ipp.JOB_ABORTED
      } else if which == "canceled" {
        job.state == @ipp.JOB_CANCELED
      } else if which == "pending" {
        job.state == @ipp.JOB_PENDING
      } else if which == "processing" {
        job.state == @ipp.JOB_PROCESSING
      } else if which == "all" {
        true
      } else {
        !done
      }
      if take && (!my_jobs || job.user == user) && (limit <= 0 || added < limit) {
        response.add(@ipp.TAG_JOB, filter_job_attrs(job_attrs(self, job), requested))
        added += 1
      }
    }
    response
  } else {
    response_for(request, @ipp.STATUS_SERVER_ERROR_OPERATION_NOT_SUPPORTED)
  }
}

///|
fn server_http_body(data : Bytes) -> Bytes raise @ipp.IppError {
  let text = @utf8.decode_lossy(data)
  let head_end = match text.find("\r\n\r\n") {
    Some(index) => index
    None => {
      @ipp.fail("server: an HTTP request without a header end")
      0
    }
  }
  let head = text[:head_end]
  let mut length = -1
  for line in head.split("\r\n") {
    let lower = line.to_lower()
    if lower.has_prefix("content-length:") {
      length = @string.parse_int(line[15:].trim()) catch {
        _ => -1
      }
    }
  }
  let body = data[head_end + 4:]
  if length >= 0 && body.length() != length {
    @ipp.fail("server: the HTTP body does not match Content-Length")
  }
  body.to_bytes()
}

///|
fn server_reason(status : Int) -> String {
  if status == @ipp.STATUS_OK {
    "OK"
  } else if @ipp.status_is_client_error(status) {
    "Bad Request"
  } else {
    "Internal Server Error"
  }
}

///|
/// Handle an HTTP request that carries one IPP request, and return the
/// HTTP response that carries the answer.
pub fn Server::handle(self : Server, request : @ipp.Message) -> @ipp.Message {
  self.handle_with_document(request, Bytes::new(0))
}

///|
/// Handle an HTTP request that carries one IPP request, and return the
/// HTTP response that carries the answer.
pub fn Server::handle_http(self : Server, request_bytes : Bytes) -> Bytes raise @ipp.IppError {
  let body = server_http_body(request_bytes)
  let (request, consumed) = @ipp.decode_prefix(body)
  let document = if consumed < body.length() {
    body[consumed:].to_owned()
  } else {
    Bytes::new(0)
  }
  let response = self.handle_with_document(request, document)
  let response_body = response.encode()
  let http_status = if @ipp.status_is_success(response.code) {
    200
  } else if @ipp.status_is_client_error(response.code) {
    400
  } else {
    500
  }
  let head = "HTTP/1.1 " +
    http_status.to_string() +
    " " +
    server_reason(response.code) +
    "\r\nContent-Type: application/ipp\r\nContent-Length: " +
    response_body.length().to_string() +
    "\r\nConnection: close\r\n\r\n"
  let out = @utf8.encode(head).to_array()
  for byte in response_body {
    out.push(byte)
  }
  Bytes::from_array(out)
}

