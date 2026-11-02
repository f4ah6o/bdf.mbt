///|
/// Where an edge meets a shape's outline. This is a practical subset of
/// mxPerimeter: the analytic ellipse, the box for every other kind, and
/// the polygon for the shapes the converter draws as polygons. The
/// vertices come from the same table as the painting, so an edge always
/// ends on the outline that is drawn.
fn drawio_segment_intersection(
  ax : Double,
  ay : Double,
  bx : Double,
  by : Double,
  cx : Double,
  cy : Double,
  dx : Double,
  dy : Double,
) -> (Double, Double)? {
  let r_x = bx - ax
  let r_y = by - ay
  let s_x = dx - cx
  let s_y = dy - cy
  let denominator = r_x * s_y - r_y * s_x
  if denominator.abs() < 1.0e-12 {
    return None
  }
  let q_x = cx - ax
  let q_y = cy - ay
  let t = (q_x * s_y - q_y * s_x) / denominator
  let u = (q_x * r_y - q_y * r_x) / denominator
  if t < 0.0 || t > 1.0 || u < 0.0 || u > 1.0 {
    return None
  }
  Some((ax + t * r_x, ay + t * r_y))
}

///|
fn drawio_polygon_perimeter(
  vertices : Array[(Double, Double)],
  center : (Double, Double),
  toward : (Double, Double),
) -> (Double, Double)? {
  let count = vertices.length()
  if count < 3 {
    return None
  }
  let mut best : (Double, Double)? = None
  let mut best_distance = 0.0
  for index in 0..<count {
    let from = vertices[index]
    let to = vertices[(index + 1) % count]
    match drawio_segment_intersection(
      center.0,
      center.1,
      toward.0,
      toward.1,
      from.0,
      from.1,
      to.0,
      to.1,
    ) {
      Some(point) => {
        let delta_x = toward.0 - point.0
        let delta_y = toward.1 - point.1
        let distance = delta_x * delta_x + delta_y * delta_y
        if best is None || distance < best_distance {
          best = Some(point)
          best_distance = distance
        }
      }
      None => ()
    }
  }
  best
}

///|
fn drawio_shape_perimeter(
  kind : DrawioShapeKind,
  style : String,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  toward_x : Double,
  toward_y : Double,
) -> (Double, Double) {
  let cx = x + w / 2.0
  let cy = y + h / 2.0
  let dx = toward_x - cx
  let dy = toward_y - cy
  if (dx.abs() < 1.0e-9 && dy.abs() < 1.0e-9) || w <= 0.0 || h <= 0.0 {
    return (cx, cy)
  }
  if kind == DkEllipse || kind == DkDoubleEllipse {
    let a = w / 2.0
    let b = h / 2.0
    let scale = 1.0 / ((dx * dx) / (a * a) + (dy * dy) / (b * b)).sqrt()
    return (cx + dx * scale, cy + dy * scale)
  }
  if kind == DkRhombus || kind == DkTriangle || kind == DkHexagon ||
    kind == DkParallelogram || kind == DkTrapezoid || kind == DkStep ||
    kind == DkOctagon || kind == DkCross || kind == DkStar {
    let vertices = drawio_shape_vertices(kind, style, x, y, w, h)
    match drawio_polygon_perimeter(vertices, (cx, cy), (toward_x, toward_y)) {
      Some(point) => return point
      None => ()
    }
  }
  // The box, narrowed for the shapes whose body is not the whole bounds.
  let top = y
  let mut bottom = y + h
  if kind == DkCallout {
    let size = Double::min(
      Double::max(drawio_num_from_style(style, "size", 30.0), 4.0),
      Double::min(w * 0.5, h * 0.5),
    )
    bottom = y + Double::max(h - size, 0.0)
  }
  let half_w = w / 2.0
  let half_h = (bottom - top) / 2.0
  let mid_y = (top + bottom) / 2.0
  let mut scale = 1.0e300
  if dx.abs() > 1.0e-12 {
    scale = Double::min(scale, half_w / dx.abs())
  }
  if dy.abs() > 1.0e-12 {
    scale = Double::min(scale, half_h / dy.abs())
  }
  if scale >= 1.0e300 {
    return (cx, mid_y)
  }
  (cx + dx * scale, mid_y + dy * scale)
}
