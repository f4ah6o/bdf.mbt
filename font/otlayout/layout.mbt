///|
/// OpenType language system and its feature indices.
pub(all) struct LanguageSystem {
  tag : String
  required : Int32
  features : Array[Int32]
}

///|
/// OpenType script and its default and named language systems.
pub(all) struct LayoutScript {
  tag : String
  default_language : LanguageSystem?
  languages : Array[LanguageSystem]
}

///|
/// A feature and its lookup indices and optional UI name and characters.
pub(all) struct LayoutFeature {
  tag : String
  lookups : Array[Int32]
  ui_name : Int32
  characters : Array[Int32]
}

///|
/// Lookup type, flags, and optional mark-filtering-set index.
pub(all) struct LayoutLookup {
  typ : Int32
  flag : Int32
  mark_set : Int32
}

///|
/// The common structural metadata of a GSUB or GPOS table.
pub(all) struct Layout {
  scripts : Array[LayoutScript]
  features : Array[LayoutFeature]
  lookups : Array[LayoutLookup]
  feature_variations : Int32
}

///|
fn layout_tag(data : BytesView, off : Int32) -> String {
  if off < 0 || off + 4 > data.length() {
    ""
  } else {
    @utf8.decode_lossy(data[off:off + 4])
  }
}

///|
fn layout_language(
  data : BytesView,
  tag : String,
  left : Ref[Int32],
) -> LanguageSystem {
  let req = u16(data, 2)
  let n = count(data, u16(data, 4), 6, 2)
  if !take(left, n) {
    return {
      tag,
      required: if req == 0xffff {
        -1
      } else {
        req
      },
      features: [],
    }
  }
  {
    tag,
    required: if req == 0xffff {
      -1
    } else {
      req
    },
    features: [
      for i in 0..<n => u16(data, 6 + i * 2)
    ],
  }
}

///|
fn layout_scripts(data : BytesView?, left : Ref[Int32]) -> Array[LayoutScript] {
  let out : Array[LayoutScript] = []
  guard data is Some(data) else { return out }
  let n = count(data, u16(data, 0), 2, 6)
  if !take(left, n) {
    return out
  }
  for i in 0..<n {
    let rec = 2 + i * 6
    guard at(data, u16(data, rec + 4)) is Some(script) else { continue }
    let default_language = match at(script, u16(script, 0)) {
      Some(lang) => Some(layout_language(lang, "", left))
      None => None
    }
    let m = count(script, u16(script, 2), 4, 6)
    if !take(left, m) {
      return []
    }
    let languages : Array[LanguageSystem] = []
    for j in 0..<m {
      let r = 4 + j * 6
      match at(script, u16(script, r + 4)) {
        Some(lang) =>
          languages.push(layout_language(lang, layout_tag(script, r), left))
        None => ()
      }
    }
    if left.val < 0 {
      return []
    }
    out.push({ tag: layout_tag(data, rec), default_language, languages, })
  }
  out
}

///|
fn layout_features(
  data : BytesView?,
  left : Ref[Int32],
) -> Array[LayoutFeature] {
  let out : Array[LayoutFeature] = []
  guard data is Some(data) else { return out }
  let n = count(data, u16(data, 0), 2, 6)
  if !take(left, n) {
    return out
  }
  for i in 0..<n {
    let rec = 2 + i * 6
    let lookups : Array[Int32] = []
    let characters : Array[Int32] = []
    let mut ui_name = 0
    match at(data, u16(data, rec + 4)) {
      Some(feature) => {
        let m = count(feature, u16(feature, 2), 4, 2)
        if !take(left, m) {
          return []
        }
        for j in 0..<m {
          lookups.push(u16(feature, 4 + j * 2))
        }
        match at(feature, u16(feature, 0)) {
          Some(p) if data[rec + 2] >= b'0' &&
            data[rec + 2] <= b'9' &&
            data[rec + 3] >= b'0' &&
            data[rec + 3] <= b'9' =>
            if data[rec] == b's' &&
              data[rec + 1] == b's' &&
              p.length() >= 4 &&
              u16(p, 0) == 0 {
              ui_name = u16(p, 2)
            } else if data[rec] == b'c' &&
              data[rec + 1] == b'v' &&
              p.length() >= 14 &&
              u16(p, 0) == 0 {
              ui_name = u16(p, 2)
              let m = count(p, u16(p, 12), 14, 3)
              if !take(left, m) {
                return []
              }
              for j in 0..<m {
                let r = 14 + j * 3
                characters.push(
                  (p[r].to_int() << 16) |
                  (p[r + 1].to_int() << 8) |
                  p[r + 2].to_int(),
                )
              }
            }
          _ => ()
        }
      }
      None => ()
    }
    if left.val < 0 {
      return []
    }
    out.push({ tag: layout_tag(data, rec), lookups, ui_name, characters, })
  }
  out
}

