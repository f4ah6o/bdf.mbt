///|
priv struct SfcStyle {
  color : UInt32
  width : Double
  dash : Array[Double]
}

///|
priv struct SfcRenderer {
  model : SfcModel
  drawing : @cad.Drawing
  fonts : @canvas.Fonts
  light : Bool
  bg : UInt32
  warnings : Array[String]
  mut count : Int
  stack : Array[String]
}

///|
fn SfcRenderer::warn_once(self : SfcRenderer, key : String, message : String) -> Unit {
  let marker = "[" + key + "]"
  for warning in self.warnings {
    if warning.contains(marker) {
      return
    }
  }
  self.warnings.push(marker + " " + message)
}

///|
fn SfcRenderer::paint(self : SfcRenderer, color : UInt32) -> UInt32 {
  if self.light && color == 0xffffffffU {
    0x000000ffU
  } else {
    color
  }
}

///|
fn SfcRenderer::color(self : SfcRenderer, code : Int) -> UInt32 {
  match self.model.color(code) {
    Some(value) => self.paint(value)
    None => self.paint(0xffffffffU)
  }
}

///|
fn SfcRenderer::style(self : SfcRenderer, feature : SfcFeature, index : Int) -> SfcStyle {
  let width = self.model.width(feature.int(index + 2))
  {
    color: self.color(feature.int(index)),
    width,
    dash: self.model.pattern(feature.int(index + 1), width),
  }
}

///|
fn SfcRenderer::pen(self : SfcRenderer, style : SfcStyle) -> @cad.Pen {
  let pen = @cad.Pen::new(
    color=style.color,
    width=style.width * 72.0 / 25.4,
    cap=@cad.CAP_ROUND,
    join=@cad.JOIN_ROUND,
  )
  let (dash, offset) = @cad.dash_pattern(Some(style.dash))
  pen.dash = dash
  pen.dash_offset = offset
  pen
}

///|
fn SfcRenderer::stroke(self : SfcRenderer, path : @cad.CadPath, style : SfcStyle, matrix : @canvas.Matrix) -> Unit {
  if path.is_empty() {
    return
  }
  self.count += 1
  if self.count > 5000000 {
    return
  }
  self.drawing.stroke(path.transform(matrix), self.pen(style))
}

///|
fn sfc_points(xs : Array[Double], ys : Array[Double]) -> Array[@cad.Point] {
  let count = Int::min(xs.length(), ys.length())
  let output : Array[@cad.Point] = []
  for index in 0..<count {
    output.push({ x: xs[index], y: ys[index] })
  }
  output
}

///|
fn sfc_arc_path(
  center : @cad.Point,
  rx : Double,
  ry : Double,
  rotation : Double,
  start : Double,
  end : Double,
  clockwise : Bool,
) -> @cad.CadPath {
  let path = @cad.CadPath::new()
  let angle = rotation * 3.141592653589793 / 180.0
  let major : @cad.Point = {
    x: rx * @math.cos(angle),
    y: rx * @math.sin(angle),
  }
  let ratio = if rx == 0.0 { 1.0 } else { ry / rx }
  let mut from = start * 3.141592653589793 / 180.0
  let mut to = end * 3.141592653589793 / 180.0
  let full = 2.0 * 3.141592653589793
  if clockwise {
    if (to - from).abs() >= full - 1.0e-9 {
      to = from - full
    } else {
      from = from % full
      to = to % full
      if to >= from - 1.0e-9 {
        to -= full
      }
    }
  } else {
    if (to - from).abs() >= full - 1.0e-9 {
      to = from + full
    } else {
      from = from % full
      to = to % full
      if to <= from + 1.0e-9 {
        to += full
      }
    }
  }
  path.ellipse_arc(center, major, ratio, from, to)
  path
}

///|
fn sfc_units(character : Char) -> Double {
  let text = character.to_string()
  match @encoding.encode(text, "shift_jis") {
    Ok(bytes) => if bytes.length() == 2 { 2.0 } else { 1.0 }
    Err(_) => if character.to_int() >= 0x2e80 { 2.0 } else { 1.0 }
  }
}

