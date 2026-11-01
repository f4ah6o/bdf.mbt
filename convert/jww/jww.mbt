///|
/// A Jw_cad conversion failure.
pub suberror JwwError {
  JwwInvalid(String)
}

///|
pub(all) struct JwwResult {
  bdf : Bytes
  pages : Int32
  summary : String
  warnings : Array[String]
}

///|
/// Detect a Jw_cad drawing.
pub fn detect(data : Bytes) -> Bool {
  data.has_prefix(b"JwwData.")
}

///|
priv struct JwwConverter {
  header : JwwHeader
  data : JwwData
  drawing : @cad.Drawing
  warnings : Array[String]
  warned : Map[String, Bool]
  fonts : @canvas.Fonts
  mono : Bool
  screen : Bool
  bg : UInt32
  mut count : Int
  blocks : Array[Int]
}

///|
fn JwwConverter::warn(self : JwwConverter, message : String) -> Unit {
  self.warnings.push(message)
}

///|
fn JwwConverter::warn_once(self : JwwConverter, key : String, message : String) -> Unit {
  if !self.warned.contains(key) {
    self.warned[key] = true
    self.warn(message)
  }
}

///|
fn jww_colorref(value : UInt32) -> UInt32 {
  ((value & 255U) << 24) | (((value >> 8) & 255U) << 16) | (((value >> 16) & 255U) << 8) | 255U
}

///|
fn JwwConverter::color(self : JwwConverter, number : Int) -> UInt32 {
  if self.mono {
    return if number == 0 { self.bg } else { 0x000000ffU }
  }
  if number >= 0 && number <= 9 {
    let value = if self.screen {
      self.header.screen[number]
    } else {
      self.header.prt_pen[number].color
    }
    return jww_colorref(value)
  }
  if number >= 100 && number <= 356 && self.header.has_sxf {
    return jww_colorref(self.header.sxf_pens[number - 100].color)
  }
  jww_colorref(self.header.prt_pen[2].color)
}

///|
fn JwwConverter::pen(self : JwwConverter, number : Int) -> JwwPen {
  if number >= 0 && number <= 9 {
    self.header.prt_pen[number]
  } else if number >= 100 && number <= 356 && self.header.has_sxf {
    self.header.sxf_pens[number - 100]
  } else {
    self.header.prt_pen[2]
  }
}

///|
fn JwwConverter::width_mm(self : JwwConverter, width : Int) -> Double {
  if width <= 0 {
    return 0.0
  }
  if self.header.max_width <= -101 {
    width.to_double() / 100.0
  } else {
    width.to_double() * 25.4 / self.header.dpi.to_double()
  }
}

///|
fn JwwConverter::visible(self : JwwConverter, base : JwwBase) -> Bool {
  let group = base.glayer & 15
  let layer = base.layer & 15
  if group < 0 || group >= self.header.groups.length() {
    return false
  }
  let value = self.header.groups[group]
  if layer < 0 || layer >= value.layers.length() {
    return false
  }
  value.state != 0 && value.layers[layer] != 0
}

///|
fn JwwConverter::auxiliary(self : JwwConverter, base : JwwBase) -> Bool {
  let _ = self
  base.style == 9 || base.color == 9
}

///|
fn JwwConverter::line_pen(self : JwwConverter, base : JwwBase) -> @cad.Pen {
  let pen_info = self.pen(base.color)
  let mut width = pen_info.width
  if base.width > 0 {
    width = base.width
  }
  let thin = width <= 1 && self.header.max_width > -101
  let pen = @cad.Pen::new(
    color=self.color(base.color),
    width=if thin { 0.0 } else { self.width_mm(width) * 72.0 / 25.4 },
    cap=@cad.CAP_ROUND,
    join=@cad.JOIN_ROUND,
  )
  let (dash, offset) = self.dash(base.style)
  pen.dash = dash
  pen.dash_offset = offset
  pen
}

