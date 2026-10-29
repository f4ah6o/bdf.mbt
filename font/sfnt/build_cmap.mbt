///|
fn push16(out : Array[Byte], value : Int32) -> Unit {
  out.push(((value >> 8) & 255).to_byte())
  out.push((value & 255).to_byte())
}

///|
fn push32(out : Array[Byte], value : UInt32) -> Unit {
  out.push((value >> 24).to_byte())
  out.push((value >> 16).to_byte())
  out.push((value >> 8).to_byte())
  out.push(value.to_byte())
}

///|
priv struct CmapSegment {
  start : Int32
  mut end : Int32
  glyphs : Array[Int32]
}

///|
priv struct CmapGroup {
  start : Int32
  mut end : Int32
  glyph : Int32
}

///|
fn build_cmap(map : Map[Int32, Int32]) -> Array[Byte] {
  let codes = map.keys().collect()
  codes.sort()
  let segments : Array[CmapSegment] = []
  let mut needs12 = false
  for code in codes {
    if code > 0xffff {
      needs12 = true
    }
    if code > 0xfffe {
      continue
    }
    let last = segments.length() - 1
    if last >= 0 && segments[last].end + 1 == code {
      segments[last].end = code
      segments[last].glyphs.push(map[code])
    } else {
      segments.push({ start: code, end: code, glyphs: [map[code]], })
    }
  }
  segments.push({ start: 0xffff, end: 0xffff, glyphs: [0], })
  let count = segments.length()
  let ends : Array[Byte] = []
  let starts : Array[Byte] = []
  let deltas : Array[Byte] = []
  let offsets : Array[Byte] = []
  let glyphs : Array[Byte] = []
  for i, segment in segments {
    push16(ends, segment.end)
    push16(starts, segment.start)
    let mut consecutive = true
    for k in 1..<segment.glyphs.length() {
      if segment.glyphs[k] != ((segment.glyphs[0] + k) & 0xffff) {
        consecutive = false
        break
      }
    }
    if consecutive {
      push16(deltas, segment.glyphs[0] - segment.start)
      push16(offsets, 0)
    } else {
      push16(deltas, 0)
      push16(offsets, (count - i) * 2 + glyphs.length())
      for glyph in segment.glyphs {
        push16(glyphs, glyph)
      }
    }
  }
  let mut selector = 0
  while 1 << (selector + 1) <= count {
    selector += 1
  }
  let search = (1 << selector) * 2
  let f4 : Array[Byte] = []
  push16(f4, 4)
  push16(f4, 0)
  push16(f4, 0)
  push16(f4, count * 2)
  push16(f4, search)
  push16(f4, selector)
  push16(f4, count * 2 - search)
  for byte in ends {
    f4.push(byte)
  }
  push16(f4, 0)
  for byte in starts {
    f4.push(byte)
  }
  for byte in deltas {
    f4.push(byte)
  }
  for byte in offsets {
    f4.push(byte)
  }
  for byte in glyphs {
    f4.push(byte)
  }
  put16(f4, 2, f4.length())
  let f12 : Array[Byte] = []
  if needs12 {
    let groups : Array[CmapGroup] = []
    for code in codes {
      let glyph = map[code]
      let last = groups.length() - 1
      if last >= 0 &&
        groups[last].end + 1 == code &&
        groups[last].glyph + code - groups[last].start == glyph {
        groups[last].end = code
      } else {
        groups.push({ start: code, end: code, glyph, })
      }
    }
    push16(f12, 12)
    push16(f12, 0)
    push32(f12, (16 + groups.length() * 12).reinterpret_as_uint())
    push32(f12, 0U)
    push32(f12, groups.length().reinterpret_as_uint())
    for group in groups {
      push32(f12, group.start.reinterpret_as_uint())
      push32(f12, group.end.reinterpret_as_uint())
      push32(f12, group.glyph.reinterpret_as_uint())
    }
  }
  let out : Array[Byte] = []
  let count = if needs12 { 2 } else { 1 }
  let header = 4 + count * 8
  push16(out, 0)
  push16(out, count)
  push16(out, 3)
  push16(out, 1)
  push32(out, header.reinterpret_as_uint())
  if needs12 {
    push16(out, 3)
    push16(out, 10)
    push32(out, (header + f4.length()).reinterpret_as_uint())
  }
  for byte in f4 {
    out.push(byte)
  }
  for byte in f12 {
    out.push(byte)
  }
  out
}
