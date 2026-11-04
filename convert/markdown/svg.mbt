///|
/// The placeholder inline SVG is replaced with before Markdown parsing.
fn md_svg_placeholder(index : Int) -> String {
  "\uE002" + index.to_string() + "\uE003"
}

///|
fn md_svg_placeholder_at(text : String) -> (Int, Int)? {
  if !text.has_prefix("\uE002") {
    return None
  }
  match text.find("\uE003") {
    Some(index) => {
      let digits = text[1:index].to_owned()
      let value = @string.parse_int(digits) catch { _ => -1 }
      if value < 0 {
        None
      } else {
        Some((value, index + 1))
      }
    }
    None => None
  }
}

///|
fn md_ascii_lower(c : Char) -> Char {
  if c >= 'A' && c <= 'Z' {
    Char::from_int(c.to_int() + 32)
  } else {
    c
  }
}

///|
fn md_chars_match_lower(chars : Array[Char], start : Int, word : String) -> Bool {
  let target = word.to_array()
  if start + target.length() > chars.length() {
    return false
  }
  for i in 0..<target.length() {
    if md_ascii_lower(chars[start + i]) != target[i] {
      return false
    }
  }
  true
}

///|
fn md_is_space(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\r' || c == '\n' || c == '\u000C'
}

///|
/// Read a single- or double-quoted (or unquoted) attribute of an HTML tag.
fn md_attr_in_tag(tag : String, name : String) -> String {
  let chars = tag.to_array()
  let target = name.to_lower()
  let mut i = 0
  while i < chars.length() {
    while i < chars.length() && (md_is_space(chars[i]) || chars[i] == '<' || chars[i] == '/') {
      i += 1
    }
    if i >= chars.length() {
      break
    }
    let start = i
    while i < chars.length() &&
      chars[i] != '=' &&
      chars[i] != '>' &&
      !md_is_space(chars[i]) {
      i += 1
    }
    let attr = String::from_array(chars[start:i]).to_lower()
    while i < chars.length() && md_is_space(chars[i]) {
      i += 1
    }
    if i < chars.length() && chars[i] == '=' {
      i += 1
      while i < chars.length() && md_is_space(chars[i]) {
        i += 1
      }
      let quote = if i < chars.length() && (chars[i] == '"' || chars[i] == '\'') {
        chars[i]
      } else {
        '\u0000'
      }
      let value_start = if quote != '\u0000' { i + 1 } else { i }
      let mut value_end = value_start
      if quote != '\u0000' {
        while value_end < chars.length() && chars[value_end] != quote {
          value_end += 1
        }
      } else {
        while value_end < chars.length() &&
          !md_is_space(chars[value_end]) &&
          chars[value_end] != '>' {
          value_end += 1
        }
      }
      if attr == target {
        return String::from_array(chars[value_start:value_end])
      }
      i = if value_end < chars.length() { value_end + 1 } else { value_end }
    } else {
      if attr == target {
        return ""
      }
      if i < chars.length() && chars[i] == '>' {
        i += 1
      }
    }
  }
  ""
}

///|
/// Read one declaration of a style attribute.
fn md_style_value(style : String, name : String) -> String {
  let target = name.to_lower()
  for declaration in style.split(";") {
    let text = declaration.trim()
    match text.find(":") {
      Some(index) => {
        let key = text[:index].to_owned().trim().to_lower()
        if key == target {
          return text[index + 1:].to_owned().trim().to_string()
        }
      }
      None => ()
    }
  }
  ""
}

///|
fn md_css_length_pt(value : String) -> Double {
  let mut text = value.trim().to_lower().to_owned()
  if text == "" || text == "auto" || text.has_suffix("%") {
    return 0.0
  }
  let mut factor = 0.75
  for pair in [
    ("rem", 12.0),
    ("px", 0.75),
    ("pt", 1.0),
    ("pc", 12.0),
    ("in", 72.0),
    ("cm", 72.0 / 2.54),
    ("mm", 72.0 / 25.4),
    ("q", 72.0 / 101.6),
    ("em", 12.0),
    ("ex", 6.0),
  ] {
    let (suffix, scale) = pair
    if text.has_suffix(suffix) {
      factor = scale
      text = text[:text.length() - suffix.length()].to_owned().trim().to_string()
      break
    }
  }
  let number = @string.parse_double(text) catch { _ => 0.0 }
  if number.is_nan() || number.is_inf() || number <= 0.0 {
    0.0
  } else {
    Double::min(number * factor, 1000000.0)
  }
}

