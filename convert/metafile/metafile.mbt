///|
/// A Windows metafile conversion failure.
pub suberror MetafileError {
  MetafileInvalid(String)
}

///|
priv struct Mat {
  a : Double
  b : Double
  c : Double
  d : Double
  e : Double
  f : Double
}

///|
fn mat_identity() -> Mat {
  { a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 0.0, f: 0.0, }
}

///|
fn mat_translate(x : Double, y : Double) -> Mat {
  { a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: x, f: y, }
}

///|
fn mat_scale(x : Double, y : Double) -> Mat {
  { a: x, b: 0.0, c: 0.0, d: y, e: 0.0, f: 0.0, }
}

///|
fn mat_mul(a : Mat, b : Mat) -> Mat {
  {
    a: a.a * b.a + a.c * b.b,
    b: a.b * b.a + a.d * b.b,
    c: a.a * b.c + a.c * b.d,
    d: a.b * b.c + a.d * b.d,
    e: a.a * b.e + a.c * b.f + a.e,
    f: a.b * b.e + a.d * b.f + a.f,
  }
}

///|
fn Mat::apply(self : Mat, x : Double, y : Double) -> (Double, Double) {
  (self.a * x + self.c * y + self.e, self.b * x + self.d * y + self.f)
}

///|
fn Mat::scale(self : Mat) -> Double {
  (self.a * self.d - self.b * self.c).abs().sqrt()
}

///|
priv enum GdiObject {
  Pen(Double, UInt32, Int32, Bool, Bool)
  Brush(UInt32, Bool, Int32)
  Font(Double, Int32, Bool, Bool, Bool, String, Double, Int32)
}

///|
priv struct GdiState {
  mut pen_width : Double
  mut pen_color : UInt32
  mut pen_style : Int32
  mut pen_null : Bool
  mut pen_cosmetic : Bool
  mut brush_color : UInt32
  mut brush_null : Bool
  mut brush_hatch : Int32
  mut font_height : Double
  mut font_weight : Int32
  mut font_italic : Bool
  mut font_underline : Bool
  mut font_strike : Bool
  mut font_face : String
  mut font_escapement : Double
  mut font_charset : Int32
  mut text_color : UInt32
  mut bk_color : UInt32
  mut bk_opaque : Bool
  mut text_align : Int32
  mut map_mode : Int32
  /// The binary raster operation of fills (R2_MASKPEN = 9 multiplies).
  mut rop2 : Int32
  /// GDI polygon fill mode: 1 alternate (even-odd), 2 winding.
  mut poly_fill : Int32
  mut win_org : (Double, Double)
  mut win_ext : (Double, Double)
  mut vp_org : (Double, Double)
  mut vp_ext : (Double, Double)
  mut world : Mat
  mut cur : (Double, Double)
}

///|
/// Snapshot every DC field; all member values are immutable.
fn GdiState::snapshot(self : GdiState) -> GdiState {
  {
    pen_width: self.pen_width,
    pen_color: self.pen_color,
    pen_style: self.pen_style,
    pen_null: self.pen_null,
    pen_cosmetic: self.pen_cosmetic,
    brush_color: self.brush_color,
    brush_null: self.brush_null,
    brush_hatch: self.brush_hatch,
    font_height: self.font_height,
    font_weight: self.font_weight,
    font_italic: self.font_italic,
    font_underline: self.font_underline,
    font_strike: self.font_strike,
    font_face: self.font_face,
    font_escapement: self.font_escapement,
    font_charset: self.font_charset,
    text_color: self.text_color,
    bk_color: self.bk_color,
    bk_opaque: self.bk_opaque,
    text_align: self.text_align,
    map_mode: self.map_mode,
    rop2: self.rop2,
    poly_fill: self.poly_fill,
    win_org: self.win_org,
    win_ext: self.win_ext,
    vp_org: self.vp_org,
    vp_ext: self.vp_ext,
    world: self.world,
    cur: self.cur,
  }
}

///|
priv struct Gdi {
  object : @core.ObjectBuilder
  writer : @core.DocumentWriter
  mut out : Mat
  mut pxmm : Double
  mut state : GdiState
  stack : Array[GdiState]
  objects : Map[Int64, GdiObject]
  slots : Array[GdiObject?]
  warnings : Array[String]
  warned : Map[String, Bool]
  fonts : Map[String, Int32]
  images : Map[String, Int32]
  /// DocuWorks driver pictures (attributes 301…) for the DWb records.
  dw_pics : Array[Bytes]
  mut dw_pic : Int
  /// The picture a DWc record draws: bmi + bits, a JPEG, and the DIB's
  /// bottom-up orientation.
  mut dw_dib : (Bytes, Bytes?)
  mut dw_jpeg : Bytes?
  /// A DW path accumulated by the DW02/DW-record point sequences, as
  /// drawn segments (moves, lines, cubic Béziers, closes) in page space.
  dw_path : Array[DwSeg]
  /// The EMF path bracket: verbs and coordinates collected between
  /// BEGINPATH and ENDPATH instead of being drawn.
  path_verbs : @buffer.Buffer
  path_coords : Array[Double]
  mut path_active : Bool
  /// Whether a record has already narrowed the clip, by a path or by a
  /// rectangle. The object format only carries a cumulative clip, so a
  /// replacing record first restores to the metafile's clip base.
  mut clip_active : Bool
}

