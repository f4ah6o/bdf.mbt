///|
fn hpgl_apply(matrix : @canvas.Matrix, point : @cad.Point) -> @cad.Point {
  @cad.apply(matrix, point)
}

///|
fn hpgl_linear(matrix : @canvas.Matrix, point : @cad.Point) -> @cad.Point {
  {
    x: matrix.a * point.x + matrix.c * point.y,
    y: matrix.b * point.x + matrix.d * point.y,
  }
}

///|
fn hpgl_invert(matrix : @canvas.Matrix) -> @canvas.Matrix {
  let det = matrix.a * matrix.d - matrix.b * matrix.c
  if det == 0.0 || det.is_nan() || det.is_inf() {
    return @canvas.Matrix::identity()
  }
  let a = matrix.d / det
  let b = -matrix.b / det
  let c = -matrix.c / det
  let d = matrix.a / det
  {
    a,
    b,
    c,
    d,
    e: -(a * matrix.e + c * matrix.f),
    f: -(b * matrix.e + d * matrix.f),
  }
}

///|
fn hpgl_sign(value : Double) -> Double {
  if value < 0.0 { -1.0 } else { 1.0 }
}

///|
fn hpgl_valid(values : Array[Double]) -> Bool {
  for value in values {
    if value.is_nan() || value.is_inf() || value.abs() > 1.0e12 {
      return false
    }
  }
  true
}

///|
fn HpglGl::size(self : HpglGl) -> (Double, Double) {
  if self.rot == 90 || self.rot == 270 {
    (self.hard_h, self.hard_w)
  } else {
    (self.hard_w, self.hard_h)
  }
}

///|
fn HpglGl::rotation(self : HpglGl) -> @canvas.Matrix {
  match self.rot {
    90 =>
      { a: 0.0, b: 1.0, c: -1.0, d: 0.0, e: self.hard_w, f: 0.0 }
    180 =>
      { a: -1.0, b: 0.0, c: 0.0, d: -1.0, e: self.hard_w, f: self.hard_h }
    270 =>
      { a: 0.0, b: -1.0, c: 1.0, d: 0.0, e: 0.0, f: self.hard_h }
    _ => @canvas.Matrix::identity()
  }
}

///|
fn HpglGl::default_p1_p2(self : HpglGl) -> Unit {
  let (width, height) = self.size()
  self.p1 = { x: 0.0, y: 0.0 }
  self.p2 = { x: width, y: height }
}

///|
fn HpglGl::scale_matrix(self : HpglGl) -> @canvas.Matrix {
  if !self.scale_set || self.scale_values.length() < 4 {
    return @canvas.Matrix::identity()
  }
  let xmin = self.scale_values[0]
  let xmax = self.scale_values[1]
  let ymin = self.scale_values[2]
  let ymax = self.scale_values[3]
  let left = if self.scale_values.length() >= 6 { self.scale_values[4] } else { 50.0 }
  let bottom = if self.scale_values.length() >= 6 { self.scale_values[5] } else { 50.0 }
  match self.scale_typ {
    2 => {
      if xmax == 0.0 || ymax == 0.0 {
        return @canvas.Matrix::identity()
      }
      {
        a: xmax,
        b: 0.0,
        c: 0.0,
        d: ymax,
        e: self.p1.x - xmin * xmax,
        f: self.p1.y - ymin * ymax,
      }
    }
    1 => {
      let uw = xmax - xmin
      let uh = ymax - ymin
      let w = self.p2.x - self.p1.x
      let h = self.p2.y - self.p1.y
      if uw == 0.0 || uh == 0.0 || w == 0.0 || h == 0.0 {
        return @canvas.Matrix::identity()
      }
      let k = Double::min((w / uw).abs(), (h / uh).abs())
      let sx = k * hpgl_sign(w) * hpgl_sign(uw)
      let sy = k * hpgl_sign(h) * hpgl_sign(uh)
      let ex = w.abs() - k * uw.abs()
      let ey = h.abs() - k * uh.abs()
      let lx = Double::min(self.p1.x, self.p2.x) + ex * left / 100.0
      let ly = Double::min(self.p1.y, self.p2.y) + ey * bottom / 100.0
      let tx = lx - Double::min(0.0, sx * uw) - sx * xmin
      let ty = ly - Double::min(0.0, sy * uh) - sy * ymin
      { a: sx, b: 0.0, c: 0.0, d: sy, e: tx, f: ty }
    }
    _ => {
      let uw = xmax - xmin
      let uh = ymax - ymin
      if uw == 0.0 || uh == 0.0 {
        return @canvas.Matrix::identity()
      }
      let sx = (self.p2.x - self.p1.x) / uw
      let sy = (self.p2.y - self.p1.y) / uh
      {
        a: sx,
        b: 0.0,
        c: 0.0,
        d: sy,
        e: self.p1.x - xmin * sx,
        f: self.p1.y - ymin * sy,
      }
    }
  }
}

