///|
fn HpglConverter::arc_instruction(
  self : HpglConverter,
  values : Array[Double],
  relative : Bool,
) -> Unit {
  let gl = self.gl
  if values.length() < 3 || !hpgl_valid(values) {
    return
  }
  let user = gl.user()
  let mut center : @cad.Point = { x: values[0], y: values[1] }
  if relative {
    center = user.add(center)
  }
  let mut sweep = values[2] % 360.0
  if values[2] != 0.0 && sweep == 0.0 {
    sweep = 360.0 * hpgl_sign(values[2])
  }
  let (chord, explicit) = gl.chord_param(values, 3)
  let radius = user.sub(center).length()
  let a0 = @math.atan2(user.y - center.y, user.x - center.x)
  if radius == 0.0 || sweep == 0.0 {
    if gl.down && !gl.in_poly {
      gl.dot(gl.pos)
    }
    gl.cr_point = gl.pos
    return
  }
  let path = gl.arc_path(
    center,
    radius,
    a0,
    a0 + sweep * 3.141592653589793 / 180.0,
    chord,
    explicit,
  )
  gl.add_user_path(path)
  gl.cr_point = gl.pos
}

///|
fn hpgl_norm(angle : Double) -> Double {
  let mut value = angle % (2.0 * 3.141592653589793)
  if value < 0.0 {
    value += 2.0 * 3.141592653589793
  }
  value
}

