///|
fn response_error(message : Message) -> Unit raise IppError {
  check_response(message) catch {
    StatusError(_, text) => raise IppError(text)
  }
}

///|
/// Ask the printer about itself and read the answer.
pub fn Client::fetch_printer(
  self : Client,
  transport : (Bytes) -> Bytes?,
) -> Printer raise IppError {
  let response = self.send(self.get_printer_attributes([]), transport)
  response_error(response)
  let printer = parse_printer(response)
  { ..printer, uri: self.printer_uri }
}

///|
pub fn Client::validate(
  self : Client,
  job : Array[Attribute],
  format : String,
  transport : (Bytes) -> Bytes?,
) -> Unit raise IppError {
  response_error(self.send(self.validate_job(job, format), transport))
}

///|
pub fn Client::create(
  self : Client,
  name_value : String,
  job : Array[Attribute],
  transport : (Bytes) -> Bytes?,
) -> JobStatus raise IppError {
  let response = self.send(self.create_job(name_value, job), transport)
  response_error(response)
  make_job_status(response)
}

///|
pub fn Client::send_document_to(
  self : Client,
  job_id : Int,
  name_value : String,
  format : String,
  last : Bool,
  transport : (Bytes) -> Bytes?,
) -> JobStatus raise IppError {
  let response = self.send(
    self.send_document(job_id, name_value, format, last),
    transport,
  )
  response_error(response)
  make_job_status(response)
}

///|
pub fn Client::print(
  self : Client,
  name_value : String,
  format : String,
  job : Array[Attribute],
  transport : (Bytes) -> Bytes?,
) -> JobStatus raise IppError {
  let response = self.send(self.print_job(name_value, format, job), transport)
  response_error(response)
  make_job_status(response)
}

///|
pub fn Client::job(
  self : Client,
  job_id : Int,
  transport : (Bytes) -> Bytes?,
) -> JobStatus raise IppError {
  let request = self.request(OP_GET_JOB_ATTRIBUTES)
  request.add(TAG_OPERATION, [attr("job-id", [integer(job_id)])])
  let response = self.send(request, transport)
  response_error(response)
  make_job_status(response)
}

///|
pub fn Client::cancel(
  self : Client,
  job_id : Int,
  transport : (Bytes) -> Bytes?,
) -> Unit raise IppError {
  let request = self.request(OP_CANCEL_JOB)
  request.add(TAG_OPERATION, [attr("job-id", [integer(job_id)])])
  response_error(self.send(request, transport))
}

///|
/// Read the jobs of a Get-Jobs answer.
pub fn jobs_from_response(response : Message) -> Array[JobStatus] {
  let jobs : Array[JobStatus] = []
  let current : Array[Attribute] = []
  for group in response.groups {
    if group.tag == TAG_JOB {
      for attribute in group.attrs {
        if attribute.name == "job-id" && current.length() > 0 {
          jobs.push(job_status(current.copy()))
          current.clear()
        }
        current.push(attribute)
      }
    }
  }
  if current.length() > 0 {
    jobs.push(job_status(current))
  }
  jobs
}

///|
pub fn Client::jobs(
  self : Client,
  transport : (Bytes) -> Bytes?,
) -> Array[JobStatus] raise IppError {
  let response = self.send(self.request(OP_GET_JOBS), transport)
  response_error(response)
  jobs_from_response(response)
}

///|
/// Send a request with a document after it, as Print-Job and Send-Document
/// expect (the document follows the IPP message in the HTTP body).
pub fn Client::send_with_document(
  self : Client,
  message : Message,
  document : Bytes,
  transport : (Bytes) -> Bytes?,
) -> Message raise IppError {
  let head = message.encode()
  let body = head.to_array()
  for byte in document {
    body.push(byte)
  }
  let request = http_request(self.http_url, Bytes::from_array(body))
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

///|
/// Print a PDF document as a job.
pub fn Client::print_pdf(
  self : Client,
  name_value : String,
  document : Bytes,
  transport : (Bytes) -> Bytes?,
) -> JobStatus raise IppError {
  let request = self.print_job(name_value, "application/pdf", [])
  let response = self.send_with_document(request, document, transport)
  response_error(response)
  make_job_status(response)
}


///|
/// Print a document of any format (PDF, PWG Raster, URF, PCLm …).
pub fn Client::print_data(
  self : Client,
  name_value : String,
  format : String,
  document : Bytes,
  transport : (Bytes) -> Bytes?,
) -> JobStatus raise IppError {
  let request = self.print_job(name_value, format, [])
  let response = self.send_with_document(request, document, transport)
  response_error(response)
  make_job_status(response)
}


///|
/// List jobs of the printer ("completed", "not-completed" or "all").
pub fn Client::get_jobs(
  self : Client,
  which : String,
  mine : Bool,
  transport : (Bytes) -> Bytes?,
) -> Array[JobStatus] raise IppError {
  let request = self.request(OP_GET_JOBS)
  let attrs : Array[Attribute] = []
  if which != "" {
    attrs.push(attr("which-jobs", [keyword(which)]))
  }
  if mine {
    attrs.push(attr("my-jobs", [boolean(true)]))
  }
  attrs.push(attr("requested-attributes", [keyword("job-id"), keyword("job-uri")]))
  request.add(TAG_OPERATION, attrs)
  let response = self.send(request, transport)
  response_error(response)
  jobs_from_response(response)
}


///|
pub fn Client::print_pwg(
  self : Client,
  name_value : String,
  document : Bytes,
  transport : (Bytes) -> Bytes?,
) -> JobStatus raise IppError {
  self.print_data(name_value, "image/pwg-raster", document, transport)
}

///|
pub fn Client::print_urf(
  self : Client,
  name_value : String,
  document : Bytes,
  transport : (Bytes) -> Bytes?,
) -> JobStatus raise IppError {
  self.print_data(name_value, "image/urf", document, transport)
}

///|
pub fn Client::print_pclm(
  self : Client,
  name_value : String,
  document : Bytes,
  transport : (Bytes) -> Bytes?,
) -> JobStatus raise IppError {
  self.print_data(name_value, "application/PCLm", document, transport)
}

