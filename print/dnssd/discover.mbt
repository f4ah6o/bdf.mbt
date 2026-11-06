///|
/// A printer found in a DNS-SD response.
pub(all) struct FoundService {
  name : String
  host : String
  port : Int
  addresses : Array[String]
  txt : Map[String, String]
  secure : Bool
  url : String
}

///|
fn txt_map(values : Array[Bytes]) -> Map[String, String] {
  let out : Map[String, String] = Map([])
  for value in values {
    let text = @utf8.decode_lossy(value)
    match text.find("=") {
      Some(index) => out[text[:index].to_owned()] = text[index + 1:].to_owned()
      None => out[text] = ""
    }
  }
  out
}

///|
fn address_text(data : RecordData) -> String? {
  match data {
    A(bytes) =>
      if bytes.length() == 4 {
        Some(
          bytes[0].to_int().to_string() +
          "." +
          bytes[1].to_int().to_string() +
          "." +
          bytes[2].to_int().to_string() +
          "." +
          bytes[3].to_int().to_string(),
        )
      } else {
        None
      }
    Aaaa(bytes) =>
      if bytes.length() == 16 {
        let parts : Array[String] = []
        for i in 0..<8 {
          let high = bytes[i * 2].to_int()
          let low = bytes[i * 2 + 1].to_int()
          parts.push(hex16((high << 8) | low))
        }
        Some(parts.join(":"))
      } else {
        None
      }
    _ => None
  }
}

///|
fn hex16(value : Int) -> String {
  let out = StringBuilder()
  for shift in [12, 8, 4, 0] {
    let nibble = (value >> shift) & 0xf
    let code = if nibble < 10 { 48 + nibble } else { 87 + nibble }
    out.write_char(code.unsafe_to_char())
  }
  out.to_string()
}

///|
/// Read the printers of a DNS-SD answer for a service type.
pub fn discover(message : Message, service_type : String) -> Array[FoundService] {
  let secure = service_type == "_ipps._tcp"
  let full_names : Array[String] = []
  let ptrs : Array[String] = []
  for record in message.answers {
    match record.data {
      Ptr(target) =>
        if record.name == service_type + ".local" && !ptrs.contains(target) {
          ptrs.push(target)
          full_names.push(target)
        }
      _ => ()
    }
  }
  let services : Array[FoundService] = []
  for full_name in full_names {
    let mut host = ""
    let mut port = 0
    let addresses : Array[String] = []
    let mut txt : Map[String, String] = Map([])
    for record in message.answers {
      if record.name == full_name {
        match record.data {
          Srv(_, _, record_port, target) => {
            port = record_port
            host = target
          }
          Txt(values) => txt = txt_map(values)
          _ => ()
        }
      }
      if record.name == host {
        match address_text(record.data) {
          Some(address) => addresses.push(address)
          None => ()
        }
      }
    }
    let name = instance_name(full_name, service_type)
    let scheme = if secure { "ipps" } else { "ipp" }
    let path = txt.get("rp").unwrap_or("/")
    let host_text = if host.contains(":") && !host.has_prefix("[") {
      "[" + host + "]"
    } else {
      host
    }
    let url = scheme + "://" + host_text + ":" + port.to_string() + path
    services.push({ name, host, port, addresses, txt, secure, url })
  }
  services
}

///|
/// Browse a service type over a caller-supplied multicast transport: send
/// the PTR query, decode the answer, and return the printers.
pub fn browse(
  service_type : String,
  transport : (Bytes) -> Bytes?,
) -> Array[FoundService] raise DnsError {
  browse_with_id(1, service_type, transport)
}

///|
pub fn browse_with_id(
  id : Int,
  service_type : String,
  transport : (Bytes) -> Bytes?,
) -> Array[FoundService] raise DnsError {
  let query = encode_query(id, [service_question(service_type)])
  let answer = match transport(query) {
    Some(bytes) => bytes
    None => return []
  }
  let message = decode(answer)
  discover(message, service_type)
}

