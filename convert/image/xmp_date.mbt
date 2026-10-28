///|
fn xmp_trim_space(value : String) -> String {
  let out = StringBuilder()
  let mut pending = StringBuilder()
  let mut seen = false
  let mut has_pending = false
  for ch in value {
    if ch.is_whitespace() {
      if seen {
        pending.write_char(ch)
        has_pending = true
      }
    } else {
      if has_pending {
        out.write_string(pending.to_string())
        pending = StringBuilder()
        has_pending = false
      }
      out.write_char(ch)
      seen = true
    }
  }
  out.to_string()
}

///|
fn xmp_digits(data : Bytes, offset : Int32, count : Int32) -> Int32? {
  if offset < 0 || count > data.length() - offset {
    return None
  }
  let mut value = 0
  for i in offset..<(offset + count) {
    let digit = data[i].to_int() - 48
    if digit < 0 || digit > 9 {
      return None
    }
    value = value * 10 + digit
  }
  Some(value)
}

///|
// Normalize the ISO and EXIF-style date forms accepted by the upstream XMP
// reader, preserving precision and fractions.
fn xmp_date(value : String) -> String {
  let data = @utf8.encode(xmp_trim_space(value))
  guard xmp_digits(data, 0, 4) is Some(year) && year >= 1 else { return "" }
  let out = @buffer.Buffer()
  out.write_bytes(data[:4])
  let mut at = 4
  if at == data.length() {
    return @utf8.decode(out.to_bytes()) catch { _ => "" }
  }
  if data[at] != b'-' && data[at] != b':' {
    return ""
  }
  at += 1
  guard xmp_digits(data, at, 2) is Some(month) && month >= 1 && month <= 12 else {
    return ""
  }
  out.write_byte(b'-')
  out.write_bytes(data[at:at + 2])
  at += 2
  if at == data.length() {
    return @utf8.decode(out.to_bytes()) catch { _ => "" }
  }
  if data[at] != b'-' && data[at] != b':' {
    return ""
  }
  at += 1
  guard xmp_digits(data, at, 2) is Some(day) && day >= 1 && day <= 31 else {
    return ""
  }
  out.write_byte(b'-')
  out.write_bytes(data[at:at + 2])
  at += 2
  if at == data.length() {
    return @utf8.decode(out.to_bytes()) catch { _ => "" }
  }
  if data[at] != b'T' && data[at] != b' ' {
    return ""
  }
  at += 1
  guard xmp_digits(data, at, 2) is Some(hour) && hour <= 23 else { return "" }
  out.write_byte(b'T')
  out.write_bytes(data[at:at + 2])
  at += 2
  if at >= data.length() || data[at] != b':' {
    return ""
  }
  at += 1
  guard xmp_digits(data, at, 2) is Some(minute) && minute <= 59 else {
    return ""
  }
  out.write_byte(b':')
  out.write_bytes(data[at:at + 2])
  at += 2
  if at < data.length() && data[at] == b':' {
    at += 1
    guard xmp_digits(data, at, 2) is Some(second) && second <= 60 else {
      return ""
    }
    out.write_byte(b':')
    out.write_bytes(data[at:at + 2])
    at += 2
    if at < data.length() && data[at] == b'.' {
      out.write_byte(b'.')
      at += 1
      let start = at
      while at < data.length() && data[at] >= b'0' && data[at] <= b'9' {
        at += 1
      }
      if start == at {
        return ""
      }
      out.write_bytes(data[start:at])
    }
  }
  while at < data.length() &&
        (
          data[at] == b' ' ||
          data[at] == b'\t' ||
          data[at] == b'\n' ||
          data[at] == b'\r' ||
          data[at] == b'\x0c'
        ) {
    at += 1
  }
  if at < data.length() {
    if data[at] == b'Z' {
      out.write_byte(b'Z')
      at += 1
    } else if data[at] == b'+' || data[at] == b'-' {
      out.write_byte(data[at])
      at += 1
      if xmp_digits(data, at, 2) is None {
        return ""
      }
      out.write_bytes(data[at:at + 2])
      at += 2
      if at < data.length() && data[at] == b':' {
        at += 1
      }
      if xmp_digits(data, at, 2) is None {
        return ""
      }
      out.write_byte(b':')
      out.write_bytes(data[at:at + 2])
      at += 2
    } else {
      return ""
    }
  }
  if at != data.length() {
    return ""
  }
  @utf8.decode(out.to_bytes()) catch {
    _ => ""
  }
}
