///|
priv struct CgmState {
  mut vdc_real : Bool
  mut vdc_bits : Int
  mut scaling : Int
  mut metric : Double
  mut extent : @cad.Rect
  mut extent_set : Bool
  mut background : UInt32
  mut line_color : Int
  mut line_type : Int
  mut line_width : Double
  mut fill_color : Int
  mut interior : Int
  mut text_color : Int
  mut text_height : Double
  mut text_font : Int
  mut text_align_h : Int
  mut text_align_v : Int
  mut text_path : Int
  mut char_expansion : Double
  mut char_spacing : Double
  mut char_height : Double
  mut color_precision : Int
  mut color_mode : Int
  mut color_table : Array[UInt32]
  mut edge_visible : Bool
  mut fill_visible : Bool
}

///|
fn cgm_state() -> CgmState {
  {
    vdc_real: false,
    vdc_bits: 16,
    scaling: 0,
    metric: 0.0,
    extent: @cad.Rect::empty(),
    extent_set: false,
    background: 0xffffffffU,
    line_color: 1,
    line_type: 1,
    line_width: 0.25,
    fill_color: 1,
    interior: 0,
    text_color: 1,
    text_height: 5.0,
    text_font: 0,
    text_align_h: 0,
    text_align_v: 0,
    text_path: 0,
    char_height: 0.0,
    char_expansion: 1.0,
    char_spacing: 0.0,
    color_precision: 8,
    color_mode: 1,
    color_table: cgm_default_colors(),
    edge_visible: true,
    fill_visible: true,
  }
}

///|
priv struct CgmPicture {
  number : Int
  drawing : @cad.Drawing
  mut width : Double
  mut height : Double
  mut matrix : @canvas.Matrix
  mut background : UInt32
}

///|
priv struct CgmInterp {
  mut state : CgmState
  pictures : Array[CgmPicture]
  mut current : CgmPicture?
  mut drawing : @cad.Drawing
  fonts : @canvas.Fonts
  warnings : Array[String]
  warned : Map[String, Bool]
  unknown : Map[String, Int]
  mut last_text : @cad.CadText?
}

///|
fn CgmInterp::warn_once(self : CgmInterp, key : String, message : String) -> Unit {
  if !self.warned.contains(key) {
    self.warned[key] = true
    self.warnings.push(message)
  }
}

///|
/// The CGM default colour table: eight direct RGB entries.
fn cgm_default_colors() -> Array[UInt32] {
  [
    0xffffffffU, 0x000000ffU, 0xff0000ffU, 0x00ff00ffU,
    0x0000ffffU, 0xffff00ffU, 0x00ffffffU, 0xff00ffffU,
  ]
}

///|
fn CgmInterp::color(self : CgmInterp, index : Int) -> UInt32 {
  let table = self.state.color_table
  if index >= 0 && index < table.length() {
    table[index]
  } else if index >= 0 && index < 256 {
    // A colour index past the table is the direct RGB value.
    cgm_direct_color(index, 8)
  } else {
    0x000000ffU
  }
}

///|
/// A direct (mode 2) colour value as RGBA: the low `precision` bits are blue,
/// the next `precision` bits green and the next `precision` bits red.
fn cgm_direct_color(value : Int, precision : Int) -> UInt32 {
  let bits = if precision <= 0 || precision > 8 { 8 } else { precision }
  let mask = (1 << bits) - 1
  let scale = value => {
    let v = value & mask
    (v * 255 + mask / 2) / mask
  }
  let blue = scale(value)
  let green = scale(value >> bits)
  let red = scale(value >> (bits * 2))
  ((red << 24) | (green << 16) | (blue << 8) | 255).reinterpret_as_uint()
}

///|
/// Decode one colour table entry (direct or indexed) into RGBA.
fn CgmInterp::color_entry(self : CgmInterp, direct : Bool, value : Int) -> UInt32 {
  if direct || self.state.color_mode == 2 {
    cgm_direct_color(value, self.state.color_precision)
  } else {
    self.color(value)
  }
}