///|
fn md_svg_viewbox(value : String) -> (Double, Double) {
  let fields : Array[String] = []
  let word = StringBuilder()
  for ch in value {
    if ch == ',' || ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      let text = word.to_string()
      if text != "" {
        fields.push(text)
        word.reset()
      }
    } else {
      word.write_char(ch)
    }
  }
  let last = word.to_string()
  if last != "" {
    fields.push(last)
  }
  if fields.length() == 4 {
    let width = @string.parse_double(fields[2]) catch { _ => 0.0 }
    let height = @string.parse_double(fields[3]) catch { _ => 0.0 }
    if width > 0.0 && height > 0.0 && !width.is_nan() && !height.is_nan() &&
      !width.is_inf() && !height.is_inf() {
      return (width, height)
    }
  }
  (0.0, 0.0)
}

///|
fn md_svg_attr(tag : String, name : String) -> String {
  let value = md_attr_in_tag(tag, name)
  if value != "" {
    return value
  }
  if name == "viewBox" {
    md_attr_in_tag(tag, "viewbox")
  } else {
    ""
  }
}

///|
/// Read the intrinsic size of an SVG root element in points. A document
/// with only a view box is marked to fill the text column, as browsers size
/// an inline svg without a width and height.
fn md_svg_size(tag : String) -> (Double, Double, Bool) {
  let style = md_attr_in_tag(tag, "style")
  let mut width = md_css_length_pt(md_attr_in_tag(tag, "width"))
  let mut height = md_css_length_pt(md_attr_in_tag(tag, "height"))
  if width <= 0.0 {
    width = md_css_length_pt(md_style_value(style, "width"))
  }
  if height <= 0.0 {
    height = md_css_length_pt(md_style_value(style, "height"))
  }
  let (view_width, view_height) = md_svg_viewbox(md_svg_attr(tag, "viewBox"))
  let ratio = if view_width > 0.0 && view_height > 0.0 {
    view_width / view_height
  } else {
    0.0
  }
  if width > 0.0 && height > 0.0 {
    (width, height, false)
  } else if width > 0.0 {
    if ratio > 0.0 {
      (width, width / ratio, false)
    } else {
      (width, 112.5, false)
    }
  } else if height > 0.0 {
    if ratio > 0.0 {
      (height * ratio, height, false)
    } else {
      (225.0, height, false)
    }
  } else if ratio > 0.0 {
    (225.0, 225.0 / ratio, true)
  } else {
    (225.0, 112.5, false)
  }
}

