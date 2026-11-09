///|
priv struct EmfFrame {
  left : Double
  top : Double
  right : Double
  bottom : Double
  pxmm_x : Double
  pxmm_y : Double
}

///|
fn emf_frame(data : Bytes) -> EmfFrame? {
  if data.length() < 88 {
    return None
  }
  let bounds_left = lei32(data, 8)
  let bounds_top = lei32(data, 12)
  let bounds_right = lei32(data, 16)
  let bounds_bottom = lei32(data, 20)
  let frame_left = lei32(data, 24)
  let frame_top = lei32(data, 28)
  let frame_right = lei32(data, 32)
  let frame_bottom = lei32(data, 36)
  let device_x = lei32(data, 72)
  let device_y = lei32(data, 76)
  let millimetres_x = lei32(data, 80)
  let millimetres_y = lei32(data, 84)
  let default_pxmm = 96.0 / 25.4
  let mut pxmm_x = default_pxmm
  let mut pxmm_y = default_pxmm
  if device_x > 0.0 &&
    millimetres_x > 0.0 &&
    device_y > 0.0 &&
    millimetres_y > 0.0 {
    pxmm_x = device_x / millimetres_x
    pxmm_y = device_y / millimetres_y
  }
  let mut left = frame_left / 100.0 * pxmm_x
  let mut top = frame_top / 100.0 * pxmm_y
  let mut right = frame_right / 100.0 * pxmm_x
  let mut bottom = frame_bottom / 100.0 * pxmm_y
  if right - left <= 0.0 || bottom - top <= 0.0 {
    left = bounds_left
    top = bounds_top
    right = bounds_right + 1.0
    bottom = bounds_bottom + 1.0
  }
  if right - left <= 0.0 || bottom - top <= 0.0 {
    None
  } else {
    Some({ left, top, right, bottom, pxmm_x, pxmm_y, })
  }
}

///|
fn emf_points(
  record : Bytes,
  offset : Int32,
  count : Int32,
  short : Bool,
) -> Array[(Double, Double)] {
  let size = if short { 4 } else { 8 }
  let available = (record.length() - offset) / size
  let mut number = count
  if number > available {
    number = available
  }
  let points : Array[(Double, Double)] = []
  for i in 0..<number {
    let at = offset + i * size
    if short {
      points.push(
        (lei16(record, at).to_double(), lei16(record, at + 2).to_double()),
      )
    } else {
      points.push((lei32(record, at), lei32(record, at + 4)))
    }
  }
  points
}

///|
fn emf_stock_object(index : Int64) -> GdiObject? {
  match (index & 0x7fffffffL).to_int() {
    0 => Some(Brush(0xffffffffU, false, -1))
    1 => Some(Brush(color_int(191, 191, 191), false, -1))
    2 => Some(Brush(color_int(128, 128, 128), false, -1))
    3 => Some(Brush(color_int(64, 64, 64), false, -1))
    4 => Some(Brush(0x000000ffU, false, -1))
    5 => Some(Brush(0, true, -1))
    6 => Some(Pen(1.0, 0xffffffffU, 0, false, true))
    7 => Some(Pen(1.0, 0x000000ffU, 0, false, true))
    8 => Some(Pen(1.0, 0, 0, true, false))
    10 | 11 | 16 =>
      Some(Font(12.0, 400, false, false, false, "Courier New", 0.0, 128))
    12 | 13 | 14 | 17 =>
      Some(Font(12.0, 400, false, false, false, "Arial", 0.0, 0))
    18 => Some(Brush(0xffffffffU, false, -1))
    19 => Some(Pen(1.0, 0x000000ffU, 0, false, true))
    _ => None
  }
}