///|
/// Read a COLOUR TABLE. Upstream writes the entries as bare values (direct
/// RGB when the colour mode is direct, otherwise an index); some writers
/// prefix every entry with a direct flag. The first entry decides which.
fn CgmInterp::read_color_table(self : CgmInterp, params : CgmParams) -> Array[UInt32] {
  let values : Array[Int] = []
  while params.more() {
    values.push(params.u16_value())
  }
  let flagged = values.length() % 2 == 0 &&
    values.length() > 0 &&
    (values[0] == 0 || values[0] == 1) &&
    values.length() / 2 >= 2
  let entries : Array[UInt32] = []
  if flagged {
    let mut index = 0
    while index + 1 < values.length() {
      entries.push(self.color_entry(values[index] == 1, values[index + 1]))
      index += 2
    }
  } else {
    for value in values {
      entries.push(self.color_entry(self.state.color_mode == 2, value))
    }
  }
  entries
}

///|
fn CgmInterp::line_pen(self : CgmInterp) -> @cad.Pen {
  let pen = @cad.Pen::new(
    color=self.color(self.state.line_color),
    width=self.state.line_width * 72.0 / 25.4,
    cap=@cad.CAP_ROUND,
    join=@cad.JOIN_ROUND,
  )
  let dash = cgm_dash(self.state.line_type, self.state.line_width)
  let (values, offset) = @cad.dash_pattern(Some(dash))
  pen.dash = values
  pen.dash_offset = offset
  pen
}

///|
fn cgm_dash(kind : Int, width : Double) -> Array[Double] {
  let scale = Double::max(width, 0.13) / 0.5
  let base = match kind {
    2 => [0.5, 0.25]
    3 => [0.5, 0.25, 0.05, 0.25]
    4 => [0.5, 0.25, 0.05, 0.25, 0.05, 0.25]
    5 => [0.05, 0.25]
    6 => [0.5, 0.25, 0.15, 0.25]
    _ => []
  }
  let output : Array[Double] = []
  for value in base {
    output.push(value * scale)
  }
  output
}

///|
fn CgmInterp::fill(self : CgmInterp) -> @cad.Fill {
  @cad.Fill::solid(self.color(self.state.fill_color))
}

///|
fn cgm_points(params : CgmParams) -> Array[@cad.Point] {
  let output : Array[@cad.Point] = []
  while params.more() {
    output.push(params.point())
  }
  output
}

///|
fn CgmInterp::paint(self : CgmInterp, path : @cad.CadPath, matrix : @canvas.Matrix, fill : Bool) -> Unit {
  if path.is_empty() {
    return
  }
  let transformed = path.transform(matrix)
  // FILL VISIBILITY hides the interior of a primitive; EDGE VISIBILITY hides
  // its outline. A filled primitive only draws its outline when the edge is
  // visible.
  if fill && self.state.interior == 1 {
    if self.state.fill_visible {
      self.drawing.fill(transformed, self.fill(), false)
    }
    if self.state.edge_visible {
      self.drawing.stroke(transformed, self.line_pen())
    }
  } else if self.state.edge_visible {
    self.drawing.stroke(transformed, self.line_pen())
  }
}

///|
fn CgmInterp::begin_picture(self : CgmInterp) -> Unit {
  let vdc_bits = self.state.vdc_bits
  let vdc_real = self.state.vdc_real
  // The colour table and the colour precision are metafile defaults, not
  // picture defaults, so a picture keeps them.
  let color_table = self.state.color_table
  let color_precision = self.state.color_precision
  let color_mode = self.state.color_mode
  self.state = cgm_state()
  self.state.vdc_bits = vdc_bits
  self.state.vdc_real = vdc_real
  self.state.color_table = color_table
  self.state.color_precision = color_precision
  self.state.color_mode = color_mode
  let picture : CgmPicture = {
    number: self.pictures.length() + 1,
    drawing: @cad.Drawing::new(),
    width: 0.0,
    height: 0.0,
    matrix: @canvas.Matrix::identity(),
    background: 0xffffffffU,
  }
  self.current = Some(picture)
  self.drawing = picture.drawing
}

