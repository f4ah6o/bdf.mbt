///|
priv struct WoffStream {
  data : BytesView
  mut pos : Int32
  mut error : Bool
}

///|
fn WoffStream::new(data : BytesView) -> WoffStream {
  { data, pos: 0, error: false, }
}

///|
fn WoffStream::byte(self : WoffStream) -> Int32 {
  if self.pos >= self.data.length() {
    self.error = true
    return 0
  }
  let b = self.data[self.pos].to_int()
  self.pos += 1
  b
}

///|
fn WoffStream::u16(self : WoffStream) -> Int32 {
  if self.pos > self.data.length() - 2 {
    self.error = true
    return 0
  }
  let n = get16(self.data, self.pos)
  self.pos += 2
  n
}

///|
fn WoffStream::take(self : WoffStream, n : Int32) -> BytesView {
  if n < 0 || n > self.data.length() - self.pos {
    self.error = true
    return b""[:]
  }
  let result = self.data[self.pos:self.pos + n]
  self.pos += n
  result
}

///|
fn WoffStream::u255(self : WoffStream) -> Int32 {
  match self.byte() {
    253 => self.u16()
    255 => self.byte() + 253
    254 => self.byte() + 506
    n => n
  }
}

///|
fn signed16(n : Int32) -> Int32 {
  if n >= 32768 {
    n - 65536
  } else {
    n
  }
}

///|
fn triplet_sign(flag : Int32, value : Int32) -> Int32 {
  if (flag & 1) != 0 {
    value
  } else {
    -value
  }
}

///|
fn decode_triplet(flag : Int32, stream : WoffStream) -> (Int32, Int32) {
  if flag < 10 {
    (0, triplet_sign(flag, ((flag & 14) << 7) + stream.byte()))
  } else if flag < 20 {
    (triplet_sign(flag, (((flag - 10) & 14) << 7) + stream.byte()), 0)
  } else if flag < 84 {
    let b0 = flag - 20
    let b1 = stream.byte()
    (
      triplet_sign(flag, 1 + (b0 & 0x30) + (b1 >> 4)),
      triplet_sign(flag >> 1, 1 + ((b0 & 0x0c) << 2) + (b1 & 0x0f)),
    )
  } else if flag < 120 {
    let b0 = flag - 84
    (
      triplet_sign(flag, 1 + ((b0 / 12) << 8) + stream.byte()),
      triplet_sign(flag >> 1, 1 + ((b0 % 12) >> 2 << 8) + stream.byte()),
    )
  } else if flag < 124 {
    let a = stream.byte()
    let b = stream.byte()
    let c = stream.byte()
    (
      triplet_sign(flag, (a << 4) + (b >> 4)),
      triplet_sign(flag >> 1, ((b & 15) << 8) + c),
    )
  } else {
    let a = stream.byte()
    let b = stream.byte()
    let c = stream.byte()
    let d = stream.byte()
    (triplet_sign(flag, (a << 8) + b), triplet_sign(flag >> 1, (c << 8) + d))
  }
}