///|
fn gdi_state() -> GdiState {
  {
    pen_width: 1.0,
    pen_color: 0x000000ffU,
    pen_style: 0,
    pen_null: false,
    pen_cosmetic: false,
    brush_color: 0xffffffffU,
    brush_null: false,
    brush_hatch: -1,
    font_height: 12.0,
    font_weight: 400,
    font_italic: false,
    font_underline: false,
    font_strike: false,
    font_face: "Arial",
    font_escapement: 0.0,
    font_charset: 0,
    text_color: 0x000000ffU,
    bk_color: 0xffffffffU,
    bk_opaque: true,
    text_align: 0,
    poly_fill: 1,
    rop2: 13,
    map_mode: 1,
    win_org: (0.0, 0.0),
    win_ext: (1.0, 1.0),
    vp_org: (0.0, 0.0),
    vp_ext: (1.0, 1.0),
    world: mat_identity(),
    cur: (0.0, 0.0),
  }
}

///|
fn Gdi::warn(self : Gdi, message : String) -> Unit {
  if !self.warned.contains(message) {
    self.warned[message] = true
    self.warnings.push(message)
  }
}

///|
fn Gdi::matrix(self : Gdi) -> Mat {
  let state = self.state
  let page = match state.map_mode {
    1 =>
      mat_translate(
        state.vp_org.0 - state.win_org.0,
        state.vp_org.1 - state.win_org.1,
      )
    7 | 8 => {
      let mut sx = 1.0
      let mut sy = 1.0
      if state.win_ext.0 != 0.0 {
        sx = state.vp_ext.0 / state.win_ext.0
      }
      if state.win_ext.1 != 0.0 {
        sy = state.vp_ext.1 / state.win_ext.1
      }
      if state.map_mode == 7 {
        let m = if sx.abs() < sy.abs() { sx.abs() } else { sy.abs() }
        sx = if sx < 0.0 { -m } else { m }
        sy = if sy < 0.0 { -m } else { m }
      }
      let scale = mat_scale(sx, sy)
      let move = mat_translate(-state.win_org.0, -state.win_org.1)
      mat_mul(
        mat_mul(mat_translate(state.vp_org.0, state.vp_org.1), scale),
        move,
      )
    }
    _ => {
      let mm = match state.map_mode {
        2 => 0.1
        3 => 0.01
        4 => 0.254
        5 => 0.0254
        6 => 25.4 / 1440.0
        _ => 0.1
      }
      let k = mm * self.pxmm
      let scale = mat_scale(k, -k)
      let move = mat_translate(-state.win_org.0, -state.win_org.1)
      mat_mul(
        mat_mul(mat_translate(state.vp_org.0, state.vp_org.1), scale),
        move,
      )
    }
  }
  mat_mul(mat_mul(self.out, page), state.world)
}

///|
/// The pen width in page points. A geometric pen's width is a logical width,
/// so the matrix maps it to page space. A cosmetic pen (width 0) is one
/// device pixel on the output, which the object format can only express as a
/// fixed hairline in page space. An anisotropic matrix has no single page
/// width; the geometric mean of its axes is used, as for the hairline.
fn Gdi::pen_page_width(self : Gdi) -> Double {
  let width = self.state.pen_width
  if width <= 0.0 || self.state.pen_cosmetic {
    return 0.75
  }
  let scaled = width * self.matrix().scale()
  if scaled > 0.0 {
    scaled
  } else {
    0.75
  }
}

///|
fn le16(data : Bytes, offset : Int32) -> Int32 {
  if offset < 0 || offset + 2 > data.length() {
    0
  } else {
    data[offset].to_int() | (data[offset + 1].to_int() << 8)
  }
}

///|
fn lei16(data : Bytes, offset : Int32) -> Int32 {
  let value = le16(data, offset)
  if value >= 32768 {
    value - 65536
  } else {
    value
  }
}

///|
fn le32(data : Bytes, offset : Int32) -> Int64 {
  if offset < 0 || offset + 4 > data.length() {
    0L
  } else {
    data[offset].to_int64() |
    (data[offset + 1].to_int64() << 8) |
    (data[offset + 2].to_int64() << 16) |
    (data[offset + 3].to_int64() << 24)
  }
}

///|
fn lei32(data : Bytes, offset : Int32) -> Double {
  le32(data, offset).to_int().to_double()
}

///|
fn lef32(data : Bytes, offset : Int32) -> Double {
  let bits = le32(data, offset).to_int()
  Float::reinterpret_from_uint(bits.reinterpret_as_uint()).to_double()
}

///|
fn colorref(value : Int64) -> UInt32 {
  let v = value.to_int()
  let red = v & 0xff
  let green = (v >> 8) & 0xff
  let blue = (v >> 16) & 0xff
  ((red << 24) | (green << 16) | (blue << 8) | 0xff).reinterpret_as_uint()
}

///|
fn color_int(red : Int32, green : Int32, blue : Int32) -> UInt32 {
  (((red & 0xff) << 24) | ((green & 0xff) << 16) | ((blue & 0xff) << 8) | 0xff).reinterpret_as_uint()
}

///|
fn utf16_text(data : Bytes, count : Int32) -> String {
  let length = if count * 2 > data.length() { data.length() / 2 } else { count }
  if length <= 0 {
    return ""
  }
  @utf16.decode(data[:length * 2], ignore_bom=true, endianness=@utf16.Little) catch {
    _ => @utf16.decode_lossy(data[:length * 2], endianness=@utf16.Little)
  }
}

///|
fn ansi_text(data : Bytes, charset : Int32) -> String {
  if charset == 128 {
    match @encoding.decode(data, "shift_jis") {
      Ok(text) => text
      Err(_) => @utf8.decode_lossy(data)
    }
  } else {
    @utf8.decode_lossy(data)
  }
}