///|
fn CgmInterp::begin_body(self : CgmInterp) -> Unit {
  let picture = match self.current {
    Some(value) => value
    None => return
  }
  let ext = if self.state.extent_set {
    self.state.extent
  } else {
    @cad.Rect::empty().add({ x: 0.0, y: 0.0 }).add({ x: 32767.0, y: 32767.0 })
  }
  let dx = ext.max.x - ext.min.x
  let dy = ext.max.y - ext.min.y
  let adx = if dx == 0.0 { 1.0 } else { dx.abs() }
  let ady = if dy == 0.0 { 1.0 } else { dy.abs() }
  let long = Double::max(adx, ady)
  let mut scale = if self.state.scaling == 1 && self.state.metric > 0.0 {
    self.state.metric
  } else {
    297.0 / long
  }
  let mut width = adx * scale
  let mut height = ady * scale
  if width < 1.0 && height < 1.0 {
    scale = 297.0 / long
    width = adx * scale
    height = ady * scale
  }
  let limit = Double::max(width, height)
  if limit > 5080.0 {
    scale *= 5080.0 / limit
    width *= 5080.0 / limit
    height *= 5080.0 / limit
  }
  let k = scale * 72.0 / 25.4
  let sx = if dx < 0.0 { -k } else { k }
  let sy = if dy < 0.0 { -k } else { k }
  let matrix : @canvas.Matrix = {
    a: sx,
    b: 0.0,
    c: 0.0,
    d: -sy,
    e: -ext.min.x * sx,
    f: height * 72.0 / 25.4 + ext.min.y * sy,
  }
  picture.width = width
  picture.height = height
  picture.matrix = matrix
  picture.background = self.state.background
  self.current = Some(picture)
}

///|
fn CgmInterp::end_picture(self : CgmInterp) -> Unit {
  match self.current {
    Some(picture) => {
      let finished = {
        number: picture.number,
        drawing: picture.drawing,
        width: picture.width,
        height: picture.height,
        matrix: picture.matrix,
        background: picture.background,
      }
      self.pictures.push(finished)
    }
    None => ()
  }
  self.current = None
}

///|
fn CgmInterp::text(self : CgmInterp, params : CgmParams, restricted : Bool) -> Unit {
  let point = params.point()
  if restricted {
    ignore(params.vdc())
    ignore(params.vdc())
  }
  ignore(params.i16())
  let text = cgm_decode_text(params.string())
  if text == "" {
    return
  }
  let spec = @cad.FontSpec::new()
  let placed = self.text_placement(text, spec, point.x, point.y)
  match placed {
    Some(placed) => {
      self.drawing.text(placed)
      self.last_text = Some(placed)
    }
    None => ()
  }
}

