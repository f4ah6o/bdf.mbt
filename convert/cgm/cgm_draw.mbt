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
    char_expansion: 1.0,
    char_spacing: 0.0,
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
}

///|
fn CgmInterp::warn_once(self : CgmInterp, key : String, message : String) -> Unit {
  if !self.warned.contains(key) {
    self.warned[key] = true
    self.warnings.push(message)
  }
}

///|
fn cgm_color(index : Int) -> UInt32 {
  let table : Array[UInt32] = [
    0xffffffffU, 0x000000ffU, 0xff0000ffU, 0x00ff00ffU,
    0x0000ffffU, 0xffff00ffU, 0x00ffffffU, 0xff00ffffU,
  ]
  if index >= 0 && index < table.length() { table[index] } else { 0x000000ffU }
}

///|
fn CgmInterp::color(self : CgmInterp, index : Int) -> UInt32 {
  cgm_color(index)
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
  let transformed = path.transform(matrix)
  if fill && self.state.interior == 1 {
    self.drawing.fill(transformed, self.fill(), false)
  } else {
    self.drawing.stroke(transformed, self.line_pen())
  }
}

///|
fn CgmInterp::begin_picture(self : CgmInterp) -> Unit {
  let vdc_bits = self.state.vdc_bits
  let vdc_real = self.state.vdc_real
  self.state = cgm_state()
  self.state.vdc_bits = vdc_bits
  self.state.vdc_real = vdc_real
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
  let height = self.state.text_height
  if height <= 0.0 {
    return
  }
  let matrix = self.current_matrix().mul(@canvas.Matrix::translate(point.x, point.y)).mul(
    @canvas.Matrix::scale(height, height),
  )
  let spec = @cad.FontSpec::new()
  let choice = self.fonts.face(spec.family, spec.east_asian, text[0].to_int())
  let metrics = self.fonts.metrics(choice)
  let mut advance = 0.0
  for character in text {
    advance += if character.to_int() >= 0x2e80 { 1.0 } else { 0.5 }
  }
  self.drawing.text(@cad.CadText::new(
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
      self.state.background = ((r << 24) | (g << 16) | (b << 8) | 255).to_uint()
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
      let value = params.real()
      if value > 0.0 { self.state.text_height = value }
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
      ignore(params.i16())
      let text = cgm_decode_text(params.string())
      let _ = text
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
