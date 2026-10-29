///|
/// The name and Unicode characters associated with one glyph ID.
pub(all) struct SpecimenGlyph {
  name : String
  characters : Array[Int32]
  label : String
  alternative : String
}

///|
fn character_label(chars : Array[Int32]) -> String {
  if chars.length() == 0 {
    return ""
  }
  let mut hex = name_hex(chars[0])
  while hex.length() < 4 {
    hex = "0" + hex
  }
  let base = "U+" + hex
  if chars.length() == 1 {
    base
  } else {
    base + " +" + (chars.length() - 1).to_string()
  }
}

///|
/// Return glyph names and reverse character mappings in glyph-ID order.
pub fn FileFace::specimen_glyphs(self : FileFace) -> Array[SpecimenGlyph] {
  let names = self.font.glyph_names()
  let chars : Array[Array[Int32]] = [
    for _ in 0..<self.font.metrics.glyph_count => []
  ]
  for code in self.font.characters() {
    match self.font.glyph(code) {
      Some(gid) => chars[gid].push(code)
      None => ()
    }
  }
  [
    for gid in 0..<chars.length() => {
      let mapped = chars[gid]
      let alternative = if mapped.length() == 0 ||
        mapped[0] < 32 ||
        (mapped[0] >= 127 && mapped[0] <= 159) {
        ""
      } else {
        String::from_array([mapped[0].to_char().unwrap_or('\u{fffd}')])
      }
      {
        name: names[gid],
        characters: mapped,
        label: character_label(mapped),
        alternative,
      }
    }
  ]
}

///|
/// A Unicode script and its number of mapped characters.
pub(all) struct ScriptCount {
  name : String
  count : Int32
}

///|
fn specimen_script(code : Int32) -> String {
  let mut lo = 0
  let mut hi = specimen_script_ranges.length()
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    let (first, last, name) = specimen_script_ranges[mid]
    if code < first {
      hi = mid
    } else if code > last {
      lo = mid + 1
    } else {
      return name
    }
  }
  "Unknown"
}

///|
fn script_name_compare(a : String, b : String) -> Int32 {
  let left : Array[Char] = [ for c in a => c ]
  let right : Array[Char] = [ for c in b => c ]
  for i in 0..<Int32::min(left.length(), right.length()) {
    if left[i] != right[i] {
      return left[i].to_int().compare(right[i].to_int())
    }
  }
  left.length().compare(right.length())
}

///|
/// Count mapped characters by Unicode 17 script, sorted by decreasing count
/// and then by script name, matching the upstream font overview.
pub fn FileFace::script_counts(self : FileFace) -> Array[ScriptCount] {
  let counts : Map[String, Int32] = Map([])
  for code in self.font.characters() {
    let script = specimen_script(code)
    counts[script] = counts.get(script).unwrap_or(0) + 1
  }
  let result : Array[ScriptCount] = []
  for name, count in counts {
    result.push({ name, count, })
  }
  result.sort_by((a, b) => {
    if a.count == b.count {
      script_name_compare(a.name, b.name)
    } else {
      b.count.compare(a.count)
    }
  })
  result
}
