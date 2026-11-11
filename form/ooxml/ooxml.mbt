///|
pub suberror OoxmlError {
  OoxmlError(String)
}

///|
fn zip_u16(out : Array[Byte], value : Int) -> Unit {
  out.push((value & 0xff).to_byte())
  out.push(((value >> 8) & 0xff).to_byte())
}

///|
fn zip_u32(out : Array[Byte], value : UInt) -> Unit {
  out.push((value & 0xffU).to_byte())
  out.push(((value >> 8) & 0xffU).to_byte())
  out.push(((value >> 16) & 0xffU).to_byte())
  out.push(((value >> 24) & 0xffU).to_byte())
}

///|
fn crc32(data : Bytes) -> UInt {
  let mut crc = 0xffffffffU
  for byte in data {
    crc = crc ^ byte.to_uint()
    for _ in 0..<8 {
      if (crc & 1U) != 0U {
        crc = (crc >> 1) ^ 0xedb88320U
      } else {
        crc = crc >> 1
      }
    }
  }
  crc ^ 0xffffffffU
}

///|
/// Write a ZIP of stored entries (no compression).
pub fn stored_zip(entries : Array[(String, Bytes)]) -> Bytes raise OoxmlError {
  let out : Array[Byte] = []
  let central : Array[Byte] = []
  let mut count = 0
  for entry in entries {
    let (name, data) = entry
    if name == "" {
      raise OoxmlError("ooxml: an entry has no name")
    }
    let name_bytes = @utf8.encode(name)
    if name_bytes.length() > 0xffff {
      raise OoxmlError("ooxml: an entry name is too long")
    }
    let offset = out.length()
    let crc = crc32(data)
    zip_u32(out, 0x04034b50U)
    zip_u16(out, 20)
    zip_u16(out, 0)
    zip_u16(out, 0)
    zip_u16(out, 0)
    zip_u16(out, 0x21)
    zip_u32(out, crc)
    zip_u32(out, data.length().to_uint())
    zip_u32(out, data.length().to_uint())
    zip_u16(out, name_bytes.length())
    zip_u16(out, 0)
    for byte in name_bytes {
      out.push(byte)
    }
    for byte in data {
      out.push(byte)
    }
    zip_u32(central, 0x02014b50U)
    zip_u16(central, 20)
    zip_u16(central, 20)
    zip_u16(central, 0)
    zip_u16(central, 0)
    zip_u16(central, 0)
    zip_u16(central, 0x21)
    zip_u32(central, crc)
    zip_u32(central, data.length().to_uint())
    zip_u32(central, data.length().to_uint())
    zip_u16(central, name_bytes.length())
    zip_u16(central, 0)
    zip_u16(central, 0)
    zip_u16(central, 0)
    zip_u16(central, 0)
    zip_u32(central, 0U)
    zip_u32(central, offset.to_uint())
    for byte in name_bytes {
      central.push(byte)
    }
    count += 1
  }
  let directory_offset = out.length()
  for byte in central {
    out.push(byte)
  }
  zip_u32(out, 0x06054b50U)
  zip_u16(out, 0)
  zip_u16(out, 0)
  zip_u16(out, count)
  zip_u16(out, count)
  zip_u32(out, central.length().to_uint())
  zip_u32(out, directory_offset.to_uint())
  zip_u16(out, 0)
  Bytes::from_array(out)
}

