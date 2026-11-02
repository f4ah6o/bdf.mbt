///|
priv enum DrawioRenderItem {
  Shape(DrawioCell, Double, Double, Double, Double)
  Edge(DrawioCell, Array[(Double, Double)])
}

///|
fn drawio_point(geo : DrawioNode, name : String) -> (Double, Double)? {
  match drawio_find(geo, "mxPoint") {
    Some(point) => {
      let _ = point
      ()
    }
    None => ()
  }
  let mut result : (Double, Double)? = None
  for child in geo.children {
    if child.name == "mxPoint" && drawio_attr(child, "as", "") == name {
      result = Some((drawio_num(child, "x", 0.0), drawio_num(child, "y", 0.0)))
    }
  }
  result
}

///|
fn drawio_waypoints(geo : DrawioNode) -> Array[(Double, Double)] {
  let output : Array[(Double, Double)] = []
  for child in geo.children {
    if child.name == "Array" && drawio_attr(child, "as", "") == "points" {
      for point in child.children {
        if point.name == "mxPoint" {
          output.push((drawio_num(point, "x", 0.0), drawio_num(point, "y", 0.0)))
        }
      }
    }
  }
  output
}

///|
fn DrawioModel::edge_points(self : DrawioModel, cell : DrawioCell) -> Array[(Double, Double)] {
  let geo = cell.geometry()
  let points : Array[(Double, Double)] = []
  let source = self.cell(cell.source)
  let target = self.cell(cell.target)
  let mut source_point : (Double, Double)? = None
  let mut target_point : (Double, Double)? = None
  match geo {
    Some(value) => {
      source_point = drawio_point(value, "sourcePoint")
      target_point = drawio_point(value, "targetPoint")
    }
    None => ()
  }
  let source_center = match source {
    Some(value) => {
      let (x, y, w, h) = self.absolute(value)
      Some((x + w / 2.0, y + h / 2.0))
    }
    None => None
  }
  let target_center = match target {
    Some(value) => {
      let (x, y, w, h) = self.absolute(value)
      Some((x + w / 2.0, y + h / 2.0))
    }
    None => None
  }
  if source_point is Some(value) {
    points.push(value)
  } else if source_center is Some(value) {
    points.push(value)
  }
  match geo {
    Some(value) => {
      for point in drawio_waypoints(value) {
        points.push(point)
      }
    }
    None => ()
  }
  if target_point is Some(value) {
    points.push(value)
  } else if target_center is Some(value) {
    points.push(value)
  }
  if points.is_empty() {
    match geo {
      Some(value) => {
        let x = drawio_num(value, "x", 0.0)
        let y = drawio_num(value, "y", 0.0)
        points.push((x, y))
        points.push((x, y))
      }
      None => ()
    }
  }
  points
}

///|
fn drawio_wrap_text(
  text : String,
  max_width : Double,
  font : @canvas.Fonts,
  family : String,
  east_asian : String,
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
    let words = value.split(" ").collect()
    let mut current = ""
    for word in words {
      let word_text = word.to_owned()
      let candidate = if current == "" { word_text } else { current + " " + word_text }
      let width = font.measure(family, east_asian, bold, italic, candidate) * em
      if current != "" && width > max_width {
        output.push(current)
        current = word_text
      } else {
        current = candidate
      }
    }
    output.push(current)
  }
  output
}