///|
fn HpglGl::update(self : HpglGl) -> Unit {
  self.dev = self.rotation()
  let scale = self.scale_matrix()
  self.um = self.dev.mul(scale)
  self.inv = hpgl_invert(self.um)
  self.pens.cached = None
}

///|
fn HpglGl::initialize(self : HpglGl) -> Unit {
  self.defaults()
  self.rot = 0
  self.down = false
  self.pens.defaults()
  self.default_p1_p2()
  self.update()
  self.pos = hpgl_apply(self.dev, { x: 0.0, y: 0.0 })
  self.cr_point = self.pos
  self.merge = false
  self.ticks = (0.5, 0.5)
}

///|
fn HpglGl::defaults(self : HpglGl) -> Unit {
  self.flush()
  self.close_window()
  self.window = None
  self.anchored = false
  self.relative = false
  self.scale_set = false
  self.scale_values = []
  self.chord = 0
  self.symbol = None
  self.in_poly = false
  self.polygon = HpglPolygon::new()
  self.line.defaults()
  self.fill.defaults()
  self.label.defaults()
  self.pens.default_colors()
  self.update()
  self.cr_point = self.pos
}

///|
fn HpglGl::page_advanced(self : HpglGl) -> Unit {
  self.pos = hpgl_apply(self.dev, { x: 0.0, y: 0.0 })
  self.cr_point = self.pos
  self.down = false
  self.stroke = HpglStroke::new()
}

///|
fn HpglGl::hard_rect(self : HpglGl) -> @cad.Rect {
  let rect : @cad.Rect = {
    min: { x: 0.0, y: 0.0 },
    max: { x: self.hard_w, y: self.hard_h },
    ok: true,
  }
  rect.transform(self.dev)
}

///|
fn HpglGl::scale_of(self : HpglGl) -> Double {
  @cad.scale_of(self.dev)
}

///|
fn HpglGl::diagonal(self : HpglGl) -> Double {
  self.p2.sub(self.p1).length()
}

///|
fn HpglGl::user(self : HpglGl) -> @cad.Point {
  hpgl_apply(self.inv, self.pos)
}

///|
fn HpglGl::pen_color_of(self : HpglGl, pen : Int) -> UInt32 {
  let index = self.pens.index(pen)
  let color = self.pens.colors[index]
  if self.mono {
    if index == 0 {
      hpgl_rgb(255, 255, 255)
    } else {
      hpgl_rgb(0, 0, 0)
    }
  } else {
    color
  }
}

///|
fn HpglGl::width_of(self : HpglGl, pen : Int) -> Double {
  let width = self.pens.widths[self.pens.index(pen)]
  if self.pens.relative {
    width / 100.0 * self.diagonal() * self.scale_of()
  } else {
    width * 40.0 * self.scale_of()
  }
}

///|
fn HpglGl::pattern_length(self : HpglGl, absolute : Bool, length : Double) -> Double {
  if absolute {
    length * 40.0 * self.scale_of()
  } else {
    length / 100.0 * self.diagonal() * self.scale_of()
  }
}

