///|
fn musicxml_find(
  data : Bytes,
  needle : Bytes,
  start : Int32,
  end : Int32,
) -> Int32 {
  if needle.length() == 0 {
    return start
  }
  let mut i = start
  while i + needle.length() <= end {
    let mut same = true
    for j in 0..<needle.length() {
      if data[i + j] != needle[j] {
        same = false
        break
      }
    }
    if same {
      return i
    }
    i += 1
  }
  -1
}

///|
/// Read the encoding declared in an XML header.
pub fn musicxml_declared_encoding(data : Bytes) -> String {
  let limit = Int32::min(data.length(), 1024)
  let mut start = 0
  while start < limit &&
        (
          data[start] == b' ' ||
          data[start] == b'\t' ||
          data[start] == b'\r' ||
          data[start] == b'\n'
        ) {
    start += 1
  }
  let end = Int32::min(start + 256, limit)
  if musicxml_find(data, b"<?xml", start, end) != start {
    return ""
  }
  let close = musicxml_find(data, b"?>", start, end)
  if close < 0 {
    return ""
  }
  let at = musicxml_find(data, b"encoding", start, close)
  if at < 0 {
    return ""
  }
  let mut i = at + 8
  while i < close &&
        (
          data[i] == b' ' ||
          data[i] == b'\t' ||
          data[i] == b'\r' ||
          data[i] == b'\n' ||
          data[i] == b'='
        ) {
    i += 1
  }
  if i >= close || (data[i] != b'"' && data[i] != b'\'') {
    return ""
  }
  let quote = data[i]
  i += 1
  let mut stop = i
  while stop < close && data[stop] != quote {
    stop += 1
  }
  let out = StringBuilder()
  let pending = StringBuilder()
  let mut started = false
  for c in @utf8.decode_lossy(data[i:stop]) {
    if c.is_whitespace() {
      if started {
        pending.write_char(c)
      }
    } else {
      if started {
        out.write_string(pending.to_string())
        pending.reset()
      }
      out.write_char(c)
      started = true
    }
  }
  out.to_string().to_lower()
}

///|
fn musicxml_utf16(data : Bytes, little : Bool) -> Bytes {
  let out = StringBuilder()
  let mut i = 0
  while i + 1 < data.length() {
    let a = data[i].to_int()
    let b = data[i + 1].to_int()
    let unit = if little { a | (b << 8) } else { (a << 8) | b }
    i += 2
    if unit >= 0xd800 && unit <= 0xdfff {
      let mut rune = 0xfffd
      if i + 1 < data.length() {
        let x = data[i].to_int()
        let y = data[i + 1].to_int()
        let low = if little { x | (y << 8) } else { (x << 8) | y }
        if low >= 0xdc00 && low <= 0xdfff {
          if unit <= 0xdbff {
            rune = 0x10000 + (unit - 0xd800) * 1024 + low - 0xdc00
          }
          i += 2
        }
      }
      out.write_char(rune.unsafe_to_char())
    } else {
      out.write_char(unit.unsafe_to_char())
    }
  }
  @utf8.encode(out.to_string())
}

///|
/// Prepare MusicXML bytes for XML decoding, returning the repair warning.
pub fn musicxml_to_utf8(data : Bytes) -> (Bytes, String) {
  let (little, utf16) = musicxml_utf16_order(data)
  let mut bytes = if utf16 { musicxml_utf16(data, little) } else { data }
  if bytes.has_prefix(b"\xef\xbb\xbf") {
    bytes = bytes[3:].to_owned()
  }
  let encoding = musicxml_declared_encoding(bytes)
  let unicode = encoding == "" ||
    [
      "utf-8", "utf8", "utf-16", "utf16", "utf-16le", "utf-16be", "ucs-2", "iso-10646-ucs-2",
      "unicode",
    ].contains(encoding)
  let mut warning = ""
  if unicode {
    let valid = try {
      ignore(@utf8.decode(bytes[:]))
      true
    } catch {
      _ => false
    }
    if !valid {
      let text = @csv.decode_charset(bytes, "windows-1252") catch {
        _ => @utf8.decode_lossy(bytes[:])
      }
      bytes = @utf8.encode(text)
      warning = "the text is not UTF-8; it is read as Windows-1252"
    }
  }
  let output : Array[Byte] = []
  for c in bytes {
    if c.to_int() < 32 && c != b'\t' && c != b'\n' && c != b'\r' {
      if warning == "" {
        warning = "control characters are replaced with spaces"
      }
      output.push(b' ')
    } else {
      output.push(c)
    }
  }
  (Bytes::from_array(output), warning)
}