///|
fn JwwConverter::dash(self : JwwConverter, style : Int) -> (Array[Double]?, Double) {
  if style <= 1 || (style >= 11 && style <= 15) {
    return (None, 0.0)
  }
  if style >= 30 && style <= 62 && self.header.has_sxf {
    let type_ = self.header.sxf_types[style - 30]
    if type_.segments > 0 {
      let elements : Array[Double] = []
      for index in 0..<type_.segments {
        if index >= type_.pitch.length() { break }
        let value = type_.pitch[index].abs()
        elements.push(if index % 2 == 1 { -value } else { value })
      }
      return @cad.dash_pattern(Some(elements))
    }
  }
  match self.header.line_types.get(style) {
    Some(type_) =>
      if type_.unit <= 0 || type_.unit > 32 {
        return (None, 0.0)
      } else {
        let bit = Double::max(type_.prt_pitch.to_double(), 1.0) *
          25.4 /
          self.header.dpi.to_double()
        let elements : Array[Double] = []
        for index in 0..<type_.unit {
          let on = ((type_.mask >> index) & 1U) != 0U
          let value = if on { bit } else { -bit }
          if !elements.is_empty() {
            let last = elements[elements.length() - 1]
            if (last > 0.0) == on {
              elements[elements.length() - 1] = last + value
            } else {
              elements.push(value)
            }
          } else {
            elements.push(value)
          }
        }
        @cad.dash_pattern(Some(elements))
      }
    None => (None, 0.0)
  }
}

///|
fn JwwConverter::draw_figures(
  self : JwwConverter,
  figures : Array[JwwFigure],
  matrix : @canvas.Matrix,
  depth : Int,
) -> Unit {
  for figure in figures {
    self.count += 1
    if self.count > 5000000 {
      self.warn_once("budget", "only the first 5000000 figures are drawn")
      return
    }
    match figure {
      Sen(value) => self.draw_sen(value, matrix)
      Enko(value) => self.draw_enko(value, matrix)
      Ten(value) => self.draw_ten(value, matrix)
      Moji(value) => self.draw_moji(value, matrix)
      Sunpou(value) => self.draw_sunpou(value, matrix, depth)
      Solid(value) => self.draw_solid(value, matrix)
      Block(value) => self.draw_block(value, matrix, depth)
      BlockDef(_) => ()
    }
  }
}

///|
fn JwwConverter::draw_sen(self : JwwConverter, value : JwwSen, matrix : @canvas.Matrix) -> Unit {
  if !self.visible(value.base) || self.auxiliary(value.base) {
    return
  }
  let path = @cad.CadPath::new()
  path.move_to(value.a.x, value.a.y)
  path.line_to(value.b.x, value.b.y)
  self.drawing.stroke(path.transform(matrix), self.line_pen(value.base))
}

///|
fn JwwConverter::draw_enko(self : JwwConverter, value : JwwEnko, matrix : @canvas.Matrix) -> Unit {
  if !self.visible(value.base) || self.auxiliary(value.base) {
    return
  }
  self.drawing.stroke(self.arc_path(value).transform(matrix), self.line_pen(value.base))
}

///|
fn JwwConverter::arc_path(self : JwwConverter, value : JwwEnko) -> @cad.CadPath {
  let _ = self
  let flat = if value.flat <= 0.0 { 1.0 } else { value.flat }
  let major : @cad.Point = {
    x: value.r * @math.cos(value.tilt),
    y: value.r * @math.sin(value.tilt),
  }
  let path = @cad.CadPath::new()
  if value.full || value.arc.abs() >= 2.0 * 3.141592653589793 - 1.0e-9 {
    path.ellipse(value.c, major, flat)
  } else {
    path.ellipse_arc(value.c, major, flat, value.start, value.start + value.arc)
  }
  path
}

///|
fn JwwConverter::draw_ten(self : JwwConverter, value : JwwTen, matrix : @canvas.Matrix) -> Unit {
  if value.kari || !self.visible(value.base) {
    return
  }
  let mut radius = 0.1
  if self.header.draw_prt_ten {
    let pen = self.pen(value.base.color)
    if pen.radius > 0.0 {
      radius = pen.radius
    }
  }
  let point = @cad.apply(matrix, value.p)
  let path = @cad.CadPath::new()
  path.circle(point, radius)
  self.drawing.fill(path, @cad.Fill::solid(self.color(value.base.color)), false)
}

