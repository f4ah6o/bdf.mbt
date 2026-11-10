///|
/// The DocuWorks driver's GDI comment records (`DW02`–`DW06`, `DWa`,
/// `DWb`, `DWc`, and the point-encoded DW shape records), which the
/// DocuWorks printer driver writes into the page EMFs instead of regular
/// GDI records.

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
/// The DIB `data` as PNG bytes, reading its uncompressed rows top-to-bottom
/// even when `biHeight` is positive. A kind 7 annotation body stores its
/// expanded rows that way; ordinary metafile DIBs and kind 7 page content
/// keep [`dib_to_png`]'s bottom-up reading.
pub fn dib_to_png_top_down(data : Bytes, bits : Bytes?) -> Bytes? {
  match dib_decode_top_down(data, bits) {
    Some(dib) =>
      try Some(@raster.encode_png(dib.width, dib.height, dib.rgba)) catch {
        _ => None
      }
    None => None
  }
}

///|
/// The most bands a kind 7 DIB body may carry. A real picture uses one band
/// per strip; the cap keeps a crafted count from allocating an array.
const MAX_DIB_BANDS : Int = 4096

///|
/// The largest number of bytes one picture may contribute, for one band and
/// for all bands together. It is the bits of the largest image the PNG
/// encoder accepts (67108864 pixels at 32 bits), so a picture that could be
/// drawn is never refused, while a crafted body cannot make the reader copy
/// or join more than this.
const MAX_DIB_BAND_BYTES : Int64 = 256L << 20

///|
/// The bytes a band contributes to the joined DIB: the expanded size when
/// the band is LZH-compressed, otherwise the stored bytes as they are. A
/// zero expanded size means the band is stored, not compressed.
fn dib_band_output_size(stored : Int64, expanded : Int64) -> Int64 {
  if expanded > 0L && expanded != stored {
    expanded
  } else {
    stored
  }
}

///|
/// Whether a band fits the caps: its joined output and its stored copy,
/// against the running totals. The subtraction keeps a crafted size from
/// overflowing the sum.
fn dib_band_sizes_ok(
  output : Int64,
  stored : Int64,
  output_total : Int64,
  stored_total : Int64,
) -> Bool {
  output <= MAX_DIB_BAND_BYTES - output_total &&
  stored <= MAX_DIB_BAND_BYTES - stored_total
}

///|
/// Split a kind 7 DIB body into its BITMAPINFO and its bands.
///
/// The body is the BITMAPINFO, then a u32 band count, then for each band a
/// 12-byte header (stored size, expanded size, rows) and the stored bytes.
/// A band's bits are LZH-compressed when its expanded size differs from its
/// stored size; a zero expanded size means the band is stored as it is.
/// Every length is checked against the bytes that are really there, and the
/// joined output and the stored copies are capped, so a truncated or
/// oversized body is refused instead of read past.
pub fn dib_body_bands(data : Bytes) -> (Bytes, Array[(Bytes, Int32)])? {
  let n = dib_bits_offset(data)
  // `dib_bits_offset` works in Int32 on untrusted sizes, so `n` can be a
  // large positive value; compare by subtraction so `n + 4` cannot wrap
  if n <= 0 || n > data.length() - 4 {
    return None
  }
  let count = le32(data, n)
  if count <= 0L || count > MAX_DIB_BANDS.to_int64() {
    return None
  }
  // every band needs its 12-byte header, so the count is also bounded by
  // the bytes that are really there
  if count > ((data.length() - n - 4) / 12).to_int64() {
    return None
  }
  let bands : Array[(Bytes, Int32)] = []
  let mut at = n + 4
  let mut output_total = 0L
  let mut stored_total = 0L
  for _ in 0..<count.to_int() {
    // subtraction, not `at + 12`, so a crafted offset cannot wrap
    if at > data.length() - 12 {
      return None
    }
    let stored = le32(data, at)
    let expanded = le32(data, at + 4)
    if stored > (data.length() - at - 12).to_int64() {
      return None
    }
    let output = dib_band_output_size(stored, expanded)
    if !dib_band_sizes_ok(output, stored, output_total, stored_total) {
      return None
    }
    output_total += output
    stored_total += stored
    let start = at + 12
    let end = start + stored.to_int()
    bands.push((data[start:end].to_owned(), expanded.to_int()))
    at = end
  }
  Some((data[0:n].to_owned(), bands))
}