///|
fn HpglGl::dash_elements(self : HpglGl) -> Array[Double]? {
  if !self.line.set || self.line.typ <= 0 {
    return None
  }
  let mut typ = self.line.typ
  if typ < 0 {
    typ = -typ
  }
  let pattern = self.line.pattern(typ)
  let length = self.pattern_length(self.line.absolute, self.line.length)
  if length <= 0.0 {
    return None
  }
  match pattern {
    Some(values) => {
      let elements : Array[Double] = []
      for index, value in values {
        let scaled = value / 100.0 * length
        elements.push(if index % 2 == 1 { -scaled } else { scaled })
      }
      Some(elements)
    }
    None => None
  }
}

///|
fn HpglGl::pen(self : HpglGl) -> @cad.Pen {
  match self.pens.cached {
    Some(pen) => return pen
    None => ()
  }
  let index = self.pens.current()
  let pen = @cad.Pen::new(
    color=self.pen_color_of(index),
    width=0.0,
    world_width=self.width_of(index),
    cap=self.line.cap,
    join=self.line.join,
    miter=self.line.miter,
  )
  match self.dash_elements() {
    Some(elements) => {
      let (dash, offset) = @cad.dash_pattern(Some(elements))
      pen.dash = dash
      pen.dash_offset = offset
    }
    None => ()
  }
  self.pens.cached = Some(pen)
  pen
}

///|
fn HpglGl::same_pen(left : @cad.Pen, right : @cad.Pen) -> Bool {
  if left.color != right.color ||
    left.world_width != right.world_width ||
    left.cap != right.cap ||
    left.join != right.join ||
    left.miter != right.miter ||
    left.dash_offset != right.dash_offset {
    return false
  }
  match (left.dash, right.dash) {
    (None, None) => true
    (Some(a), Some(b)) => {
      if a.length() != b.length() {
        return false
      }
      for index, value in a {
        if value != b[index] {
          return false
        }
      }
      true
    }
    _ => false
  }
}

///|
fn HpglGl::flush(self : HpglGl) -> Unit {
  match self.stroke.path {
    Some(path) => {
      if !path.is_empty() {
        match self.stroke.pen {
          Some(pen) => self.draw_stroke(path, pen)
          None => ()
        }
      }
    }
    None => ()
  }
  self.stroke.path = None
  self.stroke.pen = None
}

///|
fn HpglGl::draw_stroke(self : HpglGl, path : @cad.CadPath, pen : @cad.Pen) -> Unit {
  if !self.budget() {
    return
  }
  self.drawing.stroke(path, pen)
}

fn HpglGl::c_budget_ref(self : HpglGl) -> Bool {
  self.budget()
}

fn HpglGl::c_drawing_mut(self : HpglGl) -> @cad.Drawing {
  self.drawing
}

///|
fn HpglGl::stroke_path(self : HpglGl, path : @cad.CadPath, vertices : Array[@cad.Point]) -> Unit {
  if self.line.set && self.line.typ == 0 {
    for point in vertices {
      self.dot(point)
    }
    return
  }
  if self.line.set && self.line.typ < 0 {
    // Adaptive line types are drawn with their fixed pattern.
    self.warn_adaptive()
  }
  let pen = self.pen()
  match self.stroke.path {
    Some(current) => {
      match self.stroke.pen {
        Some(old) =>
          if !HpglGl::same_pen(old, pen) {
            self.flush()
          }
        None => ()
      }
    }
    None => ()
  }
  match self.stroke.path {
    None => {
      self.stroke.path = Some(path)
      self.stroke.pen = Some(pen)
    }
    Some(current) => {
      if current.is_open() &&
        current.current().x == path.first().x &&
        current.current().y == path.first().y {
        current.continue_with(path)
      } else {
        current.append(path)
      }
    }
  }
  match self.stroke.path {
    Some(current) =>
      if current.size() > 20000 {
        self.flush()
      }
    None => ()
  }
}