///|
fn jww_full_width(character : Char) -> Bool {
  let text = character.to_string()
  match @encoding.encode(text, "shift_jis") {
    Ok(bytes) => bytes.length() == 2
    Err(_) => character.to_int() >= 0x2e80
  }
}

///|
fn JwwConverter::draw_moji(self : JwwConverter, value : JwwMoji, matrix : @canvas.Matrix) -> Unit {
  if !self.visible(value.base) {
    return
  }
  if value.s.has_prefix("^@") {
    self.warn_once("image", "images and other special text (^@) are not drawn")
    return
  }
  if jww_blank(value.s) || value.h <= 0.0 {
    return
  }
  let italic = (value.kind / 10000) % 2 == 1
  let bold = value.kind / 20000 >= 1
  let spec = @cad.FontSpec::new(family=value.font, bold=bold, italic=italic)
  let em = value.h
  let cells : Array[Double] = []
  for character in value.s {
    let mut width = value.w / em
    if !jww_full_width(character) {
      width /= 2.0
    }
    cells.push(width)
  }
  let spacing = value.spacing / em
  let angle = value.angle * 3.141592653589793 / 180.0
  let vertical = (value.base.flag & 0x0020) != 0
  let translate : @canvas.Matrix = @canvas.Matrix::translate(value.a.x, value.a.y)
  let rotate : @canvas.Matrix = {
    a: @math.cos(angle),
    b: @math.sin(angle),
    c: -@math.sin(angle),
    d: @math.cos(angle),
    e: 0.0,
    f: 0.0,
  }
  let text_matrix = if !vertical {
    matrix.mul(translate).mul(rotate).mul(
      @canvas.Matrix::translate(0.0, 0.14 * em),
    ).mul(@canvas.Matrix::scale(em, em))
  } else {
    matrix.mul(translate).mul(rotate).mul(
      @canvas.Matrix::translate(value.w / 2.0, 0.0),
    ).mul(@canvas.Matrix::rotate(-90.0)).mul(@canvas.Matrix::scale(em, em))
  }
  let choice = self.fonts.face(
    spec.family,
    spec.east_asian,
    value.s[0].to_int(),
    bold=spec.bold,
    italic=spec.italic,
  )
  let metrics = self.fonts.metrics(choice)
  let text = @cad.CadText::new(
    value.s,
    text_matrix,
    font=spec,
    color=self.color(value.base.color),
    advance=jww_cells_sum(cells),
    cells=Some(cells),
    spacing=spacing,
    asc=metrics.asc,
    desc=metrics.desc,
    cap=metrics.cap,
    vertical=vertical,
  )
  self.drawing.text(text)
}

///|
fn jww_cells_sum(cells : Array[Double]) -> Double {
  let mut total = 0.0
  for value in cells {
    total += value
  }
  total
}

///|
fn jww_blank(value : String) -> Bool {
  for character in value {
    if !character.is_whitespace() {
      return false
    }
  }
  true
}

///|
fn JwwConverter::draw_sunpou(
  self : JwwConverter,
  value : JwwSunpou,
  matrix : @canvas.Matrix,
  depth : Int,
) -> Unit {
  if !self.visible(value.base) {
    return
  }
  self.draw_sen(value.line, matrix)
  self.draw_moji(value.text, matrix)
  for item in value.aux {
    match item {
      Some(sen) => self.draw_sen(sen, matrix)
      None => ()
    }
  }
  for item in value.points {
    match item {
      Some(point) => self.draw_ten(point, matrix)
      None => ()
    }
  }
  let _ = depth
}

