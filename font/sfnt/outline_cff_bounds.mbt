///|
fn cff_cubic_at(
  p0 : Double,
  p1 : Double,
  p2 : Double,
  p3 : Double,
  t : Double,
) -> Double {
  let u = 1.0 - t
  u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3
}

///|
fn cff_cubic_extrema(
  p0 : Double,
  p1 : Double,
  p2 : Double,
  p3 : Double,
) -> Array[Double] {
  let a = -p0 + 3.0 * p1 - 3.0 * p2 + p3
  let b = 2.0 * (p0 - 2.0 * p1 + p2)
  let c = p1 - p0
  let result : Array[Double] = []
  if a.abs() < 1.0e-9 {
    if b.abs() > 1.0e-9 {
      let t = -c / b
      if t > 0.0 && t < 1.0 {
        result.push(t)
      }
    }
    return result
  }
  let delta = b * b - 4.0 * a * c
  if delta < 0.0 {
    return result
  }
  let root = delta.sqrt()
  for t in [(-b + root) / (2.0 * a), (-b - root) / (2.0 * a)] {
    if t > 0.0 && t < 1.0 {
      result.push(t)
    }
  }
  result
}

///|
/// Find the bounds of the CFF outline, including cubic Bézier extrema.
/// An empty, unreadable or out-of-range glyph has no bounds.
pub fn CffOutlines::bounds(
  self : CffOutlines,
  glyph : Int32,
) -> (Double, Double, Double, Double)? {
  let (ok, commands) = self.outline(glyph)
  if !ok || commands.length() == 0 {
    return None
  }
  let mut xmin = 0.0
  let mut ymin = 0.0
  let mut xmax = 0.0
  let mut ymax = 0.0
  let mut x = 0.0
  let mut y = 0.0
  let mut any = false
  for command in commands {
    let points : Array[(Double, Double)] = []
    match command {
      Move(a, b) | Line(a, b) => points.push((a, b))
      Cubic(a, b, c, d, e, f) => {
        for t in cff_cubic_extrema(x, a, c, e) {
          points.push(
            (cff_cubic_at(x, a, c, e, t), cff_cubic_at(y, b, d, f, t)),
          )
        }
        for t in cff_cubic_extrema(y, b, d, f) {
          points.push(
            (cff_cubic_at(x, a, c, e, t), cff_cubic_at(y, b, d, f, t)),
          )
        }
        points.push((e, f))
      }
      _ => ()
    }
    for (px, py) in points {
      if !any {
        xmin = px
        xmax = px
        ymin = py
        ymax = py
        any = true
      } else {
        xmin = Double::min(xmin, px)
        xmax = Double::max(xmax, px)
        ymin = Double::min(ymin, py)
        ymax = Double::max(ymax, py)
      }
      x = px
      y = py
    }
  }
  if any {
    Some((xmin, ymin, xmax, ymax))
  } else {
    None
  }
}