///|
fn text_advance(text : String, size : Double) -> Double {
  let mut advance = 0.0
  for ch in text {
    let code = ch.to_int()
    advance += if code > 0x2e80 || ch == '\u3000' { size } else { size * 0.5 }
  }
  advance
}

///|
/// The BDF fill rule for the current GDI polygon fill mode: alternate
/// (1) is even-odd, winding (2) is non-zero.
fn Gdi::fill_rule(self : Gdi) -> Byte {
  if self.state.poly_fill == 2 {
    0
  } else {
    1
  }
}

///|
/// Collect a path fragment instead of drawing it.
fn Gdi::path_append(
  self : Gdi,
  verbs : Bytes,
  coordinates : Array[Double],
) -> Unit {
  self.path_verbs.write_bytes(verbs)
  for value in coordinates {
    self.path_coords.push(value)
  }
}

///|
fn Gdi::path_clear(self : Gdi) -> Unit {
  self.path_verbs.reset()
  self.path_coords.clear()
}

///|
/// Draw the collected path with the current pen and brush, then discard it.
fn Gdi::path_flush(self : Gdi, fill : Bool, stroke : Bool) -> Unit {
  if self.path_coords.is_empty() {
    self.path_clear()
    return
  }
  let verbs = self.path_verbs.to_bytes()
  let coordinates = self.path_coords.copy()
  self.path_clear()
  self.draw_path(verbs, coordinates, fill, stroke)
}

///|
/// Clip to the collected path, then discard it.
fn Gdi::path_clip(self : Gdi) -> Unit {
  if self.path_coords.is_empty() {
    self.path_clear()
    return
  }
  let verbs = self.path_verbs.to_bytes()
  let coordinates = self.path_coords.copy()
  self.path_clear()
  let index = self.object.add_path(@core.Inline({ verbs, coordinates, }))
  self.object.clip_path(index, self.fill_rule()) catch {
    error => self.warn("a path could not clip: " + error.to_string())
  }
}

///|
/// The object format's clip is cumulative. Restore to the metafile's clip
/// base, which keeps the page bounds clip, then save a fresh base so a later
/// replacing record can reset again. Coordinates are already in page space
/// and every draw re-emits its own paint, so only the clip changes.
fn Gdi::clip_replace(self : Gdi) -> Unit {
  self.object.restore()
  self.object.save()
}

///|
/// Replace the clip with the collected path, then discard it.
fn Gdi::path_clip_replace(self : Gdi) -> Unit {
  if self.path_coords.is_empty() {
    self.path_clear()
    return
  }
  self.clip_replace()
  self.path_clip()
}

///|
/// SELECTCLIPPATH combines the path with the current clipping region using
/// RegionMode. RGN_COPY replaces the region, which the clip base expresses.
/// RGN_AND is what a cumulative clip already does. The modes the object
/// format cannot express are reported instead of being silently applied as
/// an intersection.
fn Gdi::path_clip_mode(self : Gdi, mode : Int32) -> Unit {
  if self.path_coords.is_empty() {
    self.path_clear()
    return
  }
  let name = match mode {
    1 => "RGN_AND"
    2 => "RGN_OR"
    3 => "RGN_XOR"
    4 => "RGN_DIFF"
    5 => "RGN_COPY"
    _ => ""
  }
  if name == "" {
    self.warn(
      "metafile SELECTCLIPPATH has an unknown RegionMode " + mode.to_string(),
    )
  } else if mode != 1 && mode != 5 {
    self.warn("metafile SELECTCLIPPATH " + name + " is applied as RGN_AND")
  }
  if mode == 5 {
    self.path_clip_replace()
  } else {
    self.path_clip()
  }
  self.clip_active = true
}

///|
fn Gdi::draw_path(
  self : Gdi,
  verbs : Bytes,
  coordinates : Array[Double],
  fill : Bool,
  stroke : Bool,
) -> Unit {
  let brush = !self.state.brush_null && fill
  let pen = !self.state.pen_null && stroke
  if !brush && !pen {
    return
  }
  let index = self.object.add_path(@core.Inline({ verbs, coordinates, }))
  if brush {
    if self.state.brush_hatch >= 0 {
      // The hatch patterns are approximated by their colour here; a tile
      // would be a better match for a large filled area.
      self.warn("metafile hatch brushes are approximated")
    }
    self.object.fill_color(self.state.brush_color)
    self.object.fill_path(index, self.fill_rule()) catch {
      error =>
        self.warn("a metafile path could not be filled: " + error.to_string())
    }
  }
  if pen {
    let width = self.pen_page_width()
    self.object.stroke_color(self.state.pen_color)
    self.object.line(Float::from_double(width), 1, 1, 10)
    let mut dashes : Array[Float] = []
    match self.state.pen_style & 0xf {
      1 => dashes = [3.0F, 1.0F]
      2 => dashes = [1.0F, 1.0F]
      3 => dashes = [3.0F, 1.0F, 1.0F, 1.0F]
      4 => dashes = [3.0F, 1.0F, 1.0F, 1.0F, 1.0F, 1.0F]
      _ => ()
    }
    if !dashes.is_empty() {
      let scaled : Array[Float] = []
      for dash in dashes {
        scaled.push(dash * Float::from_double(width * 2.0))
      }
      self.object.dash(scaled, 0.0F)
    } else {
      self.object.dash([], 0.0F)
    }
    self.object.stroke_path(index) catch {
      error =>
        self.warn("a metafile path could not be stroked: " + error.to_string())
    }
  }
}