///|
fn HpglGl::warn_adaptive(self : HpglGl) -> Unit {
  self.warn_once(
    "adaptive",
    "adaptive line types are drawn with a fixed pattern",
  )
}

///|
fn HpglGl::dot(self : HpglGl, point : @cad.Point) -> Unit {
  self.flush()
  let pen = self.pen()
  pen.dash = None
  pen.cap = @cad.CAP_ROUND
  let delta = 0.01 * self.scale_of()
  let path = @cad.CadPath::new()
  path.move_to(point.x, point.y)
  path.line_to(point.x + delta, point.y)
  self.stroke_path(path, [point])
}

///|
fn HpglGl::plot(self : HpglGl, values : Array[Double]) -> Unit {
  let mut index = 0
  while index + 1 < values.length() {
    if !hpgl_valid([values[index], values[index + 1]]) {
      index += 2
      continue
    }
    let point : @cad.Point = if self.relative {
      self.pos.add(
        hpgl_linear(self.um, { x: values[index], y: values[index + 1] }),
      )
    } else {
      hpgl_apply(self.um, { x: values[index], y: values[index + 1] })
    }
    self.line_to(point)
    index += 2
  }
  if values.length() >= 2 {
    self.cr_point = self.pos
  }
}

///|
fn HpglGl::line_to(self : HpglGl, point : @cad.Point) -> Unit {
  if point.x == self.pos.x && point.y == self.pos.y && self.down && !self.in_poly {
    self.stroke.pending_dot = false
    self.dot(point)
    return
  }
  let path = @cad.CadPath::new()
  path.move_to(self.pos.x, self.pos.y)
  path.line_to(point.x, point.y)
  self.add_path(path, self.down, [point])
  self.pos = point
}

///|
fn HpglGl::add_path(
  self : HpglGl,
  path : @cad.CadPath,
  down : Bool,
  vertices : Array[@cad.Point],
) -> Unit {
  if self.in_poly {
    self.polygon_add(path, down)
    return
  }
  if !down {
    return
  }
  self.stroke.pending_dot = false
  self.stroke_path(path, vertices)
}

///|
fn HpglGl::add_user_path(self : HpglGl, path : @cad.CadPath) -> Unit {
  let drawing_path = path.transform(self.um)
  let end = drawing_path.current()
  self.add_path(drawing_path, self.down, [end])
  self.pos = end
}

///|
fn HpglGl::arc_path(
  self : HpglGl,
  center : @cad.Point,
  radius : Double,
  a0 : Double,
  a1 : Double,
  chord : Double,
  explicit : Bool,
) -> @cad.CadPath {
  let path = @cad.CadPath::new()
  let mut steps = 0
  if explicit && self.chord == 0 {
    let mut ca = chord % 360.0
    if ca > 180.0 {
      ca = 360.0 - ca
    }
    if ca > 5.0 + 1.0e-9 {
      steps = ((a1 - a0).abs() * 180.0 / 3.141592653589793 / ca - 1.0e-9).ceil().to_int()
    }
  }
  if steps >= 1 && steps <= 3600 {
    let count = steps + 1
    for index in 0..<count {
      let t = a0 + (a1 - a0) * index.to_double() / steps.to_double()
      let point : @cad.Point = {
        x: center.x + radius * @math.cos(t),
        y: center.y + radius * @math.sin(t),
      }
      if index == 0 {
        path.move_to(point.x, point.y)
      } else {
        path.line_to(point.x, point.y)
      }
    }
  } else {
    path.arc(center, radius, a0, a1)
  }
  path
}

///|
fn HpglGl::chord_param(self : HpglGl, values : Array[Double], index : Int) -> (Double, Bool) {
  if index < values.length() {
    (values[index].abs(), true)
  } else {
    (5.0, false)
  }
}

///|
fn HpglGl::polygon_start(self : HpglGl, at : @cad.Point) -> Unit {
  self.polygon = {
    fill: Some(@cad.CadPath::new()),
    sub: Some(@cad.CadPath::new()),
    edges: Some(@cad.CadPath::new()),
    saved_pos: self.pos,
    saved_down: self.down,
  }
  match self.polygon.sub {
    Some(sub) => sub.move_to(at.x, at.y)
    None => ()
  }
  self.in_poly = true
}

