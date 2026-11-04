///|
/// A parsed DrawingML element of a worksheet drawing part.
struct XlsxDrawNode {
  name : String
  attrs : Array[(String, String)]
  children : Array[XlsxDrawNode]
  mut text : String
}

///|
fn xlsx_draw_parse(source : String) -> XlsxDrawNode raise {
  let reader = @xml.NamespaceReader::from_string(source)
  let roots : Array[XlsxDrawNode] = []
  let stack : Array[XlsxDrawNode] = []
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        let attrs : Array[(String, String)] = []
        for attr in element.attributes {
          attrs.push((attr.name.local_name, attr.value))
        }
        let node : XlsxDrawNode = {
          name: element.name.local_name,
          attrs,
          children: [],
          text: "",
        }
        if stack.is_empty() {
          roots.push(node)
        } else {
          stack[stack.length() - 1].children.push(node)
        }
        if event.kind is Start(_) {
          stack.push(node)
        }
      }
      Text(text) | CData(text) =>
        if !stack.is_empty() {
          stack[stack.length() - 1].text = stack[stack.length() - 1].text + text
        }
      End(_) =>
        if !stack.is_empty() {
          let _ = stack.pop()
        }
      Eof => break
      _ => ()
    }
  }
  if roots.is_empty() {
    raise InvalidXlsxInput("xlsx: unable to read drawing part")
  }
  roots[0]
}

///|
// The fallback reads drawings with shapes that carry text, chart frames and
// mc:AlternateContent choices; plain pictures stay with the strict reader so
// that unsupported pictures are still rejected.
fn xlsx_draw_needs_extended(root : XlsxDrawNode) -> Bool {
  let anchors : Array[XlsxDrawNode] = []
  for child in root.children {
    if child.name == "AlternateContent" {
      for choice in child.children {
        if choice.name == "Choice" {
          for anchor in choice.children {
            anchors.push(anchor)
          }
        }
      }
    } else {
      anchors.push(child)
    }
  }
  for anchor in anchors {
    for child in anchor.children {
      if child.name == "graphicFrame" {
        return true
      }
      if child.name == "sp" {
        match xlsx_draw_child(child, "txBody") {
          Some(body) =>
            if xlsx_draw_child(body, "p") is Some(_) {
              return true
            }
          None => ()
        }
      }
    }
  }
  false
}

///|
fn xlsx_draw_attr(node : XlsxDrawNode, name : String) -> String {
  for (key, value) in node.attrs {
    if key == name {
      return value
    }
  }
  ""
}

///|
fn xlsx_draw_child(node : XlsxDrawNode, name : String) -> XlsxDrawNode? {
  for child in node.children {
    if child.name == name {
      return Some(child)
    }
  }
  None
}

///|
fn xlsx_draw_children(node : XlsxDrawNode, name : String) -> Array[XlsxDrawNode] {
  node.children.filter(child => child.name == name)
}

///|
fn xlsx_draw_all_text(node : XlsxDrawNode) -> String {
  let out = StringBuilder()
  xlsx_draw_collect_text(node, out)
  out.to_string()
}

///|
fn xlsx_draw_collect_text(node : XlsxDrawNode, out : StringBuilder) -> Unit {
  out.write_string(node.text)
  for child in node.children {
    xlsx_draw_collect_text(child, out)
  }
}

///|
struct XlsxPlainDrawing {
  pictures : Array[@sheet.GridPicture]
  hidden : Array[Bool]
  fills : Array[UInt32?]
  strokes : Array[(UInt32, Double)?]
  no_fills : Array[Bool]
  dashes : Array[String]
  geometries : Array[String]
  adjustments : Array[Int64?]
  extra_adjustments : Array[Map[String, Int64]]
  texts : Array[Array[@sheet.GridShapeTextLine]]
}