///|
/// Split a kind 7 DIB body into its BITMAPINFO and its first band: the
/// stored bits and the size they expand to. A body with several bands is
/// read by [`dib_body_bands`]; this keeps the single-band shape.
pub fn dib_body_split(data : Bytes) -> (Bytes, Bytes, Int32, Int32)? {
  match dib_body_bands(data) {
    Some((bmi, bands)) =>
      if bands.is_empty() {
        None
      } else {
        let (stored, expanded) = bands[0]
        Some((bmi, stored, stored.length(), expanded))
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
        // DW03: clip to the path, then consume it
        self.dw_set_clip()
        self.dw_path.clear()
      }
      52 => {
        // DW04: fill the path, then consume it
        self.dw_draw_accumulated(true, false)
        self.dw_path.clear()
      }
      53 => {
        // DW05: stroke the path, then consume it
        self.dw_draw_accumulated(false, true)
        self.dw_path.clear()
      }
      54 => {
        // DW06: clip to a rectangle (i32, logical units)
        if p.length() >= 16 {
          let x0 = lei32(p, 0)
          let y0 = lei32(p, 4)
          let x1 = lei32(p, 8)
          let y1 = lei32(p, 12)
          self.dw_set_clip_rect(x0, y0, x1, y1)
        }
      }
      _ => ()
    }
  } else if a == 97 && b2 == 0 {
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
  } else if a == 98 && b2 == 0 {
    // 'b': the next picture of the page's picture list
    let pic = self.dw_pic
    if pic < self.dw_pics.length() && pic < 100000 {
      self.dw_pic += 1
      self.dw_external_picture(self.dw_pics[pic])
    } else {
      self.warn("DWb without a picture of the page")
    }
  } else if a == 99 && b2 == 0 {
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
      // 0x20: a polygon on its own, filled (brush only)
      self.dw_poly(pts, true, false)
    } else if a == 64 {
      // 0x40: a polyline on its own, stroked (pen only)
      self.dw_poly(pts, false, true)
    } else {
      self.dw_extend(pts, a)
    }
  } else {
    self.warn("DW " + a.to_string() + " " + b2.to_string() + " is not supported")
  }
}

///|
/// A drawn DW path segment. Points are carried in page space (each record
/// is transformed as it is played, like GDI does at path-play time).
priv enum DwSeg {
  DwMove(Double, Double)
  DwLine(Double, Double)
  DwCubic(Double, Double, Double, Double, Double, Double)
  DwClose
}

///|
/// The DW path as a clip. DW03 replaces the clip region, like
/// SelectClipPath(RGN_COPY), so reset to the clip base first.
fn Gdi::dw_set_clip(self : Gdi) -> Unit {
  if self.dw_path.is_empty() {
    return
  }
  let verbs = @buffer.Buffer()
  let coordinates : Array[Double] = []
  dw_emit(self.dw_path, verbs, coordinates)
  let index = self.object.add_path(
    @core.Inline({ verbs: verbs.to_bytes(), coordinates, }),
  )
  self.clip_replace()
  self.object.clip_path(index, 1) catch {
    error => self.warn("a path could not clip: " + error.to_string())
  }
  self.clip_active = true
}

///|
/// Turn the stored segments into path verbs/coordinates.
fn dw_emit(
  path : Array[DwSeg],
  verbs : @buffer.Buffer,
  coordinates : Array[Double],
) -> Unit {
  for seg in path {
    match seg {
      DwMove(x, y) => {
        verbs.write_byte(0)
        coordinates.push(x)
        coordinates.push(y)
      }
      DwLine(x, y) => {
        verbs.write_byte(1)
        coordinates.push(x)
        coordinates.push(y)
      }
      DwCubic(x1, y1, x2, y2, x, y) => {
        verbs.write_byte(3)
        coordinates.push(x1)
        coordinates.push(y1)
        coordinates.push(x2)
        coordinates.push(y2)
        coordinates.push(x)
        coordinates.push(y)
      }
      DwClose => verbs.write_byte(4)
    }
  }
}