///|
fn hpgl_circumcentre(
  a : @cad.Point,
  b : @cad.Point,
  c : @cad.Point,
) -> @cad.Point? {
  let d = 2.0 *
    (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
  let scale = Double::max(
    Double::max(b.sub(a).length(), c.sub(a).length()),
    1.0e-300,
  )
  if d.abs() < 1.0e-12 * scale * scale {
    return None
  }
  let a2 = a.x * a.x + a.y * a.y
  let b2 = b.x * b.x + b.y * b.y
  let c2 = c.x * c.x + c.y * c.y
  Some({
    x: (a2 * (b.y - c.y) + b2 * (c.y - a.y) + c2 * (a.y - b.y)) / d,
    y: (a2 * (c.x - b.x) + b2 * (a.x - c.x) + c2 * (b.x - a.x)) / d,
  })
}

///|
fn HpglConverter::arc_three(
  self : HpglConverter,
  values : Array[Double],
  relative : Bool,
) -> Unit {
  let gl = self.gl
  if values.length() < 4 || !hpgl_valid(values) {
    return
  }
  let user = gl.user()
  let mut middle : @cad.Point = { x: values[0], y: values[1] }
  let mut end : @cad.Point = { x: values[2], y: values[3] }
  if relative {
    middle = user.add(middle)
    end = user.add(end)
  }
  let (chord, explicit) = gl.chord_param(values, 4)
  if middle.x == user.x && middle.y == user.y && end.x == user.x && end.y == user.y {
    if gl.down && !gl.in_poly {
      gl.dot(gl.pos)
    }
    gl.cr_point = gl.pos
    return
  }
  if (middle.x == user.x && middle.y == user.y) ||
    (middle.x == end.x && middle.y == end.y) {
    let path = @cad.CadPath::new()
    path.move_to(user.x, user.y)
    path.line_to(end.x, end.y)
    gl.add_user_path(path)
    return
  }
  if end.x == user.x && end.y == user.y {
    let center = user.add(middle).mul(0.5)
    let a0 = @math.atan2(user.y - center.y, user.x - center.x)
    let path = gl.arc_path(
      center,
      user.sub(center).length(),
      a0,
      a0 + 2.0 * 3.141592653589793,
      chord,
      explicit,
    )
    gl.add_user_path(path)
    return
  }
  match hpgl_circumcentre(user, middle, end) {
    None => {
      let path = @cad.CadPath::new()
      path.move_to(user.x, user.y)
      path.line_to(end.x, end.y)
      gl.add_user_path(path)
    }
    Some(center) => {
      let radius = user.sub(center).length()
      let a0 = @math.atan2(user.y - center.y, user.x - center.x)
      let am = @math.atan2(middle.y - center.y, middle.x - center.x)
      let a1 = @math.atan2(end.y - center.y, end.x - center.x)
      let counter_clockwise = hpgl_norm(am - a0) < hpgl_norm(a1 - a0)
      let mut sweep = hpgl_norm(a1 - a0)
      if !counter_clockwise {
        sweep -= 2.0 * 3.141592653589793
      }
      let path = gl.arc_path(center, radius, a0, a0 + sweep, chord, explicit)
      gl.add_user_path(path)
    }
  }
}

///|
fn HpglConverter::circle(self : HpglConverter, values : Array[Double]) -> Unit {
  let gl = self.gl
  if values.is_empty() || !hpgl_valid(values) {
    return
  }
  let center = gl.user()
  let mut radius = values[0]
  let (chord, explicit) = gl.chord_param(values, 1)
  let mut start = 0.0
  if radius < 0.0 {
    start = 3.141592653589793
    radius = -radius
  }
  if gl.in_poly {
    gl.polygon_close(gl.down)
  }
  if radius == 0.0 {
    if !gl.in_poly {
      gl.dot(gl.pos)
    }
    return
  }
  let path = gl.arc_path(
    center,
    radius,
    start,
    start + 2.0 * 3.141592653589793,
    chord,
    explicit,
  )
  path.close()
  let drawing_path = path.transform(gl.um)
  if gl.in_poly {
    gl.polygon_add_closed(drawing_path, gl.down)
    return
  }
  gl.stroke_path(drawing_path, [drawing_path.first()])
}

///|
fn HpglGl::polygon_add_closed(self : HpglGl, path : @cad.CadPath, down : Bool) -> Unit {
  if self.polygon.fill is None {
    self.polygon_start(path.first())
    self.polygon.sub = None
  }
  self.polygon_close(down)
  match self.polygon.fill {
    Some(fill) => fill.append(path)
    None => ()
  }
  match self.polygon.edges {
    Some(edges) => edges.append(path)
    None => ()
  }
}

///|
fn HpglConverter::bezier(
  self : HpglConverter,
  values : Array[Double],
  relative : Bool,
) -> Unit {
  let gl = self.gl
  let mut index = 0
  while index + 5 < values.length() {
    let slice = [
      values[index],
      values[index + 1],
      values[index + 2],
      values[index + 3],
      values[index + 4],
      values[index + 5],
    ]
    if !hpgl_valid(slice) {
      index += 6
      continue
    }
    let user = gl.user()
    let mut c1 : @cad.Point = { x: values[index], y: values[index + 1] }
    let mut c2 : @cad.Point = { x: values[index + 2], y: values[index + 3] }
    let mut end : @cad.Point = { x: values[index + 4], y: values[index + 5] }
    if relative {
      c1 = user.add(c1)
      c2 = user.add(c2)
      end = user.add(end)
    }
    let path = @cad.CadPath::new()
    path.move_to(user.x, user.y)
    path.cubic_to(c1, c2, end)
    gl.add_user_path(path)
    index += 6
  }
  if values.length() >= 6 {
    gl.cr_point = gl.pos
  }
}

///|
fn read_encoded_number(
  data : Bytes,
  start : Int,
  base : Int,
) -> (Int64, Int, Bool) {
  let mut value = 0L
  let mut multiplier = 1L
  let mut index = start
  while index < data.length() {
    let byte = data[index]
    if byte == 59 || byte == 0x1b {
      return (0L, index, false)
    }
    index += 1
    let code = if base == 64 {
      byte.to_int() & 0xff
    } else {
      byte.to_int() & 0x7f
    }
    if base == 64 && code >= 63 && code <= 126 {
      value += (code - 63).to_int64() * multiplier
    } else if base == 64 && code >= 191 && code <= 254 {
      value += (code - 191).to_int64() * multiplier
      return (value, index, true)
    } else if base == 32 && code >= 63 && code <= 94 {
      value += (code - 63).to_int64() * multiplier
    } else if base == 32 && code >= 95 && code <= 126 {
      value += (code - 95).to_int64() * multiplier
      return (value, index, true)
    } else {
      continue
    }
    if multiplier > (1L << 40) {
      return (0L, index, false)
    }
    multiplier *= base.to_int64()
  }
  (0L, index, false)
}

///|
fn hpgl_signed(value : Int64) -> Double {
  if (value & 1L) != 0L {
    -(value >> 1).to_double()
  } else {
    (value >> 1).to_double()
  }
}

///|
fn HpglConverter::polyline_encoded(self : HpglConverter) -> Unit {
  let data = self.data
  let gl = self.gl
  let mut base = 64
  let mut fraction = 0.0
  let mut up_next = false
  let mut absolute_next = false
  let was_relative = gl.relative
  let mut moved = false
  while self.offset < data.length() {
    let byte = data[self.offset]
    if byte == 59 {
      self.offset += 1
      break
    }
    if byte == 0x1b {
      break
    }
    let flag = (byte.to_int() & 0x7f).unsafe_to_char()
    match flag {
      ':' => {
        self.offset += 1
        let (value, next, ok) = read_encoded_number(data, self.offset, base)
        self.offset = next
        if ok && !gl.in_poly {
          self.select_pen([hpgl_signed(value)])
        }
        continue
      }
      '<' => {
        self.offset += 1
        up_next = true
        continue
      }
      '>' => {
        self.offset += 1
        let (value, next, ok) = read_encoded_number(data, self.offset, base)
        self.offset = next
        if ok {
          let decoded = hpgl_signed(value)
          if decoded >= 0.0 && decoded < 64.0 {
            fraction = decoded
          }
        }
        continue
      }
      '=' => {
        self.offset += 1
        absolute_next = true
        continue
      }
      '7' => {
        self.offset += 1
        base = 32
        continue
      }
      _ => ()
    }
    let code = byte.to_int() & 0x7f
    if code < 63 {
      self.offset += 1
      continue
    }
    let (x_value, next, x_ok) = read_encoded_number(data, self.offset, base)
    if !x_ok {
      break
    }
    self.offset = next
    let (y_value, next, y_ok) = read_encoded_number(data, self.offset, base)
    if !y_ok {
      break
    }
    self.offset = next
    let scale = @math.pow(2.0, -fraction)
    let x = hpgl_signed(x_value) * scale
    let y = hpgl_signed(y_value) * scale
    let point = if absolute_next {
      hpgl_apply(gl.um, { x, y })
    } else {
      gl.pos.add(hpgl_linear(gl.um, { x, y }))
    }
    if up_next {
      gl.pen_up()
    } else {
      gl.pen_down()
    }
    gl.line_to(point)
    up_next = false
    absolute_next = false
    moved = true
  }
  gl.relative = was_relative
  if moved {
    gl.cr_point = gl.pos
  }
}

///|
fn HpglConverter::polygon_mode(self : HpglConverter, values : Array[Double]) -> Unit {
  let gl = self.gl
  let mode = if values.is_empty() { 0 } else { values[0].to_int() }
  match mode {
    0 => {
      gl.flush()
      gl.polygon_start(gl.pos)
      gl.in_poly = true
    }
    1 => if gl.in_poly {
      gl.polygon_close(gl.down)
    }
    2 => if gl.in_poly {
      gl.polygon_close(gl.down)
      gl.in_poly = false
      let saved = gl.polygon.saved_pos
      let saved_down = gl.polygon.saved_down
      gl.pos = saved
      gl.down = saved_down
      gl.stroke.pending_dot = false
    }
    _ => ()
  }
}

///|
fn HpglConverter::edge_polygon(self : HpglConverter) -> Unit {
  let gl = self.gl
  if gl.in_poly {
    return
  }
  match gl.polygon.edges {
    Some(edges) =>
      if !edges.is_empty() {
        gl.flush()
        let pen = gl.pen()
        gl.draw_stroke(edges, pen)
      }
    None => ()
  }
}

///|
fn HpglConverter::fill_polygon(self : HpglConverter, values : Array[Double]) -> Unit {
  let gl = self.gl
  if gl.in_poly {
    return
  }
  match gl.polygon.fill {
    Some(path) =>
      if !path.is_empty() {
        gl.flush()
        gl.fill_path(path, !(!values.is_empty() && values[0] == 1.0))
      }
    None => ()
  }
}

///|
fn HpglConverter::rectangle(
  self : HpglConverter,
  values : Array[Double],
  relative : Bool,
  fill : Bool,
) -> Unit {
  let gl = self.gl
  if values.length() < 2 || !hpgl_valid(values) || gl.in_poly {
    return
  }
  let user = gl.user()
  let mut corner : @cad.Point = { x: values[0], y: values[1] }
  if relative {
    corner = user.add(corner)
  }
  let path = @cad.CadPath::new()
  path.move_to(user.x, user.y)
  path.line_to(corner.x, user.y)
  path.line_to(corner.x, corner.y)
  path.line_to(user.x, corner.y)
  path.close()
  let drawing_path = path.transform(gl.um)
  gl.flush()
  if fill {
    gl.fill_path(drawing_path, true)
  } else {
    gl.stroke_path(drawing_path, [drawing_path.first()])
  }
}

///|
fn HpglConverter::wedge(
  self : HpglConverter,
  values : Array[Double],
  fill : Bool,
) -> Unit {
  let gl = self.gl
  if values.length() < 3 || !hpgl_valid(values) || gl.in_poly {
    return
  }
  let user = gl.user()
  let mut radius = values[0]
  let mut start = values[1] * 3.141592653589793 / 180.0
  let sweep = Double::max(-360.0, Double::min(360.0, values[2])) *
    3.141592653589793 /
    180.0
  if radius < 0.0 {
    radius = -radius
    start += 3.141592653589793
  }
  let (chord, explicit) = gl.chord_param(values, 3)
  let path = @cad.CadPath::new()
  if sweep.abs() >= 2.0 * 3.141592653589793 - 1.0e-12 {
    let arc = gl.arc_path(user, radius, start, start + sweep, chord, explicit)
    path.append(arc)
    path.close()
  } else {
    path.move_to(user.x, user.y)
    let arc = gl.arc_path(user, radius, start, start + sweep, chord, explicit)
    path.continue_with(arc)
    path.close()
  }
  let drawing_path = path.transform(gl.um)
  gl.flush()
  if radius == 0.0 {
    gl.dot(gl.pos)
    return
  }
  if fill {
    gl.fill_path(drawing_path, true)
  } else {
    gl.stroke_path(drawing_path, [drawing_path.first()])
  }
}

///|
fn HpglConverter::select_pen(self : HpglConverter, values : Array[Double]) -> Unit {
  self.gl.flush()
  let mut pen = 0
  if !values.is_empty() && hpgl_valid([values[0]]) {
    pen = Double::max(-1.0e6, Double::min(1.0e6, values[0])).round().to_int()
  }
  self.gl.pens.selected = pen
  self.gl.pens.chosen = true
  self.gl.pens.cached = None
}

///|
fn HpglConverter::pen_width(self : HpglConverter, values : Array[Double]) -> Unit {
  self.gl.flush()
  let pens = self.gl.pens
  let mut width = if pens.relative { 0.1 } else { HPGL_DEFAULT_WIDTH }
  if !values.is_empty() {
    if !hpgl_valid([values[0]]) || values[0] < 0.0 {
      return
    }
    width = values[0]
  }
  if values.length() > 1 {
    let index = values[1].to_int()
    if index < 0 || index >= pens.count {
      return
    }
    pens.widths[index] = width
  } else {
    for index in 0..<pens.widths.length() {
      pens.widths[index] = width
    }
  }
  pens.cached = None
}

///|
fn HpglConverter::width_unit(self : HpglConverter, values : Array[Double]) -> Unit {
  self.gl.flush()
  let pens = self.gl.pens
  let relative = !values.is_empty() && values[0] == 1.0
  if !values.is_empty() && values[0] != 0.0 && values[0] != 1.0 {
    return
  }
  pens.relative = relative
  let width = if relative { 0.1 } else { HPGL_DEFAULT_WIDTH }
  for index in 0..<pens.widths.length() {
    pens.widths[index] = width
  }
  pens.cached = None
}

///|
fn HpglConverter::number_of_pens(self : HpglConverter, values : Array[Double]) -> Unit {
  let pens = self.gl.pens
  let mut count = 8
  if !values.is_empty() {
    if values[0] < 2.0 || !hpgl_valid(values) {
      return
    }
    count = 2
    while count < values[0].to_int() && count < 256 {
      count *= 2
    }
  }
  pens.resize(count)
}

///|
fn HpglConverter::pen_color(self : HpglConverter, values : Array[Double]) -> Unit {
  let pens = self.gl.pens
  if values.is_empty() {
    for index in 0..<pens.colors.length() {
      pens.colors[index] = hpgl_default_color(index)
    }
    pens.cached = None
    return
  }
  let pen = values[0].to_int()
  if pen < 0 || pen >= pens.count || !hpgl_valid(values) {
    return
  }
  if values.length() == 1 {
    pens.colors[pen] = hpgl_default_color(pen)
  } else if values.length() >= 4 {
    let rgb : Array[Int] = []
    for index in 0..<3 {
      let low = pens.cr[index * 2]
      let high = pens.cr[index * 2 + 1]
      let mut value = values[index + 1]
      if low < high {
        value = Double::max(low, Double::min(high, value))
      } else {
        value = Double::max(high, Double::min(low, value))
      }
      let ratio = if high == low { 0.0 } else { (value - low) / (high - low) }
      rgb.push((ratio * 255.0).round().to_int())
    }
    pens.colors[pen] = hpgl_rgb(rgb[0], rgb[1], rgb[2])
  }
  pens.cached = None
}

///|
fn HpglConverter::color_range(self : HpglConverter, values : Array[Double]) -> Unit {
  if values.is_empty() {
    self.gl.pens.default_color_range()
    return
  }
  if values.length() < 6 ||
    !hpgl_valid(values) ||
    values[0] == values[1] ||
    values[2] == values[3] ||
    values[4] == values[5] {
    return
  }
  self.gl.pens.cr = [values[0], values[1], values[2], values[3], values[4], values[5]]
}

///|
fn HpglConverter::line_type(self : HpglConverter, values : Array[Double]) -> Unit {
  let line = self.gl.line
  self.gl.flush()
  if values.is_empty() {
    line.set = false
    return
  }
  let typ = values[0].round().to_int()
  if typ < -8 || typ > 8 || !hpgl_valid(values) {
    return
  }
  line.typ = typ
  line.set = true
  if values.length() > 1 {
    if values[1] <= 0.0 {
      return
    }
    line.length = values[1]
  }
  if values.length() > 2 {
    if values[2] == 0.0 {
      line.absolute = false
    } else if values[2] == 1.0 {
      line.absolute = true
    }
  }
}

///|
fn HpglConverter::user_line_type(self : HpglConverter, values : Array[Double]) -> Unit {
  let line = self.gl.line
  self.gl.flush()
  if values.is_empty() {
    for index in 0..<line.user.length() {
      line.user[index] = None
    }
    return
  }
  let index = values[0].abs().to_int()
  if index < 1 || index > 8 || !hpgl_valid(values) {
    return
  }
  if values.length() == 1 {
    line.user[index] = None
    return
  }
  let gaps : Array[Double] = []
  let mut sum = 0.0
  for at in 1..<values.length() {
    let value = Double::max(0.0, values[at])
    gaps.push(value)
    sum += value
  }
  if sum <= 0.0 {
    return
  }
  for at in 0..<gaps.length() {
    gaps[at] = gaps[at] / sum * 100.0
  }
  line.user[index] = Some(gaps)
}

///|
fn HpglConverter::line_attributes(self : HpglConverter, values : Array[Double]) -> Unit {
  let line = self.gl.line
  self.gl.flush()
  if values.is_empty() {
    line.cap = @cad.CAP_BUTT
    line.join = @cad.JOIN_MITER
    line.miter = 5.0
    return
  }
  let mut index = 0
  while index + 1 < values.length() {
    let key = values[index].to_int()
    let value = values[index + 1]
    match key {
      1 =>
        match value.to_int() {
          1 => line.cap = @cad.CAP_BUTT
          2 => line.cap = @cad.CAP_SQUARE
          3 | 4 => line.cap = @cad.CAP_ROUND
          _ => ()
        }
      2 =>
        match value.to_int() {
          1 | 2 => line.join = @cad.JOIN_MITER
          3 | 4 => line.join = @cad.JOIN_ROUND
          5 | 6 => line.join = @cad.JOIN_BEVEL
          _ => ()
        }
      3 => if hpgl_valid([value]) {
        line.miter = Double::max(1.0, value)
      }
      _ => ()
    }
    index += 2
  }
}

///|
fn HpglConverter::fill_type(self : HpglConverter, values : Array[Double]) -> Unit {
  let fill = self.gl.fill
  self.gl.flush()
  let typ = if values.is_empty() { 1 } else { values[0].to_int() }
  if !hpgl_valid(values) {
    return
  }
  match typ {
    1 | 2 => ()
    3 | 4 => {
      if values.length() > 1 {
        if values[1] < 0.0 {
          return
        }
        fill.spacing[typ] = values[1] * self.gl.user_scale_x().abs()
      }
      if values.length() > 2 {
        fill.angle[typ] = values[2]
      }
    }
    10 => if values.length() > 1 {
      fill.shade = Double::max(0.0, Double::min(100.0, values[1]))
    }
    11 | 21 | 22 => {
      if typ == 22 {
        self.warn_once(
          "FT22",
          "user-defined PCL fill patterns (FT 22) are filled solid",
        )
      } else if typ == 21 {
        // A predefined PCL cross-hatch is drawn as a solid fill.
        ()
      } else {
        self.warn_once(
          "RF",
          "raster fill patterns (RF) are filled solid",
        )
      }
    }
    _ => return
  }
  fill.typ = typ
}

///|
fn HpglConverter::raster_fill(self : HpglConverter, values : Array[Double]) -> Unit {
  self.gl.flush()
  if values.is_empty() {
    return
  }
  self.warn_once(
    "RF",
    "raster fill patterns (RF) are filled solid",
  )
}

///|
fn HpglConverter::screened_vectors(self : HpglConverter, values : Array[Double]) -> Unit {
  self.gl.flush()
  self.gl.fill.sv = 0
  if values.is_empty() {
    return
  }
  match values[0].to_int() {
    0 => ()
    1 => {
      self.gl.fill.sv = 1
      if values.length() > 1 && hpgl_valid([values[1]]) {
        self.gl.fill.sv_shade = Double::max(0.0, Double::min(100.0, values[1]))
      }
    }
    2 | 21 | 22 => {
      self.gl.fill.sv = 1
      self.gl.fill.sv_shade = 50.0
      self.warn_once("SV", "vectors screened with patterns are drawn half shaded")
    }
    _ => ()
  }
  self.gl.pens.cached = None
}

///|
fn HpglConverter::anchor_corner(self : HpglConverter, values : Array[Double]) -> Unit {
  self.gl.flush()
  if values.length() < 2 || !hpgl_valid(values) {
    self.gl.anchored = false
    return
  }
  self.gl.anchor = hpgl_apply(self.gl.um, { x: values[0], y: values[1] })
  self.gl.anchored = true
}

///|
fn HpglConverter::tick_length(self : HpglConverter, values : Array[Double]) -> Unit {
  self.gl.ticks = (0.5, 0.5)
  if !values.is_empty() && hpgl_valid([values[0]]) {
    self.gl.ticks = (values[0], 0.0)
  }
  if values.length() > 1 && hpgl_valid([values[1]]) {
    self.gl.ticks = (self.gl.ticks.0, values[1])
  }
}

///|
fn HpglConverter::tick(
  self : HpglConverter,
  values : Array[Double],
  horizontal : Bool,
) -> Unit {
  let _ = values
  let gl = self.gl
  let delta = gl.p2.sub(gl.p1)
  let (first, second) = gl.ticks
  let a : @cad.Point = if horizontal {
    { x: 0.0, y: first / 100.0 * delta.y }
  } else {
    { x: first / 100.0 * delta.x, y: 0.0 }
  }
  let b : @cad.Point = if horizontal {
    { x: 0.0, y: -second / 100.0 * delta.y }
  } else {
    { x: -second / 100.0 * delta.x, y: 0.0 }
  }
  let p0 = gl.pos.add(hpgl_linear(gl.dev, b))
  let p1 = gl.pos.add(hpgl_linear(gl.dev, a))
  let path = @cad.CadPath::new()
  path.move_to(p0.x, p0.y)
  path.line_to(p1.x, p1.y)
  gl.stroke_path(path, [])
}