///|
/// The text item for `text` at VDC `x`, `y`, honouring TEXT PATH and TEXT
/// ALIGNMENT. Returns None when the text has no size.
fn CgmInterp::text_placement(
  self : CgmInterp,
  text : String,
  spec : @cad.FontSpec,
  x : Double,
  y : Double,
) -> @cad.CadText? {
  let size = self.text_size(text, spec)
  match size {
    None => None
    Some((advance, height, metrics)) => {
      // TEXT PATH: 0 right, 1 left, 2 up, 3 down (degrees clockwise in the
      // y-down canvas space). Other values are left as right.
      let rotation = match self.state.text_path {
        1 => 180.0
        2 => 90.0
        3 => -90.0
        _ => 0.0
      }
      // TEXT ALIGNMENT: horizontal 0 left, 1 centre, 2 right, 3 normal,
      // 4 continuous; vertical 0 base, 1 bottom, 2 centre, 3 top, 4 cap,
      // 5 half-cap. The origin moves so the text lands on the given point.
      let dx = match self.state.text_align_h {
        1 => -advance / 2.0
        2 => -advance
        4 => -advance
        _ => 0.0
      }
      let dy = match self.state.text_align_v {
        1 => -metrics.desc
        2 => (metrics.asc - metrics.desc) / 2.0
        3 => metrics.asc
        4 => metrics.cap
        5 => metrics.cap / 2.0
        _ => 0.0
      }
      let matrix = self.current_matrix().mul(@canvas.Matrix::translate(x, y)).mul(
        @canvas.Matrix::rotate(rotation),
      ).mul(@canvas.Matrix::translate(dx, dy)).mul(
        @canvas.Matrix::scale(height, height),
      )
      Some(@cad.CadText::new(
        text,
        matrix,
        font=spec,
        color=self.color(self.state.text_color),
        advance=advance,
        asc=metrics.asc,
        desc=metrics.desc,
        cap=metrics.cap,
      ))
    }
  }
}

///|
/// APPEND TEXT draws a continuation of the last text at its end point.
fn CgmInterp::append_text(self : CgmInterp, text : String) -> Unit {
  if text == "" {
    return
  }
  let last = match self.last_text {
    Some(last) => last
    None => return
  }
  // The continuation starts where the previous text ended, in the previous
  // text's own space, and keeps its placement.
  let end = last.m.mul(@canvas.Matrix::translate(last.advance, 0.0))
  let (x, y) = end.apply(0.0, 0.0)
  let spec = @cad.FontSpec::new()
  let placed = self.text_placement(text, spec, x, y)
  match placed {
    Some(placed) => {
      self.drawing.text(placed)
      self.last_text = Some(placed)
    }
    None => ()
  }
}

///|
/// The advance, height and metrics of `text` in text-space units (em = 1).
/// The character height (element 5/16) sets the em when it is positive;
/// otherwise the text height does. Character expansion and spacing scale the
/// advance.
fn CgmInterp::text_size(
  self : CgmInterp,
  text : String,
  spec : @cad.FontSpec,
) -> (Double, Double, @canvas.TextMetrics)? {
  let height = if self.state.char_height > 0.0 {
    self.state.char_height
  } else {
    self.state.text_height
  }
  if height <= 0.0 {
    return None
  }
  let mut width = 0.0
  for character in text {
    let choice = self.fonts.face(spec.family, spec.east_asian, character.to_int())
    width += self.fonts.advance(choice, character.to_int()) *
      self.state.char_expansion +
      self.state.char_spacing
  }
  if width <= 0.0 {
    return None
  }
  let metrics = self.fonts.metrics(
    self.fonts.face(spec.family, spec.east_asian, text[0].to_int()),
  )
  Some((width, height, metrics))
}

///|
fn CgmInterp::current_matrix(self : CgmInterp) -> @canvas.Matrix {
  match self.current {
    Some(picture) => picture.matrix
    None => @canvas.Matrix::identity()
  }
}

