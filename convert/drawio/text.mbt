///|
/// The style of a run of label text (draw.io's inline HTML formatting).
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
/// The rectangle a cell's label occupies, with the rotation it is drawn
/// at. `anchor` is the point the rotation turns about.
priv struct DrawioLabelBox {
  x : Double
  y : Double
  w : Double
  h : Double
  rotation : Double
  anchor_x : Double
  anchor_y : Double
  align : String
  valign : String
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
  // Lists: the kind of each open list (ul or ol) and the item count, and
  // the marker owed to the line being built.
  let list_kinds : Array[String] = []
  let list_counts : Array[Int] = []
  let pending_marker : Array[String?] = [None]
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
      match pending_marker[0] {
        Some(marker) =>
          current.insert(0, { text: marker, style: current[0].style })
        None => ()
      }
      lines.push(current.copy())
      current.clear()
    }
    pending_marker[0] = None
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
          } else if name == "ul" || name == "ol" {
            if closing {
              if !list_kinds.is_empty() {
                list_kinds.pop() |> ignore
                list_counts.pop() |> ignore
              }
              end_line()
            } else {
              if !current.is_empty() {
                end_line()
              }
              list_kinds.push(name)
              list_counts.push(0)
            }
          } else if name == "li" {
            if closing {
              end_line()
            } else {
              if !current.is_empty() {
                end_line()
              }
              let index = list_counts.length() - 1
              if index >= 0 {
                list_counts[index] = list_counts[index] + 1
                let ordered = list_kinds[index] == "ol"
                let marker = if ordered {
                  "  " + list_counts[index].to_string() + ". "
                } else {
                  "  • "
                }
                pending_marker[0] = Some(marker)
              }
            }
          } else if name == "p" || name == "div" || name == "h1" || name == "h2" {
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
/// Whether a character may be wrapped before or after itself: East Asian
/// text breaks between characters, Latin text at spaces.
fn drawio_is_east_asian(c : Char) -> Bool {
  let code = c.to_int()
  (code >= 0x2E80 && code <= 0x9FFF) ||
  (code >= 0xAC00 && code <= 0xD7AF) ||
  (code >= 0xF900 && code <= 0xFAFF) ||
  (code >= 0x3040 && code <= 0x30FF) ||
  (code >= 0x3000 && code <= 0x303F) ||
  (code >= 0xFF00 && code <= 0xFFEF)
}

///|
fn drawio_is_line_start_forbidden(c : Char) -> Bool {
  let code = c.to_int()
  code == 0x3001 ||
  code == 0x3002 ||
  code == 0xFF0C ||
  code == 0xFF0E ||
  code == 0x30FB ||
  code == 0xFF1A ||
  code == 0xFF1B ||
  code == 0xFF1F ||
  code == 0xFF01 ||
  code == 0xFF09 ||
  code == 0xFF3D ||
  code == 0xFF5D ||
  code == 0x3015 ||
  code == 0x3009 ||
  code == 0x300B ||
  code == 0x300D ||
  code == 0x300F ||
  code == 0x3011 ||
  code == 0x3019 ||
  code == 0x3017 ||
  code == 0x301F ||
  code == 0x2019 ||
  code == 0x201D ||
  code == 0xFF60 ||
  code == 0x00BB ||
  code == 0x30FC ||
  code == 0x3041 ||
  code == 0x3043 ||
  code == 0x3045 ||
  code == 0x3047 ||
  code == 0x3049 ||
  code == 0x3063 ||
  code == 0x3083 ||
  code == 0x3085 ||
  code == 0x3087 ||
  code == 0x308E ||
  code == 0x30A1 ||
  code == 0x30A3 ||
  code == 0x30A5 ||
  code == 0x30A7 ||
  code == 0x30A9 ||
  code == 0x30C3 ||
  code == 0x30E3 ||
  code == 0x30E5 ||
  code == 0x30E7 ||
  code == 0x30EE ||
  code == 0x30F5 ||
  code == 0x30F6
}

///|
fn drawio_token_is_line_start_forbidden(token : String) -> Bool {
  let mut count = 0
  let mut forbidden = false
  for character in token {
    count += 1
    forbidden = drawio_is_line_start_forbidden(character)
  }
  count == 1 && forbidden
}

///|
fn drawio_is_space(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\r'
}

///|
fn drawio_run_em(style : DrawioRunStyle, base_size : Double) -> Double {
  let size = if style.size > 0.0 { style.size } else { base_size }
  size * 0.75
}

///|
fn drawio_run_width(
  text : String,
  style : DrawioRunStyle,
  font : @canvas.Fonts,
  family : String,
  base_bold : Bool,
  base_italic : Bool,
  base_size : Double,
) -> Double {
  let bold = base_bold || style.bold
  let italic = base_italic || style.italic
  font.measure(family, "", bold, italic, text) * drawio_run_em(style, base_size)
}

///|
fn drawio_append_run(line : Array[DrawioRun], text : String, style : DrawioRunStyle) -> Unit {
  if line.is_empty() {
    line.push({ text, style })
    return
  }
  let last = line.length() - 1
  if line[last].style == style {
    line[last] = { text: line[last].text + text, style }
  } else {
    line.push({ text, style })
  }
}

///|
/// Greedily wrap rich-text lines at spaces and between East Asian
/// characters, keeping each token's run style. This is the safe subset of
/// draw.io's CSS layout: no hyphenation, no shrink-to-fit, no margins.
fn drawio_wrap_rich_lines(
  lines : Array[Array[DrawioRun]],
  max_width : Double,
  font : @canvas.Fonts,
  family : String,
  base_bold : Bool,
  base_italic : Bool,
  base_size : Double,
) -> Array[Array[DrawioRun]] {
  let output : Array[Array[DrawioRun]] = []
  for line in lines {
    if line.is_empty() {
      output.push([])
      continue
    }
    let current : Array[DrawioRun] = []
    let mut current_width = 0.0
    let mut pending = StringBuilder()
    let mut pending_style = line[0].style
    let mut pending_space = false
    let emit_pending = fn() {
      let content = pending.to_string()
      if content == "" {
        return
      }
      let width = drawio_run_width(
        content,
        pending_style,
        font,
        family,
        base_bold,
        base_italic,
        base_size,
      )
      if current_width > 0.0 &&
        current_width + width > max_width &&
        !current.is_empty() &&
        !drawio_token_is_line_start_forbidden(content) {
        output.push(current.copy())
        current.clear()
        current_width = 0.0
        if pending_space {
          pending = StringBuilder()
          return
        }
      }
      drawio_append_run(current, content, pending_style)
      current_width += width
      pending = StringBuilder()
    }
    for run in line {
      for character in run.text {
        if drawio_is_space(character) {
          emit_pending()
          if !current.is_empty() {
            drawio_append_run(current, " ", run.style)
            current_width += drawio_run_width(
              " ",
              run.style,
              font,
              family,
              base_bold,
              base_italic,
              base_size,
            )
          }
        } else if drawio_is_east_asian(character) {
          emit_pending()
          pending_style = run.style
          pending_space = false
          pending.write_char(character)
          emit_pending()
          pending_style = run.style
        } else {
          if pending_space {
            emit_pending()
          }
          if pending.to_string() == "" {
            pending_style = run.style
            pending_space = false
          }
          pending.write_char(character)
        }
      }
      emit_pending()
      pending_style = run.style
    }
    emit_pending()
    output.push(current.copy())
  }
  output
}

///|
/// The text matrix of a run: origin at the start of the baseline, scaled
/// to ems and turned about the label's anchor when the label is rotated.
fn drawio_text_matrix(
  origin_x : Double,
  baseline : Double,
  em : Double,
  box : DrawioLabelBox,
) -> @canvas.Matrix {
  let base = @canvas.Matrix::translate(origin_x, baseline).mul(
    @canvas.Matrix::scale(em, -em),
  )
  if box.rotation == 0.0 {
    return base
  }
  @canvas.Matrix::translate(box.anchor_x, box.anchor_y).mul(
    @canvas.Matrix::rotate(box.rotation),
  ).mul(@canvas.Matrix::translate(-box.anchor_x, -box.anchor_y)).mul(base)
}

///|
/// The padding of a label: the base spacing plus each directional value
/// (upstream label.go readTextProps: spacingLeft = spacing + spacingLeft,
/// spacingRight/Top/Bottom alike); the base spacing defaults to 2.
/// `block` covers `blockSpacing=1`, which suppresses the base paddings
/// (upstream label.go passes blockSpacing=="1" as noBase to getSpacing).
struct DrawioLabelSpacing {
  left : Double
  right : Double
  top : Double
  bottom : Double
  block : Bool
}

///|
/// The extra paddings draw.io puts above and below every label
/// (mxText.baseSpacingTop/baseSpacingBottom; upstream label.go).
let drawio_label_base_top : Double = 5.0

///|
let drawio_label_base_bottom : Double = 1.0

///|
fn drawio_label_spacing(style : String) -> DrawioLabelSpacing {
  let base = drawio_num_from_style(style, "spacing", 2.0)
  let block = drawio_style(style, "blockSpacing", "") == "1"
  {
    left: base + drawio_num_from_style(style, "spacingLeft", 0.0),
    right: base + drawio_num_from_style(style, "spacingRight", 0.0),
    top: base + drawio_num_from_style(style, "spacingTop", 0.0),
    bottom: base + drawio_num_from_style(style, "spacingBottom", 0.0),
    block,
  }
}

///|
/// The base paddings of mxText.getSpacing, kept off for blockSpacing=1
/// labels (upstream passes that as noBase there).
fn drawio_label_space_top(
  spacing : DrawioLabelSpacing,
) -> Double {
  if spacing.block {
    0.0
  } else {
    drawio_label_base_top
  }
}

///|
fn drawio_label_space_bottom(
  spacing : DrawioLabelSpacing,
) -> Double {
  if spacing.block {
    0.0
  } else {
    drawio_label_base_bottom
  }
}

///|
/// The left edge of a line of label text in its box. A box wider than
/// 1e8 is a label outside the shape (`labelPosition=left` or `right`),
/// laid out at the label's own width. The alignment offset is the
/// directional padding of the alignment (mxText.getSpacing: left adds
/// spacingLeft, right subtracts spacingRight, the center balances them).
fn drawio_label_origin_x(
  box : DrawioLabelBox,
  text_width : Double,
  spacing : DrawioLabelSpacing,
) -> Double {
  if box.w >= 1.0e8 {
    if box.align == "right" {
      box.x - spacing.right - text_width
    } else {
      box.x + spacing.left
    }
  } else if box.align == "center" {
    box.x +
      (box.w - text_width) / 2.0 +
      (spacing.left - spacing.right) / 2.0
  } else if box.align == "right" {
    box.x + box.w - spacing.right - text_width
  } else {
    box.x + spacing.left
  }
}

///|
/// The top of a label's text block. A box taller than 1e8 is a label
/// outside the shape (`verticalLabelPosition=top` or `bottom`). Like
/// mxText.getSpacing, top-aligned labels sit spacingTop plus the base
/// top padding below the box and bottom-aligned ones spacingBottom plus
/// the base bottom padding above its lower edge.
fn drawio_label_block_top(
  box : DrawioLabelBox,
  total_height : Double,
  spacing : DrawioLabelSpacing,
) -> Double {
  if box.h >= 1.0e8 {
    if box.valign == "bottom" {
      box.y - spacing.bottom - drawio_label_space_bottom(spacing) - total_height
    } else {
      box.y + spacing.top + drawio_label_space_top(spacing)
    }
  } else if box.valign == "top" {
    box.y + spacing.top + drawio_label_space_top(spacing)
  } else if box.valign == "bottom" {
    box.y +
      box.h -
      spacing.bottom -
      drawio_label_space_bottom(spacing) -
      total_height
  } else {
    box.y +
      (box.h - total_height) / 2.0 +
      (spacing.top - spacing.bottom) / 2.0
  }
}

///|
/// Lay out and draw a cell's label: plain or HTML runs, wrapped at the
/// label box, turned for rotation and vertical labels.
fn drawio_label_runs(
  cell : DrawioCell,
  kind : DrawioShapeKind,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  font : @canvas.Fonts,
  drawing : @cad.Drawing,
  labels : Array[String],
  math_enabled : Bool,
  warn : DrawioWarn,
) -> Unit {
  let style = cell.style
  let raw = drawio_plain(cell.value)
  if raw == "" {
    return
  }
  if drawio_has_html(cell.value) {
    drawio_rich_label(
      cell,
      kind,
      x,
      y,
      w,
      h,
      font,
      drawing,
      labels,
      math_enabled,
      warn,
    )
    return
  }
  let box = drawio_label_box(kind, style, x, y, w, h)
  let (text, converted) = drawio_math_text(raw, math_enabled, warn)
  let size = drawio_num_from_style(style, "fontSize", 12.0)
  let em = size * 0.75
  let family = drawio_style(style, "fontFamily", "")
  let font_style = drawio_num_from_style(style, "fontStyle", 0.0).to_int()
  let bold = (font_style & 1) != 0
  let italic = (font_style & 2) != 0
  let color = drawio_color(drawio_style(style, "fontColor", ""), 0x000000ffU)
  let spacing = drawio_label_spacing(style)
  let max_width = if box.w > 0.0 && box.w < 1.0e8 {
    box.w - spacing.left - spacing.right
  } else {
    1.0e9
  }
  let wrap = drawio_label_wraps(style) && max_width > 1.0
  let lines = if wrap {
    drawio_wrap_text(text, max_width, font, family, bold, italic, em)
  } else {
    text.split("\n").map(fn(line) { sfc_drawio_trim(line) }).collect()
  }
  if converted {
    labels.push(raw)
  }
  let line_height = em * 1.2
  let count = lines.length()
  let total = line_height * count.to_double()
  let first_baseline = drawio_label_block_top(box, total, spacing) + em * 0.9
  for index, line in lines {
    if line == "" {
      continue
    }
    labels.push(line)
    let width_em = font.measure(family, "", bold, italic, line)
    let origin_x = drawio_label_origin_x(box, width_em * em, spacing)
    let baseline = first_baseline + line_height * index.to_double()
    let choice = font.face(family, "", line[0].to_int(), bold~, italic~)
    let metrics = font.metrics(choice)
    drawing.text(@cad.CadText::new(
      line,
      drawio_text_matrix(origin_x, baseline, em, box),
      color=color,
      advance=width_em,
      asc=metrics.asc,
      desc=metrics.desc,
      cap=metrics.cap,
    ))
  }
}

///|
fn drawio_label_wraps(style : String) -> Bool {
  drawio_style(style, "whiteSpace", "") == "wrap" ||
    drawio_style(style, "html", "") == "1" ||
    drawio_style(style, "whiteSpace", "") == "pre-wrap"
}

///|
/// Where a cell's label is laid out and how it is turned. The label
/// position styles move the box first; vertical labels (`horizontal=0`)
/// swap its dimensions and turn it -90°; a swimlane's label lives in its
/// header.
fn drawio_label_box(
  kind : DrawioShapeKind,
  style : String,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> DrawioLabelBox {
  let (base_x, base_y, base_w, base_h) = drawio_shape_label_rect(kind, style, x, y, w, h)
  let mut lx = base_x
  let mut ly = base_y
  let mut lw = base_w
  let mut lh = base_h
  let mut align = drawio_style(style, "align", "center")
  let mut valign = drawio_style(style, "verticalAlign", "middle")
  let label_position = drawio_style(style, "labelPosition", "center")
  if label_position == "right" {
    lx = x + w + 4.0
    lw = 1.0e9
    align = "left"
  } else if label_position == "left" {
    lx = x - 4.0
    lw = 1.0e9
    align = "right"
  }
  let vertical_position = drawio_style(style, "verticalLabelPosition", "middle")
  if vertical_position == "bottom" {
    ly = y + h + 2.0
    lh = 1.0e9
    valign = "top"
  } else if vertical_position == "top" {
    ly = y - 2.0
    lh = 1.0e9
    valign = "bottom"
  }
  let vertical = drawio_shape_vertical(style)
  if vertical {
    let cx = lx + lw / 2.0
    let cy = ly + lh / 2.0
    let swapped_w = lh
    let swapped_h = lw
    lx = cx - swapped_w / 2.0
    ly = cy - swapped_h / 2.0
    lw = swapped_w
    lh = swapped_h
  }
  let rotation = drawio_shape_label_rotation(style, kind)
  let anchor_x = if lw < 1.0e8 { lx + lw / 2.0 } else { x + w / 2.0 }
  let anchor_y = if lh < 1.0e8 { ly + lh / 2.0 } else { y + h / 2.0 }
  {
    x: lx,
    y: ly,
    w: lw,
    h: lh,
    rotation,
    anchor_x,
    anchor_y,
    align,
    valign,
  }
}

///|
fn drawio_wrap_text(
  text : String,
  max_width : Double,
  font : @canvas.Fonts,
  family : String,
  bold : Bool,
  italic : Bool,
  em : Double,
) -> Array[String] {
  let output : Array[String] = []
  for line in text.split("\n") {
    let value = sfc_drawio_trim(line)
    if value == "" {
      output.push("")
      continue
    }
    let tokens : Array[String] = []
    let pending = StringBuilder()
    for character in value {
      if drawio_is_space(character) {
        let word = pending.to_string()
        if word != "" {
          tokens.push(word)
          pending.reset()
        }
        tokens.push(" ")
      } else if drawio_is_east_asian(character) {
        let word = pending.to_string()
        if word != "" {
          tokens.push(word)
          pending.reset()
        }
        tokens.push(character.to_string())
      } else {
        pending.write_char(character)
      }
    }
    let word = pending.to_string()
    if word != "" {
      tokens.push(word)
    }
    let mut current = ""
    for token in tokens {
      if token == " " {
        if current != "" {
          current = current + token
        }
        continue
      }
      let candidate = current + token
      let width = font.measure(family, "", bold, italic, candidate) * em
      if current != "" &&
        width > max_width &&
        !drawio_token_is_line_start_forbidden(token) {
        output.push(sfc_drawio_trim(current))
        current = token
      } else {
        current = candidate
      }
    }
    output.push(sfc_drawio_trim(current))
  }
  output
}

///|
fn drawio_rich_label(
  cell : DrawioCell,
  kind : DrawioShapeKind,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  font : @canvas.Fonts,
  drawing : @cad.Drawing,
  labels : Array[String],
  math_enabled : Bool,
  warn : DrawioWarn,
) -> Unit {
  let style = cell.style
  let base_size = drawio_num_from_style(style, "fontSize", 12.0)
  let base_color = drawio_color(drawio_style(style, "fontColor", ""), 0x000000ffU)
  let family = drawio_style(style, "fontFamily", "")
  let font_style = drawio_num_from_style(style, "fontStyle", 0.0).to_int()
  let base_bold = (font_style & 1) != 0
  let base_italic = (font_style & 2) != 0
  let box = drawio_label_box(kind, style, x, y, w, h)
  let spacing = drawio_label_spacing(style)
  let mut lines = drawio_rich_lines(cell.value, base_size, base_color)
  let mut converted = false
  if math_enabled {
    for line_index in 0..<lines.length() {
      for run_index in 0..<lines[line_index].length() {
        let run = lines[line_index][run_index]
        let (text, changed) = drawio_math_text(run.text, math_enabled, warn)
        if changed {
          converted = true
          lines[line_index][run_index] = { text, style: run.style }
        }
      }
    }
  }
  if drawio_label_wraps(style) && box.w > 0.0 && box.w < 1.0e8 {
    let max_width = box.w - spacing.left - spacing.right
    if max_width > 1.0 {
      lines = drawio_wrap_rich_lines(
        lines,
        max_width,
        font,
        family,
        base_bold,
        base_italic,
        base_size,
      )
    }
  }
  if converted {
    labels.push(drawio_plain(cell.value))
  }
  let line_heights : Array[Double] = []
  let line_widths : Array[Double] = []
  for line in lines {
    let mut width = 0.0
    let mut height = base_size * 0.75 * 1.2
    for run in line {
      let em = drawio_run_em(run.style, base_size)
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
  let mut baseline = drawio_label_block_top(box, total, spacing)
  for line_index, line in lines {
    let width = line_widths[line_index]
    let mut origin_x = drawio_label_origin_x(box, width, spacing)
    let plain = line.map(fn(run) { run.text }).join("")
    if plain != "" {
      labels.push(plain)
    }
    for run in line {
      if run.text == "" {
        continue
      }
      let em = drawio_run_em(run.style, base_size)
      let bold = base_bold || run.style.bold
      let italic = base_italic || run.style.italic
      let run_width = font.measure(family, "", bold, italic, run.text)
      let choice = font.face(family, "", run.text[0].to_int(), bold~, italic~)
      let metrics = font.metrics(choice)
      drawing.text(@cad.CadText::new(
        run.text,
        drawio_text_matrix(origin_x, baseline + em * 0.9, em, box),
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
