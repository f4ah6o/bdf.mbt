///|
/// A glyph outline operation in font units, with the y-axis pointing up.
pub(all) enum OutlineCommand {
  Move(Double, Double)
  Line(Double, Double)
  Quad(Double, Double, Double, Double)
  Cubic(Double, Double, Double, Double, Double, Double)
  Close
} derive(Eq, Debug)

///|
struct OutlineMatrix {
  a : Double
  b : Double
  c : Double
  d : Double
  e : Double
  f : Double
}

///|
fn OutlineMatrix::point(
  self : OutlineMatrix,
  x : Double,
  y : Double,
) -> (Double, Double) {
  (self.a * x + self.c * y + self.e, self.b * x + self.d * y + self.f)
}

///|
fn OutlineMatrix::compose(
  self : OutlineMatrix,
  n : OutlineMatrix,
) -> OutlineMatrix {
  {
    a: self.a * n.a + self.c * n.b,
    b: self.b * n.a + self.d * n.b,
    c: self.a * n.c + self.c * n.d,
    d: self.b * n.c + self.d * n.d,
    e: self.a * n.e + self.c * n.f + self.e,
    f: self.b * n.e + self.d * n.f + self.f,
  }
}

///|
fn outline_glyph_data(font : Font, glyph : Int32) -> BytesView? {
  if glyph < 0 ||
    glyph >= font.metrics.glyph_count ||
    !font.tables.contains("glyf") ||
    !font.tables.contains("loca") {
    return None
  }
  let glyf = sfnt_table(font.source, font.tables, "glyf")
  let loca = sfnt_table(font.source, font.tables, "loca")
  let head = sfnt_table(font.source, font.tables, "head")
  if head.length() < 54 {
    return None
  }
  let long = u16(head, 50) != 0
  let unit = if long { 4 } else { 2 }
  let p = glyph * unit
  if p + unit * 2 > loca.length() {
    return None
  }
  let start = if long {
    u32(loca, p).to_int64()
  } else {
    u16(loca, p).to_int64() * 2L
  }
  let end = if long {
    u32(loca, p + unit).to_int64()
  } else {
    u16(loca, p + unit).to_int64() * 2L
  }
  if start == end {
    return Some(glyf[0:0])
  }
  if start > end || end > glyf.length().to_int64() || end - start < 10L {
    return None
  }
  Some(glyf[start.to_int():end.to_int()])
}

///|
fn outline_contour(
  out : Array[OutlineCommand],
  matrix : OutlineMatrix,
  xs : Array[Double],
  ys : Array[Double],
  flags : Array[Int32],
  start : Int32,
  end : Int32,
) -> Unit {
  let n = end - start + 1
  if n <= 0 {
    return
  }
  let mut first = -1
  for i in 0..<n {
    if (flags[start + i] & 1) != 0 {
      first = i
      break
    }
  }
  let sx = if first < 0 {
    (xs[start] + xs[end]) / 2.0
  } else {
    xs[start + first]
  }
  let sy = if first < 0 {
    (ys[start] + ys[end]) / 2.0
  } else {
    ys[start + first]
  }
  let (x0, y0) = matrix.point(sx, sy)
  out.push(Move(x0, y0))
  let from = if first < 0 { 0 } else { first + 1 }
  let mut cx = 0.0
  let mut cy = 0.0
  let mut pending = false
  for k in 0..<n {
    let i = start + (from + k) % n
    let x = xs[i]
    let y = ys[i]
    let on = (flags[i] & 1) != 0
    if k == n - 1 && on && x == sx && y == sy && !pending {
      break
    }
    if on {
      if pending {
        let (a, b) = matrix.point(cx, cy)
        let (c, d) = matrix.point(x, y)
        out.push(Quad(a, b, c, d))
        pending = false
      } else {
        let (a, b) = matrix.point(x, y)
        out.push(Line(a, b))
      }
    } else {
      if pending {
        let (a, b) = matrix.point(cx, cy)
        let (c, d) = matrix.point((cx + x) / 2.0, (cy + y) / 2.0)
        out.push(Quad(a, b, c, d))
      }
      cx = x
      cy = y
      pending = true
    }
  }
  if pending {
    let (a, b) = matrix.point(cx, cy)
    let (c, d) = matrix.point(sx, sy)
    out.push(Quad(a, b, c, d))
  }
  out.push(Close)
}

///|
fn outline_simple(
  data : BytesView,
  contours : Int32,
  out : Array[OutlineCommand],
  matrix : OutlineMatrix,
  left : Ref[Int32],
) -> Bool {
  let mut pos = 10
  if pos + 2 * contours + 2 > data.length() {
    return false
  }
  let ends : Array[Int32] = []
  let mut points = 0
  for i in 0..<contours {
    let end = u16(data, pos + 2 * i)
    if i > 0 && end < ends[i - 1] {
      return false
    }
    ends.push(end)
    points = end + 1
  }
  left.val -= points
  if left.val < 0 {
    return false
  }
  pos += 2 * contours
  pos += 2 + u16(data, pos)
  let flags : Array[Int32] = []
  while flags.length() < points {
    if pos >= data.length() {
      return false
    }
    let f = data[pos].to_int()
    pos += 1
    flags.push(f)
    if (f & 8) != 0 {
      if pos >= data.length() {
        return false
      }
      let repeat = data[pos].to_int()
      pos += 1
      for _ in 0..<repeat {
        if flags.length() < points {
          flags.push(f)
        }
      }
    }
  }
  let coords : Array[Array[Double]] = []
  for axis in 0..<2 {
    let short = if axis == 0 { 2 } else { 4 }
    let same = if axis == 0 { 16 } else { 32 }
    let values : Array[Double] = []
    let mut value = 0L
    for flag in flags {
      if (flag & short) != 0 {
        if pos >= data.length() {
          return false
        }
        let delta = data[pos].to_int64()
        pos += 1
        value += if (flag & same) == 0 { -delta } else { delta }
      } else if (flag & same) == 0 {
        if pos + 2 > data.length() {
          return false
        }
        value += s16(data, pos).to_int64()
        pos += 2
      }
      values.push(value.to_double())
    }
    coords.push(values)
  }
  let mut start = 0
  for end in ends {
    outline_contour(out, matrix, coords[0], coords[1], flags, start, end)
    start = end + 1
  }
  true
}

