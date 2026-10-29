///|
/// Decoded CSV text and the selected character encoding.
pub(all) struct DecodedText {
  text : String
  charset : String
  bom : Bool
} derive(Debug, Eq)

///|
/// Decode CSV bytes, honoring a BOM before an explicit WHATWG encoding label.
/// Without either, the encoding is guessed from the input as upstream does.
pub fn decode_text(data : Bytes, charset~ : String = "") -> DecodedText raise {
  let (name, bom_length) = if data.has_prefix(b"\xef\xbb\xbf") {
    ("UTF-8", 3)
  } else if data.has_prefix(b"\xff\xfe\x00\x00") {
    ("UTF-32LE", 4)
  } else if data.has_prefix(b"\x00\x00\xfe\xff") {
    ("UTF-32BE", 4)
  } else if data.has_prefix(b"\xff\xfe") {
    ("UTF-16LE", 2)
  } else if data.has_prefix(b"\xfe\xff") {
    ("UTF-16BE", 2)
  } else if charset != "" && charset != "auto" {
    (csv_charset_name(charset), 0)
  } else {
    (csv_detect_charset(data), 0)
  }
  let bytes = data[bom_length:].to_owned()
  let text = csv_decode_charset(bytes, name)
  { text, charset: name, bom: bom_length != 0, }
}

///|
fn csv_charset_name(label : String) -> String raise {
  let trimmed = csv_trim(label).to_lower()
  let name = match trimmed {
    "cp932" => "shift_jis"
    "cp936" => "gbk"
    "cp949" => "euc-kr"
    "cp950" => "big5"
    "cp1252" => "windows-1252"
    "eucjp" => "euc-jp"
    "euckr" => "euc-kr"
    _ => trimmed
  }
  match @encoding.label_to_encoding(name) {
    Ok(canonical) =>
      match canonical {
        "UTF-8" => "UTF-8"
        "Shift_JIS" => "Shift_JIS"
        "UTF-16LE"
        | "UTF-16BE"
        | "EUC-JP"
        | "EUC-KR"
        | "ISO-2022-JP"
        | "windows-1252"
        | "GBK"
        | "gb18030"
        | "Big5" => canonical.to_upper()
        _ => canonical.to_lower()
      }
    Err(_) =>
      raise InvalidDialect(
        "csv: unknown character encoding " + csv_go_quote(label, '"'),
      )
  }
}

///|
fn csv_decode_charset(data : Bytes, name : String) -> String raise {
  if name == "UTF-8" {
    return csv_decode_utf8(data)
  }
  if name == "UTF-32LE" || name == "UTF-32BE" {
    return csv_decode_utf32(data, name == "UTF-32LE")
  }
  if name == "Shift_JIS" || name == "EUC-JP" {
    return csv_decode_japanese(data, name)
  }
  if name == "ISO-2022-JP" {
    return csv_decode_iso2022(data)
  }
  if name == "GBK" || name == "GB18030" || name == "BIG5" {
    return csv_decode_chinese(data, name)
  }
  match @encoding.decode(data, name) {
    Ok(text) => {
      if name != "WINDOWS-1252" &&
        !name.has_prefix("windows-") &&
        !name.has_prefix("iso-8859-") {
        return text
      }
      // Go's single-byte decoders replace undefined C1 bytes, while WHATWG
      // preserves them as control characters.
      let output = StringBuilder()
      for c in text {
        if c.to_int() >= 0x80 && c.to_int() <= 0x9f {
          output.write_char('\u{fffd}')
        } else {
          output.write_char(c)
        }
      }
      output.to_string()
    }
    Err(_) => raise InvalidDialect("unsupported character encoding " + name)
  }
}

///|
fn csv_decode_utf32(data : Bytes, little : Bool) -> String {
  let output = StringBuilder()
  let mut at = 0
  while at + 4 <= data.length() {
    let b0 = data[at].to_uint()
    let b1 = data[at + 1].to_uint()
    let b2 = data[at + 2].to_uint()
    let b3 = data[at + 3].to_uint()
    let code = if little {
      b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    } else {
      (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
    }
    if code > 0x10ffff || (code >= 0xd800 && code <= 0xdfff) {
      output.write_char('\u{fffd}')
    } else {
      output.write_char(code.to_int().unsafe_to_char())
    }
    at += 4
  }
  if at < data.length() {
    output.write_char('\u{fffd}')
  }
  output.to_string()
}

///|
// Valid sequence length, -1 for a malformed first byte, 0 for an otherwise
// valid sequence cut short at the end.
fn csv_utf8_sequence(data : Bytes, at : Int32) -> Int32 {
  let first = data[at].to_int()
  if first < 0x80 {
    return 1
  }
  let length = if first >= 0xc2 && first <= 0xdf {
    2
  } else if first >= 0xe0 && first <= 0xef {
    3
  } else if first >= 0xf0 && first <= 0xf4 {
    4
  } else {
    return -1
  }
  for i in 1..<length {
    if at + i >= data.length() {
      return 0
    }
    let byte = data[at + i].to_int()
    let low = if i == 1 && first == 0xe0 {
      0xa0
    } else if i == 1 && first == 0xf0 {
      0x90
    } else {
      0x80
    }
    let high = if i == 1 && first == 0xed {
      0x9f
    } else if i == 1 && first == 0xf4 {
      0x8f
    } else {
      0xbf
    }
    if byte < low || byte > high {
      return -1
    }
  }
  length
}

///|
fn csv_decode_utf8(data : Bytes) -> String {
  let output = StringBuilder()
  let mut start = 0
  let mut at = 0
  let mut bad = false
  while at < data.length() {
    let size = csv_utf8_sequence(data, at)
    if size > 0 {
      at += size
      bad = false
      continue
    }
    if start < at {
      output.write_string(@utf8.decode_lossy(data[start:at]))
    }
    if !bad {
      output.write_char('\u{fffd}')
    }
    bad = true
    at += 1
    start = at
  }
  if start < data.length() {
    output.write_string(@utf8.decode_lossy(data[start:]))
  }
  output.to_string()
}

///|
fn csv_mostly_utf8(data : Bytes) -> Bool {
  let mut at = 0
  let mut multi = 0
  let mut bad = 0
  let mut incomplete = false
  while at < data.length() {
    let n = csv_utf8_sequence(data, at)
    if n == 0 {
      incomplete = true
      break
    }
    if n < 0 {
      bad += 1
      at += 1
    } else {
      if n > 1 {
        multi += 1
      }
      at += n
    }
  }
  if bad == 0 && !incomplete {
    return true
  }
  multi > 0 && bad.to_int64() * 20L <= multi.to_int64()
}
