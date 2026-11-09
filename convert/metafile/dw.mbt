///|
/// The DIB `data` (a BITMAPINFO with its bits, or separate) as PNG bytes.
pub fn dib_to_png(data : Bytes, bits : Bytes?) -> Bytes? {
  match dib_decode(data, bits) {
    Some(dib) =>
      try Some(@raster.encode_png(dib.width, dib.height, dib.rgba)) catch {
        _ => None
      }
    None => None
  }
}

///|
fn i8le(p : Bytes, at : Int) -> Double {
  if at < p.length() {
    let v = p[at].to_int()
    if v >= 128 {
      (v - 256).to_double()
    } else {
      v.to_double()
    }
  } else {
    0.0
  }
}

///|
fn i16le(p : Bytes, at : Int) -> Double {
  if at + 2 <= p.length() {
    let v = p[at].to_int() | (p[at + 1].to_int() << 8)
    if v >= 0x8000 {
      (v - 0x10000).to_double()
    } else {
      v.to_double()
    }
  } else {
    0.0
  }
}

///|
/// The layout of a GDICOMMENT record's DW shape: u32 point count, first
/// point as two i16, then `n - 1` steps in the given encoding. `0x20` is
/// two i16 per point; `0x40` is two i8 steps; `0x80` packs the x step in
/// the high nibble and the y step in the low nibble (a nibble of 8 means
/// the step is in the next byte, signed).
fn dw_points(p : Bytes, enc : Int) -> Array[(Double, Double)] {
  let out : Array[(Double, Double)] = []
  let n = le32(p, 0).to_int()
  if n <= 0 || p.length() < 8 || n > p.length() {
    return out
  }
  let mut x = i16le(p, 4)
  let mut y = i16le(p, 6)
  out.push((x, y))
  let mut i = 8
  for _ in 1..<n {
    if enc == 0x20 {
      if i + 4 > p.length() {
        break
      }
      x = i16le(p, i)
      y = i16le(p, i + 2)
      i += 4
    } else if enc == 0x40 {
      if i + 2 > p.length() {
        break
      }
      x += i8le(p, i)
      y += i8le(p, i + 1)
      i += 2
    } else {
      // one byte: x step in the high nibble, y step in the low nibble; a
      // nibble of 8 means "the step is in the next byte"
      if i >= p.length() {
        break
      }
      let b = p[i].to_int()
      i += 1
      let hx = b.lsr(4)
      let lx = b & 15
      if hx == 8 {
        x += i8le(p, i)
        i += 1
      } else {
        x += (if hx >= 8 { hx - 16 } else { hx }).to_double()
      }
      if lx == 8 {
        y += i8le(p, i)
        i += 1
      } else {
        y += (if lx >= 8 { lx - 16 } else { lx }).to_double()
      }
    }
    out.push((x, y))
  }
  out
}

///|
fn dw_slice(data : Bytes, at : Int, len : Int) -> Bytes {
  if at < 0 || len < 0 || at + len > data.length() {
    return data[0 : 0].to_owned()
  }
  data[at : at + len].to_owned()
}

