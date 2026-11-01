///|
/// A point or a vector in drawing coordinates.
pub(all) struct Point {
  x : Double
  y : Double
} derive(Eq, Debug)

///|
pub fn Point::new(x : Double, y : Double) -> Point {
  { x, y }
}

///|
pub fn Point::add(self : Point, other : Point) -> Point {
  { x: self.x + other.x, y: self.y + other.y }
}

///|
pub fn Point::sub(self : Point, other : Point) -> Point {
  { x: self.x - other.x, y: self.y - other.y }
}

///|
pub fn Point::mul(self : Point, scale : Double) -> Point {
  { x: self.x * scale, y: self.y * scale }
}

///|
pub fn Point::length(self : Point) -> Double {
  @math.hypot(self.x, self.y)
}

///|
pub fn apply(matrix : @canvas.Matrix, point : Point) -> Point {
  let (x, y) = matrix.apply(point.x, point.y)
  { x, y }
}

///|
pub const MOVE_TO : Byte = 0

///|
pub const LINE_TO : Byte = 1

///|
pub const CUBIC_TO : Byte = 3

///|
pub const CLOSE_PATH : Byte = 4

///|
/// A path in drawing coordinates. Curves are cubic Bézier curves: arcs and
/// ellipses are converted when they are added, so that a path keeps its
/// shape under any affine transform.
pub(all) struct CadPath {
  mut verbs : Array[Byte]
  mut points : Array[Point]
  mut current : Point
  mut start : Point
  mut open : Bool
}

///|
pub fn CadPath::new() -> CadPath {
  {
    verbs: [],
    points: [],
    current: { x: 0.0, y: 0.0 },
    start: { x: 0.0, y: 0.0 },
    open: false,
  }
}

///|
pub fn CadPath::is_empty(self : CadPath) -> Bool {
  self.verbs.is_empty()
}

///|
/// The number of points of the path, control points included.
pub fn CadPath::size(self : CadPath) -> Int {
  self.points.length()
}

///|
pub fn CadPath::current(self : CadPath) -> Point {
  self.current
}

///|
pub fn CadPath::move_to(self : CadPath, x : Double, y : Double) -> Unit {
  self.verbs.push(MOVE_TO)
  self.points.push({ x, y })
  self.current = { x, y }
  self.start = { x, y }
  self.open = true
}

///|
pub fn CadPath::line_to(self : CadPath, x : Double, y : Double) -> Unit {
  if !self.open {
    self.move_to(x, y)
    return
  }
  self.verbs.push(LINE_TO)
  self.points.push({ x, y })
  self.current = { x, y }
}

///|
pub fn CadPath::cubic_to(self : CadPath, c1 : Point, c2 : Point, to : Point) -> Unit {
  if !self.open {
    self.move_to(c1.x, c1.y)
  }
  self.verbs.push(CUBIC_TO)
  self.points.push(c1)
  self.points.push(c2)
  self.points.push(to)
  self.current = to
}

///|
pub fn CadPath::close(self : CadPath) -> Unit {
  if self.open {
    self.verbs.push(CLOSE_PATH)
    self.current = self.start
    self.open = false
  }
}

///|
pub fn CadPath::polyline(self : CadPath, points : Array[Point], closed : Bool) -> Unit {
  for index, point in points {
    if index == 0 {
      self.move_to(point.x, point.y)
    } else {
      self.line_to(point.x, point.y)
    }
  }
  if closed && !points.is_empty() {
    self.close()
  }
}

///|
pub fn CadPath::append(self : CadPath, other : CadPath) -> Unit {
  for verb in other.verbs {
    self.verbs.push(verb)
  }
  for point in other.points {
    self.points.push(point)
  }
  self.current = other.current
  self.start = other.start
  self.open = other.open
}

///|
pub fn CadPath::is_open(self : CadPath) -> Bool {
  self.open
}

///|
pub fn CadPath::first(self : CadPath) -> Point {
  if self.points.is_empty() {
    { x: 0.0, y: 0.0 }
  } else {
    self.points[0]
  }
}

///|
/// Add the segments of `other` to the open subpath: its first move becomes a
/// line from the current point.
pub fn CadPath::continue_with(self : CadPath, other : CadPath) -> Unit {
  if other.is_empty() {
    return
  }
  if !self.open {
    self.append(other)
    return
  }
  let mut point_index = 0
  for verb_index, verb in other.verbs {
    let count = if verb == CUBIC_TO { 3 } else if verb == CLOSE_PATH { 0 } else { 1 }
    let points : Array[Point] = []
    for offset in 0..<count {
      points.push(other.points[point_index + offset])
    }
    if verb_index == 0 && verb == MOVE_TO {
      if points[0].x != self.current.x || points[0].y != self.current.y {
        self.line_to(points[0].x, points[0].y)
      }
    } else {
      if verb == MOVE_TO {
        self.move_to(points[0].x, points[0].y)
      } else if verb == LINE_TO {
        self.line_to(points[0].x, points[0].y)
      } else if verb == CUBIC_TO {
        self.cubic_to(points[0], points[1], points[2])
      } else if verb == CLOSE_PATH {
        self.close()
      }
    }
    point_index += count
  }
}

