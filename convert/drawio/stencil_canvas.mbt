///|
/// An immediate-mode canvas over @cad.Drawing for stencil rendering, the
/// counterpart of the upstream converter's c2d. Path elements accumulate
/// into a CadPath in local coordinates; fill/stroke transforms it by the
/// current matrix and appends the item. save/restore covers the matrix and
/// the style state.

///|
priv struct DrawioStencilSaved {
  matrix : @canvas.Matrix
  state : DrawioStencilState
}

///|
priv struct DrawioStencilState {
  mut stroke_color : String
  mut fill_color : String
  mut gradient_color : String
  mut gradient_direction : String
  mut gradient_fill_alpha : Double
  mut gradient_alpha : Double
  mut alpha : Double
  mut fill_alpha : Double
  mut stroke_alpha : Double
  mut stroke_width : Double
  mut dashed : Bool
  mut fix_dash : Bool
  mut dash_pattern : String
  mut line_cap : String
  mut line_join : String
  mut miter_limit : Double
}

///|
fn drawio_stencil_state() -> DrawioStencilState {
  {
    stroke_color: "",
    fill_color: "",
    gradient_color: "",
    gradient_direction: "south",
    gradient_fill_alpha: 1.0,
    gradient_alpha: 1.0,
    alpha: 1.0,
    fill_alpha: 1.0,
    stroke_alpha: 1.0,
    stroke_width: 1.0,
    dashed: false,
    fix_dash: false,
    dash_pattern: "3 3",
    line_cap: "flat",
    line_join: "miter",
    miter_limit: 10.0,
  }
}

///|
priv struct DrawioStencilCanvas {
  drawing : @cad.Drawing
  mut matrix : @canvas.Matrix
  mut path : @cad.CadPath?
  mut last_x : Double
  mut last_y : Double
  stack : Array[DrawioStencilSaved]
  mut state : DrawioStencilState
  warn : DrawioWarn
}

///|
fn DrawioStencilCanvas::new(drawing : @cad.Drawing, warn : DrawioWarn) -> DrawioStencilCanvas {
  {
    drawing,
    matrix: @canvas.Matrix::identity(),
    path: None,
    last_x: 0.0,
    last_y: 0.0,
    stack: [],
    state: drawio_stencil_state(),
    warn,
  }
}

///|
fn DrawioStencilCanvas::save(self : DrawioStencilCanvas) -> Unit {
  self.stack.push({ matrix: self.matrix, state: self.state })
}

///|
fn DrawioStencilCanvas::restore(self : DrawioStencilCanvas, base : Int) -> Unit {
  while self.stack.length() > base {
    let saved = self.stack.pop().unwrap()
    self.matrix = saved.matrix
    self.state = saved.state
  }
}

///|
fn DrawioStencilCanvas::translate(self : DrawioStencilCanvas, dx : Double, dy : Double) -> Unit {
  self.matrix = self.matrix.mul(@canvas.Matrix::translate(dx, dy))
}

///|
/// Turn what follows by theta degrees about (cx, cy), after flipping —
/// mxSvgCanvas2D.rotate as the upstream canvas does.
fn DrawioStencilCanvas::rotate(
  self : DrawioStencilCanvas,
  theta : Double,
  flip_h : Bool,
  flip_v : Bool,
  cx : Double,
  cy : Double,
) -> Unit {
  let mut theta = theta
  if theta == 0.0 && !flip_h && !flip_v {
    return
  }
  let mut m = @canvas.Matrix::identity()
  if flip_h && flip_v {
    theta += 180.0
  } else if flip_h != flip_v {
    let (tx, sx) = if flip_h { (cx, -1.0) } else { (0.0, 1.0) }
    let (ty, sy) = if flip_v { (cy, -1.0) } else { (0.0, 1.0) }
    m = @canvas.Matrix::translate(tx, ty).mul(@canvas.Matrix::scale(sx, sy)).mul(
      @canvas.Matrix::translate(-tx, -ty),
    )
    theta = -theta
  }
  if theta != 0.0 {
    m = m.mul(
      @canvas.Matrix::translate(cx, cy).mul(@canvas.Matrix::rotate(theta)).mul(
        @canvas.Matrix::translate(-cx, -cy),
      ),
    )
  }
  self.matrix = self.matrix.mul(m)
}

///|
fn DrawioStencilCanvas::set_alpha(self : DrawioStencilCanvas, v : Double) -> Unit {
  self.state.alpha = v
}

