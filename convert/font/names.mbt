///|
/// A decoded name-table record with its platform preference and language.
pub(all) struct SpecimenName {
  id : Int32
  lang : String
  english : Bool
  text : String
  rank : Int32
}

///|
/// Name records and whether the upstream four-megabyte decoding limit was hit.
pub(all) struct SpecimenNames {
  records : Array[SpecimenName]
  cut : Bool
}

///|
fn name_utf16(data : BytesView) -> String {
  let out = StringBuilder()
  let mut i = 0
  while i + 1 < data.length() {
    let first = be16(data, i)
    i += 2
    if first >= 0xd800 && first <= 0xdbff && i + 1 < data.length() {
      let second = be16(data, i)
      if second >= 0xdc00 && second <= 0xdfff {
        out.write_char(
          (0x10000 + ((first - 0xd800) << 10) + second - 0xdc00).unsafe_to_char(),
        )
        i += 2
        continue
      }
    }
    if first >= 0xd800 && first <= 0xdfff {
      out.write_char('\u{fffd}')
    } else {
      out.write_char(first.unsafe_to_char())
    }
  }
  out.to_string()
}

///|
fn name_hex(n : Int32) -> String {
  let digits = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F',
  ]
  let chars : Array[Char] = []
  let mut n = n
  while n >= 16 {
    chars.push(digits[n & 15])
    n = n >> 4
  }
  chars.push(digits[n & 15])
  let out = StringBuilder()
  for i = chars.length() - 1; i >= 0; i = i - 1 {
    out.write_char(chars[i])
  }
  out.to_string()
}

///|
fn name_language(
  id : Int32,
  tags : Array[String],
  known : Map[Int32, String],
) -> String {
  if id >= 0x8000 {
    let i = id - 0x8000
    return if i < tags.length() { tags[i] } else { "" }
  }
  known.get(id).unwrap_or("0x" + name_hex(id))
}

///|
fn name_decode_legacy(
  raw : BytesView,
  encoding : String,
  wide : Bool,
) -> String {
  let bytes : Array[Byte] = []
  if wide {
    for i = 0; i + 1 < raw.length(); i = i + 2 {
      if raw[i] != 0 {
        bytes.push(raw[i])
      }
      bytes.push(raw[i + 1])
    }
  } else {
    for byte in raw {
      bytes.push(byte)
    }
  }
  @csv.decode_charset(Bytes::from_array(bytes), encoding) catch {
    _ => ""
  }
}

///|
fn trim_name_nuls(text : String) -> String {
  let out = StringBuilder()
  let mut zeros = 0
  for ch in text {
    if ch == '\u{0}' {
      zeros += 1
    } else {
      while zeros > 0 {
        out.write_char('\u{0}')
        zeros -= 1
      }
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
/// Decode a raw OpenType name table with upstream platform, language, and
/// duplicate-record rules. The input and decoded work are size-bounded.
pub fn parse_specimen_names(data : Bytes) -> SpecimenNames {
  let records : Array[SpecimenName] = []
  if data.length() < 6 {
    return { records, cut: false, }
  }
  let count = be16(data[:], 2)
  let strings = be16(data[:], 4)
  let mut left = 4194304
  let tags : Array[String] = []
  if be16(data[:], 0) == 1 {
    let p = 6 + count * 12
    let n = Int32::min(
      be16(data[:], p),
      Int32::max((data.length() - p - 2) / 4, 0),
    )
    for i in 0..<n {
      let len = be16(data[:], p + 2 + i * 4)
      let off = strings + be16(data[:], p + 4 + i * 4)
      left -= len
      if left < 0 {
        return { records, cut: true, }
      }
      tags.push(
        if off + len <= data.length() {
          name_utf16(data[off:off + len])
        } else {
          ""
        },
      )
    }
  }
  let seen : Map[String, Bool] = Map([])
  for i in 0..<count {
    let rec = 6 + i * 12
    if rec + 12 > data.length() {
      break
    }
    let pid = be16(data[:], rec)
    let eid = be16(data[:], rec + 2)
    let lid = be16(data[:], rec + 4)
    let id = be16(data[:], rec + 6)
    let len = be16(data[:], rec + 8)
    let off = strings + be16(data[:], rec + 10)
    if off + len > data.length() || len == 0 {
      continue
    }
    left -= len
    if left < 0 {
      return { records, cut: true, }
    }
    let raw = data[off:off + len]
    let (decoded, rank, lang, english) = match pid {
      0 => (name_utf16(raw), 2, name_language(lid, tags, {}), false)
      3 => {
        let text = match eid {
          0 | 1 | 10 => name_utf16(raw)
          2 => name_decode_legacy(raw, "shift_jis", true)
          3 => name_decode_legacy(raw, "gbk", true)
          4 => name_decode_legacy(raw, "big5", true)
          5 => name_decode_legacy(raw, "euc-kr", true)
          _ => ""
        }
        (
          text,
          3,
          name_language(lid, tags, windows_name_languages),
          (lid & 0x3ff) == 9,
        )
      }
      1 => {
        let enc = match eid {
          0 => "macintosh"
          1 => "shift_jis"
          2 => "big5"
          3 => "euc-kr"
          25 => "gbk"
          _ => ""
        }
        (
          if enc == "" {
            ""
          } else {
            name_decode_legacy(raw, enc, false)
          },
          1,
          name_language(lid, tags, mac_name_languages),
          lid == 0,
        )
      }
      _ => ("", 0, "", false)
    }
    let text = trim_name_nuls(decoded)
    if font_trim(text) == "" {
      continue
    }
    let key = id.to_string() + "\u{0}" + lang + "\u{0}" + text
    if seen.contains(key) {
      continue
    }
    seen[key] = true
    records.push({ id, lang, english, text, rank, })
  }
  { records, cut: false, }
}

///|
/// Decode the face's name table for the font specimen.
pub fn FileFace::specimen_names(self : FileFace) -> SpecimenNames {
  parse_specimen_names(self.font.table("name").unwrap_or(b""))
}

///|
/// Select the best record of an ID, preferring English Windows names.
pub fn SpecimenNames::best(self : SpecimenNames, id : Int32) -> String {
  let mut result = ""
  let mut score = -1
  for record in self.records {
    if record.id == id {
      let n = record.rank + (if record.english { 10 } else { 0 })
      if n > score {
        result = record.text
        score = n
      }
    }
  }
  result
}

///|
/// Return non-English translations distinct from the preferred name.
pub fn SpecimenNames::local(
  self : SpecimenNames,
  id : Int32,
) -> Array[SpecimenName] {
  let seen : Map[String, Bool] = Map([])
  seen[self.best(id)] = true
  let result : Array[SpecimenName] = []
  for record in self.records {
    if record.id == id && !record.english && !seen.contains(record.text) {
      seen[record.text] = true
      result.push(record)
    }
  }
  result
}

///|
pub fn SpecimenNames::family(self : SpecimenNames) -> String {
  for id in [16, 1, 4] {
    let s = self.best(id)
    if s != "" {
      return s
    }
  }
  ""
}

///|
pub fn SpecimenNames::full(self : SpecimenNames) -> String {
  let full = self.best(4)
  if full != "" {
    return full
  }
  let family = self.family()
  let preferred = self.best(17)
  let style = if preferred == "" { self.best(2) } else { preferred }
  if family != "" && style != "" {
    family + " " + style
  } else {
    family
  }
}
