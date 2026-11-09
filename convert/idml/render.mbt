///|
priv struct IdmlRenderState {
  used_stories : Map[String, Bool]
  warned : Map[String, Bool]
  fonts : Map[String, Int32]
  page_number : Int32
  index_runs : Array[@core.IndexRun]
}

///|
fn IdmlRenderState::warn(self : IdmlRenderState, message : String, warnings : Array[String]) -> Unit {
  if !self.warned.contains(message) {
    self.warned[message] = true
    warnings.push(message)
  }
}

///|
fn idml_bounds(points : Array[(Double, Double)]) -> (Double, Double, Double, Double) {
  let mut left = 1.0e30
  let mut top = 1.0e30
  let mut right = -1.0e30
  let mut bottom = -1.0e30
  for point in points {
    left = left.min(point.0)
    top = top.min(point.1)
    right = right.max(point.0)
    bottom = bottom.max(point.1)
  }
  (left, top, right, bottom)
}

///|
fn idml_path_points(item : IdmlXmlNode) -> Array[(Double, Double)] {
  let properties = idml_child(Some(item), "Properties")
  let geometry = idml_child(idml_child(properties, "PathGeometry"), "GeometryPathType")
  let array = idml_child(geometry, "PathPointArray")
  let points : Array[(Double, Double)] = []
  for point in idml_children(array) {
    if point.element.name.local_name != "PathPointType" {
      continue
    }
    let anchor = idml_numbers(idml_attr(Some(point), "Anchor", ""))
    if anchor.length() >= 2 {
      points.push((anchor[0], anchor[1]))
    }
  }
  points
}

///|
fn idml_geom_bounds(item : IdmlXmlNode) -> Array[(Double, Double)] {
  let bounds = idml_numbers(idml_attr(Some(item), "GeometricBounds", ""))
  if bounds.length() < 4 {
    return []
  }
  let top = bounds[0]
  let left = bounds[1]
  let bottom = bounds[2]
  let right = bounds[3]
  [ (left, top), (right, top), (right, bottom), (left, bottom) ]
}

///|
fn idml_item_matrix(item : IdmlXmlNode, parent : IdmlMatrix) -> IdmlMatrix {
  idml_matrix_mul(parent, idml_matrix(idml_attr(Some(item), "ItemTransform", "")))
}

///|
fn idml_transform_points(
  points : Array[(Double, Double)],
  matrix : IdmlMatrix,
) -> Array[(Double, Double)] {
  let out : Array[(Double, Double)] = []
  for point in points {
    out.push(matrix.apply(point.0, point.1))
  }
  out
}

///|
fn idml_visible(item : IdmlXmlNode, doc : IdmlDocument) -> Bool {
  if idml_attr(Some(item), "Visible", "true").to_lower() == "false" {
    return false
  }
  let layer = idml_attr(Some(item), "ItemLayer", "")
  if layer != "" && doc.layers.contains(layer) && !doc.layers[layer] {
    return false
  }
  true
}

///|
fn idml_alpha(item : IdmlXmlNode) -> Double? {
  let setting = idml_child(Some(item), "TransparencySetting")
  let blend = idml_child(setting, "BlendingSetting")
  if !idml_has_attr(blend, "Opacity") {
    return None
  }
  let value = idml_numbers(idml_attr(blend, "Opacity", "100"))
  if value.is_empty() {
    None
  } else {
    Some((value[0] / 100.0).max(0.0).min(1.0))
  }
}

///|
fn idml_fill_color(
  item : IdmlXmlNode,
  doc : IdmlDocument,
  state : IdmlRenderState,
  warnings : Array[String],
) -> UInt32? {
  let name = idml_attr(Some(item), "FillColor", "")
  match idml_resolve_color(doc.resources, name, 0) {
    Some(color) => {
      if doc.resources.grad_words.contains(name) {
        state.warn("IDML gradients are approximated by their first stop", warnings)
      }
      Some(((color.red << 24) | (color.green << 16) | (color.blue << 8) | 0xff).reinterpret_as_uint())
    }
    None => None
  }
}

///|
fn idml_stroke_color(
  item : IdmlXmlNode,
  doc : IdmlDocument,
) -> UInt32? {
  let name = idml_attr(Some(item), "StrokeColor", "")
  match idml_resolve_color(doc.resources, name, 0) {
    Some(color) =>
      Some(((color.red << 24) | (color.green << 16) | (color.blue << 8) | 0xff).reinterpret_as_uint())
    None => None
  }
}

///|
fn idml_dash(item : IdmlXmlNode) -> Array[Float] {
  let kind = idml_attr(Some(item), "StrokeType", "").to_lower()
  if kind.contains("dotted") {
    [1.0F, 1.0F]
  } else if kind.contains("dashed") {
    [3.0F, 1.0F]
  } else {
    []
  }
}