///|
fn DrawioStencilCanvas::set_fill_alpha(self : DrawioStencilCanvas, v : Double) -> Unit {
  self.state.fill_alpha = v
}

///|
fn DrawioStencilCanvas::set_stroke_alpha(self : DrawioStencilCanvas, v : Double) -> Unit {
  self.state.stroke_alpha = v
}

///|
fn DrawioStencilCanvas::set_fill_color(self : DrawioStencilCanvas, v : String) -> Unit {
  self.state.fill_color = if v == "none" { "" } else { v }
  self.state.gradient_color = ""
}

///|
fn DrawioStencilCanvas::set_gradient(
  self : DrawioStencilCanvas,
  color1 : String,
  color2 : String,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  direction : String,
  alpha1 : Double,
  alpha2 : Double,
) -> Unit {
  self.state.fill_color = color1
  self.state.gradient_fill_alpha = alpha1
  self.state.gradient_color = color2
  self.state.gradient_alpha = alpha2
  self.state.gradient_direction = direction
}

///|
fn DrawioStencilCanvas::set_stroke_color(self : DrawioStencilCanvas, v : String) -> Unit {
  self.state.stroke_color = if v == "none" { "" } else { v }
}

///|
fn DrawioStencilCanvas::set_stroke_width(self : DrawioStencilCanvas, v : Double) -> Unit {
  self.state.stroke_width = v
}

///|
fn DrawioStencilCanvas::set_dashed(self : DrawioStencilCanvas, v : Bool, fix : Bool) -> Unit {
  self.state.dashed = v
  self.state.fix_dash = fix
}

///|
fn DrawioStencilCanvas::set_dash_pattern(self : DrawioStencilCanvas, v : String) -> Unit {
  self.state.dash_pattern = v
}

///|
fn DrawioStencilCanvas::set_line_cap(self : DrawioStencilCanvas, v : String) -> Unit {
  self.state.line_cap = v
}

///|
fn DrawioStencilCanvas::set_line_join(self : DrawioStencilCanvas, v : String) -> Unit {
  self.state.line_join = v
}

///|
fn DrawioStencilCanvas::set_miter_limit(self : DrawioStencilCanvas, v : Double) -> Unit {
  self.state.miter_limit = v
}

///|
fn DrawioStencilCanvas::set_shadow(self : DrawioStencilCanvas, _ : Bool) -> Unit {
  // Shadows are drawn for a whole shape; the draw.io converter does not
  // draw them either.
}

///|
fn DrawioStencilCanvas::begin(self : DrawioStencilCanvas) -> Unit {
  self.path = Some(@cad.CadPath::new())
  self.last_x = 0.0
  self.last_y = 0.0
}

///|
fn DrawioStencilCanvas::ensure_path(self : DrawioStencilCanvas) -> Unit {
  if self.path is None {
    self.begin()
  }
}

///|
fn DrawioStencilCanvas::move_to(self : DrawioStencilCanvas, x : Double, y : Double) -> Unit {
  self.ensure_path()
  match self.path {
    Some(p) => p.move_to(x, y)
    None => ()
  }
  self.last_x = x
  self.last_y = y
}

///|
fn DrawioStencilCanvas::line_to(self : DrawioStencilCanvas, x : Double, y : Double) -> Unit {
  self.ensure_path()
  match self.path {
    Some(p) => p.line_to(x, y)
    None => ()
  }
  self.last_x = x
  self.last_y = y
}

///|
fn DrawioStencilCanvas::quad_to(
  self : DrawioStencilCanvas,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) -> Unit {
  self.ensure_path()
  // Quadratic to cubic: c1 = p0 + 2/3(c - p0), c2 = p3 + 2/3(c - p3).
  let cx = x1
  let cy = y1
  let c1x = self.last_x + (cx - self.last_x) * (2.0 / 3.0)
  let c1y = self.last_y + (cy - self.last_y) * (2.0 / 3.0)
  let c2x = x2 + (cx - x2) * (2.0 / 3.0)
  let c2y = y2 + (cy - y2) * (2.0 / 3.0)
  match self.path {
    Some(p) =>
      p.cubic_to({ x: c1x, y: c1y }, { x: c2x, y: c2y }, { x: x2, y: y2 })
    None => ()
  }
  self.last_x = x2
  self.last_y = y2
}

