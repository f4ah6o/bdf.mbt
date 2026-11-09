///|
priv struct VisioRenderState {
  warned : Map[String, Bool]
  fonts : Map[String, Int32]
  page_number : Int32
  index_runs : Array[@core.IndexRun]
}

///|
fn VisioRenderState::warn(self : VisioRenderState, message : String, warnings : Array[String]) -> Unit {
  if !self.warned.contains(message) {
    self.warned[message] = true
    warnings.push(message)
  }
}

///|
fn visio_shape_cell(
  shape : VisioXmlNode,
  master : VisioXmlNode?,
  name : String,
  default : String,
) -> String {
  let cells = visio_cells(Some(shape))
  match cells.get(name) {
    Some(value) => value
    None =>
      match master {
        Some(master) => visio_cell(visio_cells(Some(master)), name, default)
        None => default
      }
  }
}

///|
fn visio_shape_number(
  shape : VisioXmlNode,
  master : VisioXmlNode?,
  name : String,
  default : Double,
) -> Double {
  @string.parse_double(visio_shape_cell(shape, master, name, "")) catch {
    _ => default
  }
}

///|
fn visio_shape_text(shape : VisioXmlNode, master : VisioXmlNode?) -> String {
  let own = visio_text(visio_child(Some(shape), "Text"))
  if own != "" {
    own
  } else {
    match master {
      Some(value) => visio_text(visio_child(Some(value), "Text"))
      None => ""
    }
  }
}

///|
fn visio_geometry(shape : VisioXmlNode, master : VisioXmlNode?) -> Array[VisioXmlNode] {
  let sections : Array[VisioXmlNode] = []
  for child in shape.children {
    if child.element.name.local_name == "Section" &&
      visio_attr(Some(child), "N", "") == "Geometry" {
      sections.push(child)
    }
  }
  if sections.is_empty() {
    match master {
      Some(value) =>
        for child in value.children {
          if child.element.name.local_name == "Section" &&
            visio_attr(Some(child), "N", "") == "Geometry" {
            sections.push(child)
          }
        }
      None => ()
    }
  }
  sections
}

///|
fn visio_char_size(shape : VisioXmlNode, master : VisioXmlNode?) -> Double {
  for child in shape.children {
    if child.element.name.local_name == "Section" &&
      visio_attr(Some(child), "N", "") == "Character" {
      for row in child.children {
        if row.element.name.local_name == "Row" {
          let size = visio_cell(visio_cells(Some(row)), "Size", "")
          let value = @string.parse_double(size) catch { _ => 0.0 }
          if value > 0.0 {
            return value * 72.0
          }
        }
      }
    }
  }
  match master {
    Some(value) => {
      let size = visio_char_size(value, None)
      if size > 0.0 { size } else { 12.0 }
    }
    None => 12.0
  }
}

///|
fn visio_color(text : String, fallback : UInt32) -> UInt32 {
  if text.has_prefix("#") && text.length() >= 7 {
    let red = @string.parse_int("0x" + text[1:3].to_owned()) catch { _ => -1 }
    let green = @string.parse_int("0x" + text[3:5].to_owned()) catch { _ => -1 }
    let blue = @string.parse_int("0x" + text[5:7].to_owned()) catch { _ => -1 }
    if red >= 0 && green >= 0 && blue >= 0 {
      ((red << 24) | (green << 16) | (blue << 8) | 0xff).reinterpret_as_uint()
    } else {
      fallback
    }
  } else {
    fallback
  }
}

