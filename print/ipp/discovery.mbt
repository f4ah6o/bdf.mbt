///|
/// An IPP printer found with DNS-SD.
pub(all) struct Service {
  name : String
  host : String
  port : Int
  txt : Map[String, String]
  secure : Bool
  local_printer : Bool
  url : String
}

///|
/// The document formats of the TXT record (pdl).
pub fn Service::formats(self : Service) -> Array[String] {
  let pdl = self.txt.get("pdl").unwrap_or("")
  if pdl == "" {
    []
  } else {
    pdl.split(",").map(fn(value) { value.to_owned() }).collect()
  }
}

///|
/// Decode a DNS-SD TXT record: length-prefixed "key=value" strings.
pub fn decode_txt(data : Bytes) -> Map[String, String] raise IppError {
  let out : Map[String, String] = Map([])
  let mut pos = 0
  while pos < data.length() {
    let length = data[pos].to_int()
    pos += 1
    if length == 0 {
      break
    }
    if pos + length > data.length() {
      raise IppError("ipp: the TXT record is cut")
    }
    let text = @utf8.decode_lossy(data[pos:pos + length])
    pos += length
    match text.find("=") {
      Some(index) => out[text[:index].to_owned()] = text[index + 1:].to_owned()
      None => out[text] = ""
    }
  }
  out
}

///|
/// Encode a DNS-SD TXT record.
pub fn encode_txt(entries : Array[(String, String)]) -> Bytes raise IppError {
  let out : Array[Byte] = []
  for entry in entries {
    let (key, value) = entry
    let text = if value == "" { key } else { key + "=" + value }
    let bytes = @utf8.encode(text)
    if bytes.length() == 0 || bytes.length() > 255 {
      raise IppError("ipp: a TXT entry is not 1 to 255 bytes")
    }
    out.push(bytes.length().to_byte())
    for byte in bytes {
      out.push(byte)
    }
  }
  out.push(b'\x00')
  Bytes::from_array(out)
}

///|
/// The URL of a service: ipps when secure, else ipp.
pub fn service_url(service : Service) -> String {
  let scheme = if service.secure { "ipps" } else { "ipp" }
  let host = if service.host.contains(":") && !service.host.has_prefix("[") {
    "[" + service.host + "]"
  } else {
    service.host
  }
  let path = service.txt.get("rp").unwrap_or("/")
  scheme + "://" + host + ":" + service.port.to_string() + path
}
