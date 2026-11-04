///|
// DrawingML preset geometry: guides, adjust values and path evaluation, as
// upstream drawingml/geom.go does it. The preset table itself is generated
// from the upstream presets.xml.gz (see compat/pptx/generate_presets.py).

///|
/// One command of a preset path. Coordinates and angles are guide names or
/// numbers, evaluated against the shape size.
priv enum PptxPresetCommand {
  PptxMove(String, String)
  PptxLine(String, String)
  PptxQuad(String, String, String, String)
  PptxCubic(String, String, String, String, String, String)
  PptxArc(String, String, String, String)
  PptxClose
}

///|
/// One a:path of a preset definition. width and height scale the path's own
/// coordinate space onto the shape box when they are positive.
priv struct PptxPresetPath {
  fill : String
  stroke : Bool
  width : Double
  height : Double
  commands : Array[PptxPresetCommand]
}

///|
/// A preset shape definition: adjust defaults, guides, text rectangle and
/// paths. rect names are empty when the geometry has no a:rect.
priv struct PptxPresetDef {
  av : Array[(String, String)]
  gd : Array[(String, String)]
  rect : (String, String, String, String)
  paths : Array[PptxPresetPath]
}

///|
/// The guide values of one geometry evaluation.
priv struct PptxGuideEnv {
  values : Map[String, Double]
}

///|
/// The constant part of a guide environment, and the wdN/hdN/ssdN values.
fn pptx_guide_env(width : Double, height : Double) -> PptxGuideEnv {
  let ss = Double::min(width, height)
  let ls = Double::max(width, height)
  let values : Map[String, Double] = {
    "w": width,
    "h": height,
    "l": 0.0,
    "t": 0.0,
    "r": width,
    "b": height,
    "hc": width / 2.0,
    "vc": height / 2.0,
    "ls": ls,
    "ss": ss,
    "cd2": 10800000.0,
    "cd4": 5400000.0,
    "cd8": 2700000.0,
    "3cd4": 16200000.0,
    "3cd8": 8100000.0,
    "5cd8": 13500000.0,
    "7cd8": 18900000.0,
  }
  for divisor in [2, 3, 4, 5, 6, 8, 10, 12, 16, 32] {
    let suffix = divisor.to_string()
    let scale = divisor.to_double()
    values["wd" + suffix] = width / scale
    values["hd" + suffix] = height / scale
    values["ssd" + suffix] = ss / scale
  }
  { values, }
}

///|
fn PptxGuideEnv::guide(self : PptxGuideEnv, token : String) -> Double {
  match self.values.get(token) {
    Some(value) => value
    None => @string.parse_double(token) catch { _ => 0.0 }
  }
}

///|
/// Radians per ST_Angle unit (60000ths of a degree).
let pptx_angle_unit : Double = 3.141592653589793 / 180.0 / 60000.0

///|
/// Evaluate one guide formula, like upstream guideEnv.eval.
fn PptxGuideEnv::eval(self : PptxGuideEnv, formula : String) -> Double {
  let fields : Array[String] = []
  for token in formula.split(" ") {
    if token != "" {
      fields.push(token.to_owned())
    }
  }
  if fields.is_empty() {
    return 0.0
  }
  let arg = fn(index : Int32) -> Double {
    if index < fields.length() {
      self.guide(fields[index])
    } else {
      0.0
    }
  }
  let x = arg(1)
  let y = arg(2)
  let z = arg(3)
  match fields[0] {
    "val" => x
    "*/" => if z == 0.0 { 0.0 } else { x * y / z }
    "+-" => x + y - z
    "+/" => if z == 0.0 { 0.0 } else { (x + y) / z }
    "?:" => if x > 0.0 { y } else { z }
    "abs" => x.abs()
    "at2" => @math.atan2(y, x) / pptx_angle_unit
    "cat2" => x * @math.cos(@math.atan2(z, y))
    "sat2" => x * @math.sin(@math.atan2(z, y))
    "cos" => x * @math.cos(y * pptx_angle_unit)
    "sin" => x * @math.sin(y * pptx_angle_unit)
    "tan" => x * @math.tan(y * pptx_angle_unit)
    "max" => Double::max(x, y)
    "min" => Double::min(x, y)
    "mod" => (x * x + y * y + z * z).sqrt()
    "pin" => if y < x { x } else if y > z { z } else { y }
    "sqrt" => if x < 0.0 { 0.0 } else { x.sqrt() }
    _ => 0.0
  }
}

///|
/// One evaluated path of a shape geometry.
priv struct PptxGeometryPath {
  fill : String
  stroke : Bool
  path : @core.Path
}

///|
/// An evaluated shape outline: its paths and the rectangle text lays out in.
priv struct PptxShapeGeometry {
  text_left : Double
  text_top : Double
  text_right : Double
  text_bottom : Double
  paths : Array[PptxGeometryPath]
}

