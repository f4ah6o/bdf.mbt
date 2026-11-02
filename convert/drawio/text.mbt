///|
priv struct DrawioRunStyle {
  bold : Bool
  italic : Bool
  underline : Bool
  color : UInt32
  size : Double
} derive(Eq)

///|
priv struct DrawioRun {
  text : String
  style : DrawioRunStyle
}

///|
fn drawio_tag_name(value : StringView) -> String {
  let mut start = 0
  while start < value.length() &&
        (value[start] == ' ' || value[start] == '\t' || value[start] == '\n' ||
          value[start] == '/') {
    start += 1
  }
  let mut end = start
  while end < value.length() &&
        value[end] != ' ' && value[end] != '\t' && value[end] != '\n' && value[end] != '/' {
    end += 1
  }
  value[start:end].to_owned().to_lower()
}

///|
fn drawio_tag_attr(tag : String, key : String) -> String {
  let mut index = 0
  while true {
    let found = tag[index:].find(key + "=")
    match found {
      None => return ""
      Some(offset) => {
        index += offset + key.length() + 1
        if index >= tag.length() {
          return ""
        }
        let quote = tag[index].unsafe_to_char()
        if quote == '"' || quote == '\'' {
          let quote_text = if quote == '"' { "\"" } else { "'" }
          let end = tag[index + 1:].find(quote_text)
          match end {
            Some(length) => return tag[index + 1:index + 1 + length].to_owned()
            None => return ""
          }
        }
      }
    }
  }
  ""
}

///|
fn drawio_css_value(style : String, key : String) -> String {
  for part in style.split(";") {
    let item = sfc_drawio_trim(part)
    let colon = item.find(":")
    match colon {
      Some(position) => {
        if sfc_drawio_trim(item[:position]) == key {
          return sfc_drawio_trim(item[position + 1:])
        }
      }
      None => ()
    }
  }
  ""
}

///|
fn drawio_apply_tag(
  style : DrawioRunStyle,
  tag : String,
  base_size : Double,
) -> DrawioRunStyle {
  let name = drawio_tag_name(tag)
  let mut bold = style.bold
  let mut italic = style.italic
  let mut underline = style.underline
  let mut color = style.color
  let mut size = style.size
  if name == "b" || name == "strong" {
    bold = true
  } else if name == "i" || name == "em" {
    italic = true
  } else if name == "u" {
    underline = true
  } else if name == "font" {
    let value = drawio_tag_attr(tag, "color")
    println("ATTR " + value)
    if value != "" {
      color = drawio_color(value, color)
    }
    let value = drawio_tag_attr(tag, "size")
    if value != "" {
      let parsed = @string.parse_double(value) catch { _ => 0.0 }
      if parsed > 0.0 {
        size = parsed
      }
    }
  } else if name == "span" || name == "div" || name == "p" {
    let css = drawio_tag_attr(tag, "style")
    if css != "" {
      let value = drawio_css_value(css, "color")
      if value != "" {
        color = drawio_color(value, color)
      }
      let value = drawio_css_value(css, "font-size")
      if value != "" {
        let mut number = value
        if number.has_suffix("px") {
          number = number[:number.length() - 2].to_owned()
        }
        let parsed = @string.parse_double(sfc_drawio_trim(number)) catch { _ => 0.0 }
        if parsed > 0.0 {
          size = parsed
        }
      }
      let weight = drawio_css_value(css, "font-weight")
      if weight == "bold" || weight == "700" {
        bold = true
      }
      let decoration = drawio_css_value(css, "text-decoration")
      if decoration.contains("underline") {
        underline = true
      }
    }
  } else if name == "h1" {
    size = base_size * 2.0
  } else if name == "h2" {
    size = base_size * 1.5
  }
  { bold, italic, underline, color, size }
}