///|
fn Gdi::polyline(
  self : Gdi,
  points : Array[(Double, Double)],
  closed : Bool,
  fill : Bool,
) -> Unit {
  if points.length() < 2 {
    return
  }
  let m = self.matrix()
  let verbs = @buffer.Buffer()
  let coordinates : Array[Double] = []
  for i, point in points {
    let (x, y) = m.apply(point.0, point.1)
    verbs.write_byte(if i == 0 { 0 } else { 1 })
    coordinates.push(x)
    coordinates.push(y)
  }
  if closed {
    verbs.write_byte(4)
  }
  let v = verbs.to_bytes()
  if self.path_active {
    self.path_append(v, coordinates)
  } else {
    self.draw_path(v, coordinates, fill, true)
  }
}

///|
/// A POLYBEZIER (from its first point) or POLYBEZIERTO (from the current
/// point) record: a move, then cubic segments in groups of three control
/// points.
fn Gdi::bezier(self : Gdi, points : Array[(Double, Double)], to : Bool) -> Unit {
  let m = self.matrix()
  let verbs = @buffer.Buffer()
  let coordinates : Array[Double] = []
  let mut i = 0
  if to {
    // POLYBEZIERTO continues the current figure. Inside a path a move
    // would start a new subpath, and a following CLOSEFIGURE would close
    // that one instead of the figure the curve belongs to.
    if not(self.path_active) {
      let (x, y) = m.apply(self.state.cur.0, self.state.cur.1)
      verbs.write_byte(0)
      coordinates.push(x)
      coordinates.push(y)
    }
  } else {
    if points.length() < 4 {
      return
    }
    let (x, y) = m.apply(points[0].0, points[0].1)
    verbs.write_byte(0)
    coordinates.push(x)
    coordinates.push(y)
    i = 1
  }
  while i + 2 < points.length() {
    for k in 0..<3 {
      let (x, y) = m.apply(points[i + k].0, points[i + k].1)
      coordinates.push(x)
      coordinates.push(y)
    }
    verbs.write_byte(3)
    i += 3
  }
  if coordinates.length() < 4 {
    return
  }
  if to {
    // PolyBezierTo moves the current position to the end of the last curve.
    // PolyBezier neither uses nor updates it.
    self.state.cur = points[points.length() - 1]
  }
  let v = verbs.to_bytes()
  if self.path_active {
    self.path_append(v, coordinates)
  } else {
    self.draw_path(v, coordinates, false, true)
  }
}

///|
fn Gdi::rectangle(
  self : Gdi,
  left : Double,
  top : Double,
  right : Double,
  bottom : Double,
) -> Unit {
  let m = self.matrix()
  let x = if left < right { left } else { right }
  let y = if top < bottom { top } else { bottom }
  let width = (right - left).abs()
  let height = (bottom - top).abs()
  let (x0, y0) = m.apply(x, y)
  let (x1, y1) = m.apply(x + width, y + height)
  let verbs = b"\x05"
  let coordinates = [x0, y0, x1 - x0, y1 - y0]
  if self.path_active {
    self.path_append(verbs, coordinates)
  } else {
    self.draw_path(verbs, coordinates, true, true)
  }
}

///|
fn Gdi::ellipse(
  self : Gdi,
  left : Double,
  top : Double,
  right : Double,
  bottom : Double,
) -> Unit {
  let m = self.matrix()
  let (cx, cy) = m.apply((left + right) / 2.0, (top + bottom) / 2.0)
  let (ex, ey) = m.apply(right, bottom)
  let (sx, sy) = m.apply(left, top)
  let rx = ((ex - sx) / 2.0).abs()
  let ry = ((ey - sy) / 2.0).abs()
  let verbs = b"\x06"
  let coordinates = [cx, cy, rx, ry, 0.0, 0.0, 2.0 * 3.141592653589793, 0.0]
  if self.path_active {
    self.path_append(verbs, coordinates)
  } else {
    self.draw_path(verbs, coordinates, true, true)
  }
}

///|
fn Gdi::round_rect(
  self : Gdi,
  left : Double,
  top : Double,
  right : Double,
  bottom : Double,
  width : Double,
  height : Double,
) -> Unit {
  let m = self.matrix()
  let x = if left < right { left } else { right }
  let y = if top < bottom { top } else { bottom }
  let w = (right - left).abs()
  let h = (bottom - top).abs()
  let (x0, y0) = m.apply(x, y)
  let (x1, y1) = m.apply(x + w, y + h)
  let radius = (width.abs().min(w) / 2.0).min(height.abs().min(h) / 2.0)
  let scaled_radius = radius * m.scale()
  let verbs = b"\x08"
  let coordinates = [x0, y0, x1 - x0, y1 - y0, scaled_radius]
  if self.path_active {
    self.path_append(verbs, coordinates)
  } else {
    self.draw_path(verbs, coordinates, true, true)
  }
}

///|
fn Gdi::font_index(
  self : Gdi,
  face : String,
  weight : Int32,
  italic : Bool,
) -> Int32 {
  let key = face +
    "|" +
    weight.to_string() +
    "|" +
    (if italic { "1" } else { "0" })
  match self.fonts.get(key) {
    Some(index) => index
    None => {
      let index = self.object.add_font({
        hash: None,
        family: face,
        weight,
        style: if italic {
          1
        } else {
          0
        },
      })
      self.fonts[key] = index
      index
    }
  }
}