///|
fn xml_escape(text : String) -> String {
  let out = StringBuilder()
  for c in text {
    if c == '&' {
      out.write_string("&amp;")
    } else if c == '<' {
      out.write_string("&lt;")
    } else if c == '>' {
      out.write_string("&gt;")
    } else if c == '"' {
      out.write_string("&quot;")
    } else if c == '\'' {
      out.write_string("&apos;")
    } else {
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
/// The character of a numeric entity: only the characters that XML allows, so
/// that a surrogate or a control that XML forbids stays as it is written
/// instead of becoming a character that no document can hold.
fn xml_char(value : Int) -> Char? {
  if value == 0x9 || value == 0xa || value == 0xd {
    return Some(value.unsafe_to_char())
  }
  if value >= 0x20 && value <= 0xd7ff {
    return Some(value.unsafe_to_char())
  }
  if value >= 0xe000 && value <= 0xfffd {
    return Some(value.unsafe_to_char())
  }
  if value >= 0x10000 && value <= 0x10ffff {
    return Some(value.unsafe_to_char())
  }
  None
}

///|
/// The value of the digits of a numeric entity: XML writes them without a sign
/// or a space, so `&#+65;` is not a character reference and stays as it is.
fn xml_number(digits : String, base : Int) -> Int? {
  if digits.is_empty() {
    return None
  }
  for c in digits {
    let ok = if base == 16 {
      (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
    } else {
      c >= '0' && c <= '9'
    }
    if !ok {
      return None
    }
  }
  Some(@string.parse_int(digits, base~) catch { _ => -1 })
}

///|
/// The text of an XML part with its entities back: `&amp;` becomes `&`, and
/// `&amp;quot;` becomes `&quot;` (one pass, so a text that spells an entity
/// stays as it is written). A tag of a document is written with the quotes of
/// its arguments escaped (`fmt:&quot;¥#,##0&quot;`), and the fill reads it as
/// the tag it is.
fn xml_unescape(text : String) -> String {
  let chars = text.to_array()
  let mut amp = 0
  while amp < chars.length() && chars[amp] != '&' {
    amp += 1
  }
  if amp >= chars.length() {
    return text
  }
  let out = StringBuilder()
  let mut i = 0
  while i < chars.length() {
    if chars[i] != '&' {
      out.write_char(chars[i])
      i += 1
      continue
    }
    let mut end = i + 1
    while end < chars.length() && end - i <= 12 && chars[end] != ';' {
      end += 1
    }
    if end >= chars.length() || chars[end] != ';' {
      out.write_char('&')
      i += 1
      continue
    }
    let name = String::from_array(chars[i + 1:end])
    let decoded = match name {
      "amp" => Some('&')
      "lt" => Some('<')
      "gt" => Some('>')
      "quot" => Some('"')
      "apos" => Some('\'')
      _ => {
        if name.has_prefix("#x") || name.has_prefix("#X") {
          match xml_number(name[2:].to_owned(), 16) {
            Some(value) => xml_char(value)
            None => None
          }
        } else if name.has_prefix("#") {
          match xml_number(name[1:].to_owned(), 10) {
            Some(value) => xml_char(value)
            None => None
          }
        } else {
          None
        }
      }
    }
    match decoded {
      Some(c) => {
        out.write_char(c)
        i = end + 1
      }
      None => {
        out.write_char('&')
        i += 1
      }
    }
  }
  out.to_string()
}

///|
fn visible_tag(inner : StringView) -> String {
  let out = StringBuilder()
  let mut in_markup = false
  for c in inner {
    if c == '<' {
      in_markup = true
    } else if c == '>' {
      in_markup = false
    } else if !in_markup {
      out.write_char(c)
    }
  }
  out.to_string().trim().to_owned()
}

///|
/// Report a name the data does not have: an error in strict mode, a warning
/// that the tag is left empty otherwise.
fn missing_name(
  name : String,
  strict : Bool,
  warnings : Array[String],
) -> Unit raise OoxmlError {
  if strict {
    raise OoxmlError("the data has no \"" + name + "\"")
  }
  warnings.push("the data has no \"" + name + "\"; it is left empty")
}

///|
/// Expand {{#name}}…{{/name}} and {{^name}}…{{/name}} sections and fill the
/// tags inside them.
pub fn expand_controls(
  xml : String,
  values : Json,
  strict~ : Bool = false,
) -> (String, Array[String]) raise OoxmlError {
  fill_part(xml, values, strict, 0, true)
}

///|
/// Replace {{name}} tags that stay inside one XML text node. Tags split by
/// markup are one tag; control tags are reported and left as they are.
pub fn fill_tags(
  xml : String,
  values : Json,
  strict~ : Bool = false,
) -> (String, Array[String]) raise OoxmlError {
  fill_part(xml, values, strict, 0, false)
}

///|
/// What a section of a part repeats, from the name of the part.
fn part_kind(name : String) -> Int {
  if name.has_prefix("xl/worksheets/") && name.has_suffix(".xml") {
    1
  } else if name.has_prefix("word/") && name.has_suffix(".xml") {
    2
  } else if name.has_prefix("ppt/slides/") && name.has_suffix(".xml") {
    3
  } else {
    0
  }
}

///|
/// Fill the tags of every XML part of an OOXML package and rebuild it.
pub fn fill_zip(
  data : Bytes,
  values : Json,
  strict~ : Bool = false,
) -> (Bytes, Array[String]) raise OoxmlError {
  let archive = @zip.open_zip(data) catch {
    _ => raise OoxmlError("ooxml: the package is not a ZIP")
  }
  let entries : Array[(String, Bytes)] = []
  let index : Map[String, Int] = Map([])
  let texts : Map[String, String] = Map([])
  let maps : Map[String, RowMap] = Map([])
  let warnings : Array[String] = []
  for entry in archive.entries {
    if entry.name.has_suffix("/") {
      continue
    }
    let raw = archive.read(entry, 268435456) catch {
      _ => raise OoxmlError("ooxml: a part cannot be read")
    }
    if entry.name.has_suffix(".xml") || entry.name.has_suffix(".rels") {
      let text = @utf8.decode_lossy(raw[:])
      let kind = part_kind(entry.name)
      let (filled, part_warnings) = fill_part(
        text,
        values,
        strict,
        kind,
        true,
      ) catch {
        OoxmlError(message) => raise OoxmlError(entry.name + ": " + message)
      }
      for warning in part_warnings {
        warnings.push(entry.name + ": " + warning)
      }
      let out = if kind == 1 {
        let (out, rows) = ooxml_renumber_rows(text, filled) catch {
          OoxmlError(message) => raise OoxmlError(entry.name + ": " + message)
        }
        maps[entry.name] = rows
        out
      } else {
        filled
      }
      index[entry.name] = entries.length()
      entries.push((entry.name, @utf8.encode(out)))
      texts[entry.name] = out
    } else {
      index[entry.name] = entries.length()
      entries.push((entry.name, raw))
    }
  }
  let parts : Array[String] = []
  for entry in entries {
    parts.push(entry.0)
  }
  ooxml_check_references(texts, maps, parts) catch {
    OoxmlError(message) => raise OoxmlError(message)
  }
  for name, at in index {
    match texts.get(name) {
      Some(text) => entries[at] = (name, @utf8.encode(text))
      None => ()
    }
  }
  (stored_zip(entries), warnings)
}