///|
fn SfcRenderer::text(
  self : SfcRenderer,
  feature : SfcFeature,
  color_index : Int,
  index : Int,
  matrix : @canvas.Matrix,
) -> Unit {
  let text = feature.str(index + 1)
  let mut trimmed = text
  while trimmed.has_suffix(" ") {
    trimmed = trimmed[:trimmed.length() - 1].to_owned()
  }
  if sfc_blank(trimmed) {
    return
  }
  let height = feature.num(index + 4)
  let width = feature.num(index + 5)
  if height <= 0.0 || width <= 0.0 {
    return
  }
  let x = feature.num(index + 2)
  let y = feature.num(index + 3)
  let spacing = feature.num(index + 6)
  let angle = feature.num(index + 7) * 3.141592653589793 / 180.0
  let slant = feature.num(index + 8) * 3.141592653589793 / 180.0
  let anchor = Int::max(feature.int(index + 9), 1)
  let vertical = feature.int(index + 10) == 2
  let characters : Array[Char] = []
  for character in trimmed {
    characters.push(character)
  }
  let count = characters.length()
  let mut total = 0.0
  let cells : Array[Double] = []
  for character in characters {
    total += sfc_units(character)
  }
  let cos = @math.cos(angle)
  let sin = @math.sin(angle)
  let frame = matrix.mul(@canvas.Matrix::translate(x, y)).mul({
    a: cos,
    b: sin,
    c: -sin,
    d: cos,
    e: 0.0,
    f: 0.0,
  })
  let skew : @canvas.Matrix = {
    a: 1.0,
    b: 0.0,
    c: @math.tan(slant),
    d: 1.0,
    e: 0.0,
    f: 0.0,
  }
  let spec = @cad.FontSpec::new(family=self.model.font(feature.int(index)))
  if !vertical {
    let cells_width = width - spacing * (count.to_double() - 1.0)
    let unit = if cells_width > 0.0 { cells_width / total } else { width / total }
    let mut bx = 0.0
    if (anchor - 1) % 3 == 1 { bx = -width / 2.0 }
    if (anchor - 1) % 3 == 2 { bx = -width }
    let mut by = 0.0
    if (anchor - 1) / 3 == 1 { by = -height / 2.0 }
    if (anchor - 1) / 3 == 2 { by = -height }
    for character in characters {
      cells.push(sfc_units(character) * unit / height)
    }
    let text_matrix = frame.mul(@canvas.Matrix::translate(bx, by + 0.12 * height)).mul(skew).mul(
      @canvas.Matrix::scale(height, height),
    )
    let choice = self.fonts.face(spec.family, spec.east_asian, characters[0].to_int())
    let metrics = self.fonts.metrics(choice)
    self.drawing.text(@cad.CadText::new(
      trimmed,
      text_matrix,
      font=spec,
      color=self.color(feature.int(color_index)),
      advance=sfc_cells_sum(cells),
      cells=Some(cells),
      spacing=spacing / height,
      asc=metrics.asc,
      desc=metrics.desc,
      cap=metrics.cap,
    ))
  } else {
    let cells_height = height - spacing * (count.to_double() - 1.0)
    let unit = if cells_height > 0.0 { cells_height / total } else { height / total }
    let mut bx = 0.0
    if (anchor - 1) % 3 == 1 { bx = -width / 2.0 }
    if (anchor - 1) % 3 == 2 { bx = -width }
    let mut by = 0.0
    if (anchor - 1) / 3 == 0 { by = height }
    if (anchor - 1) / 3 == 1 { by = height / 2.0 }
    for character in characters {
      cells.push(sfc_units(character) * unit / width)
    }
    let text_matrix = frame.mul(@canvas.Matrix::translate(bx + width / 2.0, by)).mul(skew).mul(
      @canvas.Matrix::rotate(-90.0),
    ).mul(@canvas.Matrix::scale(width, width))
    let choice = self.fonts.face(spec.family, spec.east_asian, characters[0].to_int())
    let metrics = self.fonts.metrics(choice)
    self.drawing.text(@cad.CadText::new(
      trimmed,
      text_matrix,
      font=spec,
      color=self.color(feature.int(color_index)),
      advance=sfc_cells_sum(cells),
      cells=Some(cells),
      spacing=spacing / width,
      asc=metrics.asc,
      desc=metrics.desc,
      cap=metrics.cap,
      vertical=true,
    ))
  }
}

///|
fn sfc_cells_sum(cells : Array[Double]) -> Double {
  let mut total = 0.0
  for value in cells {
    total += value
  }
  total
}

///|
fn sfc_blank(value : String) -> Bool {
  for character in value {
    if !character.is_whitespace() {
      return false
    }
  }
  true
}

