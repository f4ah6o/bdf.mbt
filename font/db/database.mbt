///|
/// A supplied font face, identified by its source name and collection index.
pub struct Face {
  path : String
  index : Int32
  font : @sfnt.Font
}

///|
/// An in-memory font database. Files are added in search order by the host.
pub struct Database {
  priv faces : Array[Face]
  priv by_name : Map[String, Array[Int32]]
}

///|
pub fn Database::new() -> Database {
  { faces: [], by_name: Map([]), }
}

///|
/// Registered faces in search order.
pub fn Database::faces(self : Database) -> Array[Face] {
  self.faces.copy()
}

///|
/// Add a parsed face. Duplicate source paths and face indexes are ignored.
/// Faces without a family name are ignored, as in the upstream scanner.
pub fn Database::add(
  self : Database,
  path : String,
  index : Int32,
  font : @sfnt.Font,
) -> Unit {
  for face in self.faces {
    if face.path == path && face.index == index {
      return
    }
  }
  let names = font.family_names()
  if names.length() == 0 || font.info.family == "" {
    return
  }
  let id = self.faces.length()
  self.faces.push({ path, index, font, })
  let seen : Map[String, Bool] = Map([])
  for name in names {
    let key = normalize(name)
    if key == "" || seen.contains(key) {
      continue
    }
    seen[key] = true
    let list = match self.by_name.get(key) {
      Some(list) => list
      None => {
        let list : Array[Int32] = []
        self.by_name[key] = list
        list
      }
    }
    list.push(id)
  }
}

///|
/// Add every readable face in an SFNT file or collection. The caller supplies
/// file contents, so discovery and filesystem access remain host controlled.
pub fn Database::add_file(
  self : Database,
  path : String,
  data : Bytes,
) -> Int32 {
  let count = @sfnt.face_count(data)
  if data.has_prefix(b"ttcf") &&
    (count <= 0 || count > 256 || count > (data.length() - 12) / 4) {
    return 0
  }
  let before = self.faces.length()
  for index in 0..<count {
    match (Some(@sfnt.parse(data, index~)) catch { _ => None }) {
      Some(font) => self.add(path, index, font)
      None => ()
    }
  }
  self.faces.length() - before
}

///|
/// Get a registered face by the index returned in a resolution.
pub fn Database::face(self : Database, index : Int32) -> Face? {
  self.faces.get(index)
}

///|
fn Database::family(self : Database, name : String) -> Array[Int32] {
  self.by_name.get(normalize(name)).unwrap_or([])
}

///|
/// A resolved face and synthetic style flags; face is None when the database
/// contains no matching or fallback font.
pub(all) struct Resolved {
  face : Int32?
  synth_bold : Bool
  synth_italic : Bool
  exact : Bool
  generic : String
} derive(Debug, Eq)

///|
fn Database::match_face(
  self : Database,
  faces : Array[Int32],
  bold : Bool,
  italic : Bool,
  generic : String,
  exact : Bool,
) -> Resolved {
  let want = if bold { 700 } else { 400 }
  let mut best = None
  let mut best_score = 1073741824
  for id in faces {
    let info = self.faces[id].font.info
    let mut score = Int32::abs(info.weight - want) * 2
    if (bold && info.weight < 600) || (!bold && info.weight >= 600) {
      score += 1000
    }
    if info.italic != italic {
      score += 5000
    }
    if score < best_score {
      best = Some(id)
      best_score = score
    }
  }
  match best {
    Some(id) => {
      let info = self.faces[id].font.info
      {
        face: Some(id),
        synth_bold: bold && info.weight < 600,
        synth_italic: italic && !info.italic,
        exact,
        generic,
      }
    }
    None =>
      { face: None, synth_bold: false, synth_italic: false, exact, generic, }
  }
}