///|
fn visio_transform(
  shape : VisioXmlNode,
  master : VisioXmlNode?,
  x : Double,
  y : Double,
  page_height : Double,
) -> (Double, Double) {
  let width = visio_shape_number(shape, master, "Width", 1.0)
  let height = visio_shape_number(shape, master, "Height", 1.0)
  let pin_x = visio_shape_number(shape, master, "PinX", 0.0)
  let pin_y = visio_shape_number(shape, master, "PinY", 0.0)
  let loc_x = visio_shape_number(shape, master, "LocPinX", width / 2.0)
  let loc_y = visio_shape_number(shape, master, "LocPinY", height / 2.0)
  let angle = visio_shape_number(shape, master, "Angle", 0.0)
  let flip_x = visio_shape_cell(shape, master, "FlipX", "0") != "0"
  let flip_y = visio_shape_cell(shape, master, "FlipY", "0") != "0"
  let x = if flip_x { width - x } else { x }
  let y = if flip_y { height - y } else { y }
  let dx = x - loc_x
  let dy = y - loc_y
  let sine = @math.sin(angle)
  let cosine = @math.cos(angle)
  let px = pin_x + dx * cosine - dy * sine
  let py = pin_y + dx * sine + dy * cosine
  (px * 72.0, (page_height - py * 72.0))
}

///|
fn visio_shape_bounds(
  shape : VisioXmlNode,
  master : VisioXmlNode?,
  page_height : Double,
) -> (Double, Double, Double, Double) {
  let width = visio_shape_number(shape, master, "Width", 0.0)
  let height = visio_shape_number(shape, master, "Height", 0.0)
  let corners = [
    visio_transform(shape, master, 0.0, 0.0, page_height),
    visio_transform(shape, master, width, 0.0, page_height),
    visio_transform(shape, master, width, height, page_height),
    visio_transform(shape, master, 0.0, height, page_height),
  ]
  let mut left = 1.0e30
  let mut top = 1.0e30
  let mut right = -1.0e30
  let mut bottom = -1.0e30
  for point in corners {
    left = left.min(point.0)
    top = top.min(point.1)
    right = right.max(point.0)
    bottom = bottom.max(point.1)
  }
  (left, top, right, bottom)
}

///|
fn visio_shape_visible(
  shape : VisioXmlNode,
  page : VisioPage,
) -> Bool {
  let layer = visio_shape_cell(shape, None, "LayerMember", "")
  if layer != "" && page.layers.contains(layer) && !page.layers[layer] {
    return false
  }
  true
}

///|
fn visio_draw_text(
  object : @core.ObjectBuilder,
  shape : VisioXmlNode,
  master : VisioXmlNode?,
  page_height : Double,
  state : VisioRenderState,
) -> Unit {
  let text = visio_shape_text(shape, master)
  if text == "" {
    return
  }
  let (left, top, right, bottom) = visio_shape_bounds(shape, master, page_height)
  let size = visio_char_size(shape, master)
  let family = "Arial"
  let key = family + "|" + size.round().to_int().to_string()
  let font = match state.fonts.get(key) {
    Some(index) => index
    None => {
      let index = object.add_font(
        { hash: None, family, weight: 400, style: 0 },
      )
      state.fonts[key] = index
      index
    }
  }
  object.save()
  object.clip_rect(
    Float::from_double(left),
    Float::from_double(top),
    Float::from_double((right - left).max(1.0)),
    Float::from_double((bottom - top).max(1.0)),
  )
  object.fill_color(0x000000ffU)
  object.font(font, Float::from_double(size)) catch { _ => () }
  let width = (right - left).max(1.0)
  let limit = (width / (size * 0.5)).to_int().max(1)
  let mut y = top + size
  for paragraph in text.split("\n") {
    let chars = paragraph.to_array()
    let mut offset = 0
    while offset < chars.length() && y <= bottom {
      let end = (offset + limit).min(chars.length())
      object.fill_text(
        String::from_array(chars[offset:end]),
        Float::from_double(left + 1.0),
        Float::from_double(y),
        0.0F,
      )
      y += size * 1.25
      offset = end
    }
  }
  object.restore()
  state.index_runs.push({
    a: state.page_number - 1,
    b: 0,
    ordinal: state.index_runs.length(),
    separator: 2,
    text,
  })
}