///|
fn XlsxWorkbook::xlsx_plain_drawing(
  self : XlsxWorkbook,
  part : String,
  theme_colors : Map[Int32, XlsxRgb],
  theme_alphas : Map[Int32, Double],
  events : Array[(String, String)],
) -> XlsxPlainDrawing? raise {
  let bytes = self.package.read(part) catch { _ => return None }
  let source = @utf8.decode_lossy(bytes[:], ignore_bom=true)
  if source.contains("<!ENTITY") {
    return None
  }
  let root = xlsx_draw_parse(source) catch { _ => return None }
  if root.name != "wsDr" || !xlsx_draw_needs_extended(root) {
    return None
  }
  let drawing : XlsxPlainDrawing = {
    pictures: [],
    hidden: [],
    fills: [],
    strokes: [],
    no_fills: [],
    dashes: [],
    geometries: [],
    adjustments: [],
    extra_adjustments: [],
    texts: [],
  }
  for child in root.children {
    if child.name == "oneCellAnchor" || child.name == "twoCellAnchor" ||
      child.name == "absoluteAnchor" {
      self.xlsx_draw_anchor(part, child, theme_colors, theme_alphas, drawing, events) catch {
        _ => ()
      }
    } else if child.name == "AlternateContent" {
      for choice in child.children {
        if choice.name == "Choice" {
          for anchor in choice.children {
            if anchor.name == "oneCellAnchor" ||
              anchor.name == "twoCellAnchor" ||
              anchor.name == "absoluteAnchor" {
              self.xlsx_draw_anchor(
                part, anchor, theme_colors, theme_alphas, drawing, events,
              ) catch {
                _ => ()
              }
            }
          }
        }
      }
    }
  }
  if drawing.pictures.is_empty() {
    None
  } else {
    Some(drawing)
  }
}

///|
fn xlsx_draw_parse_int(value : String) -> Int64 {
  let parsed = @string.parse_int(value) catch { _ => 0 }
  parsed.to_int64()
}

///|
fn xlsx_draw_int_text(node : XlsxDrawNode) -> Int64 {
  xlsx_draw_parse_int(node.text.trim().to_string())
}

///|
fn xlsx_draw_emu(value : Int64) -> Double {
  value.to_double() / 12700.0
}

///|
fn xlsx_draw_get_attr_int(node : XlsxDrawNode, name : String) -> Int64 {
  xlsx_draw_parse_int(xlsx_draw_attr(node, name))
}

