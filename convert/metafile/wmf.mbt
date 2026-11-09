///|
priv struct WmfBox {
  left : Double
  top : Double
  right : Double
  bottom : Double
  start : Int32
  inch : Double
}

///|
fn wmf_box(data : Bytes) -> WmfBox? {
  if data.length() < 18 {
    return None
  }
  let mut left = 0.0
  let mut top = 0.0
  let mut right = 0.0
  let mut bottom = 0.0
  let mut inch = 0.0
  let mut position = 0
  let placeable = le32(data, 0).to_int() == 0x9ac6cdd7
  if placeable {
    left = lei16(data, 6).to_double()
    top = lei16(data, 8).to_double()
    right = lei16(data, 10).to_double()
    bottom = lei16(data, 12).to_double()
    inch = le16(data, 14).to_double()
    position = 22
  }
  if position + 18 > data.length() {
    return None
  }
  position += le16(data, position + 2) * 2
  let start = position
  if !placeable || right == left || bottom == top {
    let mut org_x = 0.0
    let mut org_y = 0.0
    let mut ext_x = 0.0
    let mut ext_y = 0.0
    let mut have_ext = false
    let mut scan = start
    while scan + 6 <= data.length() {
      let size = le32(data, scan).to_int() * 2
      let function = le16(data, scan + 4)
      if size < 6 || scan + size > data.length() {
        break
      }
      match function {
        0x020b => {
          org_x = lei16(data, scan + 8).to_double()
          org_y = lei16(data, scan + 6).to_double()
        }
        0x020c =>
          if !have_ext {
            ext_x = lei16(data, scan + 8).to_double()
            ext_y = lei16(data, scan + 6).to_double()
            have_ext = true
          }
        _ => ()
      }
      scan += size
    }
    if !have_ext {
      ext_x = 1000.0
      ext_y = 1000.0
    }
    left = org_x
    top = org_y
    right = org_x + ext_x
    bottom = org_y + ext_y
  }
  if right == left || bottom == top {
    None
  } else {
    Some({ left, top, right, bottom, start, inch, })
  }
}

///|
fn Gdi::add_slot(self : Gdi, object : GdiObject) -> Unit {
  for i in 0..<self.slots.length() {
    if self.slots[i] is None {
      self.slots[i] = Some(object)
      return
    }
  }
  self.slots.push(Some(object))
}