///|
/// A path under construction: verbs and float coordinates in shape space.
priv struct PptxPathBuilder {
  verbs : Array[Byte]
  coordinates : Array[Double]
  mut x : Double
  mut y : Double
  mut start_x : Double
  mut start_y : Double
  mut started : Bool
}

///|
fn PptxPathBuilder::new() -> PptxPathBuilder {
  {
    verbs: [],
    coordinates: [],
    x: 0.0,
    y: 0.0,
    start_x: 0.0,
    start_y: 0.0,
    started: false,
  }
}

///|
fn PptxPathBuilder::move_to(
  self : PptxPathBuilder,
  x : Double,
  y : Double,
) -> Unit {
  self.verbs.push(0)
  self.coordinates.push(x)
  self.coordinates.push(y)
  self.x = x
  self.y = y
  self.start_x = x
  self.start_y = y
  self.started = true
}

///|
fn PptxPathBuilder::line(
  self : PptxPathBuilder,
  x : Double,
  y : Double,
) -> Unit {
  if !self.started {
    self.move_to(self.x, self.y)
  }
  self.verbs.push(1)
  self.coordinates.push(x)
  self.coordinates.push(y)
  self.x = x
  self.y = y
}

///|
fn PptxPathBuilder::quad(
  self : PptxPathBuilder,
  control_x : Double,
  control_y : Double,
  x : Double,
  y : Double,
) -> Unit {
  if !self.started {
    self.move_to(self.x, self.y)
  }
  self.verbs.push(2)
  self.coordinates.push(control_x)
  self.coordinates.push(control_y)
  self.coordinates.push(x)
  self.coordinates.push(y)
  self.x = x
  self.y = y
}

///|
fn PptxPathBuilder::cubic(
  self : PptxPathBuilder,
  control1_x : Double,
  control1_y : Double,
  control2_x : Double,
  control2_y : Double,
  x : Double,
  y : Double,
) -> Unit {
  if !self.started {
    self.move_to(self.x, self.y)
  }
  self.verbs.push(3)
  self.coordinates.push(control1_x)
  self.coordinates.push(control1_y)
  self.coordinates.push(control2_x)
  self.coordinates.push(control2_y)
  self.coordinates.push(x)
  self.coordinates.push(y)
  self.x = x
  self.y = y
}

///|
fn PptxPathBuilder::close(self : PptxPathBuilder) -> Unit {
  self.verbs.push(4)
  self.x = self.start_x
  self.y = self.start_y
}

///|
/// Append an arc from the current point, as cubic segments of at most a
/// quarter ellipse. st and sw are visual angles in radians.
fn PptxPathBuilder::arc(
  self : PptxPathBuilder,
  radius_x : Double,
  radius_y : Double,
  start : Double,
  sweep : Double,
) -> Unit {
  if radius_x <= 0.0 || radius_y <= 0.0 || sweep == 0.0 {
    return
  }
  let param = fn(angle : Double) -> Double {
    @math.atan2(radius_x * @math.sin(angle), radius_y * @math.cos(angle))
  }
  let a0 = param(start)
  // The parametric sweep differs from the visual sweep by the wrapped
  // difference of the end angles, as upstream arcEnd computes.
  let mut delta = param(start + sweep) - (a0 + sweep)
  delta -= 2.0 * 3.141592653589793 * (delta / (2.0 * 3.141592653589793)).round()
  let a1 = a0 + sweep + delta
  let center_x = self.x - radius_x * @math.cos(a0)
  let center_y = self.y - radius_y * @math.sin(a0)
  if !self.started {
    self.move_to(
      center_x + radius_x * @math.cos(a0),
      center_y + radius_y * @math.sin(a0),
    )
  }
  let total = a1 - a0
  let segments = (total.abs() / (3.141592653589793 / 2.0)).ceil().to_int()
  let count = if segments < 1 { 1 } else { segments }
  let step = total / count.to_double()
  let mut from = a0
  for _ in 0..<count {
    let to = from + step
    let kappa = 4.0 / 3.0 * @math.tan((to - from) / 4.0)
    let start_x = center_x + radius_x * @math.cos(from)
    let start_y = center_y + radius_y * @math.sin(from)
    let end_x = center_x + radius_x * @math.cos(to)
    let end_y = center_y + radius_y * @math.sin(to)
    let control1_x = start_x - kappa * radius_x * @math.sin(from)
    let control1_y = start_y + kappa * radius_y * @math.cos(from)
    let control2_x = end_x + kappa * radius_x * @math.sin(to)
    let control2_y = end_y - kappa * radius_y * @math.cos(to)
    self.cubic(control1_x, control1_y, control2_x, control2_y, end_x, end_y)
    from = to
  }
  self.x = center_x + radius_x * @math.cos(a1)
  self.y = center_y + radius_y * @math.sin(a1)
}

