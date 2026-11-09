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
  mut win_org : (Double, Double)
  mut win_ext : (Double, Double)
  mut vp_org : (Double, Double)
  mut vp_ext : (Double, Double)
  mut world : Mat
  mut cur : (Double, Double)
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
fn ansi_text(data : Bytes, count : Int32) -> String {
  let length = if count > data.length() { data.length() } else { count }
  @utf8.decode_lossy(data[:length])
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
    self.object.fill_path(index, 1) catch {
      error =>
        self.warn("a metafile path could not be filled: " + error.to_string())
    }
  }
  if pen {
    let scale = self.matrix().scale()
    let mut width = self.state.pen_width
    if width <= 0.0 || self.state.pen_cosmetic {
      width = 0.75 / (if scale > 0.000000001 { scale } else { 0.000000001 })
    }
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
  self.draw_path(verbs.to_bytes(), coordinates, fill, true)
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
  self.draw_path(verbs, [x0, y0, x1 - x0, y1 - y0], true, true)
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
  self.draw_path(
    b"\x06",
    [cx, cy, rx, ry, 0.0, 0.0, 2.0 * 3.141592653589793, 0.0],
    true,
    true,
  )
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
  self.draw_path(b"\x08", [x0, y0, x1 - x0, y1 - y0, scaled_radius], true, true)
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
  if (self.state.text_align & 8) != 0 {
    py = py + size * 0.2
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
fn dib_bits_offset(data : Bytes) -> Int32 {
  if data.length() < 12 {
    return 0
  }
  let header = le32(data, 0).to_int()
  if header == 12 {
    let bpp = le16(data, 10)
    let colors = if bpp <= 8 { 1 << bpp } else { 0 }
    return 12 + colors * 3
  }
  if data.length() < 40 {
    return 0
  }
  let bpp = le16(data, 14)
  let compression = le32(data, 16).to_int()
  let used = le32(data, 32).to_int()
  let colors = if bpp <= 8 { if used > 0 { used } else { 1 << bpp } } else { 0 }
  let masks = if compression == 3 && header == 40 { 12 } else { 0 }
  header + masks + colors * 4
}

///|
fn dib_decode(data : Bytes, bits_data : Bytes?) -> Dib? {
  if data.length() < 12 {
    return None
  }
  let header = le32(data, 0).to_int()
  let mut width = 0
  let mut height = 0
  let mut bpp = 0
  let mut compression = 0
  let mut palette_offset = 0
  let mut palette_entry = 4
  if header == 12 {
    width = le16(data, 4)
    height = le16(data, 6)
    bpp = le16(data, 10)
    palette_offset = 12
    palette_entry = 3
  } else {
    if data.length() < 40 {
      return None
    }
    width = lei32(data, 4).to_int()
    height = lei32(data, 8).to_int()
    bpp = le16(data, 14)
    compression = le32(data, 16).to_int()
    palette_offset = header
    if compression == 3 && header == 40 {
      palette_offset += 12
    }
  }
  if width <= 0 || height == 0 || width > 100000 || height.abs() > 100000 {
    return None
  }
  let top_down = height < 0
  let rows = if top_down { -height } else { height }
  if rows <= 0 || rows > 100000 {
    return None
  }
  let bits_offset = dib_bits_offset(data)
  let bits = match bits_data {
    Some(value) =>
      if value.length() > 0 {
        value
      } else {
        data[bits_offset:].to_owned()
      }
    None => data[bits_offset:].to_owned()
  }
  let stride = (width * bpp + 31) / 32 * 4
  if stride <= 0 || bits.length() < stride * rows {
    return None
  }
  let rgba : FixedArray[Byte] = FixedArray::make(
    width * rows * 4,
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
          let bit = (data[row_offset + x / 8].to_int() >> (7 - x % 8)) & 1
          let at = palette + bit * palette_entry
          blue = data[at].to_int()
          green = data[at + 1].to_int()
          red = data[at + 2].to_int()
        }
        4 => {
          let value = data[row_offset + x / 2].to_int()
          let index = if x % 2 == 0 { value >> 4 } else { value & 0xf }
          let at = palette + index * palette_entry
          blue = data[at].to_int()
          green = data[at + 1].to_int()
          red = data[at + 2].to_int()
        }
        8 => {
          let index = data[row_offset + x].to_int()
          let at = palette + index * palette_entry
          blue = data[at].to_int()
          green = data[at + 1].to_int()
          red = data[at + 2].to_int()
        }
        16 => {
          let at = row_offset + x * 2
          let value = data[at].to_int() | (data[at + 1].to_int() << 8)
          if compression == 3 {
            let masks_at = if header >= 52 { 40 } else { 40 }
            let red_mask = le32(data, masks_at).to_int()
            let green_mask = le32(data, masks_at + 4).to_int()
            let blue_mask = le32(data, masks_at + 8).to_int()
            red = ((value & red_mask) * 255 / red_mask.max(1)).min(255)
            green = ((value & green_mask) * 255 / green_mask.max(1)).min(255)
            blue = ((value & blue_mask) * 255 / blue_mask.max(1)).min(255)
          } else {
            red = ((value >> 10) & 0x1f) * 255 / 31
            green = ((value >> 5) & 0x1f) * 255 / 31
            blue = (value & 0x1f) * 255 / 31
          }
        }
        24 => {
          let at = row_offset + x * 3
          blue = data[at].to_int()
          green = data[at + 1].to_int()
          red = data[at + 2].to_int()
        }
        32 => {
          let at = row_offset + x * 4
          blue = data[at].to_int()
          green = data[at + 1].to_int()
          red = data[at + 2].to_int()
          alpha = data[at + 3].to_int()
          if alpha == 0 {
            alpha = 255
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
  pics? : Array[Bytes],
) -> Array[String] raise MetafileError {
  let pics : Array[Bytes] = match pics {
    Some(v) => v
    None => []
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
    dw_path: [],
  }
  object.save()
  object.clip_rect(
    Float::from_double(x),
    Float::from_double(y),
    Float::from_double(w),
    Float::from_double(h),
  )
  if file_kind == "emf" {
    g.play_emf(data, x, y, w, h)
  } else {
    g.play_wmf(data, x, y, w, h)
  }
  object.restore()
  g.warnings
}