///|
/// Play one GDICOMMENT record whose data starts with `DW`.
fn Gdi::dw(self : Gdi, record : Bytes) -> Unit {
  if record.length() < 16 {
    return
  }
  let data = record[12:].to_owned()
  if data.length() < 4 || data[0:2] != b"DW"[:] {
    return
  }
  let a = data[2].to_int()
  let b2 = data[3].to_int()
  let p = data[4:].to_owned()
  if a == 48 {
    // '0': the DW pen/path records
    match b2 {
      50 => {
        // DW02: begin a path
        self.dw_path.clear()
      }
      51 => {
        // DW03: clip to the path
        self.dw_set_clip()
      }
      52 => {
        // DW04: fill the path
        self.dw_draw_accumulated(true, false)
      }
      53 => {
        // DW05: stroke the path
        self.dw_draw_accumulated(false, true)
      }
      54 => {
        // DW06: clip to a rectangle
        if p.length() >= 16 {
          let x0 = lei32(p, 0)
          let y0 = lei32(p, 4)
          let x1 = lei32(p, 8)
          let y1 = lei32(p, 12)
          self.clip_rect_instance(x0, y0, x1 - x0, y1 - y0)
        }
      }
      _ => ()
    }
  } else if a == 97 {
    // 'a': a picture stored in the record (BITMAPINFO, then bits, as a
    // STRETCHDIBITS would carry them)
    if p.length() >= 16 {
      let off_bmi = le32(p, 0).to_int()
      let cb_bmi = le32(p, 4).to_int()
      let off_bits = le32(p, 8).to_int()
      let cb_bits = le32(p, 12).to_int()
      let bmi = dw_slice(record, off_bmi, cb_bmi)
      let bits = dw_slice(record, off_bits, cb_bits)
      if !bmi.is_empty() {
        self.dw_dib = (bmi, Some(bits))
        self.dw_jpeg = None
      }
    }
  } else if a == 98 {
    // 'b': the next picture of the page's picture list
    let pic = self.dw_pic
    if pic < self.dw_pics.length() && pic < 100000 {
      self.dw_pic += 1
      self.dw_external_picture(self.dw_pics[pic])
    } else {
      self.warn("DWb without a picture of the page")
    }
  } else if a == 99 {
    // 'c': draw the picture, as a STRETCHDIBITS without the offsets
    if p.length() >= 56 {
      // v[4] xDest, v[5] yDest, v[6] xSrc, v[7] ySrc, v[8] cxSrc,
      // v[9] cySrc, v[11] rop, v[12] cxDest, v[13] cyDest
      let dstx = lei32(p, 16)
      let dsty = lei32(p, 20)
      let srcx = lei32(p, 24)
      let srcy = lei32(p, 28)
      let srcw = lei32(p, 32)
      let srch = lei32(p, 36)
      let rop = le32(p, 44).to_int()
      let dstw = lei32(p, 48)
      let dsth = lei32(p, 52)
      self.dw_draw_picture(srcx, srcy, srcw, srch, dstx, dsty, dstw, dsth, rop)
    }
  } else if b2 == 32 || b2 == 64 || b2 == 128 {
    // the point-encoded DW shape records: op in data[2]
    let pts = dw_points(p, b2)
    if pts.is_empty() {
      return
    }
    if a == 32 {
      // 0x20: a polygon on its own, filled
      self.dw_poly(pts, true)
    } else if a == 64 {
      // 0x40: a polyline on its own, stroked
      self.dw_poly(pts, false)
    } else {
      self.dw_extend(pts, a)
    }
  } else {
    self.warn("DW " + a.to_string() + " " + b2.to_string() + " is not supported")
  }
}

///|
fn Gdi::dw_poly(self : Gdi, pts : Array[(Double, Double)], closed : Bool) -> Unit {
  if pts.length() < 2 {
    return
  }
  let m = self.matrix()
  let verbs = @buffer.Buffer()
  let coordinates : Array[Double] = []
  for i, point in pts {
    let (x, y) = m.apply(point.0, point.1)
    verbs.write_byte(if i == 0 { 0 } else { 1 })
    coordinates.push(x)
    coordinates.push(y)
  }
  if closed {
    verbs.write_byte(4)
  }
  let index = self.object.add_path(
    @core.Inline({ verbs: verbs.to_bytes(), coordinates, }),
  )
  self.fill_or_stroke(index, closed, true)
}

///|
fn Gdi::fill_or_stroke(
  self : Gdi,
  index : Int32,
  fill : Bool,
  stroke : Bool,
) -> Unit {
  let brush = !self.state.brush_null && fill
  let pen = !self.state.pen_null && stroke
  if !brush && !pen {
    return
  }
  let mul = self.state.rop2 == 9
  if mul {
    self.object.blend(1)
  }
  if brush {
    self.state_brush_fill(index)
  }
  if pen {
    self.state_pen_stroke(index)
  }
  if mul {
    self.object.blend(0)
  }
}

///|
fn Gdi::state_brush_fill(self : Gdi, index : Int32) -> Unit {
  if self.state.brush_hatch >= 0 {
    self.warn("metafile hatch brushes are approximated")
  }
  self.object.fill_color(self.state.brush_color)
  self.object.fill_path(index, 1) catch {
    error =>
      self.warn("a metafile path could not be filled: " + error.to_string())
  }
}

///|
fn Gdi::state_pen_stroke(self : Gdi, index : Int32) -> Unit {
  let scale = self.matrix().scale()
  let mut width = self.state.pen_width
  if width <= 0.0 || self.state.pen_cosmetic {
    width = 0.75 / (if scale > 0.000000001 { scale } else { 0.000000001 })
  }
  self.object.stroke_color(self.state.pen_color)
  self.object.line(Float::from_double(width), 1, 1, 10)
  self.object.stroke_path(index) catch {
    error =>
      self.warn("a metafile path could not be stroked: " + error.to_string())
  }
}

///|
fn Gdi::clip_rect_instance(self : Gdi, x : Double, y : Double, w : Double, h : Double) -> Unit {
  self.object.clip_rect(
    Float::from_double(x),
    Float::from_double(y),
    Float::from_double(w),
    Float::from_double(h),
  )
}

///|
/// The DW path as a clip, in the record's own units.
fn Gdi::dw_set_clip(self : Gdi) -> Unit {
  if self.dw_path.is_empty() {
    return
  }
  let verbs = @buffer.Buffer()
  let coordinates : Array[Double] = []
  for i, point in self.dw_path {
    verbs.write_byte(if i == 0 { 0 } else { 1 })
    coordinates.push(point.0)
    coordinates.push(point.1)
  }
  let index = self.object.add_path(
    @core.Inline({ verbs: verbs.to_bytes(), coordinates, }),
  )
  self.object.clip_path(index, 1) catch {
    error => self.warn("a path could not clip: " + error.to_string())
  }
}

