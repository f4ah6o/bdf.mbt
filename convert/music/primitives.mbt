///|
/// An absolute path in staff-space coordinates.
pub(all) struct MusicOutline {
  verbs : Bytes
  coordinates : Array[Double]
}

///|
/// Primitive drawing command in staff-space coordinates.
pub(all) struct MusicPrimitive {
  kind : Int32
  glyph : String
  x : Double
  y : Double
  w : Double
  h : Double
  scale : Double
  scale_x : Double
  scale_y : Double
  width : Double
  dash : Double
  outline : MusicOutline?
  text : String
  align : Int32
  mark : Int32
}

///|
pub struct SkylineSegment {
  x0 : Double
  x1 : Double
  y : Double
}

///|
/// Drawing primitives and their upper and lower skylines.
pub struct MusicDrawing {
  primitives : Array[MusicPrimitive]
  top : Array[SkylineSegment]
  bottom : Array[SkylineSegment]
}

///|
pub fn MusicDrawing::new() -> MusicDrawing {
  { primitives: [], top: [], bottom: [], }
}

///|
pub fn MusicDrawing::primitives(self : MusicDrawing) -> Array[MusicPrimitive] {
  self.primitives.copy()
}

///|
fn MusicDrawing::box(
  self : MusicDrawing,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> Unit {
  let left = Double::min(x0, x1)
  let right = Double::max(x0, x1)
  self.top.push({ x0: left, x1: right, y: y0, })
  self.bottom.push({ x0: left, x1: right, y: y1, })
}

///|
fn primitive(
  kind : Int32,
  glyph : String,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  scale : Double,
  width : Double,
  dash : Double,
  outline : MusicOutline?,
  text : String,
  align : Int32,
  mark : Int32,
) -> MusicPrimitive {
  {
    kind,
    glyph,
    x,
    y,
    w,
    h,
    scale,
    scale_x: 1.0,
    scale_y: 1.0,
    width,
    dash,
    outline,
    text,
    align,
    mark,
  }
}

///|
/// Add a Bravura symbol and its bounding box.
pub fn MusicDrawing::glyph(
  self : MusicDrawing,
  name : String,
  x : Double,
  y : Double,
  scale : Double,
) -> Unit {
  match music_glyph(name) {
    None => ()
    Some(glyph) => {
      self.primitives.push(
        primitive(0, name, x, y, 0.0, 0.0, scale, 0.0, 0.0, None, "", 0, 0),
      )
      let (x0, y0, x1, y1) = glyph.bbox
      self.box(x + x0 * scale, y + y0 * scale, x + x1 * scale, y + y1 * scale)
    }
  }
}

///|
/// Add a non-uniformly scaled glyph, such as the brace spanning staves.
/// Upstream does not include these spanning glyphs in staff skylines.
pub fn MusicDrawing::spanning_glyph(
  self : MusicDrawing,
  name : String,
  x : Double,
  y : Double,
  scale_x : Double,
  scale_y : Double,
) -> Unit {
  match music_glyph(name) {
    None => ()
    Some(_) =>
      self.primitives.push({
        kind: 0,
        glyph: name,
        x,
        y,
        w: 0.0,
        h: 0.0,
        scale: 1.0,
        scale_x,
        scale_y,
        width: 0.0,
        dash: 0.0,
        outline: None,
        text: "",
        align: 0,
        mark: 0,
      })
  }
}

///|
pub fn MusicDrawing::rect(
  self : MusicDrawing,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit {
  self.primitives.push(
    primitive(1, "", x, y, w, h, 0.0, 0.0, 0.0, None, "", 0, 0),
  )
  self.box(x, y, x + w, y + h)
}

///|
pub fn MusicOutline::bounds(
  self : MusicOutline,
) -> (Double, Double, Double, Double) {
  let mut x0 = 1.0e9
  let mut y0 = 1.0e9
  let mut x1 = -1.0e9
  let mut y1 = -1.0e9
  for i in 0..<(self.coordinates.length() / 2) {
    let x = self.coordinates[2 * i]
    let y = self.coordinates[2 * i + 1]
    x0 = Double::min(x0, x)
    x1 = Double::max(x1, x)
    y0 = Double::min(y0, y)
    y1 = Double::max(y1, y)
  }
  (x0, y0, x1, y1)
}

///|
pub fn MusicDrawing::fill(self : MusicDrawing, outline : MusicOutline) -> Unit {
  self.primitives.push(
    primitive(2, "", 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, Some(outline), "", 0, 0),
  )
  let (x0, y0, x1, y1) = outline.bounds()
  self.box(x0, y0, x1, y1)
}

///|
pub fn MusicDrawing::line(
  self : MusicDrawing,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  width : Double,
  dash : Double,
) -> Unit {
  self.primitives.push(
    primitive(3, "", x0, y0, x1, y1, 0.0, width, dash, None, "", 0, 0),
  )
  self.box(
    Double::min(x0, x1),
    Double::min(y0, y1) - width / 2.0,
    Double::max(x0, x1),
    Double::max(y0, y1) + width / 2.0,
  )
}

///|
/// Add a text line given its measured width and ascent/descent in staff spaces.
pub fn MusicDrawing::text(
  self : MusicDrawing,
  text : String,
  x : Double,
  y : Double,
  align : Int32,
  width : Double,
  ascent : Double,
  descent : Double,
) -> Unit {
  if text == "" {
    return
  }
  self.primitives.push(
    primitive(4, "", x, y, 0.0, 0.0, 0.0, 0.0, 0.0, None, text, align, 0),
  )
  let x0 = x - width * align.to_double() / 2.0
  self.box(x0, y - ascent, x0 + width, y + descent)
}

///|
pub fn MusicDrawing::mark(
  self : MusicDrawing,
  mark : Int32,
  text : String,
) -> Unit {
  self.primitives.push(
    primitive(5, "", 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, None, text, 0, mark),
  )
}

///|
/// Return the upper or lower skyline over a horizontal interval.
pub fn MusicDrawing::skyline(
  self : MusicDrawing,
  x0 : Double,
  x1 : Double,
  base : Double,
  above : Bool,
) -> Double {
  let segments = if above { self.top } else { self.bottom }
  let mut result = base
  for segment in segments {
    if segment.x1 < x0 || segment.x0 > x1 {
      continue
    }
    result = if above {
      Double::min(result, segment.y)
    } else {
      Double::max(result, segment.y)
    }
  }
  result
}

///|
/// Filled tie or slur, with the same cubic control points as upstream.
pub fn music_curve(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  height : Double,
  end : Double,
  mid : Double,
) -> MusicOutline {
  let sign = if height.reinterpret_as_uint64() >> 63 != 0UL {
    -1.0
  } else {
    1.0
  }
  let eo = sign * end / 2.0
  let ei = -sign * end / 2.0
  let co = (height + sign * mid / 2.0 - eo / 4.0) * 4.0 / 3.0
  let ci = (height - sign * mid / 2.0 - ei / 4.0) * 4.0 / 3.0
  let dx = x1 - x0
  let dy = y1 - y0
  {
    verbs: b"\x00\x03\x01\x03\x04",
    coordinates: [
      x0,
      y0 + eo,
      x0 + dx * 0.25,
      y0 + dy * 0.25 + co,
      x0 + dx * 0.75,
      y0 + dy * 0.75 + co,
      x1,
      y1 + eo,
      x1,
      y1 + ei,
      x0 + dx * 0.75,
      y0 + dy * 0.75 + ci,
      x0 + dx * 0.25,
      y0 + dy * 0.25 + ci,
      x0,
      y0 + ei,
    ],
  }
}

///|
/// Filled quadrilateral, used for a beam.
pub fn music_quad(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  x3 : Double,
  y3 : Double,
) -> MusicOutline {
  {
    verbs: b"\x00\x01\x01\x01\x04",
    coordinates: [x0, y0, x1, y1, x2, y2, x3, y3],
  }
}
