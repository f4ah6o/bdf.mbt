///|
fn font_trim(text : String) -> String {
  let output = StringBuilder()
  let pending = StringBuilder()
  let mut started = false
  for c in text {
    if c.is_whitespace() {
      if started {
        pending.write_char(c)
      }
    } else {
      if started {
        output.write_string(pending.to_string())
        pending.reset()
      }
      output.write_char(c)
      started = true
    }
  }
  output.to_string()
}

///|
fn font_quote(text : String) -> String {
  let output = StringBuilder()
  let hex = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
  ]
  output.write_char('"')
  for c in text {
    match c {
      '"' => output.write_string("\\\"")
      '\\' => output.write_string("\\\\")
      '\u{07}' => output.write_string("\\a")
      '\b' => output.write_string("\\b")
      '\u{0c}' => output.write_string("\\f")
      '\n' => output.write_string("\\n")
      '\r' => output.write_string("\\r")
      '\t' => output.write_string("\\t")
      '\u{0b}' => output.write_string("\\v")
      _ => {
        let category = @ucd.general_category(c).group()
        if c == ' ' || (category != @ucd.C && category != @ucd.Z) {
          output.write_char(c)
        } else {
          let code = c.to_int()
          let digits = if code < 0x20 || code == 0x7f {
            output.write_string("\\x")
            2
          } else if code < 0x10000 {
            output.write_string("\\u")
            4
          } else {
            output.write_string("\\U")
            8
          }
          for i = digits - 1; i >= 0; i = i - 1 {
            output.write_char(hex[(code >> (i * 4)) & 15])
          }
        }
      }
    }
  }
  output.write_char('"')
  output.to_string()
}

///|
/// Select faces by the upstream `font` parameter: empty for the default,
/// `all`, or comma-separated one-based collection indexes. Returns any
/// warning emitted when the default selection is limited by glyph count.
pub fn FontFile::select(
  self : FontFile,
  spec : String,
) -> (Array[FileFace], Array[String]) raise {
  if spec == "all" {
    return (self.faces.copy(), [])
  }
  let out : Array[FileFace] = []
  let warnings : Array[String] = []
  if spec == "" {
    let mut glyphs = 0
    for face in self.faces {
      glyphs += face.font.metrics.glyph_count
      if glyphs > 262144 && out.length() > 0 {
        warnings.push(
          "font: the collection has " +
          self.faces.length().to_string() +
          " fonts; the first " +
          out.length().to_string() +
          " are shown (-param font=N or font=all shows others)",
        )
        break
      }
      out.push(face)
    }
    return (out, warnings)
  }
  for segment in spec.split(",") {
    let original = segment.to_owned()
    let text = font_trim(original)
    let chars : Array[Char] = [ for c in text => c ]
    let start = if chars.length() > 0 && (chars[0] == '+' || chars[0] == '-') {
      1
    } else {
      0
    }
    let mut valid = start < chars.length()
    for i in start..<chars.length() {
      if chars[i] < '0' || chars[i] > '9' {
        valid = false
      }
    }
    let number : Int64 = if valid {
      @string.parse_int64(text) catch {
        _ =>
          raise InvalidFontInput(
            "font: parameter font: " + font_quote(original) + " is not a number",
          )
      }
    } else {
      raise InvalidFontInput(
        "font: parameter font: " + font_quote(original) + " is not a number",
      )
    }
    let mut found = false
    for face in self.faces {
      if number == face.index.to_int64() + 1L {
        out.push(face)
        found = true
      }
    }
    if !found {
      raise InvalidFontInput(
        "font: parameter font: the file has no font " + number.to_string(),
      )
    }
  }
  (out, warnings)
}
