///|
/// The CUPS queue URI for a printer on a host. A bare host gets the
/// conventional IPP port; an explicit scheme or port is preserved.
pub fn cups_printer_uri(host : String, name : String) -> String {
  let base = if host.contains("://") {
    host
  } else if host.contains(":") {
    "ipp://" + host
  } else {
    "ipp://" + host + ":631"
  }
  let trimmed = if base.has_suffix("/") {
    base[:base.length() - 1].to_owned()
  } else {
    base
  }
  trimmed + "/printers/" + name
}

///|
/// The CUPS job URI below a printer queue.
pub fn cups_job_uri(host : String, name : String, job : Int) -> String {
  cups_printer_uri(host, name) + "/jobs/" + job.to_string()
}


///|
/// A transport-agnostic client for a CUPS printer queue.
pub fn cups_client(host : String, name : String, user : String) -> Client raise IppError {
  Client::new(cups_printer_uri(host, name), user)
}
