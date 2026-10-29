///|
priv struct FontNameRecord {
  id : Int32
  text : String
}

///|
fn rebuild_notices(font : Font) -> Array[FontNameRecord] raise {
  let names = sfnt_table(font.source, font.tables, "name")
  let scores : Map[Int32, Int32] = Map([])
  let texts : Map[Int32, String] = Map([])
  let ids = [0, 7, 8, 9, 11, 12, 13, 14]
  if names.length() < 6 {
    return []
  }
  let count = u16(names, 2)
  let string_offset = u16(names, 4)
  let mut remaining = 4 * 1024 * 1024
  for i in 0..<count {
    let record = 6 + i * 12
    if record > names.length() - 12 {
      break
    }
    let platform = u16(names, record)
    let language = u16(names, record + 4)
    let id = u16(names, record + 6)
    let length = u16(names, record + 8)
    let offset = string_offset + u16(names, record + 10)
    if offset > names.length() ||
      length > names.length() - offset ||
      !ids.contains(id) {
      continue
    }
    let score = if platform == 0 || platform == 3 {
      if platform == 3 && language == 0x0409 {
        3
      } else {
        2
      }
    } else if platform == 1 {
      1
    } else {
      0
    }
    if score <= scores.get(id).unwrap_or(0) {
      continue
    }
    remaining -= length
    if remaining < 0 {
      raise InvalidFont(
        "sfnt: the records of the name table are too long together",
      )
    }
    let raw = names[offset:offset + length]
    let text = if platform == 1 {
      let chars : Array[Char] = []
      let mut ascii = true
      for byte in raw {
        if byte >= 128 {
          ascii = false
          break
        }
        chars.push(byte.to_int().unsafe_to_char())
      }
      if !ascii {
        continue
      }
      String::from_array(chars)
    } else {
      decode_name_utf16(raw)
    }
    if text != "" {
      scores[id] = score
      texts[id] = text
    }
  }
  [
    for id in ids if texts.contains(id) => { id, text: texts[id], }
  ]
}

///|
fn sanitize_postscript(text : String) -> String {
  let out = StringBuilder()
  for ch in text {
    if ch.to_int() > 32 &&
      ch.to_int() < 127 &&
      ch != '[' &&
      ch != ']' &&
      ch != '(' &&
      ch != ')' &&
      ch != '{' &&
      ch != '}' &&
      ch != '<' &&
      ch != '>' &&
      ch != '/' &&
      ch != '%' {
      out.write_char(ch)
    }
  }
  let result = out.to_string()
  if result == "" {
    "Font"
  } else {
    result
  }
}

///|
fn utf16be(text : String) -> Array[Byte] {
  let out : Array[Byte] = []
  for ch in text {
    let code = ch.to_int()
    if code <= 0xffff {
      push16(out, code)
    } else {
      let v = code - 0x10000
      push16(out, 0xd800 | (v >> 10))
      push16(out, 0xdc00 | (v & 0x3ff))
    }
  }
  out
}

///|
priv struct EncodedFontName {
  id : Int32
  offset : Int32
  bytes : Array[Byte]
}

///|
fn build_names(font : Font) -> Array[Byte] raise {
  let family = font.info.family
  let style = if font.info.weight >= 600 && font.info.italic {
    "Bold Italic"
  } else if font.info.weight >= 600 {
    "Bold"
  } else if font.info.italic {
    "Italic"
  } else {
    "Regular"
  }
  let full = if style == "Regular" { family } else { family + " " + style }
  let records : Array[FontNameRecord] = [
    { id: 1, text: family, },
    { id: 2, text: style, },
    { id: 3, text: family + ";" + style, },
    { id: 4, text: full, },
    { id: 5, text: "Version 1.0", },
    { id: 6, text: sanitize_postscript(family + "-" + style), },
  ]
  for notice in rebuild_notices(font) {
    records.push(notice)
  }
  records.sort_by((a, b) => a.id.compare(b.id))
  let strings : Array[Byte] = []
  let encoded : Array[EncodedFontName] = []
  for record in records {
    let bytes = utf16be(record.text)
    if bytes.length() > 0xffff - strings.length() {
      continue
    }
    encoded.push({ id: record.id, offset: strings.length(), bytes, })
    for byte in bytes {
      strings.push(byte)
    }
  }
  let out : Array[Byte] = []
  push16(out, 0)
  push16(out, encoded.length())
  push16(out, 6 + encoded.length() * 12)
  for entry in encoded {
    push16(out, 3)
    push16(out, 1)
    push16(out, 0x0409)
    push16(out, entry.id)
    push16(out, entry.bytes.length())
    push16(out, entry.offset)
  }
  for byte in strings {
    out.push(byte)
  }
  out
}
