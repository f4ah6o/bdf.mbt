///|
/// Turn a printer URL into the HTTP URL requests go to and the printer-uri
/// the requests name. ipp/http use http on port 631 unless a port is given;
/// ipps/https use https.
pub fn parse_url(value : String) -> (String, String) raise IppError {
  let scheme_end = match value.find("://") {
    Some(index) => index
    None => raise IppError("ipp: " + value + ": no scheme")
  }
  let raw_scheme = value[:scheme_end].to_lower().to_owned()
  let (http_scheme, ipp_scheme) = if raw_scheme == "ipp" || raw_scheme == "http" {
    ("http", "ipp")
  } else if raw_scheme == "ipps" || raw_scheme == "https" {
    ("https", "ipps")
  } else {
    raise IppError(
      "ipp: " + value + ": the scheme must be ipp, ipps, http or https",
    )
  }
  let rest = value[scheme_end + 3:]
  if rest == "" {
    raise IppError("ipp: " + value + ": no host")
  }
  let slash = match rest.find("/") {
    Some(index) => index
    None => rest.length()
  }
  let authority = rest[:slash].to_owned()
  let path_and_query = if slash < rest.length() {
    rest[slash:].to_owned()
  } else {
    "/"
  }
  fn valid_port(port : StringView) -> Bool {
    if port.length() == 0 {
      return false
    }
    let parsed = @string.parse_int(port) catch { _ => -1 }
    parsed >= 0
  }
  let (host, port) = if authority.has_prefix("[") {
    let close = match authority.find("]") {
      Some(index) => index
      None => raise IppError("ipp: " + value + ": a broken IPv6 host")
    }
    let host = authority[:close + 1].to_owned()
    let after = authority[close + 1:]
    let port = if after.has_prefix(":") && after.length() > 1 {
      after[1:].to_owned()
    } else {
      ""
    }
    (host, port)
  } else {
    let colon = authority.rev_find(":")
    match colon {
      Some(index) =>
        if valid_port(authority[index + 1:]) {
          (authority[:index].to_owned(), authority[index + 1:].to_owned())
        } else {
          (authority, "")
        }
      None => (authority, "")
    }
  }
  if host == "" {
    raise IppError("ipp: " + value + ": no host")
  }
  let port = if port == "" { "631" } else { port }
  let (path, query) = match path_and_query.find("?") {
    Some(index) =>
      (path_and_query[:index].to_owned(), path_and_query[index:].to_owned())
    None => (path_and_query, "")
  }
  let path = if path == "" { "/" } else { path }
  let host_port = host + ":" + port
  (
    http_scheme + "://" + host_port + path + query,
    ipp_scheme + "://" + host_port + path + query,
  )
}
