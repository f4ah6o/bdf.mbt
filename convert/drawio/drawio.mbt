///|
/// A draw.io conversion failure.
pub suberror DrawioError {
  DrawioInvalid(String)
}

///|
pub(all) struct DrawioResult {
  bdf : Bytes
  pages : Int32
  summary : String
  warnings : Array[String]
}

///|
/// Detect a draw.io XML document.
pub fn detect(data : Bytes) -> Bool {
  let head = @utf8.decode_lossy(data[:Int::min(data.length(), 8192)].to_owned())
  head.contains("<mxfile") || head.contains("<mxGraphModel")
}

///|
priv struct DrawioNode {
  name : String
  attrs : Map[String, String]
  children : Array[DrawioNode]
  text : StringBuilder
}

///|
fn drawio_attr(node : DrawioNode, name : String, default : String) -> String {
  match node.attrs.get(name) {
    Some(value) => value
    None => default
  }
}

///|
fn drawio_num(node : DrawioNode, name : String, default : Double) -> Double {
  let text = drawio_attr(node, name, "")
  if text == "" {
    return default
  }
  @string.parse_double(text) catch { _ => default }
}

///|
fn drawio_parse(content : String) -> DrawioNode raise {
  let reader = @xml.NamespaceReader::from_string(content)
  let stack : Array[DrawioNode] = []
  let mut root : DrawioNode? = None
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        let attrs : Map[String, String] = Map([])
        for attr in element.attributes {
          attrs[attr.name.local_name] = attr.value
        }
        let node : DrawioNode = {
          name: element.name.local_name,
          attrs,
          children: [],
          text: StringBuilder(),
        }
        if stack.is_empty() {
          root = Some(node)
        } else {
          stack[stack.length() - 1].children.push(node)
        }
        if event.kind is Start(_) {
          stack.push(node)
        }
      }
      Text(value) | CData(value) =>
        if !stack.is_empty() {
          stack[stack.length() - 1].text.write_string(value)
        }
      Eof => break
      _ => ()
    }
  }
  match root {
    Some(value) => value
    None => raise Failure("drawio: empty XML")
  }
}

///|
fn drawio_find(node : DrawioNode, name : String) -> DrawioNode? {
  for child in node.children {
    if child.name == name {
      return Some(child)
    }
  }
  None
}

///|
fn drawio_all(node : DrawioNode, name : String, output : Array[DrawioNode]) -> Unit {
  for child in node.children {
    if child.name == name {
      output.push(child)
    }
    drawio_all(child, name, output)
  }
}

///|
fn drawio_style(style : String, key : String, default : String) -> String {
  for part in style.split(";") {
    let item = sfc_drawio_trim(part)
    let eq = item.find("=")
    match eq {
      Some(value) =>
        if item[:value] == key {
          return item[value + 1:].to_owned()
        }
      None =>
        if item == key {
          return "1"
        }
    }
  }
  default
}

///|
fn sfc_drawio_trim(value : StringView) -> String {
  let mut start = 0
  let mut end = value.length()
  while start < end && (value[start] == ' ' || value[start] == '\t' || value[start] == '\r' || value[start] == '\n') {
    start += 1
  }
  while end > start && (value[end - 1] == ' ' || value[end - 1] == '\t' || value[end - 1] == '\r' || value[end - 1] == '\n') {
    end -= 1
  }
  value[start:end].to_owned()
}

///|
fn drawio_color(value : String, default : UInt32) -> UInt32 {
  if value == "" || value == "none" {
    return default
  }
  let mut text = value
  if text.has_prefix("#") {
    text = text[1:].to_owned()
  }
  if text.length() != 6 {
    return default
  }
  let number = @string.parse_int("0x" + text) catch { _ => return default }
  ((number << 8) | 255).to_uint()
}

///|
fn drawio_plain(value : String) -> String {
  let output = StringBuilder()
  let mut index = 0
  while index < value.length() {
    let c = value[index].unsafe_to_char()
    if c == '<' {
      let close = value[index:].find(">")
      match close {
        Some(offset) => {
          let tag = value[index + 1:index + offset].to_lower()
          if tag.has_prefix("br") || tag == "/p" || tag == "/li" {
            output.write_char('\n')
          }
          index += offset + 1
        }
        None => index = value.length()
      }
    } else {
      output.write_char(c)
      index += 1
    }
  }
  output.to_string()
}

