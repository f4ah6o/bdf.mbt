///|
/// A font's layout metrics and embedding permissions. Distances are in ems.
pub(all) struct Metrics {
  units_per_em : Int32
  glyph_count : Int32
  is_cff : Bool
  ascent : Double
  descent : Double
  underline_position : Double
  underline_thickness : Double
  cap_height : Double
  embeddable : Bool
  subsettable : Bool
}

///|
/// An SFNT face with Unicode character mapping and horizontal advances.
pub struct Font {
  metrics : Metrics
  info : FaceInfo
  priv cmap : Map[Int32, Int32]
  priv advances : Array[Int32]
  priv source : Bytes
  priv tables : Map[String, (Int32, Int32)]
}

///|
/// Return the nonzero glyph index for a Unicode scalar, or None if absent.
pub fn Font::glyph(self : Font, codepoint : Int32) -> Int32? {
  match self.cmap.get(codepoint) {
    Some(glyph) if glyph != 0 => Some(glyph)
    _ => None
  }
}

///|
/// Return the glyph's horizontal advance in font units. Glyphs beyond the hmtx
/// long metrics use its final advance, as specified by OpenType.
pub fn Font::advance_units(self : Font, glyph : Int32) -> Int32 {
  let length = self.advances.length()
  let units = if length == 0 {
    self.metrics.units_per_em / 2
  } else if glyph < 0 || glyph >= length {
    self.advances[length - 1]
  } else {
    self.advances[glyph]
  }
  units
}

///|
/// Return the glyph's horizontal advance as a fraction of the em size.
pub fn Font::advance(self : Font, glyph : Int32) -> Double {
  self.advance_units(glyph).to_double() / self.metrics.units_per_em.to_double()
}

///|
/// Parse a TrueType or OpenType face, including an indexed TTC face.
/// The character map supports the Unicode cmap formats 0, 4, 6 and 12.
pub fn parse(data : Bytes, index~ : Int32 = 0) -> Font raise {
  if data.length() < 12 {
    raise InvalidFont("font too short")
  }
  let mut tag = u32(data[:], 0)
  let mut offset = 0
  if tag == 0x74746366U {
    let count = u32(data[:], 8)
    if index < 0 || index.reinterpret_as_uint() >= count {
      raise InvalidFont("TTC index out of range")
    }
    if index > (data.length() - 12) / 4 - 1 {
      raise InvalidFont("bad TTC")
    }
    let raw = u32(data[:], 12 + index * 4)
    if raw > (data.length() - 12).reinterpret_as_uint() {
      raise InvalidFont("bad TTC")
    }
    offset = raw.reinterpret_as_int()
    tag = u32(data[:], offset)
  } else if index != 0 {
    raise InvalidFont("not a font collection")
  }
  if tag != 0x00010000U && tag != 0x74727565U && tag != 0x4f54544fU {
    raise InvalidFont("not an sfnt font")
  }
  let tables : Map[String, (Int32, Int32)] = Map([])
  let count = u16(data[:], offset + 4)
  let available_records = (data.length() - offset - 12) / 16
  for i in 0..<Int32::min(count, available_records) {
    let rec = offset + 12 + i * 16
    let start = u32(data[:], rec + 8)
    let length = u32(data[:], rec + 12)
    if start > data.length().reinterpret_as_uint() {
      continue
    }
    let start = start.reinterpret_as_int()
    let available = data.length() - start
    let length = if length > available.reinterpret_as_uint() {
      available
    } else {
      length.reinterpret_as_int()
    }
    let tag_bytes = data[rec:rec + 4]
    let name = String::from_array(
      [
        for byte in tag_bytes => byte.to_int().unsafe_to_char()
      ],
    )
    tables[name] = (start, length)
  }
  let maxp = sfnt_table(data, tables, "maxp")
  let glyph_count = if maxp.length() >= 6 { u16(maxp, 4) } else { 0 }
  let head = sfnt_table(data, tables, "head")
  let units = if head.length() >= 54 && u16(head, 18) > 0 {
    u16(head, 18)
  } else {
    1000
  }
  let hhea = sfnt_table(data, tables, "hhea")
  let hmtx = sfnt_table(data, tables, "hmtx")
  let advances : Array[Int32] = []
  if hhea.length() >= 36 && tables.contains("hmtx") {
    for i in 0..<u16(hhea, 34) {
      advances.push(u16(hmtx, i * 4))
    }
  }
  let metrics = read_metrics(
    data,
    tables,
    units,
    glyph_count,
    tag == 0x4f54544fU,
  )
  let cmap = parse_cmap(sfnt_table(data, tables, "cmap"))
  let info = read_face_info(data, tables)
  { metrics, info, cmap, advances, source: data, tables, }
}