///|
fn Gdi::dw_draw_accumulated(self : Gdi, fill : Bool, stroke : Bool) -> Unit {
  if self.dw_path.is_empty() {
    return
  }
  let verbs = @buffer.Buffer()
  let coordinates : Array[Double] = []
  dw_emit(self.dw_path, verbs, coordinates)
  let index = self.object.add_path(
    @core.Inline({ verbs: verbs.to_bytes(), coordinates, }),
  )
  self.fill_or_stroke(index, fill, stroke)
}

///|
/// Fill/stroke a built path honouring hatch approximations, the null pen
/// and brush, and the highlighter's multiply (R2_MASKPEN).
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
    if self.state.brush_hatch >= 0 {
      self.warn("metafile hatch brushes are approximated")
    }
    self.object.fill_color(self.state.brush_color)
    self.object.fill_path(index, 1) catch {
      error =>
        self.warn("a metafile path could not be filled: " + error.to_string())
    }
  }
  if pen {
    let width = self.pen_page_width()
    self.object.stroke_color(self.state.pen_color)
    self.object.line(Float::from_double(width), 1, 1, 10)
    let style = self.state.pen_style & 0xf
    let dashes : Array[Float] = match style {
      1 => [3.0F, 1.0F]
      2 => [1.0F, 1.0F]
      3 => [3.0F, 1.0F, 1.0F, 1.0F]
      4 => [3.0F, 1.0F, 1.0F, 1.0F, 1.0F, 1.0F]
      _ => []
    }
    if dashes.is_empty() {
      self.object.dash([], 0.0F)
    } else {
      let scaled : Array[Float] = []
      for dash in dashes {
        scaled.push(dash * Float::from_double(width * 2.0))
      }
      self.object.dash(scaled, 0.0F)
    }
    self.object.stroke_path(index) catch {
      error =>
        self.warn("a metafile path could not be stroked: " + error.to_string())
    }
  }
  if mul {
    self.object.blend(0)
  }
}

///|
/// A DW06 rectangle as a clip, through the current transform. DW06 replaces
/// the clip region, so reset to the clip base first.
fn Gdi::dw_set_clip_rect(self : Gdi, ax0 : Double, ay0 : Double, ax1 : Double, ay1 : Double) -> Unit {
  let mut x0 = ax0
  let mut y0 = ay0
  let mut x1 = ax1
  let mut y1 = ay1
  if x0 > x1 {
    let t = x0
    x0 = x1
    x1 = t
  }
  if y0 > y1 {
    let t = y0
    y0 = y1
    y1 = t
  }
  // the four corners go through the current transform, like the
  // upstream's poly_path(rect_points(r), true)
  let (ax, ay) = self.pt(x0, y0)
  let (bx, by) = self.pt(x1, y0)
  let (cx, cy) = self.pt(x1, y1)
  let (dx, dy) = self.pt(x0, y1)
  let path : Array[DwSeg] = [
    DwMove(ax, ay),
    DwLine(bx, by),
    DwLine(cx, cy),
    DwLine(dx, dy),
    DwClose,
  ]
  let verbs = @buffer.Buffer()
  let coordinates : Array[Double] = []
  dw_emit(path, verbs, coordinates)
  let index = self.object.add_path(
    @core.Inline({ verbs: verbs.to_bytes(), coordinates, }),
  )
  self.clip_replace()
  self.object.clip_path(index, 1) catch {
    error => self.warn("a clip rectangle could not be set: " + error.to_string())
  }
  self.clip_active = true
}

///|
/// Build a transformed polygon/polyline and fill or stroke it.
fn Gdi::dw_poly(
  self : Gdi,
  pts : Array[(Double, Double)],
  fill : Bool,
  stroke : Bool,
) -> Unit {
  if pts.length() < 2 {
    return
  }
  let verbs = @buffer.Buffer()
  let coordinates : Array[Double] = []
  for i, point in pts {
    let (x, y) = self.pt(point.0, point.1)
    verbs.write_byte(if i == 0 { 0 } else { 1 })
    coordinates.push(x)
    coordinates.push(y)
  }
  if fill {
    verbs.write_byte(4)
  }
  let index = self.object.add_path(
    @core.Inline({ verbs: verbs.to_bytes(), coordinates, }),
  )
  self.fill_or_stroke(index, fill, stroke)
}