///|
fn idml_draw_shape(
  object : @core.ObjectBuilder,
  item : IdmlXmlNode,
  matrix : IdmlMatrix,
  doc : IdmlDocument,
  state : IdmlRenderState,
  warnings : Array[String],
) -> Unit {
  let kind = item.element.name.local_name
  let mut points = idml_path_points(item)
  if points.is_empty() {
    points = idml_geom_bounds(item)
  }
  if points.is_empty() {
    return
  }
  let transformed = idml_transform_points(points, matrix)
  let fill = idml_fill_color(item, doc, state, warnings)
  let stroke = idml_stroke_color(item, doc)
  let weight = idml_numbers(idml_attr(Some(item), "StrokeWeight", "0"))
  let width = if weight.is_empty() { 0.0 } else { weight[0] }
  let alpha = idml_alpha(item)
  if fill is Some(_) || (stroke is Some(_) && width > 0.0) {
    match alpha {
      Some(value) => {
        object.save()
        object.alpha(Float::from_double(value))
      }
      None => ()
    }
    let verbs = @buffer.Buffer()
    let coordinates : Array[Double] = []
    if kind == "Oval" {
      let (left, top, right, bottom) = idml_bounds(transformed)
      verbs.write_byte(6)
      coordinates.push((left + right) / 2.0)
      coordinates.push((top + bottom) / 2.0)
      coordinates.push((right - left) / 2.0)
      coordinates.push((bottom - top) / 2.0)
      coordinates.push(0.0)
      coordinates.push(0.0)
      coordinates.push(2.0 * 3.141592653589793)
      coordinates.push(0.0)
    } else if kind == "Rectangle" && idml_path_points(item).is_empty() {
      let (left, top, right, bottom) = idml_bounds(transformed)
      verbs.write_byte(5)
      coordinates.push(left)
      coordinates.push(top)
      coordinates.push(right - left)
      coordinates.push(bottom - top)
    } else {
      for i, point in transformed {
        verbs.write_byte(if i == 0 { 0 } else { 1 })
        coordinates.push(point.0)
        coordinates.push(point.1)
      }
      if kind != "GraphicLine" {
        verbs.write_byte(4)
      }
    }
    let path = object.add_path(@core.Inline({ verbs: verbs.to_bytes(), coordinates, }))
    match fill {
      Some(color) => {
        object.fill_color(color)
        object.fill_path(path, 1) catch { _ => () }
      }
      None => ()
    }
    match stroke {
      Some(color) =>
        if width > 0.0 {
          object.stroke_color(color)
          object.line(Float::from_double(width), 1, 1, 10)
          object.dash(idml_dash(item), 0.0F)
          object.stroke_path(path) catch { _ => () }
        }
      None => ()
    }
    if alpha is Some(_) {
      object.restore()
    }
  }
}

///|
fn idml_text_frame_bounds(item : IdmlXmlNode, matrix : IdmlMatrix) -> (Double, Double, Double, Double)? {
  let mut points = idml_path_points(item)
  if points.is_empty() {
    points = idml_geom_bounds(item)
  }
  if points.is_empty() {
    return None
  }
  let transformed = idml_transform_points(points, matrix)
  Some(idml_bounds(transformed))
}

///|
fn idml_wrap_text(text : String, width : Double, size : Double) -> Array[String] {
  let lines : Array[String] = []
  let limit = if size <= 0.0 { 1 } else { (width / (size * 0.5)).to_int().max(1) }
  for paragraph in text.split("\n") {
    if paragraph == "" {
      lines.push("")
      continue
    }
    let mut offset = 0
    let chars = paragraph.to_array()
    while offset < chars.length() {
      let end = (offset + limit).min(chars.length())
      lines.push(String::from_array(chars[offset:end]))
      offset = end
    }
  }
  lines
}

///|
fn idml_draw_flowed(
  object : @core.ObjectBuilder,
  item : IdmlXmlNode,
  matrix : IdmlMatrix,
  lines : Array[@drawingml.TextLine],
  state : IdmlRenderState,
) -> Unit {
  if lines.is_empty() {
    return
  }
  let bounds = idml_text_frame_bounds(item, matrix)
  object.save()
  match bounds {
    Some((left, top, right, bottom)) =>
      object.clip_rect(
        Float::from_double(left),
        Float::from_double(top),
        Float::from_double((right - left).max(1.0)),
        Float::from_double((bottom - top).max(1.0)),
      )
    None => ()
  }
  let text = StringBuilder()
  for line in lines {
    let family = line.style.family
    let key = family + "|" + line.style.size.round().to_int().to_string()
    let font = match state.fonts.get(key) {
      Some(index) => index
      None => {
        let index = object.add_font(
          {
            hash: None,
            family,
            weight: if line.style.bold { 700 } else { 400 },
            style: if line.style.italic { 1 } else { 0 },
          },
        )
        state.fonts[key] = index
        index
      }
    }
    object.fill_color(line.style.color)
    object.font(font, Float::from_double(line.style.size)) catch { _ => () }
    object.fill_text(
      line.text,
      Float::from_double(line.x),
      Float::from_double(line.y),
      Float::from_double(line.width.max(1.0)),
    )
    text.write_string(line.text)
  }
  object.restore()
  state.index_runs.push({
    a: state.page_number - 1,
    b: 0,
    ordinal: state.index_runs.length(),
    separator: 2,
    text: text.to_string(),
  })
}