///|
fn layout_lookups(
  data : BytesView?,
  left : Ref[Int32],
  gpos : Bool,
) -> Array[LayoutLookup] {
  let out : Array[LayoutLookup] = []
  guard data is Some(data) else { return out }
  let n = count(data, u16(data, 0), 2, 2)
  if !take(left, n) {
    return out
  }
  let ext = if gpos { 9 } else { 7 }
  for i in 0..<n {
    let mut typ = 0
    let mut flag = 0
    let mut mark_set = -1
    match at(data, u16(data, 2 + 2 * i)) {
      Some(lookup) => {
        typ = u16(lookup, 0)
        flag = u16(lookup, 2)
        let m = count(lookup, u16(lookup, 4), 6, 2)
        if !take(left, m) {
          return []
        }
        if (flag & 16) != 0 {
          mark_set = u16(lookup, 6 + m * 2)
        }
        if typ == ext {
          typ = 0
          for j in 0..<m {
            guard at(lookup, u16(lookup, 6 + j * 2)) is Some(st) else {
              continue
            }
            let t = u16(st, 2)
            if u16(st, 0) != 1 || t == ext || (typ != 0 && typ != t) {
              continue
            }
            if at32(st, u32(st, 4)) is Some(_) {
              typ = t
            }
          }
        }
      }
      None => ()
    }
    out.push({ typ, flag, mark_set, })
  }
  out
}

///|
fn clean_language(lang : LanguageSystem, count : Int32) -> LanguageSystem {
  {
    tag: lang.tag,
    required: if lang.required >= count {
      -1
    } else {
      lang.required
    },
    features: [
      for f in lang.features if f < count => f
    ],
  }
}

///|
/// Parse GSUB or GPOS scripts, features, lookup metadata, and variation count.
/// Returns None for invalid headers or tables exceeding upstream's work bound.
pub fn parse_layout(data : BytesView, gpos~ : Bool = false) -> Layout? {
  if data.length() < 10 || u16(data, 0) != 1 {
    return None
  }
  let left = Ref(1048576)
  let scripts = layout_scripts(at(data, u16(data, 4)), left)
  let features = layout_features(at(data, u16(data, 6)), left)
  let lookups = layout_lookups(at(data, u16(data, 8)), left, gpos)
  if left.val < 0 {
    return None
  }
  let feature_variations = if u16(data, 2) >= 1 && data.length() >= 14 {
    match at32(data, u32(data, 10)) {
      Some(fv) => {
        let declared = u32(fv, 4)
        let available = Int32::max(fv.length() - 8, 0) / 8
        if declared > available.reinterpret_as_uint() {
          available
        } else {
          declared.reinterpret_as_int()
        }
      }
      None => 0
    }
  } else {
    0
  }
  let clean_scripts : Array[LayoutScript] = []
  for script in scripts {
    let default_language = match script.default_language {
      Some(lang) => Some(clean_language(lang, features.length()))
      None => None
    }
    clean_scripts.push({
      tag: script.tag,
      default_language,
      languages: script.languages.map(lang => {
        clean_language(lang, features.length())
      }),
    })
  }
  let clean_features = features.map(f => {
    tag: f.tag,
    lookups: [
      for l in f.lookups if l < lookups.length() => l
    ],
    ui_name: f.ui_name,
    characters: f.characters,
  })
  Some({
    scripts: clean_scripts,
    features: clean_features,
    lookups,
    feature_variations,
  })
}

///|
/// List the script and language systems using each feature, in table order.
pub fn Layout::script_features(self : Layout) -> Array[Array[String]] {
  let out : Array[Array[String]] = [ for _ in self.features => [] ]
  for script in self.scripts {
    let langs : Array[(LanguageSystem, String)] = []
    match script.default_language {
      Some(lang) => langs.push((lang, script.tag))
      None => ()
    }
    for lang in script.languages {
      langs.push((lang, script.tag + "/" + lang.tag))
    }
    for (lang, label) in langs {
      let seen : Map[Int32, Bool] = Map([])
      let all = [lang.required]
      for f in lang.features {
        all.push(f)
      }
      for f in all {
        if f >= 0 && f < out.length() && !seen.contains(f) {
          seen[f] = true
          out[f].push(label)
        }
      }
    }
  }
  out
}