///|
fn Gdi::dw_draw_accumulated(self : Gdi, fill : Bool, stroke : Bool) -> Unit {
  if self.dw_path.is_empty() {
    return
  }
  let verbs = @buffer.Buffer()
  let coordinates : Array[Double] = []
  for i, point in self.dw_path {
    verbs.write_byte(if i == 0 { 0 } else { 1 })
    coordinates.push(point.0)
    coordinates.push(point.1)
  }
  let index = self.object.add_path(
    @core.Inline({ verbs: verbs.to_bytes(), coordinates, }),
  )
  self.fill_or_stroke(index, fill, stroke)
}

///|
/// The points of a DW shape record extend the DW path. Bits:
/// the first point starts a new figure, bit 1 closes the figure after
/// these points, bit 4 marks Bézier triples.
fn Gdi::dw_extend(self : Gdi, pts : Array[(Double, Double)], op : Int) -> Unit {
  let start = (op & 1) != 0
  let bez = (op & 0x10) != 0
  let mut body = pts
  if start {
    body = []
    for i in 1..<pts.length() {
      body.push(pts[i])
    }
    let point = self.pt(pts[0].0, pts[0].1)
    self.dw_path.push(point)
  }
  if bez {
    if body.length() >= 3 && body.length() % 3 == 0 {
      let m = self.matrix()
      let mut i = 0
      while i + 2 < body.length() {
        for k in 0..<3 {
          let point = m.apply(body[i + k].0, body[i + k].1)
          self.dw_path.push(point)
        }
        i += 3
      }
    }
  } else {
    for point in body {
      let (a, b) = self.pt(point.0, point.1)
      self.dw_path.push((a, b))
    }
  }
  if !start && self.dw_path.is_empty() {
    if pts.length() > 0 {
      let point = self.pt(pts[0].0, pts[0].1)
      self.dw_path.push(point)
    }
  }
}

///|
/// The object record's transform of a point.
fn Gdi::pt(self : Gdi, x : Double, y : Double) -> (Double, Double) {
  self.matrix().apply(x, y)
}

///|
fn Gdi::dw_external_picture(self : Gdi, d : Bytes) -> Unit {
  // A picture stored in its own entry: 16-byte header (size, 0, width,
  // height) then JPEG data, or a DIB.
  if d.length() > 18 && d[16].to_int() == 0xff && d[17].to_int() == 0xd8 {
    self.dw_dib = (d[0 : 0].to_owned(), None)
    self.dw_jpeg = Some(d[16:].to_owned())
    return
  }
  self.dw_dib = (d, None)
  self.dw_jpeg = None
}

///|
fn Gdi::dw_draw_picture(
  self : Gdi,
  srcx : Double,
  srcy : Double,
  srcw : Double,
  srch : Double,
  dstx : Double,
  dsty : Double,
  dstw : Double,
  dsth : Double,
  rop : Int32,
) -> Unit {
  let mul = rop == 0x8800C6
  // SRCAND: the picture multiplies the page (a see-through image)
  if mul {
    self.object.blend(1)
  }
  let jpeg = self.dw_jpeg
  match jpeg {
    Some(by) => {
      // the whole picture is one JPEG part
      let hash = self.writer.add_part("img", by) catch {
        error => {
          self.warn("a picture could not be stored: " + error.to_string())
          return
        }
      }
      let index = match self.images.get(hash) {
        Some(v) => v
        None => {
          let v = self.object.add_image(hash)
          self.images[hash] = v
          v
        }
      }
      let m = self.matrix()
      let (x0, y0) = m.apply(dstx, dsty)
      let (x1, y1) = m.apply(dstx + dstw, dsty + dsth)
      self.object.image(
        index,
        Float::from_double(if x0 < x1 { x0 } else { x1 }),
        Float::from_double(if y0 < y1 { y0 } else { y1 }),
        Float::from_double((x1 - x0).abs()),
        Float::from_double((y1 - y0).abs()),
      ) catch {
        error => self.warn("a picture could not be drawn: " + error.to_string())
      }
    }
    None => {
      let (bmi, bits) = self.dw_dib
      // The DIB is re-oriented top-down when decoded, so the source rect
      // of a bottom-up bitmap counts y from the bottom.
      let mut sy = srcy
      if bmi.length() > 12 && lei32(bmi, 8) > 0.0 && srch > 0.0 {
        let height = lei32(bmi, 8)
        sy = height - srcy - srch
      }
      self.image(
        bmi,
        bits,
        srcx,
        sy,
        srcw,
        srch,
        dstx,
        dsty,
        dstw,
        dsth,
      )
    }
  }
  if mul {
    self.object.blend(0)
  }
}