///|
fn md_collapse_ws(text : String) -> String {
  let out = StringBuilder()
  let mut space = false
  for ch in text.trim() {
    if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      space = true
    } else {
      if space && out.to_string() != "" {
        out.write_char(' ')
      }
      space = false
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
/// The alternative text of an svg element: aria-label, else its title.
fn md_svg_alt(markup : String) -> String {
  let open_end = match markup.find(">") {
    Some(index) => index
    None => return ""
  }
  let tag = markup[:open_end + 1].to_owned()
  if md_attr_in_tag(tag, "aria-hidden").to_lower() == "true" {
    return ""
  }
  match md_attr_in_tag(tag, "role").to_lower() {
    "presentation" | "none" => return ""
    _ => ()
  }
  let aria = md_collapse_ws(md_attr_in_tag(tag, "aria-label"))
  if aria != "" {
    return aria
  }
  let lower = markup.to_lower()
  match lower.find("<title") {
    Some(start) => {
      let open = match lower[start:].find(">") {
        Some(index) => start + index + 1
        None => return ""
      }
      let close = match lower[open:].find("</title") {
        Some(index) => open + index
        None => return ""
      }
      md_collapse_ws(markup[open:close].to_owned())
    }
    None => ""
  }
}

///|
/// An svg element is a sprite sheet when it is hidden or holds only
/// definitions for other elements.
fn md_svg_is_sprite(markup : String) -> Bool {
  let open_end = match markup.find(">") {
    Some(index) => index
    None => return false
  }
  let tag = markup[:open_end + 1].to_owned()
  let style = md_attr_in_tag(tag, "style").to_lower().replace(old=" ", new="")
  if style.contains("display:none") || style.contains("visibility:hidden") {
    return true
  }
  let (width, height, _) = md_svg_size(tag)
  let attr_width = md_attr_in_tag(tag, "width").trim()
  let attr_height = md_attr_in_tag(tag, "height").trim()
  if (attr_width != "" && width <= 0.0) ||
    (attr_height != "" && height <= 0.0) {
    return true
  }
  if width <= 0.0 || height <= 0.0 {
    // A document without a size is still drawable when it holds a shape.
  }
  let lower = markup.to_lower()
  let body_start = open_end + 1
  let body_end = match lower.find("</svg") {
    Some(index) => index
    None => markup.length()
  }
  if body_start >= body_end {
    return true
  }
  let body = lower[body_start:body_end].to_owned()
  let chars = body.to_array()
  let mut i = 0
  while i < chars.length() {
    if chars[i] != '<' {
      i += 1
      continue
    }
    let mut j = i + 1
    if j < chars.length() && chars[j] == '/' {
      j += 1
    }
    let start = j
    while j < chars.length() &&
      ((chars[j] >= 'a' && chars[j] <= 'z') ||
        (chars[j] >= '0' && chars[j] <= '9') ||
        chars[j] == '-' ||
        chars[j] == ':') {
      j += 1
    }
    let name = String::from_array(chars[start:j])
    if name != "" {
      if name != "defs" &&
        name != "symbol" &&
        name != "style" &&
        name != "title" &&
        name != "desc" &&
        name != "metadata" &&
        name != "script" &&
        name != "lineargradient" &&
        name != "radialgradient" &&
        name != "pattern" &&
        name != "clippath" &&
        name != "mask" &&
        name != "filter" &&
        name != "marker" &&
        name != "stop" {
        return false
      }
      // Only the elements directly under the svg element draw; what a
      // symbol or a gradient holds is a definition.
      let close = "</" + name
      let rest = String::from_array(chars[j:])
      match rest.find(close) {
        Some(index) => {
          let mut end = j + index
          while end < chars.length() && chars[end] != '>' {
            end += 1
          }
          i = end + 1
          continue
        }
        None => ()
      }
    }
    i = j
  }
  true
}

///|
/// The content of an svg element between its root tag and closing tag.
fn md_svg_body(markup : String) -> String {
  let open_end = match markup.find(">") {
    Some(index) => index
    None => return ""
  }
  let close = match markup.to_lower().find("</svg") {
    Some(index) => index
    None => markup.length()
  }
  if open_end + 1 >= close {
    ""
  } else {
    markup[open_end + 1:close].to_owned()
  }
}

///|
/// Make an SVG document of an inline svg element: name the namespaces a
/// viewer needs, keep currentColor the text color, and lend it the symbols
/// and gradients a sprite sheet elsewhere in the document defines.
fn md_svg_document(markup : String, sprite : String) -> Bytes {
  let open_end = match markup.find(">") {
    Some(index) => index
    None => return @utf8.encode(markup)
  }
  let mut open = markup[:open_end].to_owned()
  let close = markup[open_end + 1:].to_owned()
  let lower = open.to_lower()
  let self_closing = open.has_suffix("/")
  if !lower.contains("xmlns=") {
    open += " xmlns=\"http://www.w3.org/2000/svg\""
  }
  if !lower.contains("xmlns:xlink=") {
    open += " xmlns:xlink=\"http://www.w3.org/1999/xlink\""
  }
  if !lower.contains(" color=") {
    open += " color=\"#1f2328\""
  }
  let out = StringBuilder()
  out.write_string(open)
  out.write_char('>')
  if !self_closing {
    if sprite != "" {
      out.write_string("<defs>")
      out.write_string(sprite)
      out.write_string("</defs>")
    }
    out.write_string(close)
  }
  @utf8.encode(out.to_string())
}

///|
/// Take the svg elements out of a raw HTML block: visible ones are recorded
/// in svgs, the definitions of sprite sheets in sprite. The rest of the
/// block is returned for its text and images.
fn md_extract_block_svgs(
  html : String,
  svgs : Array[MdSvg],
  sprite : StringBuilder,
) -> String {
  let out = StringBuilder()
  let chars = html.to_array()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '<' && md_chars_match_lower(chars, i, "<svg") {
      let after = i + 4
      let boundary = after >= chars.length() ||
        md_is_space(chars[after]) ||
        chars[after] == '>' ||
        chars[after] == '/'
      if boundary {
        let open_end = match String::from_array(chars[after:]).find(">") {
          Some(index) => after + index
          None => -1
        }
        if open_end >= 0 {
          let close_start = match String::from_array(chars[open_end + 1:])
            .to_lower()
            .find("</svg") {
            Some(index) => open_end + 1 + index
            None => -1
          }
          if close_start >= 0 {
            let close_end = match String::from_array(chars[close_start:]).find(">") {
              Some(index) => close_start + index
              None => -1
            }
            if close_end >= 0 {
              let markup = String::from_array(chars[i:close_end + 1])
              if md_svg_is_sprite(markup) {
                sprite.write_string(md_svg_body(markup))
              } else {
                let open_tag = String::from_array(chars[i:open_end + 1])
                let (width, height, fill) = md_svg_size(open_tag)
                svgs.push({
                  markup,
                  alt: md_svg_alt(markup),
                  width,
                  height,
                  fill,
                })
              }
              i = close_end + 1
              continue
            }
          }
        }
      }
    }
    out.write_char(chars[i])
    i += 1
  }
  out.to_string()
}

///|
/// Scan one line for svg elements. An element that fits on the line is
/// replaced with a placeholder; a sprite sheet is left out after its
/// definitions are remembered.
fn md_inline_svg_line(line : String, svgs : Array[MdSvg], sprite : StringBuilder) -> String {
  let out = StringBuilder()
  let chars = line.to_array()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == '\u0060' {
      let mut ticks = 1
      while i + ticks < chars.length() && chars[i + ticks] == '\u0060' {
        ticks += 1
      }
      out.write_string(String::from_array(chars[i:i + ticks]))
      i += ticks
      let close = String::from_array(chars[i:]).find("\u0060".repeat(ticks))
      match close {
        Some(index) => {
          out.write_string(String::from_array(chars[i:i + index + ticks]))
          i += index + ticks
        }
        None => ()
      }
      continue
    }
    if c == '\\' && i + 1 < chars.length() {
      out.write_char(c)
      out.write_char(chars[i + 1])
      i += 2
      continue
    }
    if c == '<' && md_chars_match_lower(chars, i, "<svg") {
      let after = i + 4
      let boundary = after >= chars.length() ||
        md_is_space(chars[after]) ||
        chars[after] == '>' ||
        chars[after] == '/'
      if !boundary {
        out.write_char(c)
        i += 1
        continue
      }
      let open_end = match String::from_array(chars[after:]).find(">") {
        Some(index) => after + index
        None => -1
      }
      if open_end < 0 {
        out.write_string(String::from_array(chars[i:]))
        break
      }
      let close_start = match String::from_array(chars[open_end + 1:]).to_lower().find("</svg") {
        Some(index) => open_end + 1 + index
        None => -1
      }
      if close_start < 0 {
        out.write_string(String::from_array(chars[i:]))
        break
      }
      let close_end = match String::from_array(chars[close_start:]).find(">") {
        Some(index) => close_start + index
        None => -1
      }
      if close_end < 0 {
        out.write_string(String::from_array(chars[i:]))
        break
      }
      let markup = String::from_array(chars[i:close_end + 1])
      if md_svg_is_sprite(markup) {
        sprite.write_string(md_svg_body(markup))
      } else {
        let open_tag = String::from_array(chars[i:open_end + 1])
        let (width, height, fill) = md_svg_size(open_tag)
        let index = svgs.length()
        svgs.push({
          markup,
          alt: md_svg_alt(markup),
          width,
          height,
          fill,
        })
        out.write_string(md_svg_placeholder(index))
      }
      i = close_end + 1
      continue
    }
    out.write_char(c)
    i += 1
  }
  out.to_string()
}