///|
fn Gdi::select_object(self : Gdi, handle : Int64) -> Unit {
  let object = if (handle & 0x80000000L) != 0L {
    emf_stock_object(handle)
  } else {
    self.objects.get(handle)
  }
  match object {
    Some(Pen(width, color, style, cosmetic, null)) => {
      self.state.pen_width = width
      self.state.pen_color = color
      self.state.pen_style = style
      self.state.pen_cosmetic = cosmetic
      self.state.pen_null = null
    }
    Some(Brush(color, null, hatch)) => {
      self.state.brush_color = color
      self.state.brush_null = null
      self.state.brush_hatch = hatch
    }
    Some(
      Font(height, weight, italic, underline, strike, face, escapement, charset)
    ) => {
      self.state.font_height = height
      self.state.font_weight = weight
      self.state.font_italic = italic
      self.state.font_underline = underline
      self.state.font_strike = strike
      self.state.font_face = face
      self.state.font_escapement = escapement
      self.state.font_charset = charset
    }
    None => ()
  }
}

///|
fn Gdi::save_state(self : Gdi) -> Unit {
  if self.stack.length() >= 65536 {
    self.warn("a metafile saves too many states")
    return
  }
  self.stack.push(self.state)
}

///|
fn Gdi::restore_state(self : Gdi, level : Int32) -> Unit {
  let index = if level < 0 { self.stack.length() + level } else { level - 1 }
  if index < 0 || index >= self.stack.length() {
    return
  }
  self.state = self.stack[index]
  while self.stack.length() > index {
    ignore(self.stack.pop())
  }
}

///|
/// The window an EMF sets before drawing: (extent x, extent y, origin x,
/// origin y, map mode). Annotation drawings fit this window to their box;
/// their frame is not reliable.
fn emf_window(data : Bytes) -> (Double, Double, Double, Double, Int32)? {
  let mut position = 0
  let mut records = 0
  let mut extent : (Double, Double)? = None
  let mut origin : (Double, Double) = (0.0, 0.0)
  let mut mode = 1
  while position + 8 <= data.length() && records < 1000000 {
    let kind = le32(data, position).to_int()
    let size = le32(data, position + 4).to_int()
    if size < 8 || position + size > data.length() {
      break
    }
    match kind {
      9 =>
        extent = Some((lei32(data, position + 8), lei32(data, position + 12)))
      10 => origin = (lei32(data, position + 8), lei32(data, position + 12))
      17 => mode = le32(data, position + 8).to_int()
      14 => break
      _ => ()
    }
    position += size
    records += 1
  }
  match extent {
    Some((ex, ey)) => Some((ex, ey, origin.0, origin.1, mode))
    None => None
  }
}