///|
fn XlsxWorkbook::xlsx_draw_anchor(
  self : XlsxWorkbook,
  part : String,
  anchor : XlsxDrawNode,
  theme_colors : Map[Int32, XlsxRgb],
  theme_alphas : Map[Int32, Double],
  drawing : XlsxPlainDrawing,
  events : Array[(String, String)],
) -> Unit raise {
  let kind = match anchor.name {
    "twoCellAnchor" => 0
    "oneCellAnchor" => 1
    "absoluteAnchor" => 2
    _ => -1
  }
  if kind < 0 {
    return
  }
  let mut from_row = -1
  let mut from_column = -1
  let mut to_row = -1
  let mut to_column = -1
  let mut from_x_offset = 0.0
  let mut from_y_offset = 0.0
  let mut to_x_offset = 0.0
  let mut to_y_offset = 0.0
  let mut x = 0.0
  let mut y = 0.0
  let mut width = -1.0
  let mut height = -1.0
  match xlsx_draw_child(anchor, "from") {
    Some(from) => {
      from_column = xlsx_draw_child_text_or_zero(from, "col").to_int()
      from_row = xlsx_draw_child_text_or_zero(from, "row").to_int()
      from_x_offset = xlsx_draw_emu(
        xlsx_draw_child_text_or_zero(from, "colOff"),
      )
      from_y_offset = xlsx_draw_emu(
        xlsx_draw_child_text_or_zero(from, "rowOff"),
      )
    }
    None => ()
  }
  match xlsx_draw_child(anchor, "to") {
    Some(to) => {
      to_column = xlsx_draw_child_text_or_zero(to, "col").to_int()
      to_row = xlsx_draw_child_text_or_zero(to, "row").to_int()
      to_x_offset = xlsx_draw_emu(
        xlsx_draw_child_text_or_zero(to, "colOff"),
      )
      to_y_offset = xlsx_draw_emu(
        xlsx_draw_child_text_or_zero(to, "rowOff"),
      )
    }
    None => ()
  }
  match xlsx_draw_child(anchor, "pos") {
    Some(pos) => {
      x = xlsx_draw_emu(xlsx_draw_get_attr_int(pos, "x"))
      y = xlsx_draw_emu(xlsx_draw_get_attr_int(pos, "y"))
    }
    None => ()
  }
  match xlsx_draw_child(anchor, "ext") {
    Some(ext) => {
      width = xlsx_draw_emu(xlsx_draw_get_attr_int(ext, "cx"))
      height = xlsx_draw_emu(xlsx_draw_get_attr_int(ext, "cy"))
    }
    None => ()
  }
  for child in anchor.children {
    if child.name == "pic" {
      self.xlsx_draw_picture(
        part, child, kind, from_row, from_column, to_row, to_column,
        from_x_offset, from_y_offset, to_x_offset, to_y_offset, x, y, width, height,
        drawing,
      )
    } else if child.name == "sp" {
      self.xlsx_draw_shape(
        part, child, kind, from_row, from_column, to_row, to_column,
        from_x_offset, from_y_offset, to_x_offset, to_y_offset, x, y, width, height,
        theme_colors, theme_alphas, drawing, events,
      )
    } else if child.name == "graphicFrame" {
      self.xlsx_draw_chart_frame(
        part, child, kind, from_row, from_column, to_row, to_column,
        from_x_offset, from_y_offset, to_x_offset, to_y_offset, x, y, width, height,
        drawing,
      )
    }
  }
}

///|
fn xlsx_draw_child_text_or_zero(node : XlsxDrawNode, name : String) -> Int64 {
  match xlsx_draw_child(node, name) {
    Some(child) => xlsx_draw_int_text(child)
    None => 0L
  }
}

///|
fn XlsxWorkbook::xlsx_draw_picture(
  self : XlsxWorkbook,
  part : String,
  pic : XlsxDrawNode,
  kind : Int32,
  from_row : Int32,
  from_column : Int32,
  to_row : Int32,
  to_column : Int32,
  from_x_offset : Double,
  from_y_offset : Double,
  to_x_offset : Double,
  to_y_offset : Double,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  drawing : XlsxPlainDrawing,
) -> Unit raise {
  let blip_fill = match xlsx_draw_child(pic, "blipFill") {
    Some(value) => value
    None => return
  }
  let blip = match xlsx_draw_child(blip_fill, "blip") {
    Some(value) => value
    None => return
  }
  let id = xlsx_draw_attr(blip, "embed")
  if id == "" {
    return
  }
  let mut target = ""
  for rel in self.package.relationships(part) {
    if rel.id == id {
      target = rel.target
    }
  }
  if target == "" {
    return
  }
  let image = self.package.read(target) catch { _ => return }
  let mut description = ""
  match xlsx_draw_child(pic, "nvPicPr") {
    Some(nv) =>
      match xlsx_draw_child(nv, "cNvPr") {
        Some(cnv) => description = xlsx_draw_attr(cnv, "descr")
        None => ()
      }
    None => ()
  }
  drawing.pictures.push({
    kind, from_row, from_column, to_row, to_column,
    from_x_offset, from_y_offset, to_x_offset, to_y_offset,
    x, y, width, height, description, image, alpha: None,
    fill_left: 0.0, fill_top: 0.0, fill_right: 0.0, fill_bottom: 0.0,
    crop_left: 0.0, crop_top: 0.0, crop_right: 0.0, crop_bottom: 0.0,
    image_width: 0.0, image_height: 0.0,
    flip_horizontal: false, flip_vertical: false, rotation: 0,
    frame_width: 0.0, frame_height: 0.0,
  })
  drawing.hidden.push(false)
  drawing.fills.push(None)
  drawing.strokes.push(None)
  drawing.no_fills.push(false)
  drawing.dashes.push("")
  drawing.geometries.push("rect")
  drawing.adjustments.push(None)
  drawing.extra_adjustments.push(Map([]))
  drawing.texts.push([])
}