///|
pub fn CadPath::transform(self : CadPath, matrix : @canvas.Matrix) -> CadPath {
  let output : CadPath = {
    verbs: self.verbs.copy(),
    points: [],
    current: apply(matrix, self.current),
    start: apply(matrix, self.start),
    open: self.open,
  }
  for point in self.points {
    output.points.push(apply(matrix, point))
  }
  output
}

///|
/// The bounding box of the path's points, control points included.
pub fn CadPath::bounds(self : CadPath) -> Rect {
  let mut bounds = Rect::empty()
  for point in self.points {
    bounds = bounds.add(point)
  }
  bounds
}

///|
/// Add a circular arc around `center` from `a0` to `a1` radians.
pub fn CadPath::arc(
  self : CadPath,
  center : Point,
  radius : Double,
  a0 : Double,
  a1 : Double,
) -> Unit {
  self.ellipse_arc(center, { x: radius, y: 0.0 }, 1.0, a0, a1)
}

///|
pub fn CadPath::circle(self : CadPath, center : Point, radius : Double) -> Unit {
  self.open = false
  self.arc(center, radius, 0.0, 2.0 * 3.141592653589793)
  self.close()
}

///|
pub fn CadPath::ellipse_arc(
  self : CadPath,
  center : Point,
  major : Point,
  ratio : Double,
  t0 : Double,
  t1 : Double,
) -> Unit {
  self.ellipse_arc_axes(
    center,
    major,
    { x: -major.y * ratio, y: major.x * ratio },
    t0,
    t1,
  )
}

///|
/// Add the arc `center + major * cos(t) + minor * sin(t)` from `t0` to `t1`.
pub fn CadPath::ellipse_arc_axes(
  self : CadPath,
  center : Point,
  major : Point,
  minor : Point,
  t0 : Double,
  t1 : Double,
) -> Unit {
  let at = fn(t : Double) -> Point {
    let sine = @math.sin(t)
    let cosine = @math.cos(t)
    {
      x: center.x + major.x * cosine + minor.x * sine,
      y: center.y + major.y * cosine + minor.y * sine,
    }
  }
  let derivative = fn(t : Double) -> Point {
    let sine = @math.sin(t)
    let cosine = @math.cos(t)
    {
      x: -major.x * sine + minor.x * cosine,
      y: -major.y * sine + minor.y * cosine,
    }
  }
  let start = at(t0)
  if self.open {
    self.line_to(start.x, start.y)
  } else {
    self.move_to(start.x, start.y)
  }
  let sweep = t1 - t0
  let mut steps = (sweep.abs() / (3.141592653589793 / 2.0)).ceil().to_int()
  if steps < 1 {
    steps = 1
  }
  if steps > 64 {
    steps = 64
  }
  let step = sweep / steps.to_double()
  let k = 4.0 / 3.0 * @math.tan(step / 4.0)
  for index in 0..<steps {
    let ta = t0 + step * index.to_double()
    let tb = t0 + step * (index + 1).to_double()
    let a = at(ta)
    let b = at(tb)
    let da = derivative(ta)
    let db = derivative(tb)
    self.cubic_to(a.add(da.mul(k)), b.sub(db.mul(k)), b)
  }
}

///|
pub fn CadPath::ellipse(
  self : CadPath,
  center : Point,
  major : Point,
  ratio : Double,
) -> Unit {
  self.open = false
  self.ellipse_arc(center, major, ratio, 0.0, 2.0 * 3.141592653589793)
  self.close()
}

///|
/// Add the DXF polyline segment from the current point to `to` as an arc
/// when `bulge` (the tangent of a quarter of the included angle) is not
/// zero.
pub fn CadPath::bulge_to(self : CadPath, to : Point, bulge : Double) -> Unit {
  let from = self.current
  if bulge == 0.0 || (from.x == to.x && from.y == to.y) {
    self.line_to(to.x, to.y)
    return
  }
  let (center, radius, a0, a1) = bulge_arc(from, to, bulge)
  if radius == 0.0 || radius.is_nan() || radius.is_inf() {
    self.line_to(to.x, to.y)
    return
  }
  self.arc(center, radius, a0, a1)
}

