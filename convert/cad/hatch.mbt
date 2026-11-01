///|
/// A family of parallel lines of a hatch pattern, in drawing units.
pub(all) struct PatternLine {
  angle : Double
  base : Point
  offset : Point
  dash : Array[Double]?
}

///|
/// The most lines drawn for one hatch.
pub const MAX_HATCH_LINES : Int = 20000

///|
/// The most line numbers counted from a pattern's base.
let max_line_number : Double = 1.0e15

///|
/// Draw the lines of a hatch pattern clipped by `boundary`. Returns false,
/// drawing nothing, when the pattern would need more than
/// `MAX_HATCH_LINES` lines.
pub fn Drawing::hatch(
  self : Drawing,
  boundary : CadPath,
  lines : Array[PatternLine],
  pen : Pen,
) -> Bool {
  let bounds = boundary.bounds()
  if !bounds.is_valid() {
    return true
  }
  let corners = [
    bounds.min,
    { x: bounds.max.x, y: bounds.min.y },
    bounds.max,
    { x: bounds.min.x, y: bounds.max.y },
  ]
  let paths : Array[CadPath] = []
  let pens : Array[Pen] = []
  let mut total = 0
  for pattern in lines {
    let u = { x: @math.cos(pattern.angle), y: @math.sin(pattern.angle) }
    let n = { x: -u.y, y: u.x }
    let dn = pattern.offset.x * n.x + pattern.offset.y * n.y
    let size = Double::max(bounds.w(), bounds.h())
    if dn.abs() < 1.0e-9 * size || dn.is_nan() {
      continue
    }
    let du = pattern.offset.x * u.x + pattern.offset.y * u.y
    let bn = pattern.base.x * n.x + pattern.base.y * n.y
    let bu = pattern.base.x * u.x + pattern.base.y * u.y
    let mut nmin = 1.0 / 0.0
    let mut nmax = -1.0 / 0.0
    let mut umin = 1.0 / 0.0
    let mut umax = -1.0 / 0.0
    for corner in corners {
      let cn = corner.x * n.x + corner.y * n.y
      let cu = corner.x * u.x + corner.y * u.y
      nmin = Double::min(nmin, cn)
      nmax = Double::max(nmax, cn)
      umin = Double::min(umin, cu)
      umax = Double::max(umax, cu)
    }
    let k0 = (nmin - bn) / dn
    let k1 = (nmax - bn) / dn
    let (first, last) = if k0 > k1 { (k1, k0) } else { (k0, k1) }
    let ka = first.ceil()
    let kb = last.floor()
    if ka.abs() > max_line_number || kb.abs() > max_line_number {
      continue
    }
    let count = (kb - ka + 1.0).to_int()
    if count <= 0 {
      continue
    }
    if count > MAX_HATCH_LINES || total > MAX_HATCH_LINES - count {
      return false
    }
    total += count
    let (line_dash, dash_offset) = dash_pattern(pattern.dash)
    let mut pattern_length = 0.0
    match line_dash {
      Some(values) => {
        for value in values {
          pattern_length += value
        }
      }
      None => ()
    }
    let path = CadPath::new()
    for index in 0..<count {
      let k = ka + index.to_double()
      let start_u = bu + k * du
      let mut start = umin
      if pattern_length > 0.0 {
        start = start_u + ((umin - start_u) / pattern_length).floor() * pattern_length
      }
      let line_n = bn + k * dn
      let a = {
        x: u.x * start + n.x * line_n,
        y: u.y * start + n.y * line_n,
      }
      let e = {
        x: u.x * umax + n.x * line_n,
        y: u.y * umax + n.y * line_n,
      }
      path.move_to(a.x, a.y)
      path.line_to(e.x, e.y)
    }
    let line_pen = pen
    match line_dash {
      Some(values) => {
        line_pen.dash = Some(values)
        line_pen.dash_offset = dash_offset
      }
      None => ()
    }
    paths.push(path)
    pens.push(line_pen)
  }
  self.begin(Some(boundary))
  for index, path in paths {
    self.stroke(path, pens[index])
  }
  self.end()
  true
}

///|
/// Convert a CAD line type pattern (positive: a dash, negative: a gap,
/// zero: a dot) into a dash array that starts with a dash and alternates
/// dashes and gaps, and the offset into it.
pub fn dash_pattern(elements : Array[Double]?) -> (Array[Double]?, Double) {
  let values = match elements {
    Some(value) => value
    None => return (None, 0.0)
  }
  // Each run is a dash flag and its length.
  let flags : Array[Bool] = []
  let lengths : Array[Double] = []
  for value in values {
    let dash = value >= 0.0
    if !flags.is_empty() && flags[flags.length() - 1] == dash {
      lengths[lengths.length() - 1] += value.abs()
    } else {
      flags.push(dash)
      lengths.push(value.abs())
    }
  }
  let mut phase = 0.0
  if flags.length() >= 2 && flags[0] == flags[flags.length() - 1] {
    phase = lengths[lengths.length() - 1]
    lengths[0] += lengths[lengths.length() - 1]
    ignore(flags.pop())
    ignore(lengths.pop())
  }
  if flags.length() < 2 {
    return (None, 0.0)
  }
  let mut total = 0.0
  for length in lengths {
    total += length
  }
  if total <= 0.0 {
    return (None, 0.0)
  }
  if !flags[0] {
    // start with the dash
    phase += total - lengths[0]
    let first_flag = flags[0]
    let first_length = lengths[0]
    let new_flags : Array[Bool] = []
    let new_lengths : Array[Double] = []
    for index in 1..<flags.length() {
      new_flags.push(flags[index])
      new_lengths.push(lengths[index])
    }
    new_flags.push(first_flag)
    new_lengths.push(first_length)
    let dash = new_lengths
    return (Some(dash), phase % total)
  }
  (Some(lengths), phase % total)
}