///|
fn CgmInterp::element(self : CgmInterp, element : CgmElement) -> Unit {
  let params = CgmParams::new(element.data)
  params.vdc_real = self.state.vdc_real
  params.vdc_bits = self.state.vdc_bits
  match (element.class, element.id) {
    (0, 3) => self.begin_picture()
    (0, 4) => self.begin_body()
    (0, 5) => self.end_picture()
    (1, 3) => self.state.vdc_real = params.i16() == 1
    (1, 4) => ignore(params.i16())
    (1, 5) => ignore(params.i16())
    (1, 7) => ignore(params.i16())
    (2, 1) => {
      let mode = params.i16()
      self.state.scaling = mode
      if mode == 1 && params.more() {
        self.state.metric = params.real()
      }
    }
    (2, 6) => {
      let a = params.point()
      let b = params.point()
      self.state.extent = @cad.Rect::empty().add(a).add(b)
      self.state.extent_set = true
    }
    (2, 7) => {
      let r = params.u8()
      let g = params.u8()
      let b = params.u8()
      self.state.background = ((r << 24) | (g << 16) | (b << 8) | 255).reinterpret_as_uint()
    }
    (2, 3) => {
      let precision = params.i16()
      if precision > 0 && precision <= 8 {
        self.state.color_precision = precision
      }
    }
    (2, 4) => {
      let mode = params.i16()
      if mode >= 0 && mode <= 6 {
        self.state.color_mode = mode
      }
    }
    (2, 5) => {
      let colors = self.read_color_table(params)
      if !colors.is_empty() {
        self.state.color_table = colors
      }
    }
    (5, 29) => {
      let value = params.i16()
      self.state.edge_visible = value != 0
    }
    (5, 30) => {
      let value = params.i16()
      self.state.fill_visible = value != 0
    }
    (5, 34) => {
      let colors = self.read_color_table(params)
      if !colors.is_empty() {
        self.state.color_table = colors
      }

    }
    (3, 1) => {
      let bits = params.i16()
      if bits == 16 || bits == 32 {
        self.state.vdc_bits = bits
      }
    }
    (5, 2) => self.state.line_type = params.i16()
    (5, 3) => {
      let mode = params.i16()
      let value = if mode == 2 { params.real() } else { params.i16().to_double() }
      self.state.line_width = if value > 0.0 { value } else { 0.25 }
    }
    (5, 4) => self.state.line_color = params.i16()
    (5, 6) => ignore(params.i16())
    (5, 7) => ignore(params.real())
    (5, 8) => ignore(params.i16())
    (5, 10) => self.state.text_font = params.i16()
    (5, 12) => self.state.char_expansion = params.real()
    (5, 13) => self.state.char_spacing = params.real()
    (5, 14) => self.state.text_color = params.i16()
    (5, 15) => {
      // TEXT HEIGHT is a real (f32) value in VDC units.
      let value = params.real()
      if value > 0.0 { self.state.text_height = value }
    }
    (5, 16) => {
      let value = params.real()
      if value > 0.0 { self.state.char_height = value }
    }
    (5, 17) => self.state.text_path = params.i16()
    (5, 18) => {
      self.state.text_align_h = params.i16()
      self.state.text_align_v = params.i16()
    }
    (5, 22) => self.state.interior = params.i16()
    (5, 23) => self.state.fill_color = params.i16()
    (4, 1) => {
      let path = @cad.CadPath::new()
      path.polyline(cgm_points(params), false)
      self.paint(path, self.current_matrix(), false)
    }
    (4, 2) => {
      let points = cgm_points(params)
      let path = @cad.CadPath::new()
      let mut index = 0
      while index + 1 < points.length() {
        path.move_to(points[index].x, points[index].y)
        path.line_to(points[index + 1].x, points[index + 1].y)
        index += 2
      }
      self.paint(path, self.current_matrix(), false)
    }
    (4, 3) => {
      let points = cgm_points(params)
      for point in points {
        let path = @cad.CadPath::new()
        path.circle(point, self.state.text_height * 0.1)
        self.drawing.fill(path.transform(self.current_matrix()), @cad.Fill::solid(self.color(self.state.line_color)), false)
      }
    }
    (4, 4) => self.text(params, false)
    (4, 5) => self.text(params, true)
    (4, 6) => {
      // APPEND TEXT continues the previous text's origin.
      ignore(params.i16())
      let text = cgm_decode_text(params.string())
      self.append_text(text)
    }
    (4, 7) => {
      let path = @cad.CadPath::new()
      path.polyline(cgm_points(params), true)
      self.paint(path, self.current_matrix(), true)
    }
    (4, 11) => {
      let a = params.point()
      let b = params.point()
      let path = @cad.CadPath::new()
      path.polyline([
        a,
        { x: b.x, y: a.y },
        b,
        { x: a.x, y: b.y },
      ], true)
      self.paint(path, self.current_matrix(), true)
    }
    (4, 12) => {
      let center = params.point()
      let radius = params.vdc().abs()
      if radius > 0.0 {
        let path = @cad.CadPath::new()
        path.circle(center, radius)
        self.paint(path, self.current_matrix(), true)
      }
    }
    (4, 13) | (4, 14) => {
      let a = params.point()
      let b = params.point()
      let c = params.point()
      match cgm_arc3(a, b, c) {
        Some((center, radius, start, end)) => {
          let path = @cad.CadPath::new()
          path.arc(center, radius, start, end)
          self.paint(path, self.current_matrix(), false)
        }
        None => ()
      }
    }
    (4, 15) | (4, 16) | (4, 20) => {
      let center = params.point()
      let start = params.point()
      let end = params.point()
      let radius = params.vdc().abs()
      let a0 = @math.atan2(start.y, start.x)
      let mut a1 = @math.atan2(end.y, end.x)
      if a1 <= a0 { a1 += 2.0 * 3.141592653589793 }
      let path = @cad.CadPath::new()
      path.arc(center, radius, a0, a1)
      self.paint(path, self.current_matrix(), false)
    }
    (4, 17) => {
      let center = params.point()
      let d1 = params.point()
      let d2 = params.point()
      let path = @cad.CadPath::new()
      path.ellipse_arc_axes(center, d1.sub(center), d2.sub(center), 0.0, 2.0 * 3.141592653589793)
      self.paint(path, self.current_matrix(), true)
    }
    (4, 18) | (4, 19) => {
      let center = params.point()
      let d1 = params.point()
      let d2 = params.point()
      let start = params.point()
      let end = params.point()
      let path = @cad.CadPath::new()
      path.ellipse_arc_axes(
        center,
        d1.sub(center),
        d2.sub(center),
        @math.atan2(start.y, start.x),
        @math.atan2(end.y, end.x),
      )
      self.paint(path, self.current_matrix(), false)
    }
    _ => {
      let key = element.class.to_string() + "/" + element.id.to_string()
      let count = match self.unknown.get(key) {
        Some(value) => value
        None => 0
      }
      self.unknown[key] = count + 1
    }
  }
}

