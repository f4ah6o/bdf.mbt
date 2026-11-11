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

///|
/// Whether a code point takes no column of a text form: a combining mark or
/// a zero-width space.
fn width_zero(code : Int) -> Bool {
  (code >= 0x300 && code <= 0x36f) ||
  (code >= 0x1ab0 && code <= 0x1aff) ||
  (code >= 0x1dc0 && code <= 0x1dff) ||
  (code >= 0x20d0 && code <= 0x20ff) ||
  (code >= 0xfe00 && code <= 0xfe0f) ||
  (code >= 0xfe20 && code <= 0xfe2f) ||
  (code >= 0xe0100 && code <= 0xe01ef) ||
  (code >= 0x200b && code <= 0x200f) ||
  code == 0xad ||
  code == 0x61c ||
  code == 0x180e ||
  code == 0x2060 ||
  code == 0xfeff
}

///|
/// Whether a code point takes two columns of a text form.
fn width_two(code : Int) -> Bool {
  (code >= 0x1100 && code <= 0x115f) ||
  (code >= 0x2e80 && code <= 0x303e) ||
  (code >= 0x3041 && code <= 0x33ff) ||
  (code >= 0x3400 && code <= 0x4dbf) ||
  (code >= 0x4e00 && code <= 0x9fff) ||
  (code >= 0xa000 && code <= 0xa4cf) ||
  (code >= 0xa960 && code <= 0xa97f) ||
  (code >= 0xac00 && code <= 0xd7a3) ||
  (code >= 0xf900 && code <= 0xfaff) ||
  (code >= 0xfe10 && code <= 0xfe19) ||
  (code >= 0xfe30 && code <= 0xfe6f) ||
  (code >= 0xff01 && code <= 0xff60) ||
  (code >= 0xffe0 && code <= 0xffe6) ||
  (code >= 0x1f300 && code <= 0x1f64f) ||
  (code >= 0x1f900 && code <= 0x1f9ff) ||
  (code >= 0x20000 && code <= 0x3fffd)
}

///|
/// Whether a code point takes two columns when the text form counts the
/// ambiguous characters of East Asia as wide.
fn width_ambiguous(code : Int) -> Bool {
  (code >= 0x2500 && code <= 0x257f) ||
  (code >= 0x2580 && code <= 0x259f) ||
  (code >= 0x25a0 && code <= 0x25ff) ||
  code == 0x203b ||
  code == 0x2103 ||
  code == 0x2116 ||
  code == 0x2121 ||
  code == 0x2122 ||
  code == 0x2126 ||
  code == 0x212b ||
  (code >= 0x3000 && code <= 0x303e) ||
  (code >= 0x0391 && code <= 0x03c9) ||
  (code >= 0x0401 && code <= 0x0451) ||
  (code >= 0x2010 && code <= 0x2030) ||
  (code >= 0x2160 && code <= 0x217f) ||
  (code >= 0x2460 && code <= 0x24ff)
}

///|
/// The columns of a character in a text form: 2 for a wide character, 0 for
/// one that takes no column, and 1 for the others. The writer of a PDF needs
/// the same count as the converter that laid the text out, so that every
/// character lands on its cell.
pub fn east_asian_width(c : Char, ambiguous_wide : Bool) -> Int {
  let code = c.to_int()
  if code < 0x20 || (code >= 0x7f && code < 0xa0) {
    return 0
  }
  if code < 0x7f {
    return 1
  }
  if width_zero(code) {
    return 0
  }
  if width_two(code) {
    return 2
  }
  if ambiguous_wide && width_ambiguous(code) {
    return 2
  }
  1
}