///|
fn idml_draw_text(
  object : @core.ObjectBuilder,
  item : IdmlXmlNode,
  matrix : IdmlMatrix,
  doc : IdmlDocument,
  state : IdmlRenderState,
  warnings : Array[String],
) -> Unit {
  let bounds = match idml_text_frame_bounds(item, matrix) {
    Some(value) => value
    None => return
  }
  let (left, top, right, bottom) = bounds
  let story_id = idml_attr(Some(item), "ParentStory", "")
  let text = match doc.stories.get(story_id) {
    Some(value) => value
    None => return
  }
  if text == "" {
    return
  }
  match doc.flow_lines.get(idml_attr(Some(item), "Self", "")) {
    Some(lines) => {
      idml_draw_flowed(object, item, matrix, lines, state)
      return
    }
    None => ()
  }
  if state.used_stories.contains(story_id) {
    state.warn("IDML text flow between frames is not implemented", warnings)
    return
  }
  state.used_stories[story_id] = true
  let mut text = text
  if text.contains("<?ACE 18?>") {
    text = text.split("<?ACE 18?>").join(state.page_number.to_string())
  }
  let size = 12.0
  let family = "Arial"
  let key = family + "|12"
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
    Float::from_double((right - left).max(0.0)),
    Float::from_double((bottom - top).max(0.0)),
  )
  object.fill_color(0x000000ffU)
  object.font(font, Float::from_double(size)) catch { _ => () }
  let lines = idml_wrap_text(text, (right - left).max(1.0), size)
  let line_height = size * 1.25
  let mut y = top + size
  let mut count = 0
  for line in lines {
    if y > bottom || count > 10000 {
      break
    }
    object.fill_text(
      line,
      Float::from_double(left),
      Float::from_double(y),
      0.0F,
    )
    y += line_height
    count += 1
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
fn idml_draw_image(
  object : @core.ObjectBuilder,
  item : IdmlXmlNode,
  matrix : IdmlMatrix,
  doc : IdmlDocument,
  writer : @core.DocumentWriter,
  state : IdmlRenderState,
  warnings : Array[String],
) -> Unit {
  let properties = idml_child(Some(item), "Properties")
  let contents = idml_child(properties, "Contents")
  let data = match contents {
    Some(value) => {
      let text = idml_text(Some(value))
      @base64.decode(text[:], ignore_whitespace=true) catch { _ => b"" }
    }
    None => b""
  }
  if data.is_empty() {
    state.warn("IDML linked images are not available; the placement is left blank", warnings)
    return
  }
  if @raster.image_size(data) is None {
    state.warn("IDML image data is not a supported raster format", warnings)
    return
  }
  let bounds = idml_child(properties, "GraphicBounds")
  let numbers = if bounds is Some(_) {
    [
      idml_numbers(idml_attr(bounds, "Left", "0")),
      idml_numbers(idml_attr(bounds, "Top", "0")),
      idml_numbers(idml_attr(bounds, "Right", "1")),
      idml_numbers(idml_attr(bounds, "Bottom", "1")),
    ]
  } else {
    [[0.0], [0.0], [1.0], [1.0]]
  }
  let x0 = if numbers[0].is_empty() { 0.0 } else { numbers[0][0] }
  let y0 = if numbers[1].is_empty() { 0.0 } else { numbers[1][0] }
  let x1 = if numbers[2].is_empty() { x0 + 1.0 } else { numbers[2][0] }
  let y1 = if numbers[3].is_empty() { y0 + 1.0 } else { numbers[3][0] }
  let corners = idml_transform_points(
    [(x0, y0), (x1, y0), (x1, y1), (x0, y1)],
    matrix,
  )
  let (left, top, right, bottom) = idml_bounds(corners)
  if matrix.b != 0.0 || matrix.c != 0.0 {
    state.warn("IDML rotated images are drawn as their bounding box", warnings)
  }
  let hash = writer.add_part("img", data) catch {
    _ => {
      state.warn("IDML image data could not be stored", warnings)
      return
    }
  }
  let index = object.add_image(hash)
  object.save()
  match idml_alpha(item) {
    Some(value) => object.alpha(Float::from_double(value))
    None => ()
  }
  object.image(
    index,
    Float::from_double(left),
    Float::from_double(top),
    Float::from_double((right - left).max(0.0)),
    Float::from_double((bottom - top).max(0.0)),
  ) catch { _ => () }
  object.restore()
}

///|
fn idml_render_item(
  object : @core.ObjectBuilder,
  item : IdmlXmlNode,
  parent : IdmlMatrix,
  doc : IdmlDocument,
  writer : @core.DocumentWriter,
  state : IdmlRenderState,
  warnings : Array[String],
) -> Unit {
  if !idml_visible(item, doc) {
    return
  }
  let matrix = idml_item_matrix(item, parent)
  match item.element.name.local_name {
    "Group" => {
      for child in item.children {
        idml_render_item(object, child, matrix, doc, writer, state, warnings)
      }
    }
    "TextFrame" => idml_draw_text(object, item, matrix, doc, state, warnings)
    "Image" => idml_draw_image(object, item, matrix, doc, writer, state, warnings)
    "PDF" | "EPS" =>
      state.warn("IDML PDF and EPS placements are not supported", warnings)
    _ => idml_draw_shape(object, item, matrix, doc, state, warnings)
  }
}

///|
fn idml_render_items(
  object : @core.ObjectBuilder,
  items : Array[IdmlXmlNode],
  transform : IdmlMatrix,
  doc : IdmlDocument,
  writer : @core.DocumentWriter,
  state : IdmlRenderState,
  warnings : Array[String],
) -> Unit {
  for item in items {
    idml_render_item(object, item, transform, doc, writer, state, warnings)
  }
}

///|
fn idml_master_items(
  doc : IdmlDocument,
  spread : IdmlSpread,
  page : IdmlPage,
  page_number : Int32,
  writer : @core.DocumentWriter,
  warnings : Array[String],
) -> (Json?, Array[@core.IndexRun]) {
  if page.master == "" {
    return (None, [])
  }
  let master = match doc.masters.get(page.master) {
    Some(value) => value
    None => return (None, [])
  }
  let state : IdmlRenderState = {
    used_stories: Map([]),
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
  object.save()
  object.clip_rect(
    0.0F,
    0.0F,
    Float::from_double(page.width),
    Float::from_double(page.height),
  )
  // Master spreads hold one Page per side; use the one whose transform
  // matches the target page so the other side stays clipped out.
  let mut master_transform = page.transform
  for master_page in master.pages {
    if master_page.transform.e == page.transform.e &&
      master_page.transform.f == page.transform.f {
      master_transform = master_page.transform
      break
    }
  }
  idml_render_items(object, master.items, master_transform, doc, writer, state, warnings)
  object.restore()
  let encoded = object.encode() catch { _ => b"" }
  if encoded.is_empty() {
    (None, state.index_runs)
  } else {
    let hash = writer.add_part("obj", encoded) catch {
      _ => return (None, state.index_runs)
    }
    let layer : Map[String, Json] = {
      "role": Json::string("master"),
      "obj": Json::string(hash),
    }
    (Some(Json::object(layer)), state.index_runs)
  }
}

///|
fn idml_render_page(
  doc : IdmlDocument,
  spread : IdmlSpread,
  page : IdmlPage,
  page_number : Int32,
  writer : @core.DocumentWriter,
  warnings : Array[String],
) -> (Json, Array[@core.IndexRun]) raise IdmlError {
  let state : IdmlRenderState = {
    used_stories: Map([]),
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
  object.save()
  object.clip_rect(
    0.0F,
    0.0F,
    Float::from_double(page.width),
    Float::from_double(page.height),
  )
  idml_render_items(object, spread.items, page.transform, doc, writer, state, warnings)
  object.restore()
  let encoded = object.encode() catch { _ => b"" }
  let body_hash = writer.add_part("obj", encoded) catch {
    _ => raise IdmlInvalid("IDML page object could not be stored")
  }
  let layers : Array[Json] = []
  let (master_layer, master_runs) = idml_master_items(
    doc, spread, page, page_number, writer, warnings,
  )
  match master_layer {
    Some(layer) => layers.push(layer)
    None => ()
  }
  let all_runs : Array[@core.IndexRun] = []
  for run in master_runs {
    all_runs.push(run)
  }
  for run in state.index_runs {
    all_runs.push(run)
  }
  layers.push(
    Json::object({
      "role": Json::string("body"),
      "obj": Json::string(body_hash),
    }),
  )
  let page_json = Json::object({
    "w": Json::number(page.width, repr=page.width.to_string()),
    "h": Json::number(page.height, repr=page.height.to_string()),
    "layers": Json::array(layers),
  })
  (page_json, all_runs)
}