///|
fn xlsx_draw_node_color(
  node : XlsxDrawNode,
  theme : Map[Int32, XlsxRgb],
  alphas : Map[Int32, Double],
) -> UInt32? {
  let value = xlsx_draw_attr(node, "val")
  if node.name == "schemeClr" {
    let mapped = match value {
      "bg1" => "lt1"
      "tx1" => "dk1"
      "bg2" => "lt2"
      "tx2" => "dk2"
      _ => value
    }
    let slot = xlsx_theme_slot(mapped)
    let color = match theme.get(slot) {
      Some(color) => color
      None => return None
    }
    let red = (color.red * 255.0 + 0.5).to_int().to_uint()
    let green = (color.green * 255.0 + 0.5).to_int().to_uint()
    let blue = (color.blue * 255.0 + 0.5).to_int().to_uint()
    let alpha = Double::max(
      0.0, Double::min(1.0, alphas.get(slot).unwrap_or(1.0)),
    )
    return Some((red << 24) | (green << 16) | (blue << 8) | (alpha * 255.0).round().to_uint())
  }
  if node.name == "srgbClr" || node.name == "sysClr" {
    let hex = if node.name == "sysClr" {
      let last = xlsx_draw_attr(node, "lastClr")
      if last != "" {
        last
      } else if ["window", "btnHighlight", "highlightText", "menu", "info"].contains(value) {
        "FFFFFF"
      } else {
        "000000"
      }
    } else {
      value
    }
    match xlsx_theme_hex(hex) {
      Some(color) =>
        return Some(
          ((color.red * 255.0).round().to_uint() << 24) |
          ((color.green * 255.0).round().to_uint() << 16) |
          ((color.blue * 255.0).round().to_uint() << 8) |
          255U,
        )
      None => return None
    }
  }
  if node.name == "prstClr" {
    match xlsx_shape_preset_color(value) {
      Some(color) => return Some((color << 8) | 255U)
      None => return None
    }
  }
  None
}

///|
fn xlsx_draw_shape_style(
  sp_pr : XlsxDrawNode,
  theme : Map[Int32, XlsxRgb],
  alphas : Map[Int32, Double],
) -> (UInt32?, Bool, (UInt32, Double)?, String, String, Int64?, Map[String, Int64]) raise {
  let mut fill : UInt32? = None
  let mut no_fill = false
  let mut stroke : (UInt32, Double)? = None
  let mut geometry = "rect"
  let mut dash = ""
  let mut adjustment : Int64? = None
  let extra : Map[String, Int64] = Map([])
  for child in sp_pr.children {
    if child.name == "solidFill" {
      for color_node in child.children {
        match xlsx_draw_node_color(color_node, theme, alphas) {
          Some(color) => fill = Some(color)
          None => ()
        }
        break
      }
    } else if child.name == "noFill" {
      no_fill = true
    } else if child.name == "prstGeom" {
      geometry = xlsx_draw_attr(child, "prst")
      if geometry == "" {
        geometry = "rect"
      }
      match xlsx_draw_child(child, "avLst") {
        Some(av) =>
          for gd in xlsx_draw_children(av, "gd") {
            let name = xlsx_draw_attr(gd, "name")
            let formula = xlsx_draw_attr(gd, "fmla")
            let value = if formula.has_prefix("val ") {
              xlsx_draw_parse_int(
                formula.unsafe_substring(start=4, end=formula.length()),
              )
            } else {
              -1L
            }
            if value >= 0L {
              if name == "adj" {
                adjustment = Some(value)
              } else if name != "" {
                extra[name] = value
              }
            }
          }
        None => ()
      }
    } else if child.name == "ln" {
      let mut line_width = 0.75
      let raw = xlsx_draw_attr(child, "w")
      let parsed = xlsx_draw_parse_int(raw)
      if parsed > 0L {
        line_width = parsed.to_double() / 12700.0
      }
      let mut line_color : UInt32? = None
      for inner in child.children {
        if inner.name == "solidFill" {
          for color_node in inner.children {
            line_color = xlsx_draw_node_color(color_node, theme, alphas)
            break
          }
        } else if inner.name == "prstDash" {
          dash = xlsx_draw_attr(inner, "val")
        }
      }
      match line_color {
        Some(color) => stroke = Some((color, line_width))
        None => ()
      }
    }
  }
  (fill, no_fill, stroke, geometry, dash, adjustment, extra)
}