///|
fn JwwConverter::draw_solid(
  self : JwwConverter,
  value : JwwSolid,
  matrix : @canvas.Matrix,
) -> Unit {
  if !self.visible(value.base) {
    return
  }
  let color = if value.base.color == 10 {
    jww_colorref(value.rgb)
  } else {
    self.color(value.base.color)
  }
  let path = @cad.CadPath::new()
  if value.base.style >= 101 {
    let center = value.p1
    let radius = value.p4.x
    let mut flat = value.p4.y
    let tilt = value.p2.x
    let start = value.p2.y
    let arc = value.p3.x
    let kind = value.p3.y
    if flat <= 0.0 { flat = 1.0 }
    let major : @cad.Point = {
      x: radius * @math.cos(tilt),
      y: radius * @math.sin(tilt),
    }
    if (value.base.style == 101 || value.base.style == 111) && kind == 100.0 {
      path.ellipse(center, major, flat)
    } else if value.base.style == 101 && kind == 0.0 {
      path.move_to(center.x, center.y)
      path.ellipse_arc(center, major, flat, start, start + arc)
      path.close()
    } else if value.base.style == 101 && (kind == 5.0 || kind == -1.0) {
      path.ellipse_arc(center, major, flat, start, start + arc)
      path.close()
    } else if value.base.style == 105 || value.base.style == 106 {
      let inner = kind
      let inner_major : @cad.Point = {
        x: inner * @math.cos(tilt),
        y: inner * @math.sin(tilt),
      }
      let inner_flat = if value.base.style == 106 && inner > 0.0 {
        (radius * flat - (radius - inner)) / inner
      } else {
        flat
      }
      if arc.abs() >= 2.0 * 3.141592653589793 - 1.0e-9 || arc == 0.0 {
        path.ellipse(center, major, flat)
        if inner > 0.0 {
          path.ellipse(center, inner_major, inner_flat)
        }
      } else {
        path.ellipse_arc(center, major, flat, start, start + arc)
        path.ellipse_arc(center, inner_major, inner_flat, start + arc, start)
        path.close()
      }
    } else {
      path.ellipse(center, major, flat)
    }
    self.drawing.fill(path.transform(matrix), @cad.Fill::solid(color), true)
    return
  }
  path.polyline([value.p1, value.p2, value.p3, value.p4], true)
  self.drawing.fill(path.transform(matrix), @cad.Fill::solid(color), false)
}

///|
fn JwwConverter::draw_block(
  self : JwwConverter,
  value : JwwBlock,
  matrix : @canvas.Matrix,
  depth : Int,
) -> Unit {
  if !self.visible(value.base) {
    return
  }
  match self.data.blocks.get(value.number) {
    None => self.warn_once("block", "a block refers to a missing definition")
    Some(definition) => {
      if depth > 32 {
        self.warn_once("depth", "blocks nested deeper than 32 levels are not drawn")
        return
      }
      if self.blocks.contains(value.number) {
        self.warn_once("cycle", "a block that inserts itself is drawn once")
        return
      }
      let block_matrix = matrix.mul(@canvas.Matrix::translate(value.p.x, value.p.y)).mul(
        @canvas.Matrix::rotate(value.rot * 180.0 / 3.141592653589793),
      ).mul(@canvas.Matrix::scale(value.sx, value.sy))
      self.blocks.push(value.number)
      self.draw_figures(definition.figures, block_matrix, depth + 1)
      ignore(self.blocks.pop())
    }
  }
}

