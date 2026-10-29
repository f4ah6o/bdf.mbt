///|
fn append255(out : Array[Byte], value : Int32) -> Unit {
  if value < 253 {
    out.push(value.to_byte())
  } else if value < 506 {
    out.push(255)
    out.push((value - 253).to_byte())
  } else if value < 762 {
    out.push(254)
    out.push((value - 506).to_byte())
  } else {
    out.push(253)
    append16(out, value)
  }
}

///|
fn append_triplet(
  flags : Array[Byte],
  data : Array[Byte],
  on : Int32,
  x : Int32,
  y : Int32,
) -> Unit {
  let ax = if x < 0 { -x } else { x }
  let ay = if y < 0 { -y } else { y }
  let sx = if x >= 0 { 1 } else { 0 }
  let sy = if y >= 0 { 1 } else { 0 }
  let sign = sx + 2 * sy
  if x == 0 && ay < 1280 {
    flags.push((on + ((ay & 0xf00) >> 7) + sy).to_byte())
    data.push(ay.to_byte())
  } else if y == 0 && ax < 1280 {
    flags.push((on + 10 + ((ax & 0xf00) >> 7) + sx).to_byte())
    data.push(ax.to_byte())
  } else if ax < 65 && ay < 65 {
    flags.push(
      (on + 20 + ((ax - 1) & 0x30) + (((ay - 1) & 0x30) >> 2) + sign).to_byte(),
    )
    data.push(((((ax - 1) & 15) << 4) | ((ay - 1) & 15)).to_byte())
  } else if ax < 769 && ay < 769 {
    flags.push(
      (on +
      84 +
      12 * (((ax - 1) & 0x300) >> 8) +
      (((ay - 1) & 0x300) >> 6) +
      sign).to_byte(),
    )
    data.push((ax - 1).to_byte())
    data.push((ay - 1).to_byte())
  } else if ax < 4096 && ay < 4096 {
    flags.push((on + 120 + sign).to_byte())
    data.push((ax >> 4).to_byte())
    data.push((((ax & 15) << 4) | (ay >> 8)).to_byte())
    data.push(ay.to_byte())
  } else {
    flags.push((on + 124 + sign).to_byte())
    data.push((ax >> 8).to_byte())
    data.push(ax.to_byte())
    data.push((ay >> 8).to_byte())
    data.push(ay.to_byte())
  }
}