///|
fn XlsxWorkbook::xlsx_draw_shape(
  self : XlsxWorkbook,
  part : String,
  sp : XlsxDrawNode,
  kind : Int32,
  from_row : Int32,
  from_column : Int32,
  to_row : Int32,
  to_column : Int32,
  from_x_offset : Double,
  from_y_offset : Double,
  to_x_offset : Double,
  to_y_offset : Double,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  theme_colors : Map[Int32, XlsxRgb],
  theme_alphas : Map[Int32, Double],
  drawing : XlsxPlainDrawing,
  events : Array[(String, String)],
) -> Unit raise {
  let _ = part
  let mut description = ""
  match xlsx_draw_child(sp, "nvSpPr") {
    Some(nv) =>
      match xlsx_draw_child(nv, "cNvPr") {
        Some(cnv) => description = xlsx_draw_attr(cnv, "descr")
        None => ()
      }
    None => ()
  }
  let mut fill : UInt32? = None
  let mut no_fill = false
  let mut stroke : (UInt32, Double)? = None
  let mut geometry = "rect"
  let mut dash = ""
  let mut adjustment : Int64? = None
  let mut extra : Map[String, Int64] = Map([])
  match xlsx_draw_child(sp, "spPr") {
    Some(sp_pr) => {
      let (f, nf, s, g, d, a, e) = xlsx_draw_shape_style(
        sp_pr, theme_colors, theme_alphas,
      )
      fill = f
      no_fill = nf
      stroke = s
      geometry = g
      dash = d
      adjustment = a
      extra = e
    }
    None => ()
  }
  if stroke is Some(_) && fill is None && !no_fill {
    return
  }
  if dash != "" && fill is None && !no_fill {
    return
  }
  let texts = xlsx_draw_shape_text(
    xlsx_draw_child(sp, "txBody"), width, events,
  )
  drawing.pictures.push({
    kind, from_row, from_column, to_row, to_column,
    from_x_offset, from_y_offset, to_x_offset, to_y_offset,
    x, y, width, height, description,
    image: Bytes::make(0, b'\x00'), alpha: None,
    fill_left: 0.0, fill_top: 0.0, fill_right: 0.0, fill_bottom: 0.0,
    crop_left: 0.0, crop_top: 0.0, crop_right: 0.0, crop_bottom: 0.0,
    image_width: 0.0, image_height: 0.0,
    flip_horizontal: false, flip_vertical: false, rotation: 0,
    frame_width: 0.0, frame_height: 0.0,
  })
  drawing.hidden.push(false)
  drawing.fills.push(if no_fill { None } else { fill })
  drawing.strokes.push(stroke)
  drawing.no_fills.push(no_fill)
  drawing.dashes.push(dash)
  drawing.geometries.push(geometry)
  drawing.adjustments.push(adjustment)
  drawing.extra_adjustments.push(extra)
  drawing.texts.push(texts)
}

