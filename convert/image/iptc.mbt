///|
struct IptcDataset {
  record : Int32
  id : Int32
  data : Bytes
}

///|
fn metadata_be32(data : Bytes, offset : Int32) -> Int64 {
  (jpeg_u16(data, offset).to_int64() << 16) |
  jpeg_u16(data, offset + 2).to_int64()
}

///|
fn photoshop_iptc(data : Bytes) -> Bytes? {
  let mut offset = 0
  while data.length() - offset >= 12 && data[offset:offset + 4] == b"8BIM"[:] {
    let id = jpeg_u16(data, offset + 4)
    let name_len = 1 + data[offset + 6].to_int()
    let at = offset + 6 + name_len + (name_len & 1)
    if at > data.length() - 4 {
      return None
    }
    let size = metadata_be32(data, at)
    let start = at + 4
    if size > (data.length() - start).to_int64() {
      return None
    }
    let end = start + size.to_int()
    if id == 0x0404 {
      return Some(data[start:end].to_bytes())
    }
    offset = if size % 2 == 1 && end < data.length() { end + 1 } else { end }
  }
  None
}

///|
fn iptc_date(date : String, time : String) -> String {
  let d = @utf8.encode(date)
  let t = @utf8.encode(time)
  if d.length() != 8 {
    return ""
  }
  let output = @buffer.Buffer()
  output.write_bytes(d[:4])
  output.write_byte(b'-')
  output.write_bytes(d[4:6])
  output.write_byte(b'-')
  output.write_bytes(d[6:])
  if t.length() == 6 || t.length() == 11 {
    output.write_byte(b'T')
    output.write_bytes(t[:2])
    output.write_byte(b':')
    output.write_bytes(t[2:4])
    output.write_byte(b':')
    output.write_bytes(t[4:6])
    if t.length() == 11 {
      output.write_bytes(t[6:9])
      output.write_byte(b':')
      output.write_bytes(t[9:])
    }
  }
  let text = @utf8.decode(output.to_bytes()) catch { _ => return "" }
  xmp_date(text)
}

///|
fn iptc_metadata(data : Bytes) -> Map[String, Array[String]] {
  let sets : Array[IptcDataset] = []
  let mut offset = 0
  while offset <= data.length() - 5 && data[offset] == 0x1c {
    let size = jpeg_u16(data, offset + 3)
    if (size & 0x8000) != 0 || size > data.length() - offset - 5 {
      break
    }
    sets.push({
      record: data[offset + 1].to_int(),
      id: data[offset + 2].to_int(),
      data: data[offset + 5:offset + 5 + size].to_bytes(),
    })
    offset += 5 + size
  }
  let mut utf8 = false
  for item in sets {
    if item.record == 1 && item.id == 90 && item.data == b"\x1b%G" {
      utf8 = true
    }
  }
  let dc : Map[String, Array[String]] = Map([])
  let mut date = ""
  let mut time = ""
  let mut headline = ""
  for item in sets {
    if item.record != 2 {
      continue
    }
    let value = if utf8 {
      xmp_clean(metadata_valid_utf8(item.data))
    } else {
      let text = @utf8.decode(item.data) catch {
        _ => metadata_latin1(item.data)
      }
      xmp_clean(text)
    }
    match item.id {
      5 => if dc.get("title") is None { xmp_add(dc, "title", [value]) }
      25 => xmp_add(dc, "subject", [value])
      55 => date = value
      60 => time = value
      80 => xmp_add(dc, "creator", [value])
      105 => headline = value
      116 => if dc.get("rights") is None { xmp_add(dc, "rights", [value]) }
      120 =>
        if dc.get("description") is None && !xmp_placeholder(value) {
          xmp_add(dc, "description", [value])
        }
      _ => ()
    }
  }
  if dc.get("title") is None {
    xmp_add(dc, "title", [headline])
  }
  xmp_add(dc, "created", [iptc_date(date, time)])
  dc
}
