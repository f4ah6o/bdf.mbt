///|
// A transport-agnostic CUPS/IPP client: it builds requests, and a
// transport sends them.
pub fn printer_attributes() -> Array[String] {
  [
    "printer-uri-supported",
    "uri-authentication-supported",
    "uri-security-supported",
    "printer-name",
    "printer-info",
    "printer-make-and-model",
    "printer-location",
    "printer-uuid",
    "printer-device-id",
    "printer-state",
    "queued-job-count",
    "printer-state-reasons",
    "printer-state-message",
    "printer-is-accepting-jobs",
    "ipp-versions-supported",
    "operations-supported",
    "printer-config-change-time",
    "document-format-supported",
    "document-format-default",
    "pdf-versions-supported",
    "media-supported",
    "media-ready",
    "media-default",
    "media-source-supported",
    "media-type-supported",
    "media-col-supported",
    "sides-supported",
    "sides-default",
    "print-color-mode-supported",
    "print-color-mode-default",
    "print-quality-supported",
    "print-quality-default",
    "printer-resolution-supported",
    "printer-resolution-default",
    "copies-supported",
    "copies-default",
    "page-ranges-supported",
    "print-scaling-supported",
    "print-scaling-default",
    "number-up-supported",
    "orientation-requested-supported",
    "multiple-document-handling-supported",
    "finishings-supported",
    "finishings-default",
    "output-bin-supported",
    "output-bin-default",
    "pwg-raster-document-resolution-supported",
    "pwg-raster-document-type-supported",
    "pwg-raster-document-sheet-back",
    "urf-supported",
    "pclm-strip-height-preferred",
    "pclm-raster-back-side",
    "pclm-source-resolution-supported",
    "pclm-compression-method-preferred",
    "job-password-supported",
    "job-password-encryption-supported",
    "job-account-id-supported",
    "job-accounting-user-id-supported",
    "identify-actions-supported",
    "job-creation-attributes-supported",
  ]
}

///|
pub fn job_attributes_requested() -> Array[Value] {
  [
    keyword("job-id"),
    keyword("job-uri"),
    keyword("job-name"),
    keyword("job-state"),
    keyword("job-state-reasons"),
    keyword("job-state-message"),
    keyword("job-impressions-completed"),
  ]
}

///|
pub(all) struct Client {
  http_url : String
  printer_uri : String
  user_name : String
  language : String
  major : Int
  minor : Int
  mut next_id : Int
}

///|
pub fn Client::new(url : String, user_name : String) -> Client raise IppError {
  let (http_url, printer_uri) = parse_url(url)
  {
    http_url,
    printer_uri,
    user_name: if user_name == "" { "bdf" } else { user_name },
    language: "en",
    major: 2,
    minor: 0,
    next_id: 0,
  }
}

///|
/// A request with the operation group the client fills.
pub fn Client::request(self : Client, op : Int) -> Message {
  self.next_id += 1
  let message = new_request(op, self.next_id, "utf-8", self.language)
  message.major = self.major
  message.minor = self.minor
  message.add(TAG_OPERATION, [
    attr("printer-uri", [uri(self.printer_uri)]),
    attr("requesting-user-name", [name(self.user_name)]),
  ])
  message
}

///|
pub fn Client::get_printer_attributes(self : Client, requested : Array[String]) -> Message {
  let message = self.request(OP_GET_PRINTER_ATTRIBUTES)
  let requested = if requested.length() == 0 { printer_attributes() } else { requested }
  message.add(TAG_OPERATION, [
    attr("requested-attributes", requested.map(fn(value) { keyword(value) })),
  ])
  message
}

///|
pub fn Client::validate_job(self : Client, job : Array[Attribute], format : String) -> Message {
  let message = self.request(OP_VALIDATE_JOB)
  if format != "" {
    message.add(TAG_OPERATION, [attr("document-format", [mime_type(format)])])
  }
  if job.length() > 0 {
    message.add(TAG_JOB, job)
  }
  message
}

///|
pub fn Client::create_job(self : Client, name_value : String, job : Array[Attribute]) -> Message {
  let message = self.request(OP_CREATE_JOB)
  if name_value != "" {
    message.add(TAG_OPERATION, [attr("job-name", [name(name_value)])])
  }
  if job.length() > 0 {
    message.add(TAG_JOB, job)
  }
  message
}

///|
pub fn Client::send_document(
  self : Client,
  job_id : Int,
  name_value : String,
  format : String,
  last : Bool,
) -> Message {
  let message = self.request(OP_SEND_DOCUMENT)
  message.add(TAG_OPERATION, [attr("job-id", [integer(job_id)])])
  if name_value != "" {
    message.add(TAG_OPERATION, [attr("document-name", [name(name_value)])])
  }
  if format != "" {
    message.add(TAG_OPERATION, [attr("document-format", [mime_type(format)])])
  }
  message.add(TAG_OPERATION, [attr("last-document", [boolean(last)])])
  message
}

///|
pub fn Client::print_job(
  self : Client,
  name_value : String,
  format : String,
  job : Array[Attribute],
) -> Message {
  let message = self.request(OP_PRINT_JOB)
  if name_value != "" {
    message.add(TAG_OPERATION, [attr("job-name", [name(name_value)])])
  }
  if format != "" {
    message.add(TAG_OPERATION, [attr("document-format", [mime_type(format)])])
  }
  if job.length() > 0 {
    message.add(TAG_JOB, job)
  }
  message
}

///|
/// The JobStatus of a response that made a job.
pub fn make_job_status(response : Message) -> JobStatus {
  let attrs : Array[Attribute] = []
  for group in response.groups {
    if group.tag == TAG_JOB || group.tag == TAG_PRINTER {
      for attribute in group.attrs {
        attrs.push(attribute)
      }
    }
  }
  job_status(attrs)
}

///|
/// Send a request through a transport that posts HTTP bytes and returns
/// the HTTP response bytes (or None when the connection failed).
pub fn Client::send(
  self : Client,
  message : Message,
  transport : (Bytes) -> Bytes?,
) -> Message raise IppError {
  let body = message.encode()
  let request = http_request(self.http_url, body)
  let response_bytes = match transport(request.encode()) {
    Some(value) => value
    None => raise IppError("ipp: the transport failed")
  }
  let response = parse_http_response(response_bytes)
  if response.status < 200 || response.status >= 300 {
    if response.body.length() == 0 {
      raise IppError("ipp: HTTP status " + response.status.to_string())
    }
  }
  decode(response.body)
}