///|
fn Gdi::select_slot(self : Gdi, index : Int32) -> Unit {
  if index < 0 || index >= self.slots.length() {
    return
  }
  match self.slots[index] {
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
fn Gdi::delete_slot(self : Gdi, index : Int32) -> Unit {
  if index >= 0 && index < self.slots.length() {
    self.slots[index] = None
  }
}

///|
fn Gdi::fill_rect(
  self : Gdi,
  left : Double,
  top : Double,
  right : Double,
  bottom : Double,
) -> Unit {
  let m = self.matrix()
  let (x0, y0) = m.apply(left, top)
  let (x1, y1) = m.apply(right, bottom)
  self.object.fill_color(self.state.brush_color)
  self.object.fill_rect(
    Float::from_double(if x0 < x1 { x0 } else { x1 }),
    Float::from_double(if y0 < y1 { y0 } else { y1 }),
    Float::from_double((x1 - x0).abs()),
    Float::from_double((y1 - y0).abs()),
  )
}

///|
fn Gdi::play_wmf(
  self : Gdi,
  data : Bytes,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit {
  let box = match wmf_box(data) {
    Some(value) => value
    None => return
  }
  let box_width = box.right - box.left
  let box_height = box.bottom - box.top
  self.state.map_mode = 8
  self.state.win_org = (box.left, box.top)
  self.state.vp_org = (box.left, box.top)
  self.state.win_ext = (box_width, box_height)
  self.state.vp_ext = (box_width, box_height)
  self.out = mat_mul(
    mat_mul(mat_translate(x, y), mat_scale(w / box_width, h / box_height)),
    mat_translate(-box.left, -box.top),
  )
  let mut position = box.start
  let mut records = 0
  while position + 6 <= data.length() && records < 1000000 {
    let words = le32(data, position).to_int()
    let size = words * 2
    let function = le16(data, position + 4)
    if size < 6 || position + size > data.length() {
      self.warn("a metafile could not be replayed completely")
      break
    }
    let args = data[position + 6:position + size].to_owned()
    position += size
    records += 1
    let arg = fn(index : Int32) -> Double { lei16(args, index * 2).to_double() }
    match function {
      0x0000 => return
      0x020b => self.state.win_org = (arg(1), arg(0))
      0x020c => self.state.win_ext = (arg(1), arg(0))
      0x020d => self.state.vp_org = (arg(1), arg(0))
      0x020e => self.state.vp_ext = (arg(1), arg(0))
      0x0102 => self.state.bk_opaque = le16(args, 0) == 2
      0x0106 => ()
      0x012e => self.state.text_align = le16(args, 0)
      0x0209 => self.state.text_color = colorref(le32(args, 0))
      0x0201 => self.state.bk_color = colorref(le32(args, 0))
      0x001e => self.save_state()
      0x0127 => self.restore_state(lei16(args, 0))
      0x02fa => {
        let style = le16(args, 0)
        let width = arg(1)
        self.add_slot(
          Pen(
            width,
            colorref(le32(args, 6)),
            style,
            width == 0.0,
            (style & 0xf) == 5,
          ),
        )
      }
      0x02fc => {
        let style = le16(args, 0)
        self.add_slot(
          Brush(
            colorref(le32(args, 2)),
            style == 1,
            if style == 2 {
              le16(args, 6) % 6
            } else {
              -1
            },
          ),
        )
      }
      0x02fb => {
        let mut face = "Arial"
        let mut charset = 0
        let mut italic = false
        let mut underline = false
        let mut strike = false
        if args.length() >= 18 {
          italic = args[10] != 0
          underline = args[11] != 0
          strike = args[12] != 0
          charset = args[13].to_int()
          let name = args[18:]
          let mut end = name.length()
          for i in 0..<name.length() {
            if name[i] == 0 {
              end = i
              break
            }
          }
          face = ansi_text(name[:end].to_owned(), charset)
        }
        self.add_slot(
          Font(
            arg(0).abs(),
            arg(4).to_int(),
            italic,
            underline,
            strike,
            face,
            arg(2),
            charset,
          ),
        )
      }
      0x012d => self.select_slot(le16(args, 0))
      0x01f0 => self.delete_slot(le16(args, 0))
      0x0324 | 0x0325 => {
        let count = le16(args, 0)
        let points : Array[(Double, Double)] = []
        for i in 0..<count {
          let at = 2 + i * 4
          if at + 4 > args.length() {
            break
          }
          points.push(
            (lei16(args, at).to_double(), lei16(args, at + 2).to_double()),
          )
        }
        if points.length() >= 2 {
          self.polyline(points, function == 0x0324, function == 0x0324)
        }
      }
      0x0538 => {
        let number = le16(args, 0)
        let mut offset = 2 + number * 2
        for i in 0..<number {
          let count = le16(args, 2 + i * 2)
          let points : Array[(Double, Double)] = []
          for _ in 0..<count {
            if offset + 4 > args.length() {
              break
            }
            points.push(
              (
                lei16(args, offset).to_double(),
                lei16(args, offset + 2).to_double(),
              ),
            )
            offset += 4
          }
          if points.length() >= 2 {
            self.polyline(points, true, true)
          }
        }
      }
      0x041b => self.rectangle(arg(3), arg(2), arg(1), arg(0))
      0x0418 => self.ellipse(arg(3), arg(2), arg(1), arg(0))
      0x061c => self.round_rect(arg(5), arg(4), arg(3), arg(2), arg(1), arg(0))
      0x0817 | 0x0830 | 0x081a => self.ellipse(arg(7), arg(6), arg(5), arg(4))
      0x0214 => self.state.cur = (arg(1), arg(0))
      0x0213 => {
        let point = (arg(1), arg(0))
        self.polyline([self.state.cur, point], false, false)
        self.state.cur = point
      }
      0x0416 => {
        let m = self.matrix()
        let (x0, y0) = m.apply(arg(3), arg(2))
        let (x1, y1) = m.apply(arg(1), arg(0))
        self.object.clip_rect(
          Float::from_double(if x0 < x1 { x0 } else { x1 }),
          Float::from_double(if y0 < y1 { y0 } else { y1 }),
          Float::from_double((x1 - x0).abs()),
          Float::from_double((y1 - y0).abs()),
        )
      }
      0x0922 => self.fill_rect(arg(5), arg(4), arg(5) + arg(3), arg(4) + arg(2))
      0x0521 => {
        let count = le16(args, 0)
        let offset = 2 + (count + 1) / 2 * 2
        if 2 + count > args.length() || offset < 0 {
          continue
        }
        let text = ansi_text(
          args[2:2 + count].to_owned(),
          self.state.font_charset,
        )
        let x = lei16(args, offset + 2).to_double()
        let y = lei16(args, offset).to_double()
        self.text(x, y, text, None)
      }
      0x0a32 => {
        let y = arg(0)
        let x = arg(1)
        let count = le16(args, 4)
        let options = le16(args, 6)
        let mut offset = 8
        if (options & 0x6) != 0 {
          if (options & 0x2) != 0 {
            self.fill_rect(
              lei16(args, 8).to_double(),
              lei16(args, 10).to_double(),
              lei16(args, 12).to_double(),
              lei16(args, 14).to_double(),
            )
          }
          offset += 8
        }
        if count <= 0 || offset + count > args.length() {
          continue
        }
        let text = ansi_text(
          args[offset:offset + count].to_owned(),
          self.state.font_charset,
        )
        offset += (count + 1) / 2 * 2
        let advances : Array[Double] = []
        if offset + count * 2 <= args.length() {
          for i in 0..<count {
            advances.push(lei16(args, offset + i * 2).to_double())
          }
        }
        let adv : Array[Double]? = if advances.length() == count {
          Some(advances)
        } else {
          None
        }
        self.text(x, y, text, adv)
      }
      0x0f43 =>
        if args.length() > 22 {
          let dib = args[22:]
          self.image(
            dib.to_owned(),
            None,
            arg(6),
            arg(5),
            arg(4),
            arg(3),
            arg(10),
            arg(9),
            arg(8),
            arg(7),
          )
        }
      0x0940 =>
        if args.length() > 16 {
          let dib = args[16:]
          self.image(
            dib.to_owned(),
            None,
            arg(3),
            arg(2),
            arg(5),
            arg(4),
            arg(7),
            arg(6),
            arg(5),
            arg(4),
          )
        }
      0x0b41 =>
        if args.length() > 20 {
          let dib = args[20:]
          self.image(
            dib.to_owned(),
            None,
            arg(5),
            arg(4),
            arg(3),
            arg(2),
            arg(9),
            arg(8),
            arg(7),
            arg(6),
          )
        }
      _ => ()
    }
  }
}
