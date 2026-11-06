///|
// DNS wire format for DNS-SD (RFC 1035, RFC 6762/6763).
pub const CLASS_IN : Int = 1
pub const CLASS_FLUSH : Int = 0x8001
pub const TYPE_A : Int = 1
pub const TYPE_PTR : Int = 12
pub const TYPE_TXT : Int = 16
pub const TYPE_AAAA : Int = 28
pub const TYPE_SRV : Int = 33
pub const TYPE_ANY : Int = 255

///|
pub(all) enum RecordData {
  A(Bytes)
  Aaaa(Bytes)
  Ptr(String)
  Srv(Int, Int, Int, String)
  Txt(Array[Bytes])
  Raw(Bytes)
}

///|
pub(all) struct Question {
  name : String
  typ : Int
  class_ : Int
}

///|
pub(all) struct Record {
  name : String
  typ : Int
  class_ : Int
  ttl : Int
  data : RecordData
}

///|
pub(all) struct Message {
  id : Int
  flags : Int
  questions : Array[Question]
  answers : Array[Record]
}

///|
pub suberror DnsError {
  DnsError(String)
}

///|
fn put_u16(out : Array[Byte], value : Int) -> Unit {
  out.push(((value >> 8) & 0xff).to_byte())
  out.push((value & 0xff).to_byte())
}

///|
fn put_u32(out : Array[Byte], value : Int) -> Unit {
  out.push(((value >> 24) & 0xff).to_byte())
  out.push(((value >> 16) & 0xff).to_byte())
  out.push(((value >> 8) & 0xff).to_byte())
  out.push((value & 0xff).to_byte())
}

///|
fn put_name(out : Array[Byte], name : String) -> Unit raise DnsError {
  if name == "" || name == "." {
    out.push(b'\x00')
    return
  }
  for label in name.split(".") {
    if label == "" {
      continue
    }
    let bytes = @utf8.encode(label)
    if bytes.length() == 0 || bytes.length() > 63 {
      raise DnsError("dns: a label is not 1 to 63 bytes")
    }
    out.push(bytes.length().to_byte())
    for byte in bytes {
      out.push(byte)
    }
  }
  out.push(b'\x00')
}

///|
fn record_rdata(record : Record) -> Bytes raise DnsError {
  let out : Array[Byte] = []
  match record.data {
    A(bytes) => {
      if bytes.length() != 4 {
        raise DnsError("dns: an A record is 4 bytes")
      }
      for byte in bytes {
        out.push(byte)
      }
    }
    Aaaa(bytes) => {
      if bytes.length() != 16 {
        raise DnsError("dns: an AAAA record is 16 bytes")
      }
      for byte in bytes {
        out.push(byte)
      }
    }
    Ptr(name) => put_name(out, name)
    Srv(priority, weight, port, target) => {
      put_u16(out, priority)
      put_u16(out, weight)
      put_u16(out, port)
      put_name(out, target)
    }
    Txt(values) => {
      for value in values {
        if value.length() > 255 {
          raise DnsError("dns: a TXT string is longer than 255 bytes")
        }
        out.push(value.length().to_byte())
        for byte in value {
          out.push(byte)
        }
      }
    }
    Raw(bytes) => {
      for byte in bytes {
        out.push(byte)
      }
    }
  }
  Bytes::from_array(out)
}

///|
fn put_record(out : Array[Byte], record : Record) -> Unit raise DnsError {
  put_name(out, record.name)
  put_u16(out, record.typ)
  put_u16(out, record.class_)
  put_u32(out, record.ttl)
  let data = record_rdata(record)
  put_u16(out, data.length())
  for byte in data {
    out.push(byte)
  }
}

///|
pub fn encode_query(id : Int, questions : Array[Question]) -> Bytes raise DnsError {
  let out : Array[Byte] = []
  put_u16(out, id)
  put_u16(out, 0)
  put_u16(out, questions.length())
  put_u16(out, 0)
  put_u16(out, 0)
  put_u16(out, 0)
  for question in questions {
    put_name(out, question.name)
    put_u16(out, question.typ)
    put_u16(out, question.class_)
  }
  Bytes::from_array(out)
}

///|
pub fn encode_response(
  id : Int,
  questions : Array[Question],
  answers : Array[Record],
) -> Bytes raise DnsError {
  let out : Array[Byte] = []
  put_u16(out, id)
  put_u16(out, 0x8400)
  put_u16(out, questions.length())
  put_u16(out, answers.length())
  put_u16(out, 0)
  put_u16(out, 0)
  for question in questions {
    put_name(out, question.name)
    put_u16(out, question.typ)
    put_u16(out, question.class_)
  }
  for record in answers {
    put_record(out, record)
  }
  Bytes::from_array(out)
}