///|
fn HpglGl::polygon_add(self : HpglGl, path : @cad.CadPath, down : Bool) -> Unit {
  if self.polygon.fill is None {
    self.polygon_start(path.first())
  }
  let is_move = self.polygon.sub is None && path.size() == 2
  if is_move {
    let end = path.current()
    let sub = @cad.CadPath::new()
    sub.move_to(end.x, end.y)
    self.polygon.sub = Some(sub)
  } else if self.polygon.sub is None {
    let sub = @cad.CadPath::new()
    sub.append(path)
    self.polygon.sub = Some(sub)
  } else {
    match self.polygon.sub {
      Some(sub) => sub.continue_with(path)
      None => ()
    }
  }
  if down && !is_move {
    match self.polygon.edges {
      Some(edges) =>
        if edges.is_open() &&
          edges.current().x == path.first().x &&
          edges.current().y == path.first().y {
          edges.continue_with(path)
        } else {
          edges.append(path)
        }
      None => ()
    }
  }
}

///|
fn HpglGl::polygon_close(self : HpglGl, down : Bool) -> Unit {
  if self.polygon.fill is None {
    return
  }
  match self.polygon.sub {
    Some(sub) => {
      if sub.size() >= 2 {
        let first = sub.first()
        let last = sub.current()
        if (first.x != last.x || first.y != last.y) && down {
          match self.polygon.edges {
            Some(edges) => {
              let closing = @cad.CadPath::new()
              closing.move_to(last.x, last.y)
              closing.line_to(first.x, first.y)
              edges.continue_with(closing)
            }
            None => ()
          }
        }
        sub.close()
        match self.polygon.fill {
          Some(fill) => fill.append(sub)
          None => ()
        }
      }
      self.polygon.sub = None
    }
    None => ()
  }
}

///|
fn HpglGl::polygon_transform(self : HpglGl, matrix : @canvas.Matrix) -> Unit {
  match self.polygon.fill {
    Some(path) => self.polygon.fill = Some(path.transform(matrix))
    None => ()
  }
  match self.polygon.sub {
    Some(path) => self.polygon.sub = Some(path.transform(matrix))
    None => ()
  }
  match self.polygon.edges {
    Some(path) => self.polygon.edges = Some(path.transform(matrix))
    None => ()
  }
}

///|
fn HpglGl::shaded(self : HpglGl, color : UInt32, level : Double, transparent : Bool) -> UInt32 {
  let k = Double::max(0.0, Double::min(1.0, level / 100.0))
  if transparent {
    let alpha = (255.0 * k).round().to_int()
    (color & 0xffffff00U) | (alpha & 255).reinterpret_as_uint()
  } else {
    let mix = fn(value : UInt32) -> UInt32 {
      ((value.to_double() * k + 255.0 * (1.0 - k)).round().to_int() & 255).reinterpret_as_uint()
    }
    (mix(color >> 24) << 24) |
    (mix((color >> 16) & 255U) << 16) |
    (mix((color >> 8) & 255U) << 8) |
    0xffU
  }
}

///|
fn HpglGl::anchor_point(self : HpglGl) -> @cad.Point {
  if self.anchored {
    self.anchor
  } else {
    hpgl_apply(self.dev, { x: 0.0, y: 0.0 })
  }
}

///|
fn HpglGl::user_scale_x(self : HpglGl) -> Double {
  if !self.scale_set {
    return 1.0
  }
  self.scale_matrix().a
}