///|
fn Gdi::text(
  self : Gdi,
  x : Double,
  y : Double,
  text : String,
  advances : Array[Double]?,
) -> Unit {
  if text == "" {
    return
  }
  let m = self.matrix()
  let (px0, py0) = m.apply(x, y)
  let mut px = px0
  let mut py = py0
  let scale = if m.scale() > 0.000000001 { m.scale() } else { 1.0 }
  let mut size = self.state.font_height.abs() * scale
  if size <= 0.0 || size > 10000.0 {
    size = 12.0 * scale
  }
  let mut advance = 0.0
  match advances {
    Some(values) =>
      for value in values {
        advance += value * scale
      }
    None => advance = text_advance(text, size)
  }
  if (self.state.text_align & 6) == 6 {
    px = px - advance / 2.0
  } else if (self.state.text_align & 6) == 2 {
    px = px - advance
  }
  // TA_TOP (0) puts the reference point at the top of the text, TA_BOTTOM
  // (8) at the bottom, TA_BASELINE (24) on the baseline itself.
  let valign = self.state.text_align & 24
  if valign == 24 {
    // the reference point is already the baseline
  } else if valign == 8 {
    py = py - size * 0.2
  } else {
    py = py + size * 0.8
  }
  let index = self.font_index(
    self.state.font_face,
    self.state.font_weight,
    self.state.font_italic,
  )
  self.object.fill_color(self.state.text_color)
  self.object.font(index, Float::from_double(size)) catch {
    error =>
      self.warn("a metafile font could not be used: " + error.to_string())
  }
  self.object.fill_text(
    text,
    Float::from_double(px),
    Float::from_double(py),
    Float::from_double(advance),
  )
  let thickness = (size * 0.05).max(0.5)
  if self.state.font_underline {
    self.object.fill_rect(
      Float::from_double(px),
      Float::from_double(py - size * 0.1),
      Float::from_double(advance),
      Float::from_double(thickness),
    )
  }
  if self.state.font_strike {
    self.object.fill_rect(
      Float::from_double(px),
      Float::from_double(py - size * 0.3),
      Float::from_double(advance),
      Float::from_double(thickness),
    )
  }
}

///|
priv struct Dib {
  width : Int32
  height : Int32
  rgba : Bytes
  bits_offset : Int32
}

///|
/// The largest DIB header this decoder accepts. Known headers are 12, 40, 52,
/// 56, 64, 108 and 124 bytes; the cap rejects absurd sizes that would
/// otherwise be used as a palette offset.
const MAX_DIB_HEADER_SIZE : Int64 = 65536L

///|
/// A DIB header whose size, colour count and palette bounds have been
/// validated. `None` means the header or its colour table is malformed.
priv struct DibHeader {
  header_size : Int32
  width : Int32
  height : Int32
  bpp : Int32
  compression : Int32
  palette_offset : Int32
  palette_entry : Int32
  colors : Int32
  bits_offset : Int32
}

///|
fn dib_header(data : Bytes) -> DibHeader? {
  if data.length() < 12 {
    return None
  }
  let header = le32(data, 0)
  if header == 12L {
    let width = le16(data, 4)
    let height = le16(data, 6)
    let bpp = le16(data, 10)
    let colors = if bpp <= 8 { 1 << bpp } else { 0 }
    let bits_offset = 12 + colors * 3
    if bits_offset > data.length() {
      return None
    }
    return Some({
      header_size: 12,
      width,
      height,
      bpp,
      compression: 0,
      palette_offset: 12,
      palette_entry: 3,
      colors,
      bits_offset,
    })
  }
  if header < 40L ||
    header > MAX_DIB_HEADER_SIZE ||
    header > data.length().to_int64() {
    return None
  }
  let width = lei32(data, 4).to_int()
  let height = lei32(data, 8).to_int()
  let bpp = le16(data, 14)
  let compression = le32(data, 16).to_int()
  let used = le32(data, 32)
  let colors = if bpp <= 8 {
    if used > 0L {
      // biClrUsed is unsigned: a value above the 2^bpp table would make the
      // palette offset wrap when it is multiplied by the entry size.
      if used > (1L << bpp) {
        return None
      }
      used.to_int()
    } else {
      1 << bpp
    }
  } else {
    0
  }
  let masks = if compression == 3 && header == 40L { 12 } else { 0 }
  let palette_offset = header.to_int() + masks
  let palette_end = palette_offset.to_int64() + colors.to_int64() * 4L
  if palette_end > data.length().to_int64() {
    return None
  }
  Some({
    header_size: header.to_int(),
    width,
    height,
    bpp,
    compression,
    palette_offset,
    palette_entry: 4,
    colors,
    bits_offset: palette_end.to_int(),
  })
}

///|
fn dib_bits_offset(data : Bytes) -> Int32 {
  match dib_header(data) {
    Some(header) => header.bits_offset
    None => 0
  }
}

///|
/// One channel of a bitfield pixel: shift the mask down to bit 0, then
/// scale its range to 0…255.
fn mask_channel(value : Int32, mask : Int32) -> Int32 {
  if mask == 0 {
    return 0
  }
  // the masks are unsigned bit patterns: a mask in the high byte would
  // sign-extend through an Int32 shift, so work in Int64
  let u_value = value.to_int64() & 0xffffffffL
  let u_mask = mask.to_int64() & 0xffffffffL
  let mut shift = 0
  while shift < 32 && (u_mask & (1L << shift)) == 0L {
    shift += 1
  }
  if shift >= 32 {
    return 0
  }
  let mut width = 0
  while width < 32 - shift && (u_mask & (1L << (shift + width))) != 0L {
    width += 1
  }
  if width == 0 {
    return 0
  }
  let max = (1L << width) - 1L
  let channel = (u_value >> shift) & max
  ((channel * 255L / max).to_int()).min(255)
}