///|
/// Replace the svg elements that fit on a line with placeholders, before
/// the inline Markdown parser sees their markup. The contents of code
/// fences and code spans are left alone.
fn md_parse_svg_before(text : String, svgs : Array[MdSvg], sprite : StringBuilder) -> String {
  let out = StringBuilder()
  let lines = text.split("\n").to_array()
  let mut i = 0
  let mut fenced = false
  let mut fence = ""
  while i < lines.length() {
    let line = lines[i].to_owned()
    let trimmed = line.trim()
    if fenced {
      out.write_string(line)
      out.write_char('\n')
      if trimmed.has_prefix(fence) {
        fenced = false
      }
      i += 1
      continue
    }
    if trimmed.has_prefix("\u0060\u0060\u0060") || trimmed.has_prefix("~~~") {
      fenced = true
      fence = trimmed[:3].to_owned()
      out.write_string(line)
      out.write_char('\n')
      i += 1
      continue
    }
    if md_indent_of(line) >= 4 {
      out.write_string(line)
      out.write_char('\n')
      i += 1
      continue
    }
    let mut markup = line
    let mut consumed = i + 1
    if markup.contains("<svg") && !markup.contains("</svg>") {
      while consumed < lines.length() && !markup.contains("</svg>") {
        markup += "\n" + lines[consumed].to_owned()
        consumed += 1
      }
    }
    out.write_string(md_inline_svg_line(markup, svgs, sprite))
    out.write_char('\n')
    i = consumed
  }
  out.to_string()
}
