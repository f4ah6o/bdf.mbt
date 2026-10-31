///|
// Decode PDFDocEncoding's non-Latin-1 byte assignments.
fn pdf_doc_code(byte : Byte) -> Int32 {
  match byte {
    b'\x18' => 0x02d8
    b'\x19' => 0x02c7
    b'\x1a' => 0x02c6
    b'\x1b' => 0x02d9
    b'\x1c' => 0x02dd
    b'\x1d' => 0x02db
    b'\x1e' => 0x02da
    b'\x1f' => 0x02dc
    b'\x7f' | b'\x9f' | b'\xad' => 0xfffd
    b'\x80' => 0x2022
    b'\x81' => 0x2020
    b'\x82' => 0x2021
    b'\x83' => 0x2026
    b'\x84' => 0x2014
    b'\x85' => 0x2013
    b'\x86' => 0x0192
    b'\x87' => 0x2044
    b'\x88' => 0x2039
    b'\x89' => 0x203a
    b'\x8a' => 0x2212
    b'\x8b' => 0x2030
    b'\x8c' => 0x201e
    b'\x8d' => 0x201c
    b'\x8e' => 0x201d
    b'\x8f' => 0x2018
    b'\x90' => 0x2019
    b'\x91' => 0x201a
    b'\x92' => 0x2122
    b'\x93' => 0xfb01
    b'\x94' => 0xfb02
    b'\x95' => 0x0141
    b'\x96' => 0x0152
    b'\x97' => 0x0160
    b'\x98' => 0x0178
    b'\x99' => 0x017d
    b'\x9a' => 0x0131
    b'\x9b' => 0x0142
    b'\x9c' => 0x0153
    b'\x9d' => 0x0161
    b'\x9e' => 0x017e
    b'\xa0' => 0x20ac
    _ => byte.to_int()
  }
}

///|
fn pdf_text_char(out : StringBuilder, code : Int32) -> Unit {
  match code.to_char() {
    Some(value) => out.write_char(value)
    None => out.write_char('\ufffd')
  }
}

///|
fn pdf_decode_text(bytes : Bytes) -> String {
  if bytes.length() >= 2 && bytes[0] == b'\xfe' && bytes[1] == b'\xff' {
    let out = StringBuilder()
    let mut i = 2
    while i + 1 < bytes.length() {
      let mut code = bytes[i].to_int() * 256 + bytes[i + 1].to_int()
      if code >= 0xd800 && code < 0xdc00 && i + 3 < bytes.length() {
        let lo = bytes[i + 2].to_int() * 256 + bytes[i + 3].to_int()
        code = 0x10000 + (code - 0xd800) * 1024 + (lo - 0xdc00)
        i += 2
      }
      pdf_text_char(out, code)
      i += 2
    }
    return out.to_string()
  }
  if bytes.length() >= 3 &&
    bytes[0] == b'\xef' &&
    bytes[1] == b'\xbb' &&
    bytes[2] == b'\xbf' {
    return pdf_decode_utf8_go(bytes[3:])
  }
  let decoded : String? = Some(@utf8.decode(bytes[:])) catch { _ => None }
  match decoded {
    Some(value) => value
    None => {
      let out = StringBuilder()
      for byte in bytes {
        pdf_text_char(out, pdf_doc_code(byte))
      }
      out.to_string()
    }
  }
}

///|
// Go's UTF-8 decoder emits one replacement rune for each invalid byte.
fn pdf_decode_utf8_go(bytes : BytesView) -> String {
  let out = StringBuilder()
  let mut pos = 0
  while pos < bytes.length() {
    let first = bytes[pos].to_int()
    if first < 128 {
      pdf_text_char(out, first)
      pos += 1
      continue
    }
    let count = if first >= 0xc2 && first <= 0xdf {
      2
    } else if first >= 0xe0 && first <= 0xef {
      3
    } else if first >= 0xf0 && first <= 0xf4 {
      4
    } else {
      0
    }
    let mut code = if count == 2 {
      first & 0x1f
    } else if count == 3 {
      first & 0x0f
    } else {
      first & 0x07
    }
    let mut valid = count > 0 && pos + count <= bytes.length()
    if valid {
      for j in 1..<count {
        let byte = bytes[pos + j].to_int()
        if byte < 0x80 || byte > 0xbf {
          valid = false
          break
        }
        code = (code << 6) | (byte & 0x3f)
      }
      if (count == 2 && code < 0x80) ||
        (count == 3 && code < 0x800) ||
        (count == 4 && code < 0x10000) ||
        (code >= 0xd800 && code <= 0xdfff) ||
        code > 0x10ffff {
        valid = false
      }
    }
    if valid {
      pdf_text_char(out, code)
      pos += count
    } else {
      out.write_char('\ufffd')
      pos += 1
    }
  }
  out.to_string()
}