///|
/// The largest DIB this decoder expands: 64 Mi pixels, 256 MiB of RGBA. A
/// 600 dpi A4 scan is about 34.8 Mi pixels, so it stays below the limit.
const MAX_DIB_PIXELS : Int64 = 67108864L

///|
/// One palette entry as (red, green, blue), or None when the index is outside
/// the declared colour table or the table is truncated.
fn rle8_palette_color(
  data : Bytes,
  palette : Int32,
  palette_entry : Int32,
  index : Int32,
  colors : Int32,
) -> (Int32, Int32, Int32)? {
  if index < 0 || index >= colors {
    return None
  }
  let at = palette.to_int64() + index.to_int64() * palette_entry.to_int64()
  if at < 0L || at + 2L >= data.length().to_int64() {
    return None
  }
  let at = at.to_int()
  Some((data[at + 2].to_int(), data[at + 1].to_int(), data[at].to_int()))
}

///|
/// Decode a BI_RLE8 stream into top-down RGBA. The stream starts at the
/// lower-left for a bottom-up DIB and at the upper-left for a top-down DIB.
/// Pixels the stream does not cover keep palette index 0.
fn dib_decode_rle8(
  data : Bytes,
  bits : Bytes,
  width : Int32,
  rows : Int32,
  total : Int32,
  top_down : Bool,
  palette : Int32,
  palette_entry : Int32,
  colors : Int32,
) -> Bytes? {
  if total <= 0 || bits.length() == 0 {
    return None
  }
  let rgba : FixedArray[Byte] = FixedArray::make(total * 4, (0).to_byte())
  let background = match rle8_palette_color(
    data,
    palette,
    palette_entry,
    0,
    colors,
  ) {
    Some(value) => value
    None => return None
  }
  let (bg_red, bg_green, bg_blue) = background
  for p in 0..<total {
    let at = p * 4
    rgba[at] = bg_red.to_byte()
    rgba[at + 1] = bg_green.to_byte()
    rgba[at + 2] = bg_blue.to_byte()
    rgba[at + 3] = (255).to_byte()
  }
  let n = bits.length()
  let mut i = 0
  let mut x = 0
  let mut stored_row = 0
  let mut ended = false
  while i < n {
    let count = bits[i].to_int()
    i += 1
    if i >= n {
      return None
    }
    let value = bits[i].to_int()
    i += 1
    if count > 0 {
      if x + count > width || stored_row >= rows {
        return None
      }
      let color = match rle8_palette_color(
        data,
        palette,
        palette_entry,
        value,
        colors,
      ) {
        Some(value) => value
        None => return None
      }
      let (red, green, blue) = color
      let visual_row = if top_down { stored_row } else { rows - 1 - stored_row }
      let base = (visual_row * width + x) * 4
      for k in 0..<count {
        let at = base + k * 4
        rgba[at] = red.to_byte()
        rgba[at + 1] = green.to_byte()
        rgba[at + 2] = blue.to_byte()
        rgba[at + 3] = (255).to_byte()
      }
      x += count
    } else {
      match value {
        0 => {
          x = 0
          stored_row += 1
          // the end of line after the last row is allowed when end of bitmap
          // follows, but a further line is outside the image
          if stored_row > rows {
            return None
          }
        }
        1 => {
          ended = true
          break
        }
        2 => {
          if n - i < 2 {
            return None
          }
          let dx = bits[i].to_int()
          let dy = bits[i + 1].to_int()
          i += 2
          x += dx
          stored_row += dy
          if x > width || stored_row >= rows {
            return None
          }
        }
        _ => {
          let run = value
          if n - i < run {
            return None
          }
          if x + run > width || stored_row >= rows {
            return None
          }
          let visual_row = if top_down { stored_row } else { rows - 1 - stored_row }
          let base = (visual_row * width + x) * 4
          for k in 0..<run {
            let index = bits[i + k].to_int()
            let color = match rle8_palette_color(
              data,
              palette,
              palette_entry,
              index,
              colors,
            ) {
              Some(value) => value
              None => return None
            }
            let (red, green, blue) = color
            let at = base + k * 4
            rgba[at] = red.to_byte()
            rgba[at + 1] = green.to_byte()
            rgba[at + 2] = blue.to_byte()
            rgba[at + 3] = (255).to_byte()
          }
          i += run
          if run % 2 == 1 {
            if i >= n {
              return None
            }
            i += 1
          }
          x += run
        }
      }
    }
  }
  if !ended {
    return None
  }
  Some(Bytes::from_array(rgba))
}

///|
fn dib_decode(data : Bytes, bits_data : Bytes?) -> Dib? {
  dib_decode_oriented(data, bits_data, false)
}

///|
/// Decode a DIB whose uncompressed rows are stored top-to-bottom even when
/// `biHeight` is positive. A negative height already means top-down, so it
/// keeps the same reading; BI_RLE8 keeps its own orientation because its
/// stream is not a row array. The decoder has no separate BI_RLE4 path.
fn dib_decode_top_down(data : Bytes, bits_data : Bytes?) -> Dib? {
  dib_decode_oriented(data, bits_data, true)
}