///|
fn PptxPathBuilder::finish(self : PptxPathBuilder) -> @core.Path {
  { verbs: Bytes::from_array(self.verbs), coordinates: self.coordinates, }
}

///|
/// Build one path of a preset definition at the given shape size.
fn pptx_build_preset_path(
  env : PptxGuideEnv,
  def : PptxPresetPath,
  width : Double,
  height : Double,
) -> PptxGeometryPath {
  let sx = if def.width > 0.0 { width / def.width } else { 1.0 }
  let sy = if def.height > 0.0 { height / def.height } else { 1.0 }
  let builder = PptxPathBuilder::new()
  for command in def.commands {
    match command {
      PptxMove(x, y) => builder.move_to(env.guide(x) * sx, env.guide(y) * sy)
      PptxLine(x, y) => builder.line(env.guide(x) * sx, env.guide(y) * sy)
      PptxQuad(x1, y1, x, y) =>
        builder.quad(
          env.guide(x1) * sx,
          env.guide(y1) * sy,
          env.guide(x) * sx,
          env.guide(y) * sy,
        )
      PptxCubic(x1, y1, x2, y2, x, y) =>
        builder.cubic(
          env.guide(x1) * sx,
          env.guide(y1) * sy,
          env.guide(x2) * sx,
          env.guide(y2) * sy,
          env.guide(x) * sx,
          env.guide(y) * sy,
        )
      PptxArc(wr, hr, start, sweep) =>
        builder.arc(
          env.guide(wr) * sx,
          env.guide(hr) * sy,
          env.guide(start) * pptx_angle_unit,
          env.guide(sweep) * pptx_angle_unit,
        )
      PptxClose => builder.close()
    }
  }
  { fill: def.fill, stroke: def.stroke, path: builder.finish(), }
}

///|
/// Evaluate a preset geometry at width×height. adjust holds the shape's
/// a:avLst overrides; nil when the preset is unknown, so that the caller can
/// draw a rectangle and warn.
fn pptx_preset_geometry(
  name : String,
  adjust : Array[(String, String)],
  width : Double,
  height : Double,
) -> PptxShapeGeometry? {
  let def = match pptx_presets.get(name) {
    Some(value) => value
    None => return None
  }
  let env = pptx_guide_env(width, height)
  for (guide_name, formula) in def.av {
    env.values[guide_name] = env.eval(formula)
  }
  for (guide_name, formula) in adjust {
    env.values[guide_name] = env.eval(formula)
  }
  for (guide_name, formula) in def.gd {
    env.values[guide_name] = env.eval(formula)
  }
  let (rect_l, rect_t, rect_r, rect_b) = def.rect
  let text_left = if rect_l == "" { 0.0 } else { env.guide(rect_l) }
  let text_top = if rect_t == "" { 0.0 } else { env.guide(rect_t) }
  let text_right = if rect_r == "" { width } else { env.guide(rect_r) }
  let text_bottom = if rect_b == "" { height } else { env.guide(rect_b) }
  let paths : Array[PptxGeometryPath] = []
  for path in def.paths {
    paths.push(pptx_build_preset_path(env, path, width, height))
  }
  Some({ text_left, text_top, text_right, text_bottom, paths, })
}

///|
/// Read the shape's a:avLst adjust overrides, if it has any.
fn pptx_preset_adjust(geom : PptxXmlNode?) -> Array[(String, String)] {
  let out : Array[(String, String)] = []
  match geom {
    Some(node) =>
      for guide in pptx_children(pptx_child(Some(node), "avLst")) {
        out.push(
          (
            pptx_attribute(guide.element, "name", ""),
            pptx_attribute(guide.element, "fmla", ""),
          ),
        )
      }
    None => ()
  }
  out
}

///|
/// The geometry of a shape with no preset: the whole box, filled and
/// stroked in one path.
fn pptx_rect_geometry(width : Double, height : Double) -> PptxShapeGeometry {
  let builder = PptxPathBuilder::new()
  builder.move_to(0.0, 0.0)
  builder.line(width, 0.0)
  builder.line(width, height)
  builder.line(0.0, height)
  builder.close()
  {
    text_left: 0.0,
    text_top: 0.0,
    text_right: width,
    text_bottom: height,
    paths: [{ fill: "norm", stroke: true, path: builder.finish(), }],
  }
}

///|
/// Translate every point of a path.
fn pptx_translate_path(
  path : @core.Path,
  dx : Double,
  dy : Double,
) -> @core.Path {
  if dx == 0.0 && dy == 0.0 {
    return path
  }
  let coordinates : Array[Double] = []
  let mut index = 0
  while index + 1 < path.coordinates.length() {
    coordinates.push(path.coordinates[index] + dx)
    coordinates.push(path.coordinates[index + 1] + dy)
    index += 2
  }
  { verbs: path.verbs, coordinates, }
}
