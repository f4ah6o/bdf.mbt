///|
let no_line_start = "、。，．,.:;?!)]}」』】〕〉》）］｝〙〗〟”’ゝゞヽヾーぁぃぅぇぉっゃゅょゎゕゖァィゥェォッャュョヮヵヶ々〻‐゠–〜？！：；・…‥%％°℃"

///|
let no_line_end = "([{「『【〔〈《（［｛〘〖〝“‘¥$£＄￥"

///|
fn break_space(c : Char) -> Bool {
  c == ' ' ||
  c == '\u{3000}' ||
  c == '\u{2009}' ||
  c == '\u{2002}' ||
  c == '\u{2003}'
}

///|
/// Whether the upstream sheet line breaker permits a break between characters.
pub fn line_break_allowed(a : Char, b : Char) -> Bool {
  if break_space(a) {
    return !break_space(b)
  }
  if break_space(b) || a == '\u{a0}' || b == '\u{a0}' {
    return false
  }
  if no_line_start.contains(b.to_string()) ||
    no_line_end.contains(a.to_string()) {
    return false
  }
  if is_cjk(a.to_int()) || is_cjk(b.to_int()) {
    return true
  }
  (a == '-' || a == '\u{2010}') && upstream_letter(b)
}

///|
fn upstream_letter(character : Char) -> Bool {
  if @ucd.general_category(character).group() == @ucd.L {
    return true
  }
  // Go's Unicode 17 tables contain letters missing from the Unicode tables
  // of the current MoonBit dependency. See licenses/Go-x-text.txt.
  let c = character.to_int()
  c == 0x88f ||
  c == 0xc5c ||
  c == 0xcdc ||
  (c >= 0xa7ce && c <= 0xa7cf) ||
  c == 0xa7d2 ||
  c == 0xa7d4 ||
  c == 0xa7f1 ||
  (c >= 0x10940 && c <= 0x10959) ||
  (c >= 0x10ec5 && c <= 0x10ec7) ||
  (c >= 0x11db0 && c <= 0x11ddb) ||
  (c >= 0x16ea0 && c <= 0x16eb8) ||
  (c >= 0x16ebb && c <= 0x16ed3) ||
  (c >= 0x16ff2 && c <= 0x16ff3) ||
  (c >= 0x187f8 && c <= 0x187ff) ||
  (c >= 0x18d09 && c <= 0x18d1e) ||
  (c >= 0x18d80 && c <= 0x18df2) ||
  (c >= 0x1e6c0 && c <= 0x1e6de) ||
  (c >= 0x1e6e0 && c <= 0x1e6e2) ||
  (c >= 0x1e6e4 && c <= 0x1e6e5) ||
  (c >= 0x1e6e7 && c <= 0x1e6ed) ||
  (c >= 0x1e6f0 && c <= 0x1e6f4) ||
  (c >= 0x1e6fe && c <= 0x1e6ff) ||
  (c >= 0x2b73a && c <= 0x2b73f) ||
  (c >= 0x2cea2 && c <= 0x2cead) ||
  (c >= 0x323b0 && c <= 0x33479)
}

///|
/// Whether a wrapped line joins the previous line without an inserted space.
pub fn line_break_joins(a : Char, b : Char) -> Bool {
  !break_space(a) && (is_cjk(a.to_int()) || is_cjk(b.to_int()))
}