///|
fn drawio_render_page(
  writer : @core.DocumentWriter,
  diagram : DrawioNode,
  page_index : Int,
  fonts : @canvas.Fonts,
  warnings : Array[String],
) -> (Json, Array[String])? {
  let model = match drawio_find(diagram, "mxGraphModel") {
    Some(value) => value
    None => return None
  }
  let page_w = drawio_num(model, "pageWidth", 827.0) * 0.75
  let page_h = drawio_num(model, "pageHeight", 1169.0) * 0.75
  let cells : Array[DrawioNode] = []
  drawio_all(model, "mxCell", cells)
  let drawing = @cad.Drawing::new()
  let labels : Array[String] = []
  let vertices : Map[String, DrawioNode] = Map([])
  for cell in cells {
    if drawio_attr(cell, "vertex", "") == "1" {
      vertices[drawio_attr(cell, "id", "")] = cell
    }
  }
  for cell in cells {
    let style = drawio_attr(cell, "style", "")
    let geometry = match drawio_find(cell, "mxGeometry") {
      Some(value) => value
      None => continue
    }
    let x = drawio_num(geometry, "x", 0.0) * 0.75
    let y = drawio_num(geometry, "y", 0.0) * 0.75
    let w = drawio_num(geometry, "width", 0.0) * 0.75
    let h = drawio_num(geometry, "height", 0.0) * 0.75
    if drawio_attr(cell, "vertex", "") == "1" {
      let text = drawio_plain(drawio_attr(cell, "value", ""))
      let fill = drawio_color(drawio_style(style, "fillColor", ""), 0xffffffU)
      let stroke = drawio_color(drawio_style(style, "strokeColor", ""), 0x000000ffU)
      let is_text = drawio_style(style, "text", "") == "1" || style.has_prefix("text;")
      let path = @cad.CadPath::new()
      if drawio_style(style, "ellipse", "") == "1" || style.contains("shape=ellipse") {
        path.ellipse({ x: x + w / 2.0, y: y + h / 2.0 }, { x: w / 2.0, y: 0.0 }, if w == 0.0 { 1.0 } else { h / w })
      } else {
        path.polyline([
          { x, y },
          { x: x + w, y },
          { x: x + w, y: y + h },
          { x, y: y + h },
        ], true)
      }
      if !is_text {
        drawing.fill(path, @cad.Fill::solid(fill), false)
        drawing.stroke(path, @cad.Pen::new(color=stroke, width=0.75, cap=@cad.CAP_ROUND, join=@cad.JOIN_ROUND))
      }
      if text != "" {
        let align = drawio_style(style, "align", "center")
        let valign = drawio_style(style, "verticalAlign", "middle")
        let size = drawio_num(geometry, "height", 60.0)
        let font_size = {
          let text_size = drawio_style(style, "fontSize", "")
          if text_size == "" { 12.0 } else { @string.parse_double(text_size) catch { _ => 12.0 } }
        }
        let color = drawio_color(drawio_style(style, "fontColor", ""), 0x000000ffU)
        let em = font_size * 0.75
        let mut tx = x + w / 2.0
        if align == "left" { tx = x + 4.0 }
        if align == "right" { tx = x + w - 4.0 }
        let mut ty = y + h / 2.0
        if valign == "top" { ty = y + em }
        if valign == "bottom" { ty = y + h - 4.0 }
        let line_height = em * 1.2
        let lines = text.split("\n").collect()
        let mut line_index = 0
        for line in lines {
          let value = sfc_drawio_trim(line)
          if value != "" {
            labels.push(value)
            let advance = value.length().to_double() * 0.55
            let mut origin_x = tx
            if align != "left" {
              origin_x -= if align == "right" { advance * em } else { advance * em / 2.0 }
            }
            let matrix = @canvas.Matrix::translate(origin_x, ty - line_index.to_double() * line_height).mul(
              @canvas.Matrix::scale(em, em),
            )
            let spec = @cad.FontSpec::new()
            let choice = fonts.face(spec.family, spec.east_asian, value[0].to_int())
            let metrics = fonts.metrics(choice)
            drawing.text(@cad.CadText::new(
              value,
              matrix,
              font=spec,
              color=color,
              advance=advance,
              asc=metrics.asc,
              desc=metrics.desc,
              cap=metrics.cap,
            ))
          }
          line_index += 1
        }
      }
    } else if drawio_attr(cell, "edge", "") == "1" {
      let source = drawio_attr(cell, "source", "")
      let target = drawio_attr(cell, "target", "")
      let mut from : @cad.Point = { x, y }
      let mut to : @cad.Point = { x, y }
      if source != "" {
        match vertices.get(source) {
          Some(vertex) => {
            match drawio_find(vertex, "mxGeometry") {
              Some(geo) => {
                from = {
                  x: (drawio_num(geo, "x", 0.0) + drawio_num(geo, "width", 0.0) / 2.0) * 0.75,
                  y: (drawio_num(geo, "y", 0.0) + drawio_num(geo, "height", 0.0) / 2.0) * 0.75,
                }
              }
              None => ()
            }
          }
          None => ()
        }
      }
      if target != "" {
        match vertices.get(target) {
          Some(vertex) => {
            match drawio_find(vertex, "mxGeometry") {
              Some(geo) => {
                to = {
                  x: (drawio_num(geo, "x", 0.0) + drawio_num(geo, "width", 0.0) / 2.0) * 0.75,
                  y: (drawio_num(geo, "y", 0.0) + drawio_num(geo, "height", 0.0) / 2.0) * 0.75,
                }
              }
              None => ()
            }
          }
          None => ()
        }
      }
      let path = @cad.CadPath::new()
      path.move_to(from.x, from.y)
      path.line_to(to.x, to.y)
      let stroke = drawio_color(drawio_style(style, "strokeColor", ""), 0x000000ffU)
      drawing.stroke(path, @cad.Pen::new(color=stroke, width=1.0, cap=@cad.CAP_ROUND, join=@cad.JOIN_ROUND))
    }
  }
  let canvas = @canvas.Canvas::new()
  canvas.object().set_bbox(0.0F, 0.0F, @canvas.f32(page_w), @canvas.f32(page_h))
  canvas.object().fill_color(0xffffffffU)
  canvas.object().fill_rect(0.0F, 0.0F, @canvas.f32(page_w), @canvas.f32(page_h))
  canvas.set_drawn()
  let matrix = @canvas.Matrix::identity()
  let plotter = @cad.Plotter::new(fonts, thin=0.1)
  plotter.plot(canvas, drawing, matrix, {
    min: { x: 0.0, y: 0.0 },
    max: { x: page_w, y: page_h },
    ok: true,
  }) catch {
    error => {
      warnings.push("drawio: " + error.to_string())
      return None
    }
  }
  let hash = canvas.encode(writer, fonts, warnings) catch {
    error => {
      warnings.push("drawio: " + error.to_string())
      return None
    }
  }
  let page = @cad.page(page_w, page_h, [@cad.layer("body", hash)])
  Some((page, labels))
}