///|
fn drawio_label_runs(
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
  let text = drawio_plain(cell.value)
  if text == "" {
    return
  }
  let size = drawio_num_from_style(style, "fontSize", 12.0)
  let em = size * 0.75
  let family = drawio_style(style, "fontFamily", "")
  let font_style = drawio_num_from_style(style, "fontStyle", 0.0).to_int()
  let bold = (font_style & 1) != 0
  let italic = (font_style & 2) != 0
  let color = drawio_color(drawio_style(style, "fontColor", ""), 0x000000ffU)
  let mut align = drawio_style(style, "align", "center")
  let mut valign = drawio_style(style, "verticalAlign", "middle")
  let label_position = drawio_style(style, "labelPosition", "center")
  let mut lx = x
  let mut ly = y
  let mut lw = w
  let mut lh = h
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
  let spacing = drawio_num_from_style(style, "spacing", 2.0)
  let wrap = drawio_style(style, "whiteSpace", "") == "wrap" || drawio_style(style, "html", "") == "1"
  let max_width = if lw > 0.0 && lw < 1.0e8 { lw - spacing * 2.0 } else { 1.0e9 }
  let lines = if wrap {
    drawio_wrap_text(text, max_width, font, family, "", bold, italic, em)
  } else {
    text.split("\n").map(fn(line) { sfc_drawio_trim(line) }).collect()
  }
  let line_height = em * 1.2
  let count = lines.length()
  let total = line_height * count.to_double()
  let first_baseline = if valign == "top" {
    ly + spacing + em * 0.9
  } else if valign == "bottom" {
    ly + lh - spacing - total + em * 0.9
  } else {
    ly + (lh - total) / 2.0 + em * 0.9
  }
  for index, line in lines {
    if line == "" {
      continue
    }
    labels.push(line)
    let width_em = font.measure(family, "", bold, italic, line)
    let mut origin_x = lx + spacing
    if align == "center" {
      origin_x = lx + (lw - width_em * em) / 2.0
    } else if align == "right" {
      origin_x = lx + lw - spacing - width_em * em
    }
    let baseline = first_baseline + line_height * index.to_double()
    let choice = font.face(family, "", line[0].to_int(), bold~, italic~)
    let metrics = font.metrics(choice)
    let matrix = @canvas.Matrix::translate(origin_x, baseline).mul(
      @canvas.Matrix::scale(em, em),
    )
    drawing.text(@cad.CadText::new(
      line,
      matrix,
      color=color,
      advance=width_em,
      asc=metrics.asc,
      desc=metrics.desc,
      cap=metrics.cap,
    ))
  }
}

///|
fn drawio_arrow(
  drawing : @cad.Drawing,
  from : (Double, Double),
  to : (Double, Double),
  style : String,
  color : UInt32,
) -> Unit {
  let arrow = drawio_style(style, "endArrow", "classic")
  if arrow == "none" || arrow == "" {
    return
  }
  let dx = to.0 - from.0
  let dy = to.1 - from.1
  let length = (dx * dx + dy * dy).sqrt()
  if length <= 0.0 {
    return
  }
  let ux = dx / length
  let uy = dy / length
  let size = drawio_num_from_style(style, "endSize", 8.0)
  let bx = to.0 - ux * size
  let by = to.1 - uy * size
  let px = -uy * size * 0.45
  let py = ux * size * 0.45
  let path = @cad.CadPath::new()
  path.move_to(to.0, to.1)
  path.line_to(bx + px, by + py)
  path.line_to(bx - px, by - py)
  path.close()
  if drawio_style(style, "endFill", "1") != "0" {
    drawing.fill(path, @cad.Fill::solid(color), false)
  } else {
    drawing.stroke(path, @cad.Pen::new(color=color, width=1.0))
  }
}

