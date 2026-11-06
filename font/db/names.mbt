///|
/// Normalize a family name as upstream does: NFKC, lowercase, and removal
/// of spaces, hyphens and underscores.
pub fn normalize(name : String) -> String {
  let value = @core.normalize_nfkc(name)
  let result = StringBuilder()
  for ch in value {
    if ch != ' ' && ch != '-' && ch != '_' && ch != '\u{3000}' {
      result.write_char(@unicode.to_simple_lowercase(ch))
    }
  }
  result.to_string()
}

///|
/// The CSS family list for a FONT record: the requested family followed by
/// the generic family, as upstream's fontset writes it when no face is
/// embedded.
pub fn css_family(name : String) -> String {
  let generic = if name == "" {
    "sans-serif"
  } else {
    classify(name)
  }
  if name == "" || is_generic_family(name) {
    return generic
  }
  let out = StringBuilder()
  out.write_char('"')
  for c in name {
    if c == '"' || c == '\\' {
      out.write_char('\\')
    }
    out.write_char(c)
  }
  out.write_char('"')
  out.write_string(", ")
  out.write_string(generic)
  out.to_string()
}

///|
fn is_generic_family(name : String) -> Bool {
  [
    "sans-serif", "serif", "monospace", "cursive", "fantasy", "system-ui",
    "ui-sans-serif", "ui-serif", "ui-monospace",
  ].contains(name.to_lower())
}

///|
/// Guess the CSS generic family used for an unresolved family request.
pub fn classify(name : String) -> String {
  let n = normalize(name)
  if n.contains("mono") ||
    n.contains("courier") ||
    n.contains("consola") ||
    n.contains("code") ||
    n == "msgothic" ||
    n == "msゴシック" ||
    n == "msmincho" ||
    n == "ms明朝" ||
    n.contains("lucidaconsole") {
    "monospace"
  } else if n.contains("sans") ||
    n.contains("gothic") ||
    n.contains("ゴシック") ||
    n.contains("黑") ||
    n.contains("hei") {
    "sans-serif"
  } else if n.contains("serif") ||
    n.contains("times") ||
    n.contains("mincho") ||
    n.contains("明朝") ||
    n.contains("cambria") ||
    n.contains("georgia") ||
    n.contains("garamond") ||
    n.contains("century") ||
    n.contains("palatino") ||
    n.contains("bodoni") ||
    n.contains("bookantiqua") ||
    n.contains("roman") ||
    n.contains("song") ||
    n.contains("宋") ||
    n.contains("ming") ||
    n.contains("明") ||
    n.contains("batang") ||
    n.contains("바탕") {
    "serif"
  } else {
    "sans-serif"
  }
}

///|
fn heavy_name(name : String) -> Bool {
  let n = normalize(name)
  for
    suffix in [
      "black", "heavy", "bold", "extrabold", "ultrabold", "semibold", "demibold",
    ] {
    if n.has_suffix(suffix) || n.contains(suffix + "italic") {
      return true
    }
  }
  false
}