///|
/// Convert a JWW drawing into a fixed-view BDF document.
pub fn convert(
  data : Bytes,
  title~ : String = "",
  colors~ : String = "",
  no_text_index~ : Bool = false,
  db~ : @fontdb.Database? = None,
) -> JwwResult raise JwwError {
  if data.length() > 1073741824 {
    raise JwwInvalid("jww: the file is larger than 1073741824 bytes")
  }
  let (mono, screen) = match colors {
    "" | "screen" => (false, true)
    "print" => (false, false)
    "mono" => (true, false)
    _ => raise JwwInvalid("jww: parameter colors: \"" + colors + "\" is not screen, print or mono")
  }
  let header_archive = JwwArchive::new(data)
  let header = read_header(header_archive) catch {
    error => raise JwwInvalid(error.to_string())
  }
  let start = header_archive.offset
  let mut parsed : JwwData? = None
  let mut fallback : JwwData? = None
  let mut parse_error = ""
  for time_size in [4, 8] {
    let value : JwwData? = try {
      Some(read_data(data, start, header, time_size))
    } catch {
      Failure(message) => {
        parse_error = message
        None
      }
      _ => None
    }
    match value {
      Some(data_value) => {
        let replace = match parsed {
          Some(current) => data_value.figures.length() > current.figures.length()
          None => true
        }
        if replace {
          parsed = Some(data_value)
        }
      }
      None => {
        if fallback is None {
          fallback = Some({ figures: [], blocks: Map([]), })
        }
      }
    }
  }
  let parsed_data = match parsed {
    Some(value) => value
    None =>
      match fallback {
        Some(value) => value
        None => { figures: [], blocks: Map([]), }
      }
  }
  if parsed_data.figures.is_empty() && parse_error != "" {
    raise JwwInvalid("jww: " + parse_error)
  }
  let fonts = @canvas.Fonts::new(db)
  let bg = if screen { jww_colorref(header.screen[0]) } else { 0xffffffffU }
  let converter : JwwConverter = {
    header,
    data: parsed_data,
    drawing: @cad.Drawing::new(),
    warnings: [],
    warned: Map([]),
    fonts,
    mono,
    screen,
    bg,
    count: 0,
    blocks: [],
  }
  converter.draw_figures(parsed_data.figures, @canvas.Matrix::identity(), 0)
  if converter.fonts.has_fonts() == false {
    converter.warn_once(
      "fonts",
      "no fonts found; text is laid out with estimated metrics and not embedded",
    )
  }
  let (sheet_w, sheet_h) = jww_sheet(header.paper)
  let sheet : @cad.Rect = {
    min: { x: -sheet_w / 2.0, y: -sheet_h / 2.0 },
    max: { x: sheet_w / 2.0, y: sheet_h / 2.0 },
    ok: true,
  }
  let bounds = converter.drawing.bounds()
  let area = if bounds.is_valid() { sheet.union(bounds) } else { sheet }
  let mm = 72.0 / 25.4
  let width = area.w() * mm
  let height = area.h() * mm
  let matrix : @canvas.Matrix = {
    a: mm,
    b: 0.0,
    c: 0.0,
    d: -mm,
    e: -area.min.x * mm,
    f: area.max.y * mm,
  }
  let meta = @cad.document_meta("jww", title=title)
  let document_title = if title != "" { title } else { header.memo }
  meta["dc"] = Json::object({
    "title": Json::string(document_title),
    "language": Json::string("ja"),
  })
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
  let canvas = @canvas.Canvas::new(doc_lang="ja")
  canvas.object().set_bbox(0.0F, 0.0F, @canvas.f32(width), @canvas.f32(height))
  canvas.object().fill_color(bg)
  canvas.object().fill_rect(0.0F, 0.0F, @canvas.f32(width), @canvas.f32(height))
  canvas.set_drawn()
  let view : @cad.Rect = {
    min: { x: 0.0, y: 0.0 },
    max: { x: width, y: height },
    ok: true,
  }
  let plotter = @cad.Plotter::new(converter.fonts, thin=0.1 * mm)
  plotter.plot(canvas, converter.drawing, matrix, view) catch {
    error => raise JwwInvalid("jww: " + error.to_string())
  }
  let hash = canvas.encode(writer, converter.fonts, converter.warnings) catch {
    error => raise JwwInvalid("jww: " + error.to_string())
  }
  let page = @cad.page(width, height, [@cad.layer("body", hash)])
  let view_json = @cad.fixed_view([page], title=title)
  let view_map = match view_json {
    Json::Object(value) => value
    _ => Map([])
  }
  if !no_text_index {
    let runs : Array[@core.IndexRun] = []
    for (text, _) in converter.drawing.texts() {
      if jww_blank(text) { continue }
      runs.push({
        a: 0,
        b: 0,
        ordinal: runs.length(),
        separator: 2,
        text,
      })
    }
    if !runs.is_empty() {
      let index_hash = writer.add_part("idx", @core.encode_text_index(runs)) catch {
        error => raise JwwInvalid("jww: " + error.to_string())
      }
      view_map["textIndex"] = Json::string(index_hash)
    }
  }
  writer.add_view(Json::object(view_map))
  let bdf = writer.write_single() catch {
    error => raise JwwInvalid("jww: " + error.to_string())
  }
  {
    bdf,
    pages: 1,
    summary: "1 page (\{area.w().round().to_int()} × \{area.h().round().to_int()} mm), 0 embedded font(s)",
    warnings: converter.warnings.copy(),
  }
}
