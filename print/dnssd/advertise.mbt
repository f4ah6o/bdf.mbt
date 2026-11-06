///|
/// A printer to advertise with DNS-SD.
pub(all) struct Advertisement {
  instance : String
  service_type : String
  port : Int
  host : String
  addresses : Array[String]
  txt : Array[(String, String)]
  subtypes : Array[String]
}

///|
fn service_full_name(service : Advertisement) -> String {
  service.instance + "." + service.service_type + ".local"
}

///|
fn txt_bytes(entries : Array[(String, String)]) -> Array[Bytes] {
  entries.map(fn(entry) {
    let (key, value) = entry
    @utf8.encode(if value == "" { key } else { key + "=" + value })
  })
}

///|
fn parse_ipv4(text : String) -> Bytes? {
  let parts = text.split(".").collect()
  if parts.length() != 4 {
    return None
  }
  let bytes : Array[Byte] = []
  for part in parts {
    let value = @string.parse_int(part) catch {
      _ => return None
    }
    if value < 0 || value > 255 {
      return None
    }
    bytes.push(value.to_byte())
  }
  Some(Bytes::from_array(bytes))
}

///|
fn parse_ipv6_group(group : String) -> Int? {
  if group == "" {
    return None
  }
  let mut value = 0
  for c in group {
    let digit = if c >= '0' && c <= '9' {
      c.to_int() - 48
    } else if c >= 'a' && c <= 'f' {
      c.to_int() - 87
    } else if c >= 'A' && c <= 'F' {
      c.to_int() - 55
    } else {
      return None
    }
    value = (value << 4) | digit
  }
  if value > 0xffff {
    None
  } else {
    Some(value)
  }
}

///|
/// Parse an IPv6 address into its 16 bytes.
fn parse_ipv6(text : String) -> Bytes? {
  if !text.contains(":") {
    return None
  }
  let mut left_text = text
  let mut right_text = ""
  let mut doubled = false
  match text.find("::") {
    Some(index) => {
      doubled = true
      left_text = text[:index].to_owned()
      right_text = text[index + 2:].to_owned()
    }
    None => ()
  }
  fn groups_of(part : String) -> Array[Int]? {
    let groups : Array[Int] = []
    if part != "" {
      for token in part.split(":") {
        if token == "" {
          return None
        }
        if token.contains(".") {
          let ipv4 = match parse_ipv4(token.to_owned()) {
            Some(bytes) => bytes
            None => return None
          }
          groups.push((ipv4[0].to_int() << 8) | ipv4[1].to_int())
          groups.push((ipv4[2].to_int() << 8) | ipv4[3].to_int())
        } else {
          let group = match parse_ipv6_group(token.to_owned()) {
            Some(value) => value
            None => return None
          }
          groups.push(group)
        }
      }
    }
    Some(groups)
  }
  let left = match groups_of(left_text) {
    Some(groups) => groups
    None => return None
  }
  let right = match groups_of(right_text) {
    Some(groups) => groups
    None => return None
  }
  let all : Array[Int] = []
  if doubled {
    if left.length() + right.length() >= 8 {
      return None
    }
    for group in left {
      all.push(group)
    }
    for _ in 0..<(8 - left.length() - right.length()) {
      all.push(0)
    }
    for group in right {
      all.push(group)
    }
  } else {
    if left.length() != 8 {
      return None
    }
    for group in left {
      all.push(group)
    }
  }
  let bytes : Array[Byte] = []
  for group in all {
    bytes.push(((group >> 8) & 0xff).to_byte())
    bytes.push((group & 0xff).to_byte())
  }
  Some(Bytes::from_array(bytes))
}

///|
fn address_record(host : String, address : String) -> Record raise DnsError {
  if address.contains(":") {
    let bytes = match parse_ipv6(address) {
      Some(bytes) => bytes
      None => raise DnsError("dnssd: a broken IPv6 address")
    }
    {
      name: host,
      typ: TYPE_AAAA,
      class_: CLASS_FLUSH,
      ttl: 120,
      data: RecordData::Aaaa(bytes),
    }
  } else {
    let bytes = match parse_ipv4(address) {
      Some(bytes) => bytes
      None => raise DnsError("dnssd: a broken IPv4 address")
    }
    {
      name: host,
      typ: TYPE_A,
      class_: CLASS_FLUSH,
      ttl: 120,
      data: RecordData::A(bytes),
    }
  }
}

///|
/// The PTR/SRV/TXT/A records of an advertised printer.
pub fn advertisement_records(service : Advertisement) -> Array[Record] raise DnsError {
  if service.instance == "" || service.service_type == "" || service.port <= 0 ||
    service.host == "" {
    raise DnsError("dnssd: an advertisement needs an instance, a type, a port and a host")
  }
  let service_name = service.service_type + ".local"
  let full_name = service_full_name(service)
  let records : Array[Record] = [
    {
      name: service_name,
      typ: TYPE_PTR,
      class_: CLASS_IN,
      ttl: 4500,
      data: RecordData::Ptr(full_name),
    },
    {
      name: full_name,
      typ: TYPE_SRV,
      class_: CLASS_FLUSH,
      ttl: 4500,
      data: RecordData::Srv(0, 0, service.port, service.host),
    },
    {
      name: full_name,
      typ: TYPE_TXT,
      class_: CLASS_FLUSH,
      ttl: 4500,
      data: RecordData::Txt(txt_bytes(service.txt)),
    },
  ]
  for address in service.addresses {
    records.push(address_record(service.host, address))
  }
  for subtype in service.subtypes {
    records.push({
      name: subtype + "._sub." + service_name,
      typ: TYPE_PTR,
      class_: CLASS_IN,
      ttl: 4500,
      data: RecordData::Ptr(full_name),
    })
  }
  records
}

///|
/// A PTR question for an IPP service type ("_ipp._tcp").
pub fn service_question(service_type : String) -> Question {
  { name: service_type + ".local", typ: TYPE_PTR, class_: CLASS_IN }
}

///|
/// The instance name of a service found by a PTR record.
pub fn instance_name(full_name : String, service_type : String) -> String {
  let suffix = "." + service_type + ".local"
  if full_name.has_suffix(suffix) {
    full_name[:full_name.length() - suffix.length()].to_owned()
  } else {
    full_name
  }
}
