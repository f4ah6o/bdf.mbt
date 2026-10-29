///|
fn glyph_components(data : BytesView) -> Array[(Int32, Int32)] {
  let result : Array[(Int32, Int32)] = []
  if data.length() < 10 || s16(data, 0) >= 0 {
    return result
  }
  let mut pos = 10
  while pos <= data.length() - 4 {
    let flags = u16(data, pos)
    result.push((pos + 2, u16(data, pos + 2)))
    pos += 4
    pos += if (flags & 1) != 0 { 4 } else { 2 }
    if (flags & 8) != 0 {
      pos += 2
    } else if (flags & 0x40) != 0 {
      pos += 4
    } else if (flags & 0x80) != 0 {
      pos += 8
    }
    if (flags & 0x20) == 0 {
      break
    }
  }
  result
}

///|
fn subset_glyph_data(font : Font, glyph : Int32) -> BytesView {
  let glyf = sfnt_table(font.source, font.tables, "glyf")
  let loca = sfnt_table(font.source, font.tables, "loca")
  let head = sfnt_table(font.source, font.tables, "head")
  if glyph < 0 || glyph >= font.metrics.glyph_count {
    return glyf[0:0]
  }
  let long = u16(head, 50) != 0
  let start = if long {
    u32(loca, glyph * 4)
  } else {
    u16(loca, glyph * 2).to_uint() * 2U
  }
  let end = if long {
    u32(loca, (glyph + 1) * 4)
  } else {
    u16(loca, (glyph + 1) * 2).to_uint() * 2U
  }
  if start > end || end > glyf.length().reinterpret_as_uint() {
    return glyf[0:0]
  }
  glyf[start.reinterpret_as_int():end.reinterpret_as_int()]
}

///|
/// Rebuild a TrueType font using only the requested characters and their
/// composite glyph dependencies. Returns None for unsupported outlines.
/// The caller must check embedding and subsetting permissions first.
pub fn Font::subset_program(
  self : Font,
  codepoints : Array[Int32],
) -> Bytes? raise {
  if self.metrics.is_cff ||
    !self.tables.contains("glyf") ||
    !self.tables.contains("loca") ||
    sfnt_table(self.source, self.tables, "head").length() < 54 ||
    self.metrics.glyph_count == 0 {
    return None
  }
  let requested : Map[Int32, Int32] = Map([])
  let pending : Array[Int32] = [0]
  let queued : Map[Int32, Bool] = { 0: true }
  for code in codepoints {
    match self.glyph(code) {
      Some(glyph) => {
        requested[code] = glyph
        if glyph < self.metrics.glyph_count && !queued.contains(glyph) {
          queued[glyph] = true
          pending.push(glyph)
        }
      }
      None => ()
    }
  }
  let needed : Map[Int32, Bool] = Map([])
  let mut next = 0
  while next < pending.length() {
    let glyph = pending[next]
    next += 1
    if glyph < 0 || glyph >= self.metrics.glyph_count || needed.contains(glyph) {
      continue
    }
    needed[glyph] = true
    for (_, child) in glyph_components(subset_glyph_data(self, glyph)) {
      if child < self.metrics.glyph_count && !queued.contains(child) {
        queued[child] = true
        pending.push(child)
      }
    }
  }
  let order = needed.keys().collect()
  order.sort()
  let remap : Map[Int32, Int32] = Map([])
  for index, glyph in order {
    remap[glyph] = index
  }
  let outlines : Array[Byte] = []
  let offsets : Array[Int32] = []
  for glyph in order {
    offsets.push(outlines.length())
    let data = subset_glyph_data(self, glyph).to_owned().to_array()
    let view = Bytes::from_array(data)
    for (pos, child) in glyph_components(view[:]) {
      put16(data, pos, remap.get(child).unwrap_or(0))
    }
    for byte in data {
      outlines.push(byte)
    }
    while outlines.length() % 4 != 0 {
      outlines.push(0)
    }
  }
  offsets.push(outlines.length())
  let long = outlines.length() >= 0x20000
  let loca : Array[Byte] = []
  for offset in offsets {
    if long {
      push32(loca, offset.reinterpret_as_uint())
    } else {
      push16(loca, offset / 2)
    }
  }
  let head = sfnt_table(self.source, self.tables, "head").to_owned().to_array()
  put16(head, 50, if long { 1 } else { 0 })
  let old_hmtx = sfnt_table(self.source, self.tables, "hmtx")
  let nhm = self.advances.length()
  let hmtx : Array[Byte] = []
  let advances : Array[Int32] = []
  let mut max_advance = 0
  for glyph in order {
    let a = self.advance_units(glyph)
    advances.push(a)
    max_advance = Int32::max(max_advance, a)
    let lsb = if glyph < nhm {
      u16(old_hmtx, glyph * 4 + 2)
    } else {
      u16(old_hmtx, nhm * 4 + (glyph - nhm) * 2)
    }
    push16(hmtx, a)
    push16(hmtx, lsb)
  }
  let hhea = sfnt_table(self.source, self.tables, "hhea").to_owned().to_array()
  if hhea.length() >= 36 {
    put16(hhea, 10, max_advance)
    put16(hhea, 34, order.length())
  }
  let maxp = sfnt_table(self.source, self.tables, "maxp").to_owned().to_array()
  if maxp.length() >= 6 {
    put16(maxp, 4, order.length())
  }
  let mapped : Map[Int32, Int32] = Map([])
  for code, glyph in requested {
    mapped[code] = remap.get(glyph).unwrap_or(0)
  }
  let tables : Map[String, Array[Byte]] = {
    "glyf": outlines,
    "loca": loca,
    "head": head,
    "hmtx": hmtx,
    "hhea": hhea,
    "maxp": maxp,
  }
  Some(rebuild_program(self, tables, mapped, order.length(), advances))
}

///|
/// Rebuild the whole font with a cmap restricted to the requested characters.
pub fn Font::mapped_program(
  self : Font,
  codepoints : Array[Int32],
) -> Bytes raise {
  let mapping : Map[Int32, Int32] = Map([])
  for code in codepoints {
    match self.glyph(code) {
      Some(glyph) => mapping[code] = glyph
      None => ()
    }
  }
  rebuild_program(
    self,
    Map([]),
    mapping,
    self.metrics.glyph_count,
    self.advances,
  )
}