///|
fn outline_glyf(
  font : Font,
  glyph : Int32,
  out : Array[OutlineCommand],
  matrix : OutlineMatrix,
  depth : Int32,
  left : Ref[Int32],
) -> Bool {
  guard outline_glyph_data(font, glyph) is Some(data) else { return false }
  if data.length() == 0 {
    return true
  }
  let contours = s16(data, 0)
  if contours >= 0 {
    return outline_simple(data, contours, out, matrix, left)
  }
  if depth > 8 {
    return false
  }
  let mut pos = 10
  while true {
    if pos + 4 > data.length() {
      return false
    }
    let flags = u16(data, pos)
    let component = u16(data, pos + 2)
    pos += 4
    let mut dx = 0.0
    let mut dy = 0.0
    if (flags & 1) != 0 {
      if pos + 4 > data.length() {
        return false
      }
      dx = s16(data, pos).to_double()
      dy = s16(data, pos + 2).to_double()
      pos += 4
    } else {
      if pos + 2 > data.length() {
        return false
      }
      let x = data[pos].to_int()
      let y = data[pos + 1].to_int()
      dx = (if x >= 128 { x - 256 } else { x }).to_double()
      dy = (if y >= 128 { y - 256 } else { y }).to_double()
      pos += 2
    }
    if (flags & 2) == 0 {
      dx = 0.0
      dy = 0.0
    }
    let mut a = 1.0
    let mut b = 0.0
    let mut c = 0.0
    let mut d = 1.0
    if (flags & 8) != 0 {
      if pos + 2 > data.length() {
        return false
      }
      a = s16(data, pos).to_double() / 16384.0
      d = a
      pos += 2
    } else if (flags & 0x40) != 0 {
      if pos + 4 > data.length() {
        return false
      }
      a = s16(data, pos).to_double() / 16384.0
      d = s16(data, pos + 2).to_double() / 16384.0
      pos += 4
    } else if (flags & 0x80) != 0 {
      if pos + 8 > data.length() {
        return false
      }
      a = s16(data, pos).to_double() / 16384.0
      b = s16(data, pos + 2).to_double() / 16384.0
      c = s16(data, pos + 4).to_double() / 16384.0
      d = s16(data, pos + 6).to_double() / 16384.0
      pos += 8
    }
    left.val -= 1
    if left.val < 0 ||
      !outline_glyf(
        font,
        component,
        out,
        matrix.compose({ a, b, c, d, e: dx, f: dy, }),
        depth + 1,
        left,
      ) {
      return false
    }
    if (flags & 0x20) == 0 {
      return true
    }
  }
  false
}

///|
/// Decode a TrueType glyph's outline. The Boolean reports whether the glyph
/// was readable; an empty glyph is readable but produces no operations. Partial
/// operations may be returned for a damaged composite. CFF is not handled here.
pub fn Font::outline_truetype(
  self : Font,
  glyph : Int32,
) -> (Bool, Array[OutlineCommand]) {
  let out : Array[OutlineCommand] = []
  if self.metrics.is_cff {
    return (false, out)
  }
  let ok = outline_glyf(
    self,
    glyph,
    out,
    { a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 0.0, f: 0.0, },
    0,
    Ref(262144),
  )
  (ok, out)
}

///|
/// TrueType glyph bounds in font units from the glyf header. Empty or unreadable
/// glyphs return None; this does not decode CFF charstrings.
pub fn Font::bounds_truetype(
  self : Font,
  glyph : Int32,
) -> (Double, Double, Double, Double)? {
  if self.metrics.is_cff ||
    glyph < 0 ||
    glyph >= self.metrics.glyph_count ||
    !self.tables.contains("glyf") ||
    !self.tables.contains("loca") {
    return None
  }
  let glyf = sfnt_table(self.source, self.tables, "glyf")
  let loca = sfnt_table(self.source, self.tables, "loca")
  let head = sfnt_table(self.source, self.tables, "head")
  if head.length() < 54 {
    return None
  }
  let long = u16(head, 50) != 0
  let unit = if long { 4 } else { 2 }
  let p = glyph * unit
  let start = if long {
    u32(loca, p).to_int64()
  } else {
    u16(loca, p).to_int64() * 2L
  }
  let end = if long {
    u32(loca, p + unit).to_int64()
  } else {
    u16(loca, p + unit).to_int64() * 2L
  }
  if end - start < 10L || end > glyf.length().to_int64() {
    return None
  }
  let pos = start.to_int()
  Some(
    (
      s16(glyf, pos + 2).to_double(),
      s16(glyf, pos + 4).to_double(),
      s16(glyf, pos + 6).to_double(),
      s16(glyf, pos + 8).to_double(),
    ),
  )
}