///|
/// One point-encoded DW shape record: the points extend the DW path.
/// op bits: the first point starts a new figure (move), bit 1 closes the
/// figure after these points, bit 4 marks Bézier triples.
fn Gdi::dw_extend(self : Gdi, pts : Array[(Double, Double)], op : Int) -> Unit {
  let start = (op & 1) != 0
  let bez = (op & 0x10) != 0
  let close = (op & 2) != 0
  // a figure that does not start with a move continues from the last
  // point; seed one before the body when there is none
  if !start && self.dw_path.is_empty() {
    if pts.length() > 0 {
      let (x, y) = self.pt(pts[0].0, pts[0].1)
      self.dw_path.push(DwMove(x, y))
    }
  }
  let mut body = pts
  if start {
    body = []
    for i in 1..<pts.length() {
      body.push(pts[i])
    }
    let (x, y) = self.pt(pts[0].0, pts[0].1)
    self.dw_path.push(DwMove(x, y))
  }
  if bez {
    if body.length() >= 3 && body.length() % 3 == 0 {
      let mut i = 0
      while i + 2 < body.length() {
        let (x1, y1) = self.pt(body[i].0, body[i].1)
        let (x2, y2) = self.pt(body[i + 1].0, body[i + 1].1)
        let (x, y) = self.pt(body[i + 2].0, body[i + 2].1)
        self.dw_path.push(DwCubic(x1, y1, x2, y2, x, y))
        i += 3
      }
    }
  } else {
    for point in body {
      let (x, y) = self.pt(point.0, point.1)
      self.dw_path.push(DwLine(x, y))
    }
  }
  if close {
    self.dw_path.push(DwClose)
  }
}

///|
/// The object record's transform of a point.
fn Gdi::pt(self : Gdi, x : Double, y : Double) -> (Double, Double) {
  self.matrix().apply(x, y)
}

///|
fn Gdi::dw_external_picture(self : Gdi, d : Bytes) -> Unit {
  // A picture stored in its own entry: either a 16-byte header (size, 0,
  // width, height) and then JPEG data, or a raw JPEG, or a DIB.
  if d.length() > 18 && d[16].to_int() == 0xff && d[17].to_int() == 0xd8 {
    self.dw_dib = (d[0 : 0].to_owned(), None)
    self.dw_jpeg = Some(d[16:].to_owned())
    return
  }
  if d.length() > 2 && d[0].to_int() == 0xff && d[1].to_int() == 0xd8 {
    self.dw_dib = (d[0 : 0].to_owned(), None)
    self.dw_jpeg = Some(d)
    return
  }
  self.dw_dib = (d, None)
  self.dw_jpeg = None
}