///|
fn DrawioStencilCanvas::curve_to(
  self : DrawioStencilCanvas,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  x3 : Double,
  y3 : Double,
) -> Unit {
  self.ensure_path()
  match self.path {
    Some(p) => p.cubic_to({ x: x1, y: y1 }, { x: x2, y: y2 }, { x: x3, y: y3 })
    None => ()
  }
  self.last_x = x3
  self.last_y = y3
}

///|
/// An SVG elliptical arc from the last point to (x, y).
fn DrawioStencilCanvas::arc_to(
  self : DrawioStencilCanvas,
  rx : Double,
  ry : Double,
  angle : Double,
  large_arc : Bool,
  sweep : Bool,
  x : Double,
  y : Double,
) -> Unit {
  let curves = drawio_arc_to_curves(
    self.last_x, self.last_y, rx, ry, angle, large_arc, sweep, x, y,
  )
  let mut i = 0
  while i + 5 < curves.length() {
    self.curve_to(curves[i], curves[i + 1], curves[i + 2], curves[i + 3], curves[i + 4], curves[i + 5])
    i += 6
  }
}

///|
fn DrawioStencilCanvas::close(self : DrawioStencilCanvas) -> Unit {
  match self.path {
    Some(p) => p.close()
    None => ()
  }
}

///|
fn DrawioStencilCanvas::rect(self : DrawioStencilCanvas, x : Double, y : Double, w : Double, h : Double) -> Unit {
  self.begin()
  match self.path {
    Some(p) =>
      p.polyline([
        { x, y },
        { x: x + w, y },
        { x: x + w, y: y + h },
        { x, y: y + h },
      ], true)
    None => ()
  }
}

///|
fn DrawioStencilCanvas::roundrect(
  self : DrawioStencilCanvas,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  dx : Double,
  dy : Double,
) -> Unit {
  if dx <= 0.0 && dy <= 0.0 {
    self.rect(x, y, w, h)
    return
  }
  if dx == dy || dx <= 0.0 || dy <= 0.0 {
    let r = Double::max(dx, dy).min(Double::min(w, h) / 2.0)
    self.begin()
    match self.path {
      Some(p) => drawio_rounded_path(p, x, y, w, h, r)
      None => ()
    }
    return
  }
  let dx = dx.min(w / 2.0)
  let dy = dy.min(h / 2.0)
  let k = 0.5522847498
  self.move_to(x + dx, y)
  self.line_to(x + w - dx, y)
  self.curve_to(x + w - dx + dx * k, y, x + w, y + dy - dy * k, x + w, y + dy)
  self.line_to(x + w, y + h - dy)
  self.curve_to(x + w, y + h - dy + dy * k, x + w - dx + dx * k, y + h, x + w - dx, y + h)
  self.line_to(x + dx, y + h)
  self.curve_to(x + dx - dx * k, y + h, x, y + h - dy + dy * k, x, y + h - dy)
  self.line_to(x, y + dy)
  self.curve_to(x, y + dy - dy * k, x + dx - dx * k, y, x + dx, y)
  self.close()
}

///|
fn DrawioStencilCanvas::ellipse(self : DrawioStencilCanvas, x : Double, y : Double, w : Double, h : Double) -> Unit {
  self.begin()
  match self.path {
    Some(p) =>
      p.ellipse(
        { x: x + w / 2.0, y: y + h / 2.0 },
        { x: w / 2.0, y: 0.0 },
        if w == 0.0 { 1.0 } else { h / w },
      )
    None => ()
  }
}

///|
fn DrawioStencilCanvas::fill(self : DrawioStencilCanvas) -> Unit {
  self.paint(true, false)
}

///|
fn DrawioStencilCanvas::stroke(self : DrawioStencilCanvas) -> Unit {
  self.paint(false, true)
}

///|
fn DrawioStencilCanvas::fill_and_stroke(self : DrawioStencilCanvas) -> Unit {
  self.paint(true, true)
}