///|
fn SfcRenderer::marker(
  self : SfcRenderer,
  code : Int,
  point : @cad.Point,
  angle : Double,
  scale : Double,
  color : UInt32,
  matrix : @canvas.Matrix,
) -> Unit {
  self.count += 1
  let center = @cad.apply(matrix, point)
  let size = 1.25 * Double::max(scale, 0.0)
  if size == 0.0 { return }
  let rotation = matrix.mul(@canvas.Matrix::translate(point.x, point.y)).mul(
    @canvas.Matrix::rotate(angle),
  ).mul(@canvas.Matrix::scale(size, size))
  let path = @cad.CadPath::new()
  if code == 1 {
    for index in 0..<3 {
      let a = index.to_double() * 3.141592653589793 / 3.0
      path.move_to(-@math.cos(a), -@math.sin(a))
      path.line_to(@math.cos(a), @math.sin(a))
    }
  } else if code == 2 {
    path.circle({ x: 0.0, y: 0.0 }, 1.0)
  } else if code == 3 {
    path.circle({ x: 0.0, y: 0.0 }, 0.3)
    self.drawing.fill(path.transform(rotation), @cad.Fill::solid(color), false)
    return
  } else if code == 4 {
    path.move_to(-1.0, 0.0)
    path.line_to(1.0, 0.0)
    path.move_to(0.0, -1.0)
    path.line_to(0.0, 1.0)
  } else if code == 5 {
    path.polyline([
      { x: -1.0, y: -1.0 },
      { x: 1.0, y: -1.0 },
      { x: 1.0, y: 1.0 },
      { x: -1.0, y: 1.0 },
    ], true)
  } else if code == 6 {
    path.polyline([
      { x: 0.0, y: 1.0 },
      { x: -0.8660254, y: -0.5 },
      { x: 0.8660254, y: -0.5 },
    ], true)
  } else {
    path.move_to(-1.0, -1.0)
    path.line_to(1.0, 1.0)
    path.move_to(-1.0, 1.0)
    path.line_to(1.0, -1.0)
  }
  self.drawing.stroke(path.transform(rotation), self.pen({
    color,
    width: 0.13,
    dash: [],
  }))
  let _ = center
}

///|
fn SfcRenderer::feature(self : SfcRenderer, feature : SfcFeature, matrix : @canvas.Matrix) -> Unit {
  if !self.model.layer_visible(feature.int(0)) {
    return
  }
  match feature.name {
    "point_marker_feature" => self.marker(
      feature.int(4),
      { x: feature.num(2), y: feature.num(3) },
      feature.num(5),
      feature.num(6),
      self.color(feature.int(1)),
      matrix,
    )
    "line_feature" => {
      let path = @cad.CadPath::new()
      path.move_to(feature.num(4), feature.num(5))
      path.line_to(feature.num(6), feature.num(7))
      self.stroke(path, self.style(feature, 1), matrix)
    }
    "polyline_feature" => {
      let path = @cad.CadPath::new()
      path.polyline(sfc_points(sfc_list(feature.str(5)), sfc_list(feature.str(6))), false)
      self.stroke(path, self.style(feature, 1), matrix)
    }
    "circle_feature" => {
      let path = @cad.CadPath::new()
      path.circle({ x: feature.num(4), y: feature.num(5) }, feature.num(6))
      self.stroke(path, self.style(feature, 1), matrix)
    }
    "arc_feature" => {
      let path = sfc_arc_path(
        { x: feature.num(4), y: feature.num(5) },
        feature.num(6),
        feature.num(6),
        0.0,
        feature.num(8),
        feature.num(9),
        feature.int(7) == 1,
      )
      self.stroke(path, self.style(feature, 1), matrix)
    }
    "ellipse_feature" => {
      let path = @cad.CadPath::new()
      let rx = feature.num(6)
      let ry = feature.num(7)
      let rotation = feature.num(8)
      let angle = rotation * 3.141592653589793 / 180.0
      path.ellipse(
        { x: feature.num(4), y: feature.num(5) },
        { x: rx * @math.cos(angle), y: rx * @math.sin(angle) },
        if rx == 0.0 { 1.0 } else { ry / rx },
      )
      self.stroke(path, self.style(feature, 1), matrix)
    }
    "ellipse_arc_feature" => {
      let path = sfc_arc_path(
        { x: feature.num(4), y: feature.num(5) },
        feature.num(6),
        feature.num(7),
        feature.num(9),
        feature.num(10),
        feature.num(11),
        feature.int(8) == 1,
      )
      self.stroke(path, self.style(feature, 1), matrix)
    }
    "text_string_feature" => self.text(feature, 1, 2, matrix)
    "spline_feature" => {
      let path = sfc_bezier(sfc_points(sfc_list(feature.str(6)), sfc_list(feature.str(7))))
      self.stroke(path, self.style(feature, 1), matrix)
    }
    "clothoid_feature" => {
      let points = sfc_clothoid(
        feature.num(6),
        feature.num(9),
        feature.num(10),
        feature.int(7) == 1,
      )
      let local = matrix.mul(@canvas.Matrix::translate(feature.num(4), feature.num(5))).mul(
        @canvas.Matrix::rotate(feature.num(8)),
      )
      let path = @cad.CadPath::new()
      path.polyline(points, false)
      self.stroke(path, self.style(feature, 1), local)
    }
    "sfig_locate_feature" => self.locate(feature, matrix)
    "linear_dim_feature" | "curve_dim_feature" | "angular_dim_feature" |
    "radius_dim_feature" | "diameter_dim_feature" | "label_feature" |
    "balloon_feature" => self.warn_once("dim", "dimension and label features are not drawn yet")
    "externally_defined_hatch_feature" | "fill_area_style_colour_feature" |
    "fill_area_style_hatching_feature" | "fill_area_style_tiles_feature" =>
      self.warn_once("hatch", "hatch features are not drawn yet")
    _ => {
      let count = match self.model.unknown.get(feature.name) {
        Some(value) => value
        None => 0
      }
      self.model.unknown[feature.name] = count + 1
    }
  }
}