///|
fn read_u16(data : Bytes, pos : Int) -> Int raise DnsError {
  if pos + 2 > data.length() {
    raise DnsError("dns: the message is cut")
  }
  (data[pos].to_int() << 8) | data[pos + 1].to_int()
}

///|
fn read_u32(data : Bytes, pos : Int) -> Int raise DnsError {
  if pos + 4 > data.length() {
    raise DnsError("dns: the message is cut")
  }
  (data[pos].to_int() << 24) |
  (data[pos + 1].to_int() << 16) |
  (data[pos + 2].to_int() << 8) |
  data[pos + 3].to_int()
}

///|
fn read_name(data : Bytes, start : Int) -> (String, Int) raise DnsError {
  let labels : Array[String] = []
  let mut pos = start
  let mut end = -1
  let mut jumps = 0
  while true {
    if pos >= data.length() {
      raise DnsError("dns: a name is cut")
    }
    let length = data[pos].to_int()
    if length == 0 {
      pos += 1
      break
    }
    if (length & 0xc0) == 0xc0 {
      if pos + 2 > data.length() {
        raise DnsError("dns: a name pointer is cut")
      }
      let pointer = ((length & 0x3f) << 8) | data[pos + 1].to_int()
      if end < 0 {
        end = pos + 2
      }
      pos = pointer
      jumps += 1
      if jumps > 16 {
        raise DnsError("dns: a name pointer loops")
      }
      continue
    }
    if length > 63 || pos + 1 + length > data.length() {
      raise DnsError("dns: a broken label")
    }
    labels.push(@utf8.decode_lossy(data[pos + 1:pos + 1 + length]))
    pos += 1 + length
  }
  (labels.join("."), if end >= 0 { end } else { pos })
}

///|
fn read_record(data : Bytes, start : Int) -> (Record, Int) raise DnsError {
  let (name, after_name) = read_name(data, start)
  let typ = read_u16(data, after_name)
  let class_ = read_u16(data, after_name + 2)
  let ttl = read_u32(data, after_name + 4)
  let length = read_u16(data, after_name + 8)
  let rdata_start = after_name + 10
  if rdata_start + length > data.length() {
    raise DnsError("dns: a record is cut")
  }
  let rdata = data[rdata_start:rdata_start + length].to_bytes()
  let record_data = if typ == TYPE_A {
    RecordData::A(rdata)
  } else if typ == TYPE_AAAA {
    RecordData::Aaaa(rdata)
  } else if typ == TYPE_PTR {
    let (target, _) = read_name(data, rdata_start)
    RecordData::Ptr(target)
  } else if typ == TYPE_SRV {
    if rdata.length() < 6 {
      raise DnsError("dns: an SRV record is short")
    }
    let priority = read_u16(rdata, 0)
    let weight = read_u16(rdata, 2)
    let port = read_u16(rdata, 4)
    let (target, _) = read_name(data, rdata_start + 6)
    RecordData::Srv(priority, weight, port, target)
  } else if typ == TYPE_TXT {
    let values : Array[Bytes] = []
    let mut pos = 0
    while pos < rdata.length() {
      let value_length = rdata[pos].to_int()
      pos += 1
      if pos + value_length > rdata.length() {
        raise DnsError("dns: a TXT string is cut")
      }
      values.push(rdata[pos:pos + value_length].to_bytes())
      pos += value_length
    }
    RecordData::Txt(values)
  } else {
    RecordData::Raw(rdata)
  }
  ({ name, typ, class_, ttl, data: record_data }, rdata_start + length)
}

///|
pub fn decode(data : Bytes) -> Message raise DnsError {
  if data.length() < 12 {
    raise DnsError("dns: the header is cut")
  }
  let id = read_u16(data, 0)
  let flags = read_u16(data, 2)
  let question_count = read_u16(data, 4)
  let answer_count = read_u16(data, 6)
  let mut pos = 12
  let questions : Array[Question] = []
  for _ in 0..<question_count {
    let (name, after) = read_name(data, pos)
    let typ = read_u16(data, after)
    let class_ = read_u16(data, after + 2)
    questions.push({ name, typ, class_ })
    pos = after + 4
  }
  let answers : Array[Record] = []
  for _ in 0..<answer_count {
    let (record, after) = read_record(data, pos)
    answers.push(record)
    pos = after
  }
  { id, flags, questions, answers }
}