///|
/// The circle of a polyline segment from `a` to `b` with a bulge, and the
/// start and end angles.
pub fn bulge_arc(
  a : Point,
  b : Point,
  bulge : Double,
) -> (Point, Double, Double, Double) {
  let theta = 4.0 * @math.atan(bulge)
  let chord = b.sub(a)
  let length = chord.length()
  let mut radius = length / (2.0 * @math.sin(theta / 2.0))
  let height = radius * @math.cos(theta / 2.0)
  let middle = a.add(chord.mul(0.5))
  let normal = { x: -chord.y / length, y: chord.x / length }
  let center = middle.add(normal.mul(height))
  radius = radius.abs()
  let a0 = @math.atan2(a.y - center.y, a.x - center.x)
  let a1 = a0 + theta
  (center, radius, a0, a1)
}

///|
/// An axis-aligned rectangle; the default is empty.
pub(all) struct Rect {
  min : Point
  max : Point
  ok : Bool
} derive(Eq, Debug)

///|
pub fn Rect::empty() -> Rect {
  { min: { x: 0.0, y: 0.0 }, max: { x: 0.0, y: 0.0 }, ok: false }
}

///|
pub fn Rect::is_valid(self : Rect) -> Bool {
  self.ok
}

///|
pub fn Rect::add(self : Rect, point : Point) -> Rect {
  if point.x.is_nan() ||
    point.y.is_nan() ||
    point.x.is_inf() ||
    point.y.is_inf() {
    return self
  }
  if !self.ok {
    return { min: point, max: point, ok: true }
  }
  {
    min: { x: Double::min(self.min.x, point.x), y: Double::min(self.min.y, point.y) },
    max: { x: Double::max(self.max.x, point.x), y: Double::max(self.max.y, point.y) },
    ok: true,
  }
}

///|
pub fn Rect::union(self : Rect, other : Rect) -> Rect {
  if !other.ok {
    return self
  }
  self.add(other.min).add(other.max)
}

///|
pub fn Rect::transform(self : Rect, matrix : @canvas.Matrix) -> Rect {
  if !self.ok {
    return self
  }
  let mut output = Rect::empty()
  output = output.add(apply(matrix, self.min))
  output = output.add(apply(matrix, { x: self.max.x, y: self.min.y }))
  output = output.add(apply(matrix, self.max))
  output = output.add(apply(matrix, { x: self.min.x, y: self.max.y }))
  output
}

///|
pub fn Rect::w(self : Rect) -> Double {
  self.max.x - self.min.x
}

///|
pub fn Rect::h(self : Rect) -> Double {
  self.max.y - self.min.y
}

///|
pub fn Rect::intersect(self : Rect, other : Rect) -> Rect {
  if !self.ok || !other.ok {
    return Rect::empty()
  }
  let result : Rect = {
    min: {
      x: Double::max(self.min.x, other.min.x),
      y: Double::max(self.min.y, other.min.y),
    },
    max: {
      x: Double::min(self.max.x, other.max.x),
      y: Double::min(self.max.y, other.max.y),
    },
    ok: true,
  }
  if result.min.x > result.max.x || result.min.y > result.max.y {
    Rect::empty()
  } else {
    result
  }
}

///|
/// The mean scale factor of a transform.
pub fn scale_of(matrix : @canvas.Matrix) -> Double {
  (matrix.a * matrix.d - matrix.b * matrix.c).abs().sqrt()
}

///|
/// Flatten a path into points: lines as they are and each curve in `steps`
/// steps.
pub fn flatten(path : CadPath, steps : Int) -> Array[Point] {
  let output : Array[Point] = []
  let mut current = { x: 0.0, y: 0.0 }
  let mut point_index = 0
  for verb in path.verbs {
    if verb == MOVE_TO || verb == LINE_TO {
      current = path.points[point_index]
      output.push(current)
      point_index += 1
    } else if verb == CUBIC_TO {
      let a = path.points[point_index]
      let b = path.points[point_index + 1]
      let c = path.points[point_index + 2]
      for index in 0..<steps {
        let t = (index + 1).to_double() / steps.to_double()
        let u = 1.0 - t
        let k0 = u * u * u
        let k1 = 3.0 * u * u * t
        let k2 = 3.0 * u * t * t
        let k3 = t * t * t
        output.push({
          x: k0 * current.x + k1 * a.x + k2 * b.x + k3 * c.x,
          y: k0 * current.y + k1 * a.y + k2 * b.y + k3 * c.y,
        })
      }
      current = c
      point_index += 3
    }
  }
  output
}