///|
fn Database::try_families(
  self : Database,
  names : Array[String],
  bold : Bool,
  italic : Bool,
  generic : String,
) -> Resolved? {
  for name in names {
    let faces = self.family(name)
    if faces.length() > 0 {
      return Some(self.match_face(faces, bold, italic, generic, false))
    }
  }
  None
}

///|
/// Resolve a family request using upstream's substitutions and fallback chains.
pub fn Database::resolve(
  self : Database,
  family : String,
  bold~ : Bool = false,
  italic~ : Bool = false,
  cjk~ : Bool = false,
) -> Resolved {
  let generic = classify(family)
  if family != "" {
    let matches = self.family(family)
    if matches.length() > 0 {
      return self.match_face(matches, bold, italic, generic, true)
    }
  }
  match
    self.try_families(substitutes(normalize(family)), bold, italic, generic) {
    Some(found) => return found
    None => ()
  }
  let bold = bold || heavy_name(family)
  if cjk {
    let chain = if generic == "serif" { ja_mincho } else { ja_gothic }
    for names in [chain, zh_hans, ko_gothic] {
      match self.try_families(names, bold, italic, generic) {
        Some(found) => return found
        None => ()
      }
    }
  }
  for names in [generic_latin(generic), generic_latin("sans-serif")] {
    match self.try_families(names, bold, italic, generic) {
      Some(found) => return found
      None => ()
    }
  }
  if !cjk {
    for names in [ja_gothic, zh_hans] {
      match self.try_families(names, bold, italic, generic) {
        Some(found) => return found
        None => ()
      }
    }
  }
  if self.faces.length() > 0 {
    let mut first = self.faces[0].font.info.family
    for face in self.faces {
      if face.font.info.family < first {
        first = face.font.info.family
      }
    }
    let same : Array[Int32] = []
    for id, face in self.faces {
      if face.font.info.family == first {
        same.push(id)
      }
    }
    return self.match_face(same, bold, italic, generic, false)
  }
  { face: None, synth_bold: false, synth_italic: false, exact: false, generic, }
}

///|
/// Resolve a math font by requested family and upstream's fallback order.
pub fn Database::resolve_math(self : Database, family : String) -> Int32? {
  let pick = (name : String) => {
    let matches = self
      .family(name)
      .filter(id => self.faces[id].font.info.has_math)
    self.match_face(matches, false, false, "serif", false).face
  }
  if family != "" {
    match pick(family) {
      Some(id) => return Some(id)
      None => ()
    }
  }
  for name in math_families {
    match pick(name) {
      Some(id) => return Some(id)
      None => ()
    }
  }
  for face in self.faces {
    if face.font.info.has_math {
      return pick(face.font.info.family)
    }
  }
  None
}

///|
/// Faces to try for missing glyphs, in the order used by the upstream DB.
pub fn Database::fallbacks(
  self : Database,
  generic : String,
  bold~ : Bool = false,
  italic~ : Bool = false,
) -> Array[Resolved] {
  let out : Array[Resolved] = []
  let seen : Map[Int32, Bool] = Map([])
  let add = (names : Array[String]) => {
    for name in names {
      let matches = self.family(name)
      if matches.length() == 0 {
        continue
      }
      let resolved = self.match_face(matches, bold, italic, generic, false)
      match resolved.face {
        Some(id) if !seen.contains(id) => {
          seen[id] = true
          out.push(resolved)
        }
        _ => ()
      }
    }
  }
  add(generic_latin(generic))
  if generic == "serif" {
    add(ja_mincho)
  }
  for
    names in [
      ja_gothic,
      zh_hans,
      zh_hant,
      ko_gothic,
      generic_latin("sans-serif"),
      generic_symbols,
    ] {
    add(names)
  }
  if self.faces.length() <= 64 {
    let seen_families : Map[String, Bool] = Map([])
    let families : Array[String] = []
    for face in self.faces {
      let name = face.font.info.family
      if !seen_families.contains(name) {
        seen_families[name] = true
        families.push(name)
      }
    }
    add(families)
  }
  out
}
