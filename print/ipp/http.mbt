///|
/// An HTTP request that carries an IPP message.
pub(all) struct HttpRequest {
  method : String
  target : String
  host : String
  body : Bytes
}

///|
/// Build a POST request for an IPP message to an http(s) URL.
pub fn http_request(url : String, body : Bytes) -> HttpRequest raise IppError {
  let scheme_end = match url.find("://") {
    Some(index) => index
    None => raise IppError("ipp: " + url + ": no scheme")
  }
  let rest = url[scheme_end + 3:]
  let slash = match rest.find("/") {
    Some(index) => index
    None => rest.length()
  }
  let host = rest[:slash].to_owned()
  if host == "" {
    raise IppError("ipp: " + url + ": no host")
  }
  let target = if slash < rest.length() {
    rest[slash:].to_owned()
  } else {
    "/"
  }
  { method: "POST", target, host, body }
}

///|
/// The bytes of an HTTP/1.1 request: headers then the body.
pub fn HttpRequest::encode(self : HttpRequest) -> Bytes {
  let head = self.method +
    " " +
    self.target +
    " HTTP/1.1\r\nHost: " +
    self.host +
    "\r\nContent-Type: application/ipp\r\nContent-Length: " +
    self.body.length().to_string() +
    "\r\nAccept-Encoding: identity\r\nConnection: close\r\n\r\n"
  let out = @utf8.encode(head)
  let all = out.to_array()
  for byte in self.body {
    all.push(byte)
  }
  Bytes::from_array(all)
}

///|
pub(all) struct HttpResponse {
  status : Int
  reason : String
  headers : Array[(String, String)]
  body : Bytes
}

///|
/// Parse an HTTP/1.1 response.
pub fn parse_http_response(data : Bytes) -> HttpResponse raise IppError {
  let text = @utf8.decode_lossy(data)
  let head_end = match text.find("\r\n\r\n") {
    Some(index) => index
    None => raise IppError("ipp: the HTTP response has no header end")
  }
  let head = text[:head_end]
  let lines = head.split("\r\n").collect()
  if lines.length() == 0 {
    raise IppError("ipp: the HTTP response has no status line")
  }
  let status_line = lines[0]
  let parts = status_line.split(" ").collect()
  if parts.length() < 2 {
    raise IppError("ipp: a broken HTTP status line")
  }
  let status = @string.parse_int(parts[1]) catch {
    _ => raise IppError("ipp: a broken HTTP status code")
  }
  let reason = if parts.length() > 2 {
    status_line[parts[0].length() + parts[1].length() + 2:].to_owned()
  } else {
    ""
  }
  let headers : Array[(String, String)] = []
  for i in 1..<lines.length() {
    let line = lines[i]
    match line.find(":") {
      Some(index) =>
        headers.push((line[:index].to_owned(), line[index + 1:].trim().to_owned()))
      None => ()
    }
  }
  let body = data[head_end + 4:].to_bytes()
  { status, reason, headers, body }
}