///|
fn visio_draw_shape(
  object : @core.ObjectBuilder,
  shape : VisioXmlNode,
  master : VisioXmlNode?,
  page_height : Double,
  state : VisioRenderState,
  warnings : Array[String],
) -> Unit {
  let width = visio_shape_number(shape, master, "Width", 0.0)
  let height = visio_shape_number(shape, master, "Height", 0.0)
  if width <= 0.0 || height <= 0.0 {
    return
  }
  let fill_name = {
    let value = visio_shape_cell(shape, master, "FillForegnd", "")
    if value == "" {
      visio_shape_cell(shape, master, "FillForeColor", "")
    } else {
      value
    }
  }
  let fill_pattern = visio_shape_cell(shape, master, "FillPattern", "1")
  let line_pattern = visio_shape_cell(shape, master, "LinePattern", "1")
  let has_fill = fill_pattern != "0"
  let has_line = line_pattern != "0"
  let fill = visio_color(fill_name, 0xf2f2f2ffU)
  let stroke = visio_color(visio_shape_cell(shape, master, "LineColor", ""), 0x000000ffU)
  let weight = visio_shape_number(shape, master, "LineWeight", 1.0 / 72.0) * 72.0
  let sections = visio_geometry(shape, master)
  let verbs = @buffer.Buffer()
  let coordinates : Array[Double] = []
  let mut drew = false
  for section in sections {
    for row in section.children {
      if row.element.name.local_name != "Row" {
        continue
      }
      let kind = visio_attr(Some(row), "T", "")
      let cells = visio_cells(Some(row))
      let relative = kind == "RelMoveTo" || kind == "RelLineTo"
      let x = visio_number(cells, "X", 0.0)
      let y = visio_number(cells, "Y", 0.0)
      let x = if relative { x * width } else { x }
      let y = if relative { y * height } else { y }
      if kind == "Ellipse" {
        let a = visio_number(cells, "A", width / 2.0)
        let b = visio_number(cells, "B", height / 2.0)
        let c = visio_number(cells, "C", width / 2.0)
        let d = visio_number(cells, "D", height / 2.0)
        let (cx, cy) = visio_transform(shape, master, x, y, page_height)
        let (ex, ey) = visio_transform(shape, master, x + c, y + d, page_height)
        let (sx, sy) = visio_transform(shape, master, x - a, y - b, page_height)
        let rx = ((ex - sx) / 2.0).abs()
        let ry = ((ey - sy) / 2.0).abs()
        verbs.write_byte(6)
        coordinates.push(cx)
        coordinates.push(cy)
        coordinates.push(rx)
        coordinates.push(ry)
        coordinates.push(0.0)
        coordinates.push(0.0)
        coordinates.push(2.0 * 3.141592653589793)
        coordinates.push(0.0)
        drew = true
      } else if kind.ends_with("MoveTo") {
        let (px, py) = visio_transform(shape, master, x, y, page_height)
        verbs.write_byte(if verbs.length() == 0 { 0 } else { 0 })
        coordinates.push(px)
        coordinates.push(py)
        drew = true
      } else if kind.ends_with("LineTo") {
        let (px, py) = visio_transform(shape, master, x, y, page_height)
        if verbs.length() == 0 {
          verbs.write_byte(0)
          coordinates.push(px)
          coordinates.push(py)
        } else {
          verbs.write_byte(1)
          coordinates.push(px)
          coordinates.push(py)
        }
        drew = true
      }
    }
  }
  if !drew {
    let (left, top, right, bottom) = visio_shape_bounds(shape, master, page_height)
    verbs.write_byte(5)
    coordinates.push(left)
    coordinates.push(top)
    coordinates.push(right - left)
    coordinates.push(bottom - top)
  } else {
    verbs.write_byte(4)
  }
  let path = object.add_path(@core.Inline({ verbs: verbs.to_bytes(), coordinates, }))
  if has_fill {
    object.fill_color(fill)
    object.fill_path(path, 1) catch { _ => () }
  }
  if has_line && weight > 0.0 {
    object.stroke_color(stroke)
    object.line(Float::from_double(weight), 1, 1, 10)
    object.stroke_path(path) catch { _ => () }
  }
  ignore(state)
  ignore(warnings)
}