///|
/// Paint the current path with fill and/or stroke (mxSvgCanvas2D state).
fn DrawioStencilCanvas::paint(self : DrawioStencilCanvas, fill : Bool, stroke : Bool) -> Unit {
  let path = match self.path {
    Some(p) => p
    None => return
  }
  self.path = None
  if path.is_empty() {
    return
  }
  let s = self.state
  let do_fill = fill && s.fill_color != "" && s.gradient_color == ""
  let do_stroke = stroke && s.stroke_color != ""
  if !do_fill && !do_stroke {
    return
  }
  if do_fill {
    match drawio_parse_color(s.fill_color) {
      Some(c1) => {
        let alpha = s.alpha * s.fill_alpha
        if s.gradient_color != "" {
          // A two-stop gradient over the path's bounding box.
          match drawio_parse_color(s.gradient_color) {
            Some(c2raw) => {
              let bounds = path.bounds()
              let c1a = drawio_color_alpha_mul(c1, alpha * s.gradient_fill_alpha)
              let c2a = drawio_color_alpha_mul(c2raw, alpha * s.gradient_alpha)
              let (p0, p1, radial, r1) = drawio_gradient_ends(
                bounds, s.gradient_direction,
              )
              let stops : Array[@core.ColorStop] = [
                { offset: 0.0, color: c1a.reinterpret_as_int() },
                { offset: 1.0, color: c2a.reinterpret_as_int() },
              ]
              let gradient : @cad.CadGradient = {
                radial,
                p0,
                p1,
                r0: 0.0,
                r1,
                stops,
              }
              self.drawing.fill(path.transform(self.matrix), @cad.Fill::gradient(gradient), false)
            }
            None => ()
          }
        } else {
          let col = drawio_color_alpha_mul(c1, alpha)
          if (col & 0xffU) != 0U {
            self.drawing.fill(path.transform(self.matrix), @cad.Fill::solid(col), false)
          }
        }
      }
      None => ()
    }
  }
  if do_stroke {
    match drawio_parse_color(s.stroke_color) {
      Some(c) => {
        let col = drawio_color_alpha_mul(c, s.alpha * s.stroke_alpha)
        if (col & 0xffU) != 0U {
          let cap = if s.line_cap == "round" {
            @cad.CAP_ROUND
          } else if s.line_cap == "square" {
            @cad.CAP_SQUARE
          } else {
            @cad.CAP_BUTT
          }
          let join = if s.line_join == "round" {
            @cad.JOIN_ROUND
          } else if s.line_join == "bevel" {
            @cad.JOIN_BEVEL
          } else {
            @cad.JOIN_MITER
          }
          // Dashed patterns are in stroke-width units (SVG dasharray).
          let dash = if s.dashed {
            drawio_dash_segments(s.stroke_width, s.dash_pattern, if s.fix_dash { 1.0 } else { s.stroke_width })
          } else {
            None
          }
          self.drawing.stroke(path.transform(self.matrix), @cad.Pen::new(
            color=col,
            width=0.0,
            world_width=Double::max(0.01, s.stroke_width),
            dash~,
            cap~,
            join~,
            miter=s.miter_limit,
          ))
        }
      }
      None => ()
    }
  }
}

///|
/// The ends of a gradient over a box, as upstream fillGradient.
fn drawio_gradient_ends(
  bounds : @cad.Rect,
  direction : String,
) -> (@cad.Point, @cad.Point, Bool, Double) {
  let x = bounds.min.x
  let y = bounds.min.y
  let w = bounds.w()
  let h = bounds.h()
  if direction == "radial" {
    return (
      { x: x + w / 2.0, y: y + h / 2.0 },
      { x: x + w / 2.0, y: y + h / 2.0 },
      true,
      Double::max(w, h) / 2.0,
    )
  }
  let mut x0 = x
  let mut y0 = y
  let mut x1 = x
  let mut y1 = y + h
  if direction == "east" {
    x1 = x + w
    y1 = y
  } else if direction == "north" {
    y0 = y + h
    y1 = y
  } else if direction == "west" {
    x0 = x + w
    x1 = x
    y1 = y
  }
  ({ x: x0, y: y0 }, { x: x1, y: y1 }, false, 0.0)
}

///|
/// Dash segments in drawing units: the pattern values times the stroke
/// width (or 1 with fixDash), like upstream dashKey.
fn drawio_dash_segments(_stroke_width : Double, pattern : String, factor : Double) -> Array[Double]? {
  let out : Array[Double] = []
  let mut all_zero = true
  for tok in pattern.split(" ") {
    if tok == "" {
      continue
    }
    let v = drawio_leading_float(tok.to_string())
    match v {
      Some(f) => {
        if f < 0.0 {
          return None
        }
        if f != 0.0 {
          all_zero = false
        }
        out.push(f * factor)
      }
      None => return None
    }
  }
  if out.is_empty() || all_zero {
    None
  } else {
    Some(out)
  }
}

