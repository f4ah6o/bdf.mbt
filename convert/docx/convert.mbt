///|
pub suberror DocxConvertError {
  DocxInvalid(String)
}

///|
pub(all) struct DocxResult {
  bdf : Bytes
  pages : Int32
  summary : String
  warnings : Array[String]
}

///|
priv struct DocxLineItem {
  kind : String
  text : String
  field_format : String
  link : String
  font : String
  weight : Int32
  style : Int32
  size : Double
  color : UInt32
  rise : Double
  underline : String
  strike : Bool
  emphasis : String
  x : Double
  advance : Double
  shade : UInt32?
  border_width : Double
  border_color : UInt32?
}

///|
fn docx_font_family(props : DocxRunProps) -> String {
  let name = if props.fonts.is_empty() { "" } else { props.fonts[0] }
  let lower = name.to_lower()
  if lower.contains("courier") || lower.contains("mono") {
    "monospace"
  } else if lower.contains("times") || lower.contains("serif") {
    "serif"
  } else {
    "sans-serif"
  }
}

///|
fn docx_font_weight(props : DocxRunProps) -> Int32 {
  if (props.toggles & 1) != 0 {
    700
  } else {
    400
  }
}

///|
fn docx_font_style(props : DocxRunProps) -> Int32 {
  if (props.toggles & 2) != 0 {
    1
  } else {
    0
  }
}

///|
fn docx_run_color(props : DocxRunProps) -> UInt32 {
  if props.auto_color {
    0x000000ffU
  } else {
    ((props.color & 0x00ffffffU) << 8) | 0xffU
  }
}

///|
fn docx_char_width(c : Char, size : Double) -> Double {
  let code = c.to_int()
  if c == ' ' {
    size * 0.25
  } else if code >= 0x2e80 || c == '\u3000' {
    size
  } else {
    size * 0.5
  }
}

///|
fn docx_text_width(text : String, size : Double) -> Double {
  let mut width = 0.0
  for c in text {
    width += docx_char_width(c, size)
  }
  width
}

///|
fn docx_u32_be(data : Bytes, offset : Int32) -> Int32 {
  (data[offset].to_int() << 24) |
  (data[offset + 1].to_int() << 16) |
  (data[offset + 2].to_int() << 8) |
  data[offset + 3].to_int()
}

///|
fn docx_png_size(data : Bytes) -> (Int32, Int32)? {
  if data.length() < 24 || data[:8] != b"\x89PNG\r\n\x1a\n"[:] {
    return None
  }
  Some((docx_u32_be(data, 16), docx_u32_be(data, 20)))
}

///|
fn docx_wrap_note(
  text : String,
  width : Double,
  size : Double,
) -> Array[String] {
  let lines : Array[String] = []
  let current = StringBuilder()
  let mut current_width = 0.0
  for c in text {
    let advance = docx_text_width(c.to_string(), size)
    if current_width + advance > width && current.to_string() != "" {
      lines.push(current.to_string())
      current.reset()
      current_width = 0.0
    }
    current.write_char(c)
    current_width += advance
  }
  if current.to_string() != "" {
    lines.push(current.to_string())
  }
  lines
}

///|
fn docx_round_up(value : Double) -> Double {
  let whole = value.to_int().to_double()
  if value > whole {
    whole + 1.0
  } else {
    whole
  }
}

///|
fn docx_section_at(document : DocxTextDocument, index : Int32) -> DocxSection {
  if document.sections.is_empty() {
    docx_new_section(None)
  } else if index < 0 || index >= document.sections.length() {
    document.sections[document.sections.length() - 1]
  } else {
    document.sections[index]
  }
}

///|
fn docx_story_part(
  section : DocxSection,
  header : Bool,
  kind : String,
) -> String {
  let stories = if header { section.headers } else { section.footers }
  for entry in stories {
    if entry.0 == kind {
      return entry.1
    }
  }
  ""
}

///|
/// Detect a WordprocessingML package.
pub fn detect(data : Bytes) -> Bool {
  if data.length() < 4 || data[0] != b'P' || data[1] != b'K' {
    return false
  }
  let pkg = @ooxml.open_ooxml(data) catch { _ => return false }
  match pkg.relationship_of_type("", "/officeDocument") {
    Some(rel) =>
      rel.target == "word/document.xml" || rel.target.has_prefix("word/")
    None => {
      ignore(pkg.read("word/document.xml")) catch {
        _ => return false
      }
      true
    }
  }
}

///|
/// Convert the supported WordprocessingML text subset to BDF. `views` selects
/// the views to make: `both` (the default), `pages` or `scroll`.
pub fn convert(
  data : Bytes,
  title~ : String = "",
  views~ : String = "both",
) -> DocxResult raise {
  let views = if views == "" { "both" } else { views }
  if views != "both" && views != "pages" && views != "scroll" {
    raise DocxInvalid("invalid views: " + views)
  }
  let document = docx_document_text(data) catch {
    InvalidDocx(message) => raise DocxInvalid(message)
    error => raise DocxInvalid(error.to_string())
  }
  docx_render_document(document, title, data, views) catch {
    InvalidDocx(message) => raise DocxInvalid(message)
    DocxInvalid(message) => raise DocxInvalid(message)
    error => raise DocxInvalid(error.to_string())
  }
}