///|
fn dib_decode_oriented(
  data : Bytes,
  bits_data : Bytes?,
  force_top_down : Bool,
) -> Dib? {
  let header = match dib_header(data) {
    Some(value) => value
    None => return None
  }
  let header_size = header.header_size
  let width = header.width
  let height = header.height
  let bpp = header.bpp
  let compression = header.compression
  let palette_offset = header.palette_offset
  let palette_entry = header.palette_entry
  let colors = header.colors
  let bits_offset = header.bits_offset
  let height64 = height.to_int64()
  if width <= 0 ||
    height64 == 0L ||
    width > 100000 ||
    height64 > 100000L ||
    height64 < -100000L {
    return None
  }
  // A kind 7 annotation stores its expanded rows top-to-bottom even when
  // the header says positive; BI_RLE8 is a stream, not a row array, so it
  // keeps the height's own meaning. The decoder has no separate BI_RLE4
  // path.
  let top_down = height64 < 0L || (force_top_down && compression != 1)
  let rows = (if height64 < 0L { -height64 } else { height64 }).to_int()
  // The RGBA buffer is width * rows * 4 bytes. Bound the pixel count before
  // the multiplication so a large header cannot overflow Int32 or allocate an
  // unbounded buffer; this applies to compressed and uncompressed DIBs.
  let total = width.to_int64() * rows.to_int64()
  if total <= 0L || total > MAX_DIB_PIXELS {
    return None
  }
  let bits = match bits_data {
    Some(value) =>
      if value.length() > 0 {
        value
      } else {
        data[bits_offset:].to_owned()
      }
    None => data[bits_offset:].to_owned()
  }
  if compression == 1 {
    if bpp != 8 {
      return None
    }
    let rgba = dib_decode_rle8(
      data,
      bits,
      width,
      rows,
      total.to_int(),
      top_down,
      palette_offset,
      palette_entry,
      colors,
    )
    match rgba {
      Some(value) => return Some({ width, height: rows, rgba: value, bits_offset })
      None => return None
    }
  }
  // Only the bit depths the pixel loop below handles may reach the stride
  // calculation; bpp is an untrusted u16 and width * bpp would otherwise
  // overflow before the match rejects it.
  if bpp != 1 && bpp != 4 && bpp != 8 && bpp != 16 && bpp != 24 && bpp != 32 {
    return None
  }
  let stride64 = (width.to_int64() * bpp.to_int64() + 31L) / 32L * 4L
  if stride64 <= 0L || stride64 > 2147483647L {
    return None
  }
  let stride = stride64.to_int()
  if bits.length().to_int64() < stride64 * rows.to_int64() {
    return None
  }
  let rgba : FixedArray[Byte] = FixedArray::make(
    total.to_int() * 4,
    (0).to_byte(),
  )
  let palette = palette_offset
  for row in 0..<rows {
    let source_row = if top_down { row } else { rows - 1 - row }
    let row_offset = source_row * stride
    for x in 0..<width {
      let mut red = 0
      let mut green = 0
      let mut blue = 0
      let mut alpha = 255
      match bpp {
        1 => {
          let bit = (bits[row_offset + x / 8].to_int() >> (7 - x % 8)) & 1
          if bit >= colors {
            return None
          }
          let at = palette + bit * palette_entry
          blue = data[at].to_int()
          green = data[at + 1].to_int()
          red = data[at + 2].to_int()
        }
        4 => {
          let value = bits[row_offset + x / 2].to_int()
          let index = if x % 2 == 0 { value >> 4 } else { value & 0xf }
          if index >= colors {
            return None
          }
          let at = palette + index * palette_entry
          blue = data[at].to_int()
          green = data[at + 1].to_int()
          red = data[at + 2].to_int()
        }
        8 => {
          let index = bits[row_offset + x].to_int()
          if index >= colors {
            return None
          }
          let at = palette + index * palette_entry
          blue = data[at].to_int()
          green = data[at + 1].to_int()
          red = data[at + 2].to_int()
        }
        16 => {
          let at = row_offset + x * 2
          let value = bits[at].to_int() | (bits[at + 1].to_int() << 8)
          if compression == 3 {
            let masks_at = 40
            red = mask_channel(value, le32(data, masks_at).to_int())
            green = mask_channel(value, le32(data, masks_at + 4).to_int())
            blue = mask_channel(value, le32(data, masks_at + 8).to_int())
          } else {
            red = ((value >> 10) & 0x1f) * 255 / 31
            green = ((value >> 5) & 0x1f) * 255 / 31
            blue = (value & 0x1f) * 255 / 31
          }
        }
        24 => {
          let at = row_offset + x * 3
          blue = bits[at].to_int()
          green = bits[at + 1].to_int()
          red = bits[at + 2].to_int()
        }
        32 => {
          let at = row_offset + x * 4
          let value = bits[at].to_int() |
            (bits[at + 1].to_int() << 8) |
            (bits[at + 2].to_int() << 16) |
            (bits[at + 3].to_int() << 24)
          if compression == 3 {
            let masks_at = 40
            red = mask_channel(value, le32(data, masks_at).to_int())
            green = mask_channel(value, le32(data, masks_at + 4).to_int())
            blue = mask_channel(value, le32(data, masks_at + 8).to_int())
            if header_size >= 56 {
              let alpha_mask = le32(data, masks_at + 12).to_int()
              if alpha_mask != 0 {
                alpha = mask_channel(value, alpha_mask)
              }
            }
          } else {
            blue = bits[at].to_int()
            green = bits[at + 1].to_int()
            red = bits[at + 2].to_int()
            alpha = bits[at + 3].to_int()
            if alpha == 0 {
              alpha = 255
            }
          }
        }
        _ => return None
      }
      let target = (row * width + x) * 4
      rgba[target] = red.to_byte()
      rgba[target + 1] = green.to_byte()
      rgba[target + 2] = blue.to_byte()
      rgba[target + 3] = alpha.to_byte()
    }
  }
  Some({ width, height: rows, rgba: Bytes::from_array(rgba), bits_offset, })
}