///|
fn drawio_rich_lines(
  value : String,
  base_size : Double,
  base_color : UInt32,
) -> Array[Array[DrawioRun]] {
  let lines : Array[Array[DrawioRun]] = []
  let current : Array[DrawioRun] = []
  let stack : Array[DrawioRunStyle] = []
  let style_slot : Array[DrawioRunStyle] = [{
    bold: false,
    italic: false,
    underline: false,
    color: base_color,
    size: base_size,
  }]
  let mut text = StringBuilder()
  let flush = fn() {
    let content = text.to_string()
    if content != "" {
      let style = style_slot[0]
      let run : DrawioRun = { text: content, style, }
      if !current.is_empty() && current[current.length() - 1].style == style {
        let last = current.length() - 1
        current[last] = { text: current[last].text + content, style, }
      } else {
        current.push(run)
      }
      text = StringBuilder()
    }
  }
  let end_line = fn() {
    flush()
    if !current.is_empty() {
      lines.push(current.copy())
      current.clear()
    }
  }
  let mut index = 0
  while index < value.length() {
    if value[index] == '<' {
      let close = value[index:].find(">")
      match close {
        Some(offset) => {
          flush()
          let tag = value[index + 1:index + offset].to_owned()
          let name = drawio_tag_name(tag)
          let closing = if tag.has_prefix("/") { true } else { false }
          if name == "br" {
            end_line()
          } else if name == "li" || name == "p" || name == "div" || name == "h1" || name == "h2" {
            if closing {
              end_line()
            } else if !current.is_empty() {
              end_line()
            }
            let base = drawio_apply_tag(style_slot[0], tag, base_size)
            if closing && (name == "h1" || name == "h2") {
              if !stack.is_empty() {
                style_slot[0] = stack.pop().unwrap()
              }
            } else if !closing && (name == "h1" || name == "h2") {
              stack.push(style_slot[0])
              style_slot[0] = base
            }
          } else if closing {
            if name == "b" || name == "strong" || name == "i" || name == "em" ||
              name == "u" || name == "font" || name == "span" || name == "h1" ||
              name == "h2" {
              if !stack.is_empty() {
                style_slot[0] = stack.pop().unwrap()
              }
            }
          } else {
            stack.push(style_slot[0])
            style_slot[0] = drawio_apply_tag(style_slot[0], tag, base_size)
          }
          index += offset + 1
        }
        None => {
          index = value.length()
        }
      }
    } else {
      text.write_char(value[index].unsafe_to_char())
      index += 1
    }
  }
  end_line()
  lines
}

///|
fn drawio_has_html(value : String) -> Bool {
  value.contains("<b") || value.contains("<i") || value.contains("<u") ||
    value.contains("<font") || value.contains("<span") || value.contains("<br") ||
    value.contains("<div") || value.contains("<p") || value.contains("<li") ||
    value.contains("<h1") || value.contains("<h2") || value.contains("<ul")
}

///|
fn drawio_rich_label(
  cell : DrawioCell,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  font : @canvas.Fonts,
  drawing : @cad.Drawing,
  labels : Array[String],
) -> Unit {
  let style = cell.style
  let base_size = drawio_num_from_style(style, "fontSize", 12.0)
  let base_color = drawio_color(drawio_style(style, "fontColor", ""), 0x000000ffU)
  let family = drawio_style(style, "fontFamily", "")
  let font_style = drawio_num_from_style(style, "fontStyle", 0.0).to_int()
  let base_bold = (font_style & 1) != 0
  let base_italic = (font_style & 2) != 0
  let align = drawio_style(style, "align", "center")
  let valign = drawio_style(style, "verticalAlign", "middle")
  let spacing = drawio_num_from_style(style, "spacing", 2.0)
  let lines = drawio_rich_lines(cell.value, base_size, base_color)
  let line_heights : Array[Double] = []
  let line_widths : Array[Double] = []
  for line in lines {
    let mut width = 0.0
    let mut height = base_size * 0.75 * 1.2
    for run in line {
      let em = (if run.style.size > 0.0 { run.style.size } else { base_size }) * 0.75
      let bold = base_bold || run.style.bold
      let italic = base_italic || run.style.italic
      width += font.measure(family, "", bold, italic, run.text) * em
      height = Double::max(height, em * 1.2)
    }
    line_widths.push(width)
    line_heights.push(height)
  }
  let mut total = 0.0
  for height in line_heights {
    total += height
  }
  let mut baseline = if valign == "top" {
    y + spacing
  } else if valign == "bottom" {
    y + h - spacing - total
  } else {
    y + (h - total) / 2.0
  }
  for line_index, line in lines {
    let width = line_widths[line_index]
    let mut origin_x = x + spacing
    if align == "center" {
      origin_x = x + (w - width) / 2.0
    } else if align == "right" {
      origin_x = x + w - spacing - width
    }
    let plain = line.map(fn(run) { run.text }).join("")
    if plain != "" {
      labels.push(plain)
    }
    for run in line {
      let em = (if run.style.size > 0.0 { run.style.size } else { base_size }) * 0.75
      let bold = base_bold || run.style.bold
      let italic = base_italic || run.style.italic
      let run_width = font.measure(family, "", bold, italic, run.text)
      let choice = font.face(family, "", run.text[0].to_int(), bold~, italic~)
      let metrics = font.metrics(choice)
      drawing.text(@cad.CadText::new(
        run.text,
        @canvas.Matrix::translate(origin_x, baseline + em * 0.9).mul(
          @canvas.Matrix::scale(em, em),
        ),
        color=run.style.color,
        advance=run_width,
        asc=metrics.asc,
        desc=metrics.desc,
        cap=metrics.cap,
        underline=run.style.underline,
      ))
      origin_x += run_width * em
    }
    baseline += line_heights[line_index]
  }
}
