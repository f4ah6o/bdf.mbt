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
fn json_field(value : Json, name : String) -> Json? {
  match value {
    Json::Object(object) => object.get(name)
    _ => None
  }
}

///|
fn lookup(values : Json, name : String) -> Json? {
  let mut current = values
  for part in name.split(".") {
    current = match json_field(current, part.to_owned()) {
      Some(value) => value
      None => return None
    }
  }
  Some(current)
}

///|
fn value_text(value : Json) -> String? {
  match value {
    Json::String(text) => Some(text)
    Json::Number(number, ..) => Some(number.to_string())
    Json::True => Some("true")
    Json::False => Some("false")
    Json::Null => Some("")
    _ => None
  }
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
fn truthy(value : Json) -> Bool {
  match value {
    Json::Null => false
    Json::True => true
    Json::False => false
    Json::Number(number, ..) => number != 0.0
    Json::String(text) => text != ""
    Json::Array(values) => values.length() > 0
    Json::Object(values) => values.size() > 0
  }
}

///|
fn next_control(xml : String, pos : Int) -> (Int, Bool)? {
  let rest = xml[pos:]
  let hash = rest.find("{{#")
  let caret = rest.find("{{^")
  match (hash, caret) {
    (Some(a), Some(b)) =>
      if a <= b {
        Some((pos + a, true))
      } else {
        Some((pos + b, false))
      }
    (Some(a), None) => Some((pos + a, true))
    (None, Some(b)) => Some((pos + b, false))
    (None, None) => None
  }
}

///|
fn merge_context(root : Json, item : Json) -> Json {
  match (root, item) {
    (Json::Object(base), Json::Object(overlay)) => {
      let merged : Map[String, Json] = Map([])
      for key, value in base {
        merged[key] = value
      }
      for key, value in overlay {
        merged[key] = value
      }
      Json::object(merged)
    }
    _ => item
  }
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
/// Expand {{#name}}…{{/name}} and {{^name}}…{{/name}} conditions.
pub fn expand_controls(
  xml : String,
  values : Json,
  strict~ : Bool = false,
) -> (String, Array[String]) raise OoxmlError {
  let warnings : Array[String] = []
  let out = StringBuilder()
  let mut pos = 0
  while pos < xml.length() {
    let (start, positive) = match next_control(xml, pos) {
      Some(found) => found
      None => {
        out.write_string(xml[pos:].to_owned())
        break
      }
    }
    out.write_string(xml[pos:start].to_owned())
    let after = xml[start + 3:]
    let end = match after.find("}}") {
      Some(index) => start + 3 + index
      None => {
        warnings.push("ooxml: a control tag has no closing braces")
        out.write_string(xml[start:].to_owned())
        break
      }
    }
    let name = xml[start + 3:end].trim().to_owned()
    let close_marker = "{{/" + name + "}}"
    let close = match xml[end + 2:].find(close_marker) {
      Some(index) => end + 2 + index
      None => {
        warnings.push("ooxml: the control tag {{" + name + "}} has no end")
        out.write_string(xml[start:end + 2].to_owned())
        pos = end + 2
        continue
      }
    }
    let inner = xml[end + 2:close]
    let value = match lookup(values, name) {
      Some(value) => Some(value)
      None => {
        missing_name(name, strict, warnings)
        None
      }
    }
    let items = match value {
      Some(Json::Array(items)) => Some(items)
      _ => None
    }
    if positive && items is Some(items) {
      for item in items {
        if item is Json::Object(_) {
          let context = merge_context(values, item)
          let (expanded, inner_warnings) = expand_controls(
            inner.to_owned(),
            context,
            strict~,
          )
          let (filled, tag_warnings) = fill_tags(expanded, context, strict~)
          out.write_string(filled)
          for warning in inner_warnings {
            warnings.push(warning)
          }
          for warning in tag_warnings {
            warnings.push(warning)
          }
        } else {
          warnings.push("ooxml: a list item is not an object")
        }
      }
      pos = close + close_marker.length()
      continue
    }
    let condition = match value {
      Some(value) => truthy(value)
      None => false
    }
    let keep = if positive { condition } else { !condition }
    if keep {
      let (expanded, inner_warnings) = expand_controls(
        inner.to_owned(),
        values,
        strict~,
      )
      out.write_string(expanded)
      for warning in inner_warnings {
        warnings.push(warning)
      }
    }
    pos = close + close_marker.length()
  }
  (out.to_string(), warnings)
}

///|
/// Replace {{name}} tags that stay inside one XML text node. Tags split by
/// markup and control tags are reported and left as they are.
pub fn fill_tags(
  xml : String,
  values : Json,
  strict~ : Bool = false,
) -> (String, Array[String]) raise OoxmlError {
  let warnings : Array[String] = []
  let out = StringBuilder()
  let mut pos = 0
  while pos < xml.length() {
    let rest = xml[pos:]
    let start = match rest.find("{{") {
      Some(index) => pos + index
      None => {
        out.write_string(rest.to_owned())
        break
      }
    }
    out.write_string(xml[pos:start].to_owned())
    let after = xml[start + 2:]
    let end = match after.find("}}") {
      Some(index) => start + 2 + index
      None => {
        warnings.push("ooxml: a tag has no closing braces")
        out.write_string(xml[start:].to_owned())
        break
      }
    }
    let inner = xml[start + 2:end]
    let name = visible_tag(inner)
    if name.has_prefix("#") || name.has_prefix("/") || name.has_prefix("^") ||
      name.has_prefix("!") {
      warnings.push(
        "ooxml: the control tag {{" + name + "}} is not supported",
      )
      out.write_string(xml[start:end + 2].to_owned())
    } else if name == "" {
      warnings.push("ooxml: a tag has no name")
      out.write_string(xml[start:end + 2].to_owned())
    } else {
      let value = match lookup(values, name) {
        Some(value) =>
          match value_text(value) {
            Some(text) => text
            None => ""
          }
        None => {
          missing_name(name, strict, warnings)
          ""
        }
      }
      out.write_string(xml_escape(value))
    }
    pos = end + 2
  }
  (out.to_string(), warnings)
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
      let (expanded, control_warnings) = expand_controls(text, values, strict~) catch {
        OoxmlError(message) => raise OoxmlError(entry.name + ": " + message)
      }
      let (filled, tag_warnings) = fill_tags(expanded, values, strict~) catch {
        OoxmlError(message) => raise OoxmlError(entry.name + ": " + message)
      }
      for warning in control_warnings {
        warnings.push(entry.name + ": " + warning)
      }
      for warning in tag_warnings {
        warnings.push(entry.name + ": " + warning)
      }
      entries.push((entry.name, @utf8.encode(filled)))
    } else {
      entries.push((entry.name, raw))
    }
  }
  (stored_zip(entries), warnings)
}
