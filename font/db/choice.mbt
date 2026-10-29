///|
/// A resolved face and the family and styles requested for a character.
pub(all) struct Choice {
  resolved : Resolved
  requested : String
  bold : Bool
  italic : Bool
} derive(Debug, Eq)

///|
/// Whether a code point uses Office's East Asian font selection.
pub fn is_cjk(code : Int32) -> Bool {
  (code >= 0x1100 && code <= 0x11ff) ||
  (code >= 0x2e80 && code <= 0x2fdf) ||
  (code >= 0x2ff0 && code <= 0x33ff) ||
  (code >= 0x3400 && code <= 0x4dbf) ||
  (code >= 0x4e00 && code <= 0x9fff) ||
  (code >= 0xa960 && code <= 0xa97f) ||
  (code >= 0xac00 && code <= 0xd7ff) ||
  (code >= 0xf900 && code <= 0xfaff) ||
  (code >= 0xfe30 && code <= 0xfe4f) ||
  (code >= 0xff00 && code <= 0xffef) ||
  (code >= 0x20000 && code <= 0x3ffff) ||
  (code >= 0x16fe2 && code <= 0x16fe3) ||
  (code >= 0x16ff0 && code <= 0x16ff6)
}

///|
/// Resolve the face for a character, trying the other requested family and
/// then available fallback fonts when the first face lacks the glyph.
pub fn Database::face_for(
  self : Database,
  latin : String,
  east_asian : String,
  code : Int32,
  bold~ : Bool = false,
  italic~ : Bool = false,
) -> Choice {
  let cjk = is_cjk(code)
  let mut primary = if cjk { east_asian } else { latin }
  let other = if cjk { latin } else { east_asian }
  if cjk && primary == "" {
    primary = other
  }
  let resolved = self.resolve(primary, bold~, italic~, cjk~)
  let initial : Choice = { resolved, requested: primary, bold, italic, }
  let id = match resolved.face {
    Some(id) => id
    None => return initial
  }
  if code == 9 || code == 10 || self.faces[id].font.glyph(code) is Some(_) {
    return initial
  }
  if other != "" && other != primary {
    let choice = self.resolve(other, bold~, italic~, cjk=!cjk)
    match choice.face {
      Some(id) if self.faces[id].font.glyph(code) is Some(_) =>
        return { resolved: choice, requested: other, bold, italic, }
      _ => ()
    }
  }
  for choice in self.fallbacks(resolved.generic, bold~, italic~) {
    match choice.face {
      Some(id) if self.faces[id].font.glyph(code) is Some(_) =>
        return { resolved: choice, requested: primary, bold, italic, }
      _ => ()
    }
  }
  initial
}