///|
fn drawio_render_item(
  drawing : @cad.Drawing,
  item : DrawioRenderItem,
  fonts : @canvas.Fonts,
  labels : Array[String],
) -> Unit {
  match item {
    Shape(cell, x, y, w, h) => {
      let style = cell.style
      let is_text = drawio_style(style, "text", "") == "1" ||
        style.has_prefix("text;") || style.has_prefix("edgeLabel;")
      if !is_text {
        let path = drawio_shape(style, x, y, w, h)
        let fill = drawio_color(drawio_style(style, "fillColor", ""), 0xffffffffU)
        if drawio_style(style, "fillColor", "") != "none" {
          drawing.fill(path, @cad.Fill::solid(fill), false)
        }
        let stroke = drawio_color(drawio_style(style, "strokeColor", ""), 0x000000ffU)
        if drawio_style(style, "strokeColor", "") != "none" {
          let width = drawio_num_from_style(style, "strokeWidth", 1.0)
          let dash = if drawio_style(style, "dashed", "") == "1" {
            Some([4.0, 4.0])
          } else {
            None
          }
          drawing.stroke(path, @cad.Pen::new(
            color=stroke,
            width=width,
            dash~,
            cap=@cad.CAP_ROUND,
            join=@cad.JOIN_ROUND,
          ))
        }
      }
      drawio_label_runs(cell, x, y, w, h, fonts, drawing, labels)
    }
    Edge(cell, points) => {
      if points.length() < 2 {
        return
      }
      let path = @cad.CadPath::new()
      path.move_to(points[0].0, points[0].1)
      for index in 1..<points.length() {
        path.line_to(points[index].0, points[index].1)
      }
      let stroke = drawio_color(drawio_style(cell.style, "strokeColor", ""), 0x000000ffU)
      let width = drawio_num_from_style(cell.style, "strokeWidth", 1.0)
      let dash = if drawio_style(cell.style, "dashed", "") == "1" {
        Some([4.0, 4.0])
      } else {
        None
      }
      drawing.stroke(path, @cad.Pen::new(
        color=stroke,
        width=width,
        dash~,
        cap=@cad.CAP_ROUND,
        join=@cad.JOIN_ROUND,
      ))
      drawio_arrow(drawing, points[points.length() - 2], points[points.length() - 1], cell.style, stroke)
      let text = drawio_plain(cell.value)
      if text != "" {
        let middle = points[points.length() / 2]
        let matrix = @canvas.Matrix::translate(middle.0, middle.1).mul(
          @canvas.Matrix::scale(9.0, 9.0),
        )
        let width = fonts.measure("", "", false, false, text)
        let choice = fonts.face("", "", text[0].to_int())
        let metrics = fonts.metrics(choice)
        drawing.text(@cad.CadText::new(
          text,
          @canvas.Matrix::translate(middle.0 - width * 4.5, middle.1 - 4.0).mul(
            @canvas.Matrix::scale(9.0, 9.0),
          ),
          color=stroke,
          advance=width,
          asc=metrics.asc,
          desc=metrics.desc,
          cap=metrics.cap,
        ))
        labels.push(text)
        let _ = matrix
      }
    }
  }
}

///|
fn drawio_page_bounds(model : DrawioModel, fonts : @canvas.Fonts) -> (Double, Double, Double, Double, Bool) {
  let mut min_x = 1.0e300
  let mut min_y = 1.0e300
  let mut max_x = -1.0e300
  let mut max_y = -1.0e300
  let mut found = false
  for cell in model.cells {
    if !model.visible(cell) {
      continue
    }
    if cell.vertex {
      let (x, y, w, h) = model.absolute(cell)
      if w <= 0.0 || h <= 0.0 {
        continue
      }
      min_x = Double::min(min_x, x)
      min_y = Double::min(min_y, y)
      max_x = Double::max(max_x, x + w)
      max_y = Double::max(max_y, y + h)
      let text = drawio_plain(cell.value)
      if text != "" {
        let size = drawio_num_from_style(cell.style, "fontSize", 12.0)
        let em = size * 0.75
        let family = drawio_style(cell.style, "fontFamily", "")
        let font_style = drawio_num_from_style(cell.style, "fontStyle", 0.0).to_int()
        let bold = (font_style & 1) != 0
        let italic = (font_style & 2) != 0
        let wrap = drawio_style(cell.style, "whiteSpace", "") == "wrap" ||
          drawio_style(cell.style, "html", "") == "1"
        let mut text_width = 0.0
        for line in text.split("\n") {
          let value = sfc_drawio_trim(line)
          text_width = Double::max(
            text_width,
            fonts.measure(family, "", bold, italic, value) * em,
          )
        }
        let label_position = drawio_style(cell.style, "labelPosition", "center")
        if label_position == "right" {
          max_x = Double::max(max_x, x + w + 4.0 + text_width)
        } else if label_position == "left" {
          min_x = Double::min(min_x, x - 4.0 - text_width)
        } else if !wrap && text_width > w {
          max_x = Double::max(max_x, x + text_width)
        }
        let vertical_position = drawio_style(cell.style, "verticalLabelPosition", "middle")
        let text_height = em * 1.2 * text.split("\n").length().to_double()
        if vertical_position == "bottom" {
          max_y = Double::max(max_y, y + h + text_height + 2.0)
        } else if vertical_position == "top" {
          min_y = Double::min(min_y, y - text_height - 2.0)
        }
      }
      found = true
    } else if cell.edge {
      let points = model.edge_points(cell)
      for point in points {
        min_x = Double::min(min_x, point.0)
        min_y = Double::min(min_y, point.1)
        max_x = Double::max(max_x, point.0)
        max_y = Double::max(max_y, point.1)
        found = true
      }
    }
  }
  (min_x, min_y, max_x - min_x, max_y - min_y, found)
}