///|
/// Convert a draw.io document into fixed-view BDF pages.
pub fn convert(
  data : Bytes,
  title~ : String = "",
  db~ : @fontdb.Database? = None,
) -> DrawioResult raise DrawioError {
  if data.length() > 268435456 {
    raise DrawioInvalid("drawio: the file is larger than 268435456 bytes")
  }
  let text = @utf8.decode_lossy(data)
  let root = drawio_parse(text) catch {
    Failure(message) => raise DrawioInvalid(message)
    _ => raise DrawioInvalid("drawio: invalid XML")
  }
  let diagrams : Array[DrawioNode] = []
  drawio_all(root, "diagram", diagrams)
  if diagrams.is_empty() {
    raise DrawioInvalid("drawio: the file has no diagrams")
  }
  let fonts = @canvas.Fonts::new(db)
  let warnings : Array[String] = []
  let meta = @cad.document_meta("drawio", title=title)
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
  let pages : Array[Json] = []
  let runs : Array[@core.IndexRun] = []
  let mut page_index = 0
  for diagram in [diagrams[0]] {
    let result = drawio_render_page(writer, diagram, page_index, fonts, warnings)
    match result {
      Some((page, labels)) => {
        pages.push(page)
        for label in labels {
          runs.push({
            a: page_index,
            b: 0,
            ordinal: runs.length(),
            separator: 2,
            text: label,
          })
        }
      }
      None => ()
    }
    page_index += 1
  }
  if pages.is_empty() {
    raise DrawioInvalid("drawio: no pages could be drawn")
  }
  let view_json = @cad.fixed_view(pages, title=title)
  let view_map = match view_json {
    Json::Object(value) => value
    _ => Map([])
  }
  if !runs.is_empty() {
    let index_hash = writer.add_part("idx", @core.encode_text_index(runs)) catch {
      error => raise DrawioInvalid("drawio: " + error.to_string())
    }
    view_map["textIndex"] = Json::string(index_hash)
  }
  writer.add_view(Json::object(view_map))
  let bdf = writer.write_single() catch {
    error => raise DrawioInvalid("drawio: " + error.to_string())
  }
  {
    bdf,
    pages: pages.length(),
    summary: "\{pages.length()} page(s)",
    warnings,
  }
}