///|
/// The width and height a JPEG's SOF frame keeps, when the file carries
/// them.
fn dw_jpeg_size(d : Bytes) -> (Int, Int)? {
  if d.length() < 4 || d[0].to_int() != 0xff || d[1].to_int() != 0xd8 {
    return None
  }
  let mut i = 2
  while i + 4 <= d.length() {
    if d[i].to_int() != 0xff {
      i += 1
      continue
    }
    let m = d[i + 1].to_int()
    if m == 0xff {
      i += 1
      continue
    }
    if m == 0xd8 || (m >= 0xd0 && m <= 0xd7) || m == 0x01 {
      i += 2
      continue
    }
    let len = (d[i + 2].to_int() << 8) | d[i + 3].to_int()
    // the segment must be fully inside the file; past it the file is
    // truncated and the caller just does not learn a size
    if i + 2 + len > d.length() {
      return None
    }
    if m >= 0xc0 && m <= 0xcf && m != 0xc4 && m != 0xc8 && m != 0xcc {
      // a SOF frame is at least 8 bytes long (precision, height, width,
      // then the component list): refuse shorter ones instead of reading
      // the height/width bytes past the segment
      if len < 8 {
        return None
      }
      let h = (d[i + 5].to_int() << 8) | d[i + 6].to_int()
      let w = (d[i + 7].to_int() << 8) | d[i + 8].to_int()
      if w > 0 && h > 0 {
        return Some((w, h))
      }
      return None
    }
    // a short non-SOF segment only shortens the scan
    if len < 2 {
      return None
    }
    i += 2 + len
  }
  None
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
  match rop {
    0xcc0020 => () // SRCCOPY: a plain draw
    0x8800c6 => {
      // SRCAND: the picture multiplies the page (a see-through image)
      self.object.blend(1)
    }
    _ =>
      self.warn(
        "a DW picture uses the raster operation " +
        rop.to_string() +
        ", which is not supported",
      )
  }
  let jpeg = self.dw_jpeg
  match jpeg {
    Some(by) => {
      // The picture is one JPEG part. A scanned page draws it in strips:
      // each DWc carries a source rectangle, so the part is cropped with
      // image_sub instead of being squeezed into the strip.
      let hash = self.writer.add_part("img", by) catch {
        error => {
          self.warn("a picture could not be stored: " + error.to_string())
          if rop == 0x8800c6 {
            self.object.blend(0)
          }
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
      let dx = if x0 < x1 { x0 } else { x1 }
      let dy = if y0 < y1 { y0 } else { y1 }
      let dw = (x1 - x0).abs()
      let dh = (y1 - y0).abs()
      let full = dw_jpeg_size(by)
      let sx = srcx
      let sy = srcy
      let mut sw = srcw
      let mut sh = srch
      if sw <= 0.0 || sh <= 0.0 {
        match full {
          Some((pw, ph)) => {
            if sw <= 0.0 {
              sw = pw.to_double() - sx
            }
            if sh <= 0.0 {
              sh = ph.to_double() - sy
            }
          }
          None => ()
        }
      }
      let cropped = sx > 0.0 ||
        sy > 0.0 ||
        (match full {
          Some((pw, ph)) => sw < pw.to_double() || sh < ph.to_double()
          None => false
        })
      if cropped {
        match full {
          Some(_) =>
            self.object.image_sub(
              index,
              Float::from_double(sx),
              Float::from_double(sy),
              Float::from_double(sw),
              Float::from_double(sh),
              Float::from_double(dx),
              Float::from_double(dy),
              Float::from_double(dw),
              Float::from_double(dh),
            ) catch {
              error =>
                self.warn("a picture could not be drawn: " + error.to_string())
            }
          None => {
            self.warn("a DW picture draws a cropped JPEG of unknown size")
            self.object.image(
              index,
              Float::from_double(dx),
              Float::from_double(dy),
              Float::from_double(dw),
              Float::from_double(dh),
            ) catch {
              error =>
                self.warn("a picture could not be drawn: " + error.to_string())
            }
          }
        }
      } else {
        self.object.image(
          index,
          Float::from_double(dx),
          Float::from_double(dy),
          Float::from_double(dw),
          Float::from_double(dh),
        ) catch {
          error =>
            self.warn("a picture could not be drawn: " + error.to_string())
        }
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
      self.image(bmi, bits, srcx, sy, srcw, srch, dstx, dsty, dstw, dsth)
    }
  }
  if rop == 0x8800c6 {
    self.object.blend(0)
  }
}

///|
test "dw_jpeg_size does not read past a truncated SOF" {
  // the announcement of a SOF frame at the very end of the file: the old
  // code read the height/width bytes unguarded
  let truncated = Bytes::from_array(
    FixedArray::from_array([0xff, 0xd8, 0xff, 0xc0, 0x00, 0x0b, 0xaa, 0xbb].map((v) => v.to_byte())),
  )
  guard dw_jpeg_size(truncated) is None else {
    abort("a size came out of a truncated frame")
  }
  // a segment that announces a SOF with no payload (len = 2)
  // never reads the height and width bytes
  let short = Bytes::from_array(
    FixedArray::from_array([0xff, 0xd8, 0xff, 0xc0, 0x00, 0x02].map((v) => v.to_byte())),
  )
  guard dw_jpeg_size(short) is None else {
    abort("a size came out of a two-byte SOF segment")
  }
  // a healthy SOF0 still reports its size
  let healthy = Bytes::from_array(
    FixedArray::from_array(
      [0xff, 0xd8, 0xff, 0xc0, 0x00, 0x11, 0x08, 0x00, 0x10, 0x00, 0x20, 0x03, 0x01, 0x11, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01]
      .map((v) => v.to_byte()),
    ),
  )
  guard dw_jpeg_size(healthy) == Some((32, 16)) else {
    abort("a healthy SOF0 did not report 32x16")
  }
}