///|
fn visio_render_shape(
  object : @core.ObjectBuilder,
  shape : VisioXmlNode,
  doc : VisioDocument,
  page : VisioPage,
  state : VisioRenderState,
  warnings : Array[String],
) -> Unit {
  if !visio_shape_visible(shape, page) {
    return
  }
  if visio_shape_cell(shape, None, "LayerMember", "") == "" {
    // no layer restriction
  }
  let master_id = visio_attr(Some(shape), "Master", "")
  let master = if master_id == "" { None } else { doc.masters.get(master_id) }
  visio_draw_shape(object, shape, master, page.height, state, warnings)
  visio_draw_text(object, shape, master, page.height, state)
  let nested = visio_child(Some(shape), "Shapes")
  for child in visio_children(nested) {
    if child.element.name.local_name == "Shape" {
      visio_render_shape(object, child, doc, page, state, warnings)
    }
  }
}

///|
fn visio_render_page_shapes(
  object : @core.ObjectBuilder,
  shapes : Array[VisioXmlNode],
  doc : VisioDocument,
  page : VisioPage,
  state : VisioRenderState,
  warnings : Array[String],
) -> Unit {
  object.save()
  object.clip_rect(
    0.0F,
    0.0F,
    Float::from_double(page.width),
    Float::from_double(page.height),
  )
  for shape in shapes {
    visio_render_shape(object, shape, doc, page, state, warnings)
  }
  object.restore()
}

///|
fn visio_page_object(
  shapes : Array[VisioXmlNode],
  doc : VisioDocument,
  page : VisioPage,
  page_number : Int32,
  writer : @core.DocumentWriter,
  warnings : Array[String],
) -> (String, Array[@core.IndexRun]) raise VisioError {
  let state : VisioRenderState = {
    warned: Map([]),
    fonts: Map([]),
    page_number,
    index_runs: [],
  }
  let object = @core.ObjectBuilder::new()
  object.set_bbox(
    0.0F,
    0.0F,
    Float::from_double(page.width),
    Float::from_double(page.height),
  )
  visio_render_page_shapes(object, shapes, doc, page, state, warnings)
  let encoded = object.encode() catch {
    _ => raise VisioInvalid("Visio page object could not be stored")
  }
  let hash = writer.add_part("obj", encoded) catch {
    _ => raise VisioInvalid("Visio page object could not be stored")
  }
  (hash, state.index_runs)
}

///|
fn visio_render(
  doc : VisioDocument,
  writer : @core.DocumentWriter,
  warnings : Array[String],
) -> (Array[Json], Array[@core.IndexRun]) raise VisioError {
  let pages : Array[Json] = []
  let index_runs : Array[@core.IndexRun] = []
  let mut number = 1
  for page in doc.pages {
    let layers : Array[Json] = []
    let mut background : VisioPage? = None
    if page.back_page != "" {
      for candidate in doc.backgrounds {
        if candidate.id == page.back_page {
          background = Some(candidate)
        }
      }
    }
    match background {
      Some(bg) => {
        let (hash, runs) = visio_page_object(
          bg.shapes, doc, page, number, writer, warnings,
        )
        layers.push(Json::object({
          "role": Json::string("background"),
          "obj": Json::string(hash),
        }))
        for run in runs {
          index_runs.push(run)
        }
      }
      None => ()
    }
    let (hash, runs) = visio_page_object(
      page.shapes, doc, page, number, writer, warnings,
    )
    layers.push(Json::object({
      "role": Json::string("body"),
      "obj": Json::string(hash),
    }))
    for run in runs {
      index_runs.push(run)
    }
    pages.push(Json::object({
      "w": Json::number(page.width, repr=page.width.to_string()),
      "h": Json::number(page.height, repr=page.height.to_string()),
      "layers": Json::array(layers),
    }))
    number += 1
  }
  (pages, index_runs)
}
