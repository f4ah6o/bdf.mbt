///|
// Match the upstream PDF date parser, retaining only the precision present.
fn pdf_metadata_date(input : String) -> String {
  let data = @utf8.encode(input.trim().to_owned())
  let start = if data.length() >= 2 && data[0] == b'D' && data[1] == b':' {
    2
  } else {
    0
  }
  let mut digits = 0
  while start + digits < data.length() &&
        digits < 14 &&
        data[start + digits] >= b'0' &&
        data[start + digits] <= b'9' {
    digits += 1
  }
  if digits < 4 || digits % 2 != 0 {
    return ""
  }
  let out = StringBuilder()
  for i in 0..<4 {
    pdf_text_char(out, data[start + i].to_int())
  }
  let separators = ['-', '-', 'T', ':', ':']
  let lows = [1, 1, 0, 0, 0]
  let highs = [12, 31, 23, 59, 59]
  for i in 0..<5 {
    let p = 4 + i * 2
    if p >= digits {
      break
    }
    let number = (data[start + p].to_int() - 48) * 10 +
      data[start + p + 1].to_int() -
      48
    if number < lows[i] || number > highs[i] {
      return ""
    }
    out.write_char(separators[i])
    pdf_text_char(out, data[start + p].to_int())
    pdf_text_char(out, data[start + p + 1].to_int())
  }
  if digits < 10 {
    return out.to_string()
  }
  if digits == 10 {
    out.write_string(":00")
  }
  let pos = start + digits
  if pos == data.length() {
    return out.to_string()
  }
  if data[pos] == b'Z' {
    out.write_char('Z')
    return out.to_string()
  }
  if data[pos] != b'+' && data[pos] != b'-' {
    return ""
  }
  let zone : Array[Byte] = []
  for i in (pos + 1)..<data.length() {
    let byte = data[i]
    if byte == b'\'' {
      continue
    }
    if byte < b'0' || byte > b'9' {
      return ""
    }
    zone.push(byte)
  }
  if zone.length() != 2 && zone.length() != 4 {
    return ""
  }
  pdf_text_char(out, data[pos].to_int())
  pdf_text_char(out, zone[0].to_int())
  pdf_text_char(out, zone[1].to_int())
  out.write_char(':')
  if zone.length() == 4 {
    pdf_text_char(out, zone[2].to_int())
    pdf_text_char(out, zone[3].to_int())
  } else {
    out.write_string("00")
  }
  out.to_string()
}
