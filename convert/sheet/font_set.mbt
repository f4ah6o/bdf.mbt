///|
/// Glyph coverage for one face in a supplied font database.
pub(all) struct FaceUsage {
  face : Int32
  codepoints : Array[Int32]
}

///|
/// The faces used while drawing a grid and any characters they could not draw.
pub(all) struct FontSetUsage {
  faces : Array[FaceUsage]
  missing : Array[Int32]
}

///|
priv struct GridFontSet {
  db : @fontdb.Database
  requested : String
  cache : Map[String, @fontdb.Choice]
  used : Map[Int32, Map[Int32, Bool]]
  missing : Map[Int32, Bool]
}

///|
fn GridFontSet::new(db : @fontdb.Database, language : String) -> GridFontSet {
  let requested = match grid_script(language) {
    1 => "游ゴシック"
    2 => "等线"
    3 => "新細明體"
    4 => "맑은 고딕"
    _ => "Calibri"
  }
  { db, requested, cache: Map([]), used: Map([]), missing: Map([]), }
}

///|
fn GridFontSet::choice(
  self : GridFontSet,
  character : Char,
  bold : Bool,
) -> @fontdb.Choice {
  let key = "\{character.to_int()}:\{bold}"
  match self.cache.get(key) {
    Some(choice) => choice
    None => {
      let choice = self.db.face_for(
        self.requested,
        "",
        character.to_int(),
        bold~,
      )
      self.cache[key] = choice
      choice
    }
  }
}

///|
fn GridFontSet::advance_for(
  self : GridFontSet,
  face : Int32?,
  character : Char,
) -> Double {
  match face {
    Some(id) =>
      match self.db.face(id) {
        Some(entry) =>
          match entry.font.glyph(character.to_int()) {
            Some(glyph) => {
              let used = match self.used.get(id) {
                Some(used) => used
                None => {
                  let used : Map[Int32, Bool] = Map([])
                  self.used[id] = used
                  used
                }
              }
              used[character.to_int()] = true
              entry.font.advance(glyph) * 11.0
            }
            None => {
              let code = character.to_int()
              if !character.is_whitespace() &&
                code >= 0x20 &&
                code != 0x200b &&
                code != 0xfeff {
                self.missing[code] = true
              }
              fallback_advance(character, false)
            }
          }
        None => fallback_advance(character, false)
      }
    None => fallback_advance(character, false)
  }
}

///|
fn GridFontSet::advance(
  self : GridFontSet,
  character : Char,
  bold : Bool,
) -> Double {
  self.advance_for(self.choice(character, bold).resolved.face, character)
}

///|
fn GridFontSet::metrics(
  self : GridFontSet,
  character : Char,
  bold : Bool,
) -> (Double, Double) {
  match self.choice(character, bold).resolved.face {
    Some(id) =>
      match self.db.face(id) {
        Some(entry) =>
          (entry.font.metrics.ascent * 11.0, entry.font.metrics.descent * 11.0)
        None => fallback_line_metrics(character, bold)
      }
    None => fallback_line_metrics(character, bold)
  }
}

///|
fn GridFontSet::mdw(self : GridFontSet, language : String) -> Double {
  let primary = self.db.resolve(self.requested).face
  if primary is None {
    return 7.0
  }
  let mut widest = 0.0
  for digit in 48..<=57 {
    widest = Double::max(
      widest,
      self.advance_for(primary, digit.unsafe_to_char()) / 11.0,
    )
  }
  if widest == 0.0 {
    7.0
  } else {
    let ppem = if grid_script(language) == 0 {
      11.0 * 96.0 / 72.0
    } else {
      15.0
    }
    Double::max(1.0, (widest * ppem).round())
  }
}

///|
fn GridFontSet::usage(self : GridFontSet) -> FontSetUsage {
  let ids = self.used.keys().collect()
  ids.sort()
  let faces : Array[FaceUsage] = []
  for id in ids {
    let codepoints = self.used[id].keys().collect()
    codepoints.sort()
    faces.push({ face: id, codepoints, })
  }
  let missing = self.missing.keys().collect()
  missing.sort()
  { faces, missing, }
}