///|
fn transform_glyf(
  glyf : Bytes,
  loca : Bytes,
  count : Int32,
  long : Bool,
) -> Bytes? {
  let offset = (index : Int32) => {
    if long {
      if index * 4 + 4 > loca.length() {
        None
      } else {
        Some(get32(loca[:], index * 4).to_uint64())
      }
    } else if index * 2 + 2 > loca.length() {
      None
    } else {
      Some((get16(loca[:], index * 2) * 2).to_uint64())
    }
  }
  let contours : Array[Byte] = []
  let points : Array[Byte] = []
  let flag_data : Array[Byte] = []
  let glyph_data : Array[Byte] = []
  let components : Array[Byte] = []
  let bbox_data : Array[Byte] = []
  let instructions : Array[Byte] = []
  let bbox_bitmap = Bytes::make((count + 31) >> 5 << 2, 0).to_array()
  let overlap = Bytes::make((count + 7) >> 3, 0).to_array()
  let mut has_overlap = false
  guard offset(0) is Some(initial) else { return None }
  let mut start = initial
  for glyph in 0..<count {
    guard offset(glyph + 1) is Some(end) else { return None }
    if end < start || end > glyf.length().to_uint64() {
      return None
    }
    let d = glyf[start.to_int():end.to_int()]
    start = end
    if d.length() == 0 {
      append16(contours, 0)
      continue
    }
    if d.length() < 10 {
      return None
    }
    let nc = signed16(get16(d, 0))
    if nc == 0 {
      append16(contours, 0)
      continue
    }
    if nc > 0 {
      let s = WoffStream::new(d)
      s.pos = 10
      let mut prev = -1
      for _ in 0..<nc {
        let end = s.u16()
        if s.error || end <= prev {
          return None
        }
        append255(points, end - prev)
        prev = end
      }
      let np = prev + 1
      let instr_len = s.u16()
      let instr = s.take(instr_len)
      if s.error {
        return None
      }
      let flags : Array[Int32] = []
      while flags.length() < np {
        let f = s.byte()
        if s.error || (f & 0x80) != 0 {
          return None
        }
        flags.push(f)
        if (f & 8) != 0 {
          let repeat = s.byte()
          if s.error {
            return None
          }
          for _ in 0..<repeat {
            if flags.length() < np {
              flags.push(f)
            }
          }
        }
      }
      let overlapped = (flags[0] & 0x40) != 0
      let coords = (short : Int32, same : Int32) => {
        let values : Array[Int32] = []
        for f in flags {
          if (f & short) != 0 {
            let value = s.byte()
            values.push(if (f & same) == 0 { -value } else { value })
          } else if (f & same) == 0 {
            values.push(signed16(s.u16()))
          } else {
            values.push(0)
          }
        }
        values
      }
      let dx = coords(2, 16)
      let dy = coords(4, 32)
      if s.error {
        return None
      }
      let bbox = [0, 0, 0, 0]
      let mut x = 0
      let mut y = 0
      for i, f in flags {
        x += dx[i]
        y += dy[i]
        if i == 0 || x < bbox[0] {
          bbox[0] = signed16(x & 65535)
        }
        if i == 0 || y < bbox[1] {
          bbox[1] = signed16(y & 65535)
        }
        if i == 0 || x > bbox[2] {
          bbox[2] = signed16(x & 65535)
        }
        if i == 0 || y > bbox[3] {
          bbox[3] = signed16(y & 65535)
        }
        append_triplet(
          flag_data,
          glyph_data,
          if (f & 1) != 0 {
            0
          } else {
            128
          },
          dx[i],
          dy[i],
        )
      }
      append255(glyph_data, instr_len)
      append_bytes(instructions, instr)
      append16(contours, nc)
      for i in 0..<4 {
        if signed16(get16(d, 2 + i * 2)) != bbox[i] {
          bbox_bitmap[glyph >> 3] = (bbox_bitmap[glyph >> 3].to_int() |
          (0x80 >> (glyph & 7))).to_byte()
          append_bytes(bbox_data, d[2:10])
          break
        }
      }
      if overlapped {
        overlap[glyph >> 3] = (overlap[glyph >> 3].to_int() |
        (0x80 >> (glyph & 7))).to_byte()
        has_overlap = true
      }
    } else {
      let mut p = 10
      let mut have_instructions = false
      while true {
        if p > d.length() - 4 {
          return None
        }
        let f = get16(d, p)
        have_instructions = have_instructions || (f & 0x100) != 0
        p += 4
        p += if (f & 1) != 0 { 4 } else { 2 }
        if (f & 8) != 0 {
          p += 2
        } else if (f & 0x40) != 0 {
          p += 4
        } else if (f & 0x80) != 0 {
          p += 8
        }
        if (f & 0x20) == 0 {
          break
        }
      }
      if p > d.length() {
        return None
      }
      append_bytes(components, d[10:p])
      if have_instructions {
        if p > d.length() - 2 {
          return None
        }
        let n = get16(d, p)
        if n > d.length() - (p + 2) {
          return None
        }
        append255(glyph_data, n)
        append_bytes(instructions, d[p + 2:p + 2 + n])
      }
      append16(contours, 0xffff)
      bbox_bitmap[glyph >> 3] = (bbox_bitmap[glyph >> 3].to_int() |
      (0x80 >> (glyph & 7))).to_byte()
      append_bytes(bbox_data, d[2:10])
    }
  }
  let bbox = bbox_bitmap
  for b in bbox_data {
    bbox.push(b)
  }
  let streams = [
    contours, points, flag_data, glyph_data, components, bbox, instructions,
  ]
  let out = Bytes::make(36, 0).to_array()
  put16(out, 2, if has_overlap { 1 } else { 0 })
  put16(out, 4, count)
  put16(out, 6, 1)
  for i, stream in streams {
    put32(out, 8 + i * 4, stream.length().reinterpret_as_uint())
  }
  for stream in streams {
    for b in stream {
      out.push(b)
    }
  }
  if has_overlap {
    for b in overlap {
      out.push(b)
    }
  }
  Some(Bytes::from_array(out))
}