///|
fn Gdi::play_emf(
  self : Gdi,
  data : Bytes,
  x : Double,
  y : Double,
  w : Double,
  annotation~ : Bool,
  h : Double,
) -> Unit {
  let frame = emf_frame(data)
  let window = if annotation { emf_window(data) } else { None }
  let use_window = match window {
    Some((ex, ey, _, _, mode)) => ex > 0.0 && ey > 0.0 && mode == 1
    None => false
  }
  if use_window {
    // the viewer fits the annotation's window to its box
    let (ex, ey, _, _, _) = match window {
      Some(value) => value
      None => (0.0, 0.0, 0.0, 0.0, 1)
    }
    self.out = mat_mul(mat_translate(x, y), mat_scale(w / ex, h / ey))
    match frame {
      Some(value) => self.pxmm = value.pxmm_x
      None => ()
    }
  } else {
    let frame = match frame {
      Some(value) => value
      None => return
    }
    self.pxmm = frame.pxmm_x
    let box_width = frame.right - frame.left
    let box_height = frame.bottom - frame.top
    self.out = mat_mul(
      mat_mul(mat_translate(x, y), mat_scale(w / box_width, h / box_height)),
      mat_translate(-frame.left, -frame.top),
    )
  }
  let mut position = 0
  let mut records = 0
  while position + 8 <= data.length() && records < 1000000 {
    let kind = le32(data, position).to_int()
    let size = le32(data, position + 4).to_int()
    if size < 8 || position + size > data.length() {
      self.warn("a metafile could not be replayed completely")
      break
    }
    let record = data[position:position + size].to_owned()
    position += size
    records += 1
    match kind {
      14 => return
      2 | 3 | 4 | 85 | 86 | 87 => {
        let short = kind >= 85
        let mut base = kind
        if short {
          base -= 83
        }
        let points = emf_points(record, 28, le32(record, 24).to_int(), short)
        if points.is_empty() {
          continue
        }
        if base == 2 {
          // POLYBEZIER: the first point is the start, then cubic triples
          self.bezier(points, false)
        } else {
          let closed = base == 3
          self.polyline(points, closed, closed)
        }
      }
      5 | 6 | 88 | 89 => {
        let short = kind >= 88
        let points = emf_points(record, 28, le32(record, 24).to_int(), short)
        if points.is_empty() {
          continue
        }
        if kind == 5 || kind == 88 {
          // POLYBEZIERTO: cubic triples from the current point
          self.bezier(points, true)
        } else {
          if self.path_active {
            // LINETO inside a path extends the current figure
            let m = self.matrix()
            let verbs = @buffer.Buffer()
            let coordinates : Array[Double] = []
            for point in points {
              let (x, y) = m.apply(point.0, point.1)
              verbs.write_byte(1)
              coordinates.push(x)
              coordinates.push(y)
            }
            self.path_append(verbs.to_bytes(), coordinates)
          } else {
            let all : Array[(Double, Double)] = [self.state.cur]
            for point in points {
              all.push(point)
            }
            self.polyline(all, false, false)
          }
          self.state.cur = points[points.length() - 1]
        }
      }
      7 | 8 | 90 | 91 => {
        let short = kind >= 90
        let number = le32(record, 24).to_int()
        let total = le32(record, 28).to_int()
        if number <= 0 || number > record.length() {
          continue
        }
        let counts : Array[Int32] = []
        for i in 0..<number {
          counts.push(le32(record, 32 + i * 4).to_int())
        }
        let all = emf_points(record, 32 + number * 4, total, short)
        let closed = kind == 8 || kind == 91
        let mut at = 0
        for count in counts {
          let points : Array[(Double, Double)] = []
          for _ in 0..<count {
            if at < all.length() {
              points.push(all[at])
              at += 1
            }
          }
          if points.length() >= 2 {
            self.polyline(points, closed, closed)
          }
        }
      }
      9 => self.state.win_ext = (lei32(record, 8), lei32(record, 12))
      10 => self.state.win_org = (lei32(record, 8), lei32(record, 12))
      11 => self.state.vp_ext = (lei32(record, 8), lei32(record, 12))
      12 => self.state.vp_org = (lei32(record, 8), lei32(record, 12))
      17 => self.state.map_mode = le32(record, 8).to_int()
      18 => self.state.bk_opaque = le32(record, 8).to_int() == 2
      19 => self.state.poly_fill = le32(record, 8).to_int()
      20 => self.state.rop2 = le32(record, 8).to_int()
      22 => self.state.text_align = le32(record, 8).to_int()
      24 => self.state.text_color = colorref(le32(record, 8))
      25 => self.state.bk_color = colorref(le32(record, 8))
      27 => {
        let point = (lei32(record, 8), lei32(record, 12))
        if self.path_active {
          let (x, y) = self.pt(point.0, point.1)
          let verbs = @buffer.Buffer()
          verbs.write_byte(0)
          self.path_append(verbs.to_bytes(), [x, y])
        }
        self.state.cur = point
      }
      30 => {
        let m = self.matrix()
        let (x0, y0) = m.apply(lei32(record, 8), lei32(record, 12))
        let (x1, y1) = m.apply(lei32(record, 16), lei32(record, 20))
        self.object.clip_rect(
          Float::from_double(if x0 < x1 { x0 } else { x1 }),
          Float::from_double(if y0 < y1 { y0 } else { y1 }),
          Float::from_double((x1 - x0).abs()),
          Float::from_double((y1 - y0).abs()),
        )
        self.clip_active = true
      }
      33 => self.save_state()
      34 => self.restore_state(le32(record, 8).to_int())
      35 =>
        self.state.world = {
          a: lef32(record, 8),
          b: lef32(record, 12),
          c: lef32(record, 16),
          d: lef32(record, 20),
          e: lef32(record, 24),
          f: lef32(record, 28),
        }
      36 => {
        let transform : Mat = {
          a: lef32(record, 8),
          b: lef32(record, 12),
          c: lef32(record, 16),
          d: lef32(record, 20),
          e: lef32(record, 24),
          f: lef32(record, 28),
        }
        match le32(record, 32).to_int() {
          1 => self.state.world = mat_identity()
          2 => self.state.world = mat_mul(self.state.world, transform)
          3 => self.state.world = mat_mul(transform, self.state.world)
          4 => self.state.world = transform
          _ => ()
        }
      }
      37 => self.select_object(le32(record, 8))
      38 => {
        let style = le32(record, 12).to_int()
        let width = lei32(record, 16)
        self.objects[le32(record, 8)] = Pen(
          width,
          colorref(le32(record, 24)),
          style,
          width == 0.0,
          (style & 0xf) == 5,
        )
      }
      95 => {
        let style = le32(record, 28).to_int()
        let width = le32(record, 32).to_double()
        self.objects[le32(record, 8)] = Pen(
          width,
          colorref(le32(record, 40)),
          style,
          (style & 0x10000) == 0,
          (style & 0xf) == 5 || le32(record, 36).to_int() == 1,
        )
      }
      39 => {
        let style = le32(record, 12).to_int()
        self.objects[le32(record, 8)] = Brush(
          colorref(le32(record, 16)),
          style == 1,
          if style == 2 {
            le32(record, 20).to_int() % 6
          } else {
            -1
          },
        )
      }
      40 => self.objects.remove(le32(record, 8))
      42 =>
        self.ellipse(
          lei32(record, 8),
          lei32(record, 12),
          lei32(record, 16),
          lei32(record, 20),
        )
      43 =>
        self.rectangle(
          lei32(record, 8),
          lei32(record, 12),
          lei32(record, 16),
          lei32(record, 20),
        )
      44 =>
        self.round_rect(
          lei32(record, 8),
          lei32(record, 12),
          lei32(record, 16),
          lei32(record, 20),
          lei32(record, 24),
          lei32(record, 28),
        )
      45 | 46 | 47 =>
        // Arc, chord and pie: approximate the bounding ellipse.
        self.ellipse(
          lei32(record, 8),
          lei32(record, 12),
          lei32(record, 16),
          lei32(record, 20),
        )
      54 => {
        let point = (lei32(record, 8), lei32(record, 12))
        if self.path_active {
          let (x, y) = self.pt(point.0, point.1)
          let verbs = @buffer.Buffer()
          verbs.write_byte(1)
          self.path_append(verbs.to_bytes(), [x, y])
        } else {
          self.polyline([self.state.cur, point], false, false)
        }
        self.state.cur = point
      }
      59 => {
        // BEGINPATH: the drawing records that follow collect a path
        self.path_clear()
        self.path_active = true
      }
      60 => self.path_active = false // ENDPATH: keep the path for a fill/stroke
      61 =>
        // CLOSEFIGURE
        if self.path_active {
          let verbs = @buffer.Buffer()
          verbs.write_byte(4)
          self.path_append(verbs.to_bytes(), [])
        }
      62 => {
        // FILLPATH
        self.path_active = false
        self.path_flush(true, false)
      }
      63 => {
        // STROKEANDFILLPATH
        self.path_active = false
        self.path_flush(true, true)
      }
      64 => {
        // STROKEPATH
        self.path_active = false
        self.path_flush(false, true)
      }
      65 => () // FLATTENPATH: the path is already flat
      66 => self.warn("metafile WIDENPATH is not supported") // WIDENPATH
      67 => {
        // SELECTCLIPPATH
        self.path_active = false
        self.path_clip_mode(le32(record, 8).to_int())
      }
      68 => {
        // ABORTPATH
        self.path_active = false
        self.path_clear()
      }
      76 | 77 => {
        let dx = lei32(record, 24)
        let dy = lei32(record, 28)
        let dw = lei32(record, 32)
        let dh = lei32(record, 36)
        let bmi = emf_slice(record, le32(record, 84), le32(record, 88))
        let bits = emf_slice(record, le32(record, 92), le32(record, 96))
        if bmi.is_empty() {
          self.rectangle(dx, dy, dx + dw, dy + dh)
        } else {
          self.image(
            bmi,
            Some(bits),
            lei32(record, 44),
            lei32(record, 48),
            dw,
            dh,
            dx,
            dy,
            dw,
            dh,
          )
        }
      }
      80 => {
        let bmi = emf_slice(record, le32(record, 48), le32(record, 52))
        let bits = emf_slice(record, le32(record, 56), le32(record, 60))
        if !bmi.is_empty() {
          self.image(
            bmi,
            Some(bits),
            lei32(record, 32),
            lei32(record, 36),
            lei32(record, 40),
            lei32(record, 44),
            lei32(record, 24),
            lei32(record, 28),
            lei32(record, 40),
            lei32(record, 44),
          )
        }
      }
      81 => {
        let bmi = emf_slice(record, le32(record, 48), le32(record, 52))
        let bits = emf_slice(record, le32(record, 56), le32(record, 60))
        if !bmi.is_empty() {
          self.image(
            bmi,
            Some(bits),
            lei32(record, 32),
            lei32(record, 36),
            lei32(record, 40),
            lei32(record, 44),
            lei32(record, 24),
            lei32(record, 28),
            lei32(record, 72),
            lei32(record, 76),
          )
        }
      }
      82 => {
        let face = if record.length() >= 72 {
          utf16_text(record[40:].to_owned(), 32)
        } else {
          "Arial"
        }
        self.objects[le32(record, 8)] = Font(
          lei32(record, 12),
          lei32(record, 28).to_int(),
          record.length() > 32 && record[32] != 0,
          record.length() > 33 && record[33] != 0,
          record.length() > 34 && record[34] != 0,
          face,
          lei32(record, 20),
          if record.length() > 35 {
            record[35].to_int()
          } else {
            0
          },
        )
      }
      83 | 84 => {
        if record.length() < 76 {
          continue
        }
        let rx = lei32(record, 36)
        let ry = lei32(record, 40)
        let count = le32(record, 44).to_int()
        let offset = le32(record, 48).to_int()
        let options = le32(record, 52).to_int()
        if (options & 0x10) != 0 {
          self.warn("metafile text drawn by glyph index is not supported")
          continue
        }
        if count <= 0 || offset < 0 || offset >= record.length() {
          continue
        }
        let text = if kind == 84 {
          utf16_text(record[offset:].to_owned(), count)
        } else {
          let length = count.min(record.length() - offset)
          ansi_text(
            record[offset:offset + length].to_owned(),
            self.state.font_charset,
          )
        }
        let dx_offset = le32(record, 72).to_int()
        let advances : Array[Double] = []
        if dx_offset > 0 && dx_offset < record.length() {
          let step = if (options & 0x2000) != 0 { 8 } else { 4 }
          for i in 0..<count {
            let at = dx_offset + i * step
            if at + 4 > record.length() {
              break
            }
            advances.push(lei32(record, at))
          }
        }
        let mut adv : Array[Double]? = None
        if !advances.is_empty() && advances.length() == count {
          adv = Some(advances)
        }
        if (options & 0x2) != 0 {
          self.object.fill_color(self.state.bk_color)
          let m = self.matrix()
          let (x0, y0) = m.apply(lei32(record, 56), lei32(record, 60))
          let (x1, y1) = m.apply(lei32(record, 64), lei32(record, 68))
          self.object.fill_rect(
            Float::from_double(if x0 < x1 { x0 } else { x1 }),
            Float::from_double(if y0 < y1 { y0 } else { y1 }),
            Float::from_double((x1 - x0).abs()),
            Float::from_double((y1 - y0).abs()),
          )
        }
        self.text(rx, ry, text, adv)
      }
      70 =>
        if record.length() >= 20 &&
          record[12:16] == b"EMF+"[:] &&
          le16(record, 16) == 0x4001 &&
          (le16(record, 18) & 1) == 0 {
          self.warn("EMF+ only metafiles are not supported")
        } else {
          self.dw(record)
        }
      _ => ()
    }
  }
}

///|
fn emf_slice(record : Bytes, offset : Int64, length : Int64) -> Bytes {
  if length <= 0L || offset < 0L {
    return b""
  }
  let end = offset + length
  if end > record.length().to_int64() {
    b""
  } else {
    record[offset.to_int():end.to_int()].to_owned()
  }
}