///|
fn HpglGl::hatch_path(self : HpglGl, path : @cad.CadPath, typ : Int) -> Unit {
  let mut spacing = self.fill.spacing[typ] * self.scale_of()
  if spacing <= 0.0 {
    spacing = 0.01 * self.diagonal() * self.scale_of()
  }
  if spacing <= 0.0 {
    return
  }
  let angles : Array[Double] = [self.fill.angle[typ]]
  if typ == 4 {
    angles.push(self.fill.angle[typ] + 90.0)
  }
  let pen = self.pen()
  pen.dash = None
  pen.dash_offset = 0.0
  let elements = self.dash_elements()
  let mut pattern_length = 0.0
  match elements {
    Some(values) => {
      for value in values {
        pattern_length += value.abs()
      }
    }
    None => ()
  }
  let anchor = self.anchor_point()
  let lines : Array[@cad.PatternLine] = []
  for angle in angles {
    let radians = angle * 3.141592653589793 / 180.0
    let direction = hpgl_linear(
      self.dev,
      { x: @math.cos(radians), y: @math.sin(radians) },
    )
    let theta = @math.atan2(direction.y, direction.x)
    let u : @cad.Point = { x: @math.cos(theta), y: @math.sin(theta) }
    let normal : @cad.Point = { x: -u.y, y: u.x }
    match elements {
      Some(values) => {
        lines.push({
          angle: theta,
          base: anchor,
          offset: normal.mul(2.0 * spacing),
          dash: Some(values),
        })
        lines.push({
          angle: theta,
          base: anchor.add(normal.mul(spacing)).add(u.mul(pattern_length / 2.0)),
          offset: normal.mul(2.0 * spacing),
          dash: Some(values),
        })
      }
      None =>
        lines.push({
          angle: theta,
          base: anchor,
          offset: normal.mul(spacing),
          dash: None,
        })
    }
  }
  if !self.drawing.hatch(path, lines, pen) {
    self.warn_once(
      "hatch",
      "hatching too fine to draw is filled in a lighter color",
    )
    self.drawing.fill(
      path,
      @cad.Fill::solid(self.shaded(pen.color, 30.0, true)),
      true,
    )
  }
}

///|
fn HpglGl::fill_path(self : HpglGl, path : @cad.CadPath, even_odd : Bool) -> Unit {
  if path.is_empty() || !self.c_budget_ref() {
    return
  }
  let color = self.pen_color_of(self.pens.current())
  match self.fill.typ {
    3 | 4 => self.hatch_path(path, self.fill.typ)
    10 =>
      self.drawing.fill(
        path,
        @cad.Fill::solid(self.shaded(color, self.fill.shade, self.fill.transparent)),
        even_odd,
      )
    11 => {
      // Raster fill patterns are drawn as a solid fill.
      self.drawing.fill(path, @cad.Fill::solid(color), even_odd)
    }
    21 => self.hatch_path(path, 4)
    _ => self.drawing.fill(path, @cad.Fill::solid(color), even_odd)
  }
}

///|
fn HpglGl::close_window(self : HpglGl) -> Unit {
  match self.window {
    Some(window) =>
      if window.open {
        self.flush()
        self.c_drawing_end()
        window.open = false
      }
    None => ()
  }
}

///|
fn HpglGl::input_window(self : HpglGl, values : Array[Double]) -> Unit {
  self.flush()
  self.close_window()
  self.window = None
  if values.length() >= 4 && hpgl_valid(values) {
    let x0 = Double::min(values[0], values[2])
    let x1 = Double::max(values[0], values[2])
    let y0 = Double::min(values[1], values[3])
    let y1 = Double::max(values[1], values[3])
    let path = @cad.CadPath::new()
    path.move_to(x0, y0)
    path.line_to(x1, y0)
    path.line_to(x1, y1)
    path.line_to(x0, y1)
    path.close()
    self.window = Some({ path: path.transform(self.um), open: false })
  }
  self.open_window()
}

// The page drawing accessors are replaced by the converter through the
// fields below; they keep the state methods testable on their own.
fn HpglGl::c_drawing_begin(self : HpglGl, clip : @cad.CadPath?) -> Unit {
  self.drawing.begin(clip)
}

fn HpglGl::c_drawing_end(self : HpglGl) -> Unit {
  self.drawing.end()
}