///|
/// SVG endpoint arc to cubic curves (mxAbstractCanvas2D.arcTo), ported from
/// the upstream canvas. Returns x1,y1,x2,y2,x,y triples.
fn drawio_arc_to_curves(
  x1 : Double,
  y1 : Double,
  rx : Double,
  ry : Double,
  angle : Double,
  large_arc : Bool,
  sweep : Bool,
  x2 : Double,
  y2 : Double,
) -> Array[Double] {
  let out : Array[Double] = []
  if rx == 0.0 || ry == 0.0 || (x1 == x2 && y1 == y2) {
    out.push(x1)
    out.push(y1)
    out.push(x2)
    out.push(y2)
    out.push(x2)
    out.push(y2)
    return out
  }
  let mut rx = rx.abs()
  let mut ry = ry.abs()
  let phi = angle * 3.141592653589793 / 180.0
  let cos_phi = @math.cos(phi)
  let sin_phi = @math.sin(phi)
  let dx = (x1 - x2) / 2.0
  let dy = (y1 - y2) / 2.0
  let x1p = cos_phi * dx + sin_phi * dy
  let y1p = -sin_phi * dx + cos_phi * dy
  // Correct out-of-range radii.
  let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
  if lambda > 1.0 {
    let s = lambda.sqrt()
    rx *= s
    ry *= s
  }
  let rx2 = rx * rx
  let ry2 = ry * ry
  let x1p2 = x1p * x1p
  let y1p2 = y1p * y1p
  let mut num = rx2 * ry2 - rx2 * y1p2 - ry2 * x1p2
  num = num.max(0.0)
  let den = rx2 * y1p2 + ry2 * x1p2
  let mut coef = if den == 0.0 { 0.0 } else { (num / den).sqrt() }
  if large_arc == sweep {
    coef = -coef
  }
  let cxp = coef * rx * y1p / ry
  let cyp = -coef * ry * x1p / rx
  let cx = cos_phi * cxp - sin_phi * cyp + (x1 + x2) / 2.0
  let cy = sin_phi * cxp + cos_phi * cyp + (y1 + y2) / 2.0
  let angle_of = fn(ux : Double, uy : Double, vx : Double, vy : Double) -> Double {
    let dot = ux * vx + uy * vy
    let len = ((ux * ux + uy * uy) * (vx * vx + vy * vy)).sqrt()
    let mut a = if len == 0.0 { 0.0 } else { (dot / len).max(-1.0).min(1.0) }
    if ux * vy - uy * vx < 0.0 {
      a = -a
    }
    a
  }
  let theta1 = angle_of(1.0, 0.0, (x1p - cxp) / rx, (y1p - cyp) / ry)
  let mut dtheta = angle_of(
    (x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry,
  )
  if !sweep && dtheta > 0.0 {
    dtheta -= 2.0 * 3.141592653589793
  } else if sweep && dtheta < 0.0 {
    dtheta += 2.0 * 3.141592653589793
  }
  // Approximate with cubic segments of at most 90 degrees.
  let segments = (dtheta.abs() / (3.141592653589793 / 2.0)).ceil().to_int().max(1)
  let delta = dtheta / segments.to_double()
  let alpha = 4.0 / 3.0 * @math.tan(delta / 4.0)
  let point_at = fn(t : Double) -> (Double, Double) {
    let ct = @math.cos(t)
    let st = @math.sin(t)
    let ex = rx * ct
    let ey = ry * st
    let dx = -rx * st
    let dy = ry * ct
    let x = cos_phi * ex - sin_phi * ey
    let y = sin_phi * ex + cos_phi * ey
    (cx + x, cy + y)
  }
  // derivative at theta (unrotated frame scaled)
  let deriv_at = fn(t : Double) -> (Double, Double) {
    let ct = @math.cos(t)
    let st = @math.sin(t)
    let dx = -rx * st
    let dy = ry * ct
    (cos_phi * dx - sin_phi * dy, sin_phi * dx + cos_phi * dy)
  }
  let mut t = theta1
  for _ in 0..<segments {
    let t2 = t + delta
    let (px, py) = point_at(t)
    let (x2p, y2p) = point_at(t2)
    let (d1x, d1y) = deriv_at(t)
    let (d2x, d2y) = deriv_at(t2)
    let c1x = px + alpha * d1x
    let c1y = py + alpha * d1y
    let ex = x2p - alpha * d2x
    let ey = y2p - alpha * d2y
    out.push(c1x)
    out.push(c1y)
    out.push(ex)
    out.push(ey)
    out.push(x2p)
    out.push(y2p)
    t = t2
  }
  out
}