///|
fn Gdi::image(
  self : Gdi,
  bmi : Bytes,
  bits : Bytes?,
  sx : Double,
  sy : Double,
  sw : Double,
  sh : Double,
  dx : Double,
  dy : Double,
  dw : Double,
  dh : Double,
) -> Unit {
  let dib = match dib_decode(bmi, bits) {
    Some(value) => value
    None => {
      self.warn("a metafile bitmap could not be decoded")
      return
    }
  }
  let png = @raster.encode_png(dib.width, dib.height, dib.rgba) catch {
    _ => {
      self.warn("a metafile bitmap could not be decoded")
      return
    }
  }
  let hash = self.writer.add_part("img", png) catch {
    error => {
      self.warn("a metafile bitmap could not be stored: " + error.to_string())
      return
    }
  }
  let image = match self.images.get(hash) {
    Some(index) => index
    None => {
      let index = self.object.add_image(hash)
      self.images[hash] = index
      index
    }
  }
  let m = self.matrix()
  let (x0, y0) = m.apply(dx, dy)
  let (x1, y1) = m.apply(dx + dw, dy + dh)
  let source_w = if sw <= 0.0 { dib.width.to_double() } else { sw }
  let source_h = if sh <= 0.0 { dib.height.to_double() } else { sh }
  self.object.image_sub(
    image,
    Float::from_double(sx),
    Float::from_double(sy),
    Float::from_double(source_w),
    Float::from_double(source_h),
    Float::from_double(if x0 < x1 { x0 } else { x1 }),
    Float::from_double(if y0 < y1 { y0 } else { y1 }),
    Float::from_double((x1 - x0).abs()),
    Float::from_double((y1 - y0).abs()),
  ) catch {
    error =>
      self.warn("a metafile bitmap could not be drawn: " + error.to_string())
  }
}

///|
/// Tell an EMF, a WMF or another file: `"emf"`, `"wmf"` or `""`.
pub fn kind(data : Bytes) -> String {
  if data.length() >= 44 && le32(data, 0) == 1L && data[40:44] == b" EMF"[:] {
    "emf"
  } else if (data.length() >= 22 && le32(data, 0) == 0x9ac6cdd7L) ||
    (
      data.length() >= 18 &&
      (le16(data, 0) == 1 || le16(data, 0) == 2) &&
      le16(data, 2) == 9
    ) {
    "wmf"
  } else {
    ""
  }
}

///|
/// The size a metafile is meant to be shown at, in points.
pub fn size(data : Bytes) -> (Double, Double)? {
  match kind(data) {
    "emf" =>
      match emf_frame(data) {
        Some(frame) =>
          Some(
            (
              (frame.right - frame.left) / frame.pxmm_x * 72.0 / 25.4,
              (frame.bottom - frame.top) / frame.pxmm_y * 72.0 / 25.4,
            ),
          )
        None => None
      }
    "wmf" =>
      match wmf_box(data) {
        Some(box) => {
          let inch = if box.inch > 0.0 { box.inch } else { 96.0 }
          Some(
            (
              (box.right - box.left).abs() / inch * 72.0,
              (box.bottom - box.top).abs() / inch * 72.0,
            ),
          )
        }
        None => None
      }
    _ => None
  }
}

///|
/// Replay a metafile into `object`: the picture fills the rectangle
/// `x,y,w,h`. Images are stored through `writer`. Unsupported records are
/// left out, with a warning.
pub fn draw_into(
  object : @core.ObjectBuilder,
  writer : @core.DocumentWriter,
  data : Bytes,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  annotation? : Bool,
  pics? : Array[Bytes],
) -> Array[String] raise MetafileError {
  let pics : Array[Bytes] = match pics {
    Some(v) => v
    None => []
  }
  let annotation : Bool = match annotation {
    Some(v) => v
    None => false
  }
  let file_kind = kind(data)
  if file_kind == "" {
    raise MetafileInvalid("metafile: not an EMF or WMF file")
  }
  if w <= 0.0 || h <= 0.0 {
    raise MetafileInvalid("metafile: the picture has no size")
  }
  let g : Gdi = {
    object,
    writer,
    out: mat_identity(),
    pxmm: 96.0 / 25.4,
    state: gdi_state(),
    stack: [],
    objects: Map([]),
    slots: [],
    warnings: [],
    warned: Map([]),
    fonts: Map([]),
    images: Map([]),
    dw_pics: pics,
    dw_pic: 0,
    dw_dib: (Bytes::from_array(FixedArray::make(1, b'\x00')), None),

    dw_jpeg: None,
    path_verbs: @buffer.Buffer(),
    path_coords: [],
    path_active: false,
    clip_active: false,
    dw_path: [],
  }
  object.save()
  object.clip_rect(
    Float::from_double(x),
    Float::from_double(y),
    Float::from_double(w),
    Float::from_double(h),
  )
  // A clip base below the metafile's own clips but above the page bounds:
  // a replacing record restores here, so it never wipes the page clip.
  object.save()
  if file_kind == "emf" {
    g.play_emf(data, x, y, w, h, annotation~)
  } else {
    g.play_wmf(data, x, y, w, h)
  }
  object.restore()
  object.restore()
  g.warnings
}