///|
fn cgm_arc3(
  a : @cad.Point,
  b : @cad.Point,
  c : @cad.Point,
) -> (@cad.Point, Double, Double, Double)? {
  let d = 2.0 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
  if d.abs() < 1.0e-12 {
    return None
  }
  let a2 = a.x * a.x + a.y * a.y
  let b2 = b.x * b.x + b.y * b.y
  let c2 = c.x * c.x + c.y * c.y
  let center : @cad.Point = {
    x: (a2 * (b.y - c.y) + b2 * (c.y - a.y) + c2 * (a.y - b.y)) / d,
    y: (a2 * (c.x - b.x) + b2 * (a.x - c.x) + c2 * (b.x - a.x)) / d,
  }
  let radius = a.sub(center).length()
  let a0 = @math.atan2(a.y - center.y, a.x - center.x)
  let am = @math.atan2(b.y - center.y, b.x - center.x)
  let a1 = @math.atan2(c.y - center.y, c.x - center.x)
  let mut end = a1
  if cgm_norm(am - a0) < cgm_norm(a1 - a0) {
    if end <= a0 { end += 2.0 * 3.141592653589793 }
  } else if end >= a0 {
    end -= 2.0 * 3.141592653589793
  }
  Some((center, radius, a0, end))
}

///|
fn cgm_norm(value : Double) -> Double {
  let mut result = value % (2.0 * 3.141592653589793)
  if result < 0.0 { result += 2.0 * 3.141592653589793 }
  result
}
