///|
/// Recognize the byte order of a UTF-16 XML prefix.
pub fn musicxml_utf16_order(data : Bytes) -> (Bool, Bool) {
  if data.length() >= 2 && data[0] == b'\xff' && data[1] == b'\xfe' {
    return (true, true)
  }
  if data.length() >= 2 && data[0] == b'\xfe' && data[1] == b'\xff' {
    return (false, true)
  }
  if data.length() >= 4 &&
    data[0] == b'<' &&
    data[1] == b'\x00' &&
    data[2] != b'\x00' &&
    data[3] == b'\x00' {
    return (true, true)
  }
  if data.length() >= 4 &&
    data[0] == b'\x00' &&
    data[1] == b'<' &&
    data[2] == b'\x00' &&
    data[3] != b'\x00' {
    return (false, true)
  }
  (false, false)
}

///|
/// Decode the start of a MusicXML input for signature detection.
pub fn musicxml_head_text(data : Bytes) -> String {
  let (little, utf16) = musicxml_utf16_order(data)
  if utf16 {
    let out = StringBuilder()
    let mut i = 0
    while i + 1 < data.length() {
      let a = data[i].to_int()
      let b = data[i + 1].to_int()
      let unit = if little { a | (b << 8) } else { (a << 8) | b }
      if unit != 0xfeff {
        out.write_char(if unit < 128 { unit.unsafe_to_char() } else { '?' })
      }
      i += 2
    }
    return out.to_string()
  }
  let start = if data.length() >= 3 &&
    data[0] == b'\xef' &&
    data[1] == b'\xbb' &&
    data[2] == b'\xbf' {
    3
  } else {
    0
  }
  @utf8.decode_lossy(data[start:])
}

///|
/// Tell whether XML text names a partwise or timewise MusicXML score.
pub fn musicxml_is_score_text(text : String) -> Bool {
  let data = @utf8.encode(text)
  let mut i = 0
  while i < data.length() &&
        (
          data[i] == b' ' ||
          data[i] == b'\t' ||
          data[i] == b'\r' ||
          data[i] == b'\n'
        ) {
    i += 1
  }
  if i >= data.length() || data[i] != b'<' {
    return false
  }
  let text = @utf8.decode_lossy(data[i:])
  if text.contains("<score-partwise") || text.contains("<score-timewise") {
    return true
  }
  let marker = b"-//Recordare//DTD MusicXML"
  let bytes = @utf8.encode(text)
  let mut at = -1
  for start in 0..<bytes.length() {
    if start + marker.length() > bytes.length() {
      break
    }
    let mut equal = true
    for j in 0..<marker.length() {
      if bytes[start + j] != marker[j] {
        equal = false
        break
      }
    }
    if equal {
      at = start + marker.length()
      break
    }
  }
  if at < 0 {
    return false
  }
  let mut id = @utf8.decode_lossy(bytes[at:])
  for segment in id.split("//EN") {
    id = segment.to_owned()
    break
  }
  id.contains("Partwise") || id.contains("Timewise")
}

///|
/// Recognize an uncompressed MusicXML signature from the input prefix.
pub fn detect_musicxml_text(head : Bytes) -> Bool {
  musicxml_is_score_text(musicxml_head_text(head))
}