///|
fn XlsxWorkbook::xlsx_draw_chart_frame(
  self : XlsxWorkbook,
  part : String,
  frame : XlsxDrawNode,
  kind : Int32,
  from_row : Int32,
  from_column : Int32,
  to_row : Int32,
  to_column : Int32,
  from_x_offset : Double,
  from_y_offset : Double,
  to_x_offset : Double,
  to_y_offset : Double,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  drawing : XlsxPlainDrawing,
) -> Unit raise {
  let graphic = match xlsx_draw_child(frame, "graphic") {
    Some(value) => value
    None => return
  }
  let data = match xlsx_draw_child(graphic, "graphicData") {
    Some(value) => value
    None => return
  }
  let chart = match xlsx_draw_child(data, "chart") {
    Some(value) => value
    None => return
  }
  let id = xlsx_draw_attr(chart, "id")
  if id == "" {
    return
  }
  let mut target = ""
  for rel in self.package.relationships(part) {
    if rel.id == id {
      target = rel.target
    }
  }
  if target == "" {
    return
  }
  let width = if width <= 0.0 { 340.0 } else { width }
  let height = if height <= 0.0 { 198.0 } else { height }
  let svg = self.xlsx_chart_svg(target, width, height) catch { _ => return }
  drawing.pictures.push({
    kind, from_row, from_column, to_row, to_column,
    from_x_offset, from_y_offset, to_x_offset, to_y_offset,
    x, y, width, height, description: "Chart",
    image: @utf8.encode(svg), alpha: None,
    fill_left: 0.0, fill_top: 0.0, fill_right: 0.0, fill_bottom: 0.0,
    crop_left: 0.0, crop_top: 0.0, crop_right: 0.0, crop_bottom: 0.0,
    image_width: width, image_height: height,
    flip_horizontal: false, flip_vertical: false, rotation: 0,
    frame_width: 0.0, frame_height: 0.0,
  })
  drawing.hidden.push(false)
  drawing.fills.push(None)
  drawing.strokes.push(None)
  drawing.no_fills.push(false)
  drawing.dashes.push("")
  drawing.geometries.push("rect")
  drawing.adjustments.push(None)
  drawing.extra_adjustments.push(Map([]))
  drawing.texts.push(self.xlsx_chart_labels(target))
}

///|
fn xlsx_draw_run_style(rpr : XlsxDrawNode?) -> (Double, Bool, Bool, UInt32) raise {
  let mut size = 11.0
  let mut bold = false
  let mut italic = false
  let mut color = 0x000000ffU
  match rpr {
    Some(node) => {
      let raw = xlsx_draw_attr(node, "sz")
      if raw != "" {
        let parsed = xlsx_draw_parse_int(raw)
        if parsed > 0L {
          size = parsed.to_double() / 100.0
        }
      }
      bold = ["1", "true", "on"].contains(xlsx_draw_attr(node, "b"))
      italic = ["1", "true", "on"].contains(xlsx_draw_attr(node, "i"))
      for child in node.children {
        if child.name == "solidFill" {
          for color_node in child.children {
            match xlsx_draw_node_color(color_node, Map([]), Map([])) {
              Some(value) => color = value
              None => ()
            }
            break
          }
        }
      }
    }
    None => ()
  }
  (size, bold, italic, color)
}

