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