///|
fn rebuild_glyf(data : BytesView) -> (Bytes, Bytes) raise {
  if data.length() < 36 {
    fail()
  }
  let flags = get16(data, 2)
  let glyph_count = get16(data, 4)
  let streams : Array[WoffStream] = []
  let mut pos = 36
  for i in 0..<7 {
    let n = get32(data, 8 + i * 4).to_uint64()
    if n > (data.length() - pos).to_uint64() {
      fail()
    }
    let end = pos + n.to_int()
    streams.push(WoffStream::new(data[pos:end]))
    pos = end
  }
  let contours = streams[0]
  let points = streams[1]
  let point_flags = streams[2]
  let glyph_data = streams[3]
  let components = streams[4]
  let bounds = streams[5]
  let instructions = streams[6]
  let bitmap = bounds.take((glyph_count + 31) >> 5 << 2)
  let overlap = if (flags & 1) != 0 {
    let n = (glyph_count + 7) >> 3
    if n > data.length() - pos {
      fail()
    }
    Some(data[pos:pos + n])
  } else {
    None
  }
  if bounds.error {
    fail()
  }
  let glyf : Array[Byte] = []
  let loca : Array[Byte] = []
  for glyph in 0..<glyph_count {
    append32(loca, glyf.length().reinterpret_as_uint())
    let has_bbox = (bitmap[glyph >> 3].to_int() & (0x80 >> (glyph & 7))) != 0
    let n = signed16(contours.u16())
    if n == 0 {
      if has_bbox {
        fail()
      }
    } else if n < 0 {
      if !has_bbox {
        fail()
      }
      append16(glyf, 0xffff)
      append_bytes(glyf, bounds.take(8))
      let mut has_instructions = false
      while true {
        let flags = components.u16()
        let mut size = 4
        if (flags & 0x0001) != 0 {
          size += 2
        }
        if (flags & 0x0008) != 0 {
          size += 2
        } else if (flags & 0x0040) != 0 {
          size += 4
        } else if (flags & 0x0080) != 0 {
          size += 8
        }
        append16(glyf, flags)
        append_bytes(glyf, components.take(size))
        if (flags & 0x0100) != 0 {
          has_instructions = true
        }
        if components.error || (flags & 0x0020) == 0 {
          break
        }
      }
      if has_instructions {
        let size = glyph_data.u255()
        append16(glyf, size)
        append_bytes(glyf, instructions.take(size))
      }
    } else {
      let ends : Array[Int32] = []
      let mut total = 0
      for _ in 0..<n {
        total += points.u255()
        ends.push(total - 1)
      }
      if total > 65535 {
        fail()
      }
      let xs : Array[Int32] = []
      let ys : Array[Int32] = []
      let on : Array[Bool] = []
      let mut x = 0
      let mut y = 0
      for _ in 0..<total {
        let f = point_flags.byte()
        on.push((f & 128) == 0)
        let (dx, dy) = decode_triplet(f & 127, glyph_data)
        x += dx
        y += dy
        xs.push(x)
        ys.push(y)
      }
      let ilen = glyph_data.u255()
      let instr = instructions.take(ilen)
      let mut xmin = 0
      let mut ymin = 0
      let mut xmax = 0
      let mut ymax = 0
      if has_bbox {
        let b = bounds.take(8)
        if b.length() == 8 {
          xmin = signed16(get16(b, 0))
          ymin = signed16(get16(b, 2))
          xmax = signed16(get16(b, 4))
          ymax = signed16(get16(b, 6))
        }
      } else if total > 0 {
        xmin = xs[0]
        xmax = xs[0]
        ymin = ys[0]
        ymax = ys[0]
        for i in 1..<total {
          xmin = Int32::min(xmin, xs[i])
          xmax = Int32::max(xmax, xs[i])
          ymin = Int32::min(ymin, ys[i])
          ymax = Int32::max(ymax, ys[i])
        }
      }
      append16(glyf, n)
      for v in [xmin, ymin, xmax, ymax] {
        append16(glyf, v)
      }
      for end in ends {
        append16(glyf, end)
      }
      append16(glyf, ilen)
      append_bytes(glyf, instr)
      let overlap_bit = match overlap {
        Some(bits) => (bits[glyph >> 3].to_int() & (0x80 >> (glyph & 7))) != 0
        None => false
      }
      for i in 0..<total {
        let mut f = if on[i] { 1 } else { 0 }
        if i == 0 && overlap_bit {
          f = f | 0x40
        }
        glyf.push(f.to_byte())
      }
      let mut previous = 0
      for value in xs {
        append16(glyf, value - previous)
        previous = value
      }
      previous = 0
      for value in ys {
        append16(glyf, value - previous)
        previous = value
      }
    }
    while glyf.length() % 4 != 0 {
      glyf.push(0)
    }
    for stream in streams {
      if stream.error {
        fail()
      }
    }
  }
  append32(loca, glyf.length().reinterpret_as_uint())
  (Bytes::from_array(glyf), Bytes::from_array(loca))
}

///|
fn rebuild_hmtx(data : BytesView, tables : Map[String, Bytes]) -> Bytes raise {
  let hhea = tables.get("hhea").unwrap_or(b"")
  let maxp = tables.get("maxp").unwrap_or(b"")
  let glyf = tables.get("glyf").unwrap_or(b"")
  let loca = tables.get("loca").unwrap_or(b"")
  if data.length() < 1 || hhea.length() < 36 || maxp.length() < 6 {
    fail()
  }
  let num_h = get16(hhea[:], 34)
  let glyph_count = get16(maxp[:], 4)
  if num_h < 1 || num_h > glyph_count {
    fail()
  }
  let stream = WoffStream::new(data[1:])
  let flags = data[0].to_int()
  let advances = [ for _ in 0..<num_h => stream.u16() ]
  let bearings : Array[Int32] = []
  for g in 0..<glyph_count {
    if (g < num_h && (flags & 1) == 0) || (g >= num_h && (flags & 2) == 0) {
      bearings.push(signed16(stream.u16()))
    } else {
      let mut xmin = 0
      if loca.length() >= (g + 2) * 4 {
        let start = get32(loca[:], g * 4).to_uint64()
        let end = get32(loca[:], g * 4 + 4).to_uint64()
        if start != end && start + 10UL <= glyf.length().to_uint64() {
          xmin = signed16(get16(glyf[:], start.to_int() + 2))
        }
      }
      bearings.push(xmin)
    }
  }
  if stream.error {
    fail()
  }
  let out : Array[Byte] = []
  for g in 0..<glyph_count {
    if g < num_h {
      append16(out, advances[g])
    }
    append16(out, bearings[g])
  }
  Bytes::from_array(out)
}