///|
fn xlsx_draw_shape_text(
  tx_body : XlsxDrawNode?,
  width : Double,
  events : Array[(String, String)],
) -> Array[@sheet.GridShapeTextLine] raise {
  let lines : Array[@sheet.GridShapeTextLine] = []
  let body = match tx_body {
    Some(value) => value
    None => return lines
  }
  for paragraph in xlsx_draw_children(body, "p") {
    let mut align = "ctr"
    match xlsx_draw_child(paragraph, "pPr") {
      Some(props) => {
        let value = xlsx_draw_attr(props, "algn")
        if value != "" {
          align = value
        }
      }
      None => ()
    }
    let runs : Array[@sheet.GridShapeTextRun] = []
    for child in paragraph.children {
      if child.name == "r" {
        let (size, bold, italic, color) = xlsx_draw_run_style(
          xlsx_draw_child(child, "rPr"),
        )
        let text = xlsx_draw_all_text(child)
        if text != "" {
          runs.push({ text, size, bold, italic, color })
        }
      } else if child.name == "m" {
        let warning = "no font with a MATH table (such as STIX Two Math or Cambria Math) is available; formulas are laid out with the text font"
        let mut seen = false
        for (_, text) in events {
          if text == warning {
            seen = true
          }
        }
        if !seen {
          events.push(("", warning))
        }
        for run in xlsx_draw_math_runs(child) {
          runs.push(run)
        }
      } else if child.name == "br" {
        if !runs.is_empty() {
          lines.push({ runs: runs.copy(), align })
          runs.clear()
        }
      }
    }
    if !runs.is_empty() {
      if width > 10.0 {
        let text_runs : Array[@drawingml.TextRun] = []
        for run in runs {
          text_runs.push({
            text: run.text,
            style: @drawingml.TextStyle::new(
              size=run.size,
              bold=run.bold,
              italic=run.italic,
              color=run.color,
            ),
          })
        }
        let wrapped = @drawingml.wrap_runs(text_runs, width - 10.0, 1)
        if wrapped.is_empty() {
          lines.push({ runs, align })
        } else {
          for line in wrapped {
            lines.push({
              runs: [
                {
                  text: line.text,
                  size: line.style.size,
                  bold: line.style.bold,
                  italic: line.style.italic,
                  color: line.style.color,
                },
              ],
              align,
            })
          }
        }
      } else {
        lines.push({ runs, align })
      }
    }
  }
  lines
}

///|
fn xlsx_draw_math_size(node : XlsxDrawNode) -> Double {
  for child in node.children {
    if child.name == "rPr" {
      let parsed = xlsx_draw_parse_int(xlsx_draw_attr(child, "sz"))
      if parsed > 0L {
        return parsed.to_double() / 100.0
      }
    }
    let inner = xlsx_draw_math_size(child)
    if inner > 0.0 {
      return inner
    }
  }
  0.0
}

///|
fn xlsx_draw_math_runs(
  node : XlsxDrawNode,
) -> Array[@sheet.GridShapeTextRun] raise {
  let runs : Array[@sheet.GridShapeTextRun] = []
  for child in node.children {
    if child.name == "oMathPara" || child.name == "oMath" {
      let text = xlsx_omml_linear(child)
      if text != "" {
        let size = Double::max(xlsx_draw_math_size(child), 14.0)
        runs.push({
          text,
          size,
          bold: false,
          italic: true,
          color: 0x000000ffU,
        })
      }
    }
  }
  runs
}

///|
fn xlsx_math_letter(character : Char) -> Char {
  let value = character.to_int()
  let starts = [
    (0x1d400, 0x41), (0x1d41a, 0x61), (0x1d434, 0x41), (0x1d44e, 0x61),
    (0x1d468, 0x41), (0x1d482, 0x61), (0x1d49c, 0x41), (0x1d4b6, 0x61),
    (0x1d4d0, 0x41), (0x1d4ea, 0x61), (0x1d504, 0x41), (0x1d51e, 0x61),
    (0x1d538, 0x41), (0x1d552, 0x61), (0x1d56c, 0x41), (0x1d586, 0x61),
    (0x1d5a0, 0x41), (0x1d5ba, 0x61), (0x1d5d4, 0x41), (0x1d5ee, 0x61),
    (0x1d608, 0x41), (0x1d622, 0x61), (0x1d63c, 0x41), (0x1d656, 0x61),
    (0x1d670, 0x41), (0x1d68a, 0x61),
  ]
  for (start, base) in starts {
    if value >= start && value < start + 26 {
      return (base + value - start).unsafe_to_char()
    }
  }
  character
}

///|
fn xlsx_math_plain_text(text : String) -> String {
  let out = StringBuilder()
  for character in text {
    out.write_char(xlsx_math_letter(character))
  }
  out.to_string()
}

