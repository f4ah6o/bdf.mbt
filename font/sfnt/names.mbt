///|
/// The family and face properties used when selecting a font.
pub(all) struct FaceInfo {
  family : String
  style : String
  weight : Int32
  italic : Bool
  monospace : Bool
  has_math : Bool
}

///|
fn decode_name_utf16(data : BytesView) -> String {
  let output = StringBuilder()
  let mut i = 0
  while i + 1 < data.length() {
    let first = u16(data, i)
    i += 2
    if first >= 0xd800 && first <= 0xdbff && i + 1 < data.length() {
      let second = u16(data, i)
      if second >= 0xdc00 && second <= 0xdfff {
        output.write_char(
          (0x10000 + ((first - 0xd800) << 10) + second - 0xdc00).unsafe_to_char(),
        )
        i += 2
        continue
      }
    }
    if first >= 0xd800 && first <= 0xdfff {
      output.write_char('\u{fffd}')
    } else {
      output.write_char(first.unsafe_to_char())
    }
  }
  output.to_string()
}

///|
fn trim_name(text : String) -> String {
  let out = StringBuilder()
  let pending = StringBuilder()
  let mut started = false
  for character in text {
    if character.is_whitespace() {
      if started {
        pending.write_char(character)
      }
    } else {
      if started {
        out.write_string(pending.to_string())
        pending.reset()
      }
      out.write_char(character)
      started = true
    }
  }
  out.to_string()
}

///|
fn read_face_info(
  data : Bytes,
  tables : Map[String, (Int32, Int32)],
) -> FaceInfo {
  let names = sfnt_table(data, tables, "name")
  let chosen : Map[Int32, (String, Bool)] = Map([])
  if names.length() >= 6 && names.length() <= 1048576 {
    let count = u16(names, 2)
    let string_offset = u16(names, 4)
    for i in 0..<count {
      let rec = 6 + i * 12
      if rec > names.length() - 12 {
        break
      }
      let platform = u16(names, rec)
      let encoding = u16(names, rec + 2)
      let lang = u16(names, rec + 4)
      let id = u16(names, rec + 6)
      if id != 1 && id != 2 && id != 16 && id != 17 {
        continue
      }
      let size = u16(names, rec + 8)
      let start = string_offset + u16(names, rec + 10)
      if start > names.length() || size > names.length() - start {
        continue
      }
      let raw = names[start:start + size]
      let (name, english) = if (
          platform == 3 && (encoding == 1 || encoding == 10 || encoding == 0)
        ) ||
        platform == 0 {
        (trim_name(decode_name_utf16(raw)), lang == 0x0409)
      } else if platform == 1 && encoding == 0 {
        (trim_name(@utf8.decode_lossy(raw)), true)
      } else {
        continue
      }
      if name == "" {
        continue
      }
      match chosen.get(id) {
        Some((_, true)) => ()
        Some((_, false)) if !english => ()
        _ => chosen[id] = (name, english)
      }
    }
  }
  let name = (id : Int32, fallback : String) => {
    match chosen.get(id) {
      Some((value, _)) => value
      None => fallback
    }
  }
  let family = name(16, name(1, ""))
  let style = name(17, name(2, "Regular"))
  let os2 = sfnt_table(data, tables, "OS/2")
  let weight = if os2.length() >= 64 { u16(os2, 4) } else { 400 }
  let weight = if weight >= 100 && weight <= 1000 { weight } else { 400 }
  let lowered = style.to_lower()
  let italic = (os2.length() >= 64 && (u16(os2, 62) & 1) != 0) ||
    lowered.contains("italic") ||
    lowered.contains("oblique")
  let post = sfnt_table(data, tables, "post")
  {
    family,
    style,
    weight,
    italic,
    monospace: post.length() >= 16 && u32(post, 12) != 0U,
    has_math: tables.contains("MATH"),
  }
}

///|
/// Family names (legacy and typographic) in all available languages.
pub fn Font::family_names(self : Font) -> Array[String] {
  let names = sfnt_table(self.source, self.tables, "name")
  let result : Array[String] = []
  let mut has_legacy = false
  if names.length() < 6 || names.length() > 1048576 {
    return result
  }
  let count = u16(names, 2)
  let string_offset = u16(names, 4)
  for i in 0..<count {
    let rec = 6 + i * 12
    if rec > names.length() - 12 {
      break
    }
    let platform = u16(names, rec)
    let encoding = u16(names, rec + 2)
    let id = u16(names, rec + 6)
    if id != 1 && id != 16 {
      continue
    }
    let size = u16(names, rec + 8)
    let start = string_offset + u16(names, rec + 10)
    if start > names.length() || size > names.length() - start {
      continue
    }
    let raw = names[start:start + size]
    let name = if (
        platform == 3 && (encoding == 0 || encoding == 1 || encoding == 10)
      ) ||
      platform == 0 {
      trim_name(decode_name_utf16(raw))
    } else if platform == 1 && encoding == 0 {
      trim_name(@utf8.decode_lossy(raw))
    } else {
      continue
    }
    if name != "" {
      result.push(name)
      if id == 1 {
        has_legacy = true
      }
    }
  }
  if has_legacy {
    result
  } else {
    []
  }
}
