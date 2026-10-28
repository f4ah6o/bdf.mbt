///|
fn metadata_latin1(data : BytesView) -> String {
  let out = StringBuilder()
  for byte in data {
    out.write_char(byte.to_int().to_char().unwrap())
  }
  out.to_string()
}

///|
fn metadata_text(data : Bytes) -> String {
  let mut end = 0
  while end < data.length() && data[end] != 0 {
    end += 1
  }
  let text = @utf8.decode(data[:end]) catch { _ => metadata_latin1(data[:end]) }
  xmp_clean(text)
}

///|
fn metadata_utf16_raw(
  data : Bytes,
  little : Bool,
  stop_at_nul : Bool,
) -> String {
  let out = StringBuilder()
  let mut pos = 0
  while pos + 1 < data.length() {
    let unit = exif_u16(data, pos, little)
    pos += 2
    if unit == 0 && stop_at_nul {
      break
    }
    if unit >= 0xd800 && unit <= 0xdbff {
      if pos + 1 < data.length() {
        let low = exif_u16(data, pos, little)
        if low >= 0xdc00 && low <= 0xdfff {
          pos += 2
          let scalar = 0x10000 + ((unit - 0xd800) << 10) + low - 0xdc00
          out.write_char(scalar.to_char().unwrap())
          continue
        }
      }
      out.write_char('\u{fffd}')
    } else if unit >= 0xdc00 && unit <= 0xdfff {
      out.write_char('\u{fffd}')
    } else {
      out.write_char(unit.to_char().unwrap())
    }
  }
  out.to_string()
}

///|
fn metadata_utf16(data : Bytes, little : Bool) -> String {
  xmp_clean(metadata_utf16_raw(data, little, true))
}

///|
fn metadata_exif_date(value : String, zone : String) -> String {
  let date = xmp_date(xmp_clean(value))
  if date.length() < 16 {
    return date
  }
  let bytes = @utf8.encode(date)
  for i in 10..<bytes.length() {
    if bytes[i] == b'Z' || bytes[i] == b'+' || bytes[i] == b'-' {
      return date
    }
  }
  let suffix = xmp_clean(zone)
  let raw = @utf8.encode(suffix)
  if raw.length() == 6 &&
    (raw[0] == b'+' || raw[0] == b'-') &&
    raw[3] == b':' &&
    xmp_date("2000-01-01T00:00" + suffix) != "" {
    date + suffix
  } else {
    date
  }
}

///|
// Go's bytes.ToValidUTF8(data, nil) removes invalid byte sequences while
// retaining genuine U+FFFD characters.
fn metadata_valid_utf8(data : Bytes) -> String {
  let out = StringBuilder()
  let mut at = 0
  while at < data.length() {
    let first = data[at].to_int()
    let mut size = 0
    let mut scalar = 0
    if first < 0x80 {
      size = 1
      scalar = first
    } else if first >= 0xc2 && first <= 0xdf {
      size = 2
      scalar = first & 0x1f
    } else if first >= 0xe0 && first <= 0xef {
      size = 3
      scalar = first & 0x0f
    } else if first >= 0xf0 && first <= 0xf4 {
      size = 4
      scalar = first & 0x07
    }
    if size == 0 || size > data.length() - at {
      at += 1
      continue
    }
    let mut valid = true
    for i in 1..<size {
      let next = data[at + i].to_int()
      if next < 0x80 || next > 0xbf {
        valid = false
        break
      }
      scalar = (scalar << 6) | (next & 0x3f)
    }
    if valid &&
      (
        (size == 2 && scalar < 0x80) ||
        (size == 3 && scalar < 0x800) ||
        (size == 4 && scalar < 0x10000) ||
        scalar > 0x10ffff ||
        (scalar >= 0xd800 && scalar <= 0xdfff)
      ) {
      valid = false
    }
    if valid {
      out.write_char(scalar.to_char().unwrap())
      at += size
    } else {
      at += 1
    }
  }
  out.to_string()
}