///|
fn xlsx_math_tokens(node : XlsxDrawNode) -> Int32 {
  match node.name {
    "r" => {
      let mut count = 0
      for _ in xlsx_draw_all_text(node) {
        count += 1
      }
      count
    }
    "t" => 0
    "rPr" => 0
    "f" | "rad" | "sSup" | "sSub" | "sSubSup" | "d" => 1
    _ => {
      let mut count = 0
      for child in node.children {
        if child.name != "rPr" {
          count += xlsx_math_tokens(child)
        }
      }
      count
    }
  }
}

///|
fn xlsx_math_group(text : String, tokens : Int32) -> String {
  if tokens <= 1 {
    text
  } else if text.has_prefix("(") && text.has_suffix(")") {
    text
  } else {
    "(" + text + ")"
  }
}

///|
fn xlsx_omml_linear(node : XlsxDrawNode) -> String {
  let (text, _) = xlsx_omml_inline(node)
  text.trim().to_string()
}

///|
fn xlsx_omml_inline(node : XlsxDrawNode) -> (String, Int32) {
  match node.name {
    "r" => {
      let out = StringBuilder()
      for child in node.children {
        if child.name == "t" {
          out.write_string(xlsx_math_plain_text(child.text))
        }
      }
      (out.to_string(), xlsx_math_tokens(node))
    }
    "t" => (xlsx_math_plain_text(node.text), 1)
    "rPr" => ("", 0)
    "f" => {
      let (num_text, num_tokens) = match xlsx_draw_child(node, "num") {
        Some(value) => xlsx_omml_inline(value)
        None => ("", 0)
      }
      let (den_text, den_tokens) = match xlsx_draw_child(node, "den") {
        Some(value) => xlsx_omml_inline(value)
        None => ("", 0)
      }
      (
        xlsx_math_group(num_text, num_tokens) +
        "/" +
        xlsx_math_group(den_text, den_tokens),
        1,
      )
    }
    "rad" => {
      let base = match xlsx_draw_child(node, "e") {
        Some(value) => value
        None => placeholder_node()
      }
      let (base_text, base_tokens) = xlsx_omml_inline(base)
      let degree_text = match xlsx_draw_child(node, "deg") {
        Some(value) => xlsx_omml_linear(value)
        None => ""
      }
      if degree_text == "" {
        ("√" + xlsx_math_group(base_text, base_tokens), 1)
      } else {
        ("√(" + degree_text + "&" + base_text + ")", 1)
      }
    }
    "sSup" | "sSub" | "sSubSup" => {
      let (base_text, base_tokens) = match xlsx_draw_child(node, "e") {
        Some(value) => xlsx_omml_inline(value)
        None => ("", 0)
      }
      let mut text = xlsx_math_group(base_text, base_tokens)
      if node.name != "sSup" {
        match xlsx_draw_child(node, "sub") {
          Some(sub) => {
            let (sub_text, sub_tokens) = xlsx_omml_inline(sub)
            text = text + "_" + xlsx_math_group(sub_text, sub_tokens)
          }
          None => ()
        }
      }
      if node.name != "sSub" {
        match xlsx_draw_child(node, "sup") {
          Some(sup) => {
            let (sup_text, sup_tokens) = xlsx_omml_inline(sup)
            text = text + "^" + xlsx_math_group(sup_text, sup_tokens)
          }
          None => ()
        }
      }
      (text, 1)
    }
    "d" => {
      let mut text = ""
      for child in node.children {
        if child.name == "e" {
          let (inner, _) = xlsx_omml_inline(child)
          text = text + inner
        }
      }
      (text, 1)
    }
    _ => {
      let out = StringBuilder()
      let mut tokens = 0
      for child in node.children {
        if child.name == "rPr" {
          continue
        }
        let (text, count) = xlsx_omml_inline(child)
        out.write_string(text)
        tokens += count
      }
      (out.to_string(), tokens)
    }
  }
}

///|
fn placeholder_node() -> XlsxDrawNode {
  { name: "", attrs: [], children: [], text: "", }
}