///|
fn drawio_view(page : Json, id : String, title : String) -> Json {
  let view : Map[String, Json] = {
    "id": Json::string(id),
    "kind": Json::string("fixed"),
    "pages": Json::array([page]),
  }
  if title != "" {
    view["title"] = Json::string(title)
  }
  Json::object(view)
}

///|
fn drawio_render_page(
  writer : @core.DocumentWriter,
  page_info : DrawioPage,
  fonts : @canvas.Fonts,
  warnings : Array[String],
) -> (Json, String, String, Array[String])? {
  let model = drawio_model(page_info.model)
  let (min_x, min_y, bounds_w, bounds_h, found) = drawio_page_bounds(model, fonts)
  let mut border = 10.0
  let mut page_w = 827.0
  let mut page_h = 1169.0
  if found && bounds_w > 0.0 && bounds_h > 0.0 {
    page_w = @math.ceil((bounds_w + border * 2.0) * 0.75)
    page_h = @math.ceil((bounds_h + border * 2.0) * 0.75)
    if page_w < 1.0 {
      page_w = 1.0
    }
    if page_h < 1.0 {
      page_h = 1.0
    }
  } else {
    border = 0.0
    page_w = @math.ceil(drawio_num(page_info.model, "pageWidth", page_w) * 0.75)
    page_h = @math.ceil(drawio_num(page_info.model, "pageHeight", page_h) * 0.75)
    page_w = Double::max(page_w, 1.0)
    page_h = Double::max(page_h, 1.0)
  }
  let labels : Array[String] = []
  let layers : Array[Json] = []
  let background = drawio_color(drawio_attr(page_info.model, "background", ""), 0x00000000U)
  if (background & 255U) != 0U {
    let canvas = @canvas.Canvas::new()
    canvas.object().set_bbox(0.0F, 0.0F, @canvas.f32(page_w), @canvas.f32(page_h))
    canvas.object().fill_color(background)
    canvas.object().fill_rect(0.0F, 0.0F, @canvas.f32(page_w), @canvas.f32(page_h))
    canvas.set_drawn()
    let hash = canvas.encode(writer, fonts, warnings) catch {
      error => {
        warnings.push("drawio: " + error.to_string())
        return None
      }
    }
    layers.push(@cad.layer("background", hash))
  }
  let matrix = @canvas.Matrix::translate(-min_x + border, -min_y + border).mul(
    @canvas.Matrix::scale(0.75, 0.75),
  )
  for layer in model.layers {
    if !layer.visible {
      continue
    }
    let drawing = @cad.Drawing::new()
    let mut has_item = false
    for cell in model.cells {
      if !model.visible(cell) || cell.layer != layer.id {
        continue
      }
      if cell.vertex {
        let (x, y, w, h) = model.absolute(cell)
        drawio_render_item(drawing, Shape(cell, x, y, w, h), fonts, labels)
        has_item = true
      } else if cell.edge {
        let points = model.edge_points(cell)
        if points.length() >= 2 {
          drawio_render_item(drawing, Edge(cell, points), fonts, labels)
          has_item = true
        }
      }
    }
    if !has_item {
      continue
    }
    let canvas = @canvas.Canvas::new()
    canvas.object().set_bbox(0.0F, 0.0F, @canvas.f32(page_w), @canvas.f32(page_h))
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
    layers.push(@cad.layer("body", hash))
  }
  if layers.is_empty() {
    let canvas = @canvas.Canvas::new()
    canvas.object().set_bbox(0.0F, 0.0F, @canvas.f32(page_w), @canvas.f32(page_h))
    canvas.set_drawn()
    let hash = canvas.encode(writer, fonts, warnings) catch {
      error => {
        warnings.push("drawio: " + error.to_string())
        return None
      }
    }
    layers.push(@cad.layer("body", hash))
  }
  let page = @cad.page(page_w, page_h, layers)
  let id = if page_info.id == "" { "page1" } else { page_info.id }
  let title = if page_info.name == "" { "Page-1" } else { page_info.name }
  Some((drawio_view(page, id, title), id, title, labels))
}