///|
fn sfc_bezier(points : Array[@cad.Point]) -> @cad.CadPath {
  let path = @cad.CadPath::new()
  if points.length() < 2 {
    return path
  }
  path.move_to(points[0].x, points[0].y)
  let mut index = 0
  while index + 3 < points.length() {
    path.cubic_to(points[index + 1], points[index + 2], points[index + 3])
    index += 3
  }
  index += 1
  while index < points.length() {
    path.line_to(points[index].x, points[index].y)
    index += 1
  }
  path
}

///|
fn sfc_clothoid(a : Double, s0 : Double, s1 : Double, clockwise : Bool) -> Array[@cad.Point] {
  let points : Array[@cad.Point] = []
  if a <= 0.0 || s1 <= s0 {
    return points
  }
  let steps = Int::min(Int::max(((s1 - s0) / a * 64.0).to_int(), 16), 2048)
  let mut x = 0.0
  let mut y = 0.0
  let f = fn(s : Double) -> (Double, Double) {
    let t = s * s / (2.0 * a * a)
    (@math.cos(t), @math.sin(t))
  }
  if s0 > 0.0 {
    let initial = Int::min(Int::max((s0 / a * 64.0).to_int(), 16), 2048)
    let h = s0 / initial.to_double()
    for index in 0..<initial {
      let sa = index.to_double() * h
      let sb = (index + 1).to_double() * h
      let (ca, ya) = f(sa)
      let (cm, ym) = f((sa + sb) / 2.0)
      let (cb, yb) = f(sb)
      x += h / 6.0 * (ca + 4.0 * cm + cb)
      y += h / 6.0 * (ya + 4.0 * ym + yb)
    }
  }
  points.push({ x, y })
  let h = (s1 - s0) / steps.to_double()
  for index in 0..<steps {
    let sa = s0 + index.to_double() * h
    let sb = s0 + (index + 1).to_double() * h
    let (ca, ya) = f(sa)
    let (cm, ym) = f((sa + sb) / 2.0)
    let (cb, yb) = f(sb)
    x += h / 6.0 * (ca + 4.0 * cm + cb)
    y += h / 6.0 * (ya + 4.0 * ym + yb)
    points.push({ x, y: if clockwise { -y } else { y } })
  }
  points
}

///|
fn SfcRenderer::locate(self : SfcRenderer, feature : SfcFeature, matrix : @canvas.Matrix) -> Unit {
  let name = feature.str(1)
  match self.model.sfigs.get(name) {
    None => self.warn_once("sfig:" + name, "compound figure \"" + name + "\" is not defined")
    Some(sfig) => {
      if self.stack.contains(name) || self.stack.length() > 32 {
        self.warn_once("cycle", "compound figures that place themselves are drawn once")
        return
      }
      let local = matrix.mul(@canvas.Matrix::translate(feature.num(2), feature.num(3))).mul(
        @canvas.Matrix::rotate(feature.num(4)),
      ).mul(@canvas.Matrix::scale(feature.num(5), feature.num(6)))
      self.stack.push(name)
      for item in sfig.items {
        self.feature(item, local)
      }
      ignore(self.stack.pop())
    }
  }
}
