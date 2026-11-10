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
      let out = if kind == 1 { ooxml_renumber_rows(filled) } else { filled }
      entries.push((entry.name, @utf8.encode(out)))
    } else {
      entries.push((entry.name, raw))
    }
  }
  (stored_zip(entries), warnings)
}
