///|
fn put16(data : Array[Byte], at : Int32, value : Int32) -> Unit {
  data[at] = ((value >> 8) & 255).to_byte()
  data[at + 1] = (value & 255).to_byte()
}

///|
fn put32(data : Array[Byte], at : Int32, value : UInt32) -> Unit {
  data[at] = (value >> 24).to_byte()
  data[at + 1] = (value >> 16).to_byte()
  data[at + 2] = (value >> 8).to_byte()
  data[at + 3] = value.to_byte()
}

///|
fn checksum(data : Array[Byte]) -> UInt32 {
  let mut sum = 0U
  let mut index = 0
  while index < data.length() {
    let mut word = 0U
    for j in 0..<4 {
      word = word << 8
      if index + j < data.length() {
        word = word | data[index + j].to_uint()
      }
    }
    sum += word
    index += 4
  }
  sum
}

///|
fn canvas_os2(font : Font) -> Array[Byte] {
  let table = sfnt_table(font.source, font.tables, "OS/2")
  let units = font.metrics.units_per_em
  let (ascent, descent) = rebuild_ascent_descent(font)
  let fs_type = if table.length() >= 10 { u16(table, 8) } else { 4 }
  let bytes = Bytes::make(96, 0).to_array()
  put16(bytes, 0, 3)
  put16(bytes, 2, units / 2)
  put16(bytes, 4, font.info.weight)
  put16(bytes, 6, 5)
  put16(bytes, 8, fs_type)
  let em = units
  // The upstream writer performs these products in uint16 arithmetic.
  let values = [
    ((em * 65) & 0xffff) / 100,
    ((em * 60) & 0xffff) / 100,
    0,
    ((((em * 75) & 0xffff) / 1000 * 10) & 0xffff) / 10,
    ((em * 65) & 0xffff) / 100,
    ((em * 60) & 0xffff) / 100,
    0,
    ((em * 35) & 0xffff) / 100,
    ((em * 5) & 0xffff) / 100,
    ((em * 26) & 0xffff) / 100,
  ]
  for i, value in values {
    put16(bytes, 10 + i * 2, value)
  }
  bytes[58] = b'B'
  bytes[59] = b'D'
  bytes[60] = b'F'
  bytes[61] = b' '
  let mut selection = if font.info.italic { 1 } else { 64 }
  if font.info.weight >= 600 {
    selection = selection | 32
  }
  put16(bytes, 62, selection)
  put16(bytes, 64, 0x20)
  put16(bytes, 66, 0xffff)
  put16(bytes, 68, ascent)
  put16(bytes, 70, descent)
  put16(bytes, 74, ascent)
  put16(bytes, 76, -descent)
  put32(bytes, 78, 1U)
  // Go int16 multiplication wraps before division.
  let xheight = (((ascent * 2 + 32768) & 0xffff) - 32768) / 3
  let capheight = (((ascent * 3 + 32768) & 0xffff) - 32768) / 4
  put16(bytes, 86, xheight)
  put16(bytes, 88, capheight)
  put16(bytes, 92, 0x20)
  bytes
}

///|
/// Build a browser-ready whole font for horizontal text. Layout tables are
/// removed to match upstream's unshaped glyph positioning; the cmap and name
/// tables are reconstructed while retaining licensing notices. The caller is
/// responsible for checking `metrics.embeddable` before storing the result.
pub fn Font::canvas_program(self : Font) -> Bytes raise {
  rebuild_program(
    self,
    Map([]),
    self.cmap,
    self.metrics.glyph_count,
    self.advances,
    [],
    false,
  )
}

///|
fn rebuild_program(
  font : Font,
  replacements : Map[String, Array[Byte]],
  cmap : Map[Int32, Int32],
  glyph_count : Int32,
  advances : Array[Int32],
  bearings : Array[Int32],
  cff_subset : Bool,
) -> Bytes raise {
  let keep = [
    "glyf", "loca", "head", "hhea", "hmtx", "maxp", "cvt ", "fpgm", "prep", "CFF ",
    "gasp", "cmap", "name", "post",
  ]
  let tables : Map[String, Array[Byte]] = Map([])
  for tag in keep {
    if cff_subset && tag != "head" && tag != "CFF " {
      continue
    }
    if cff_subset &&
      tag == "head" &&
      sfnt_table(font.source, font.tables, "head").length() < 54 {
      continue
    }
    if font.metrics.is_cff && (tag == "glyf" || tag == "loca") {
      continue
    }
    match replacements.get(tag) {
      Some(bytes) => tables[tag] = bytes.copy()
      None =>
        if font.tables.contains(tag) {
          tables[tag] = sfnt_table(font.source, font.tables, tag)
            .to_owned()
            .to_array()
        }
    }
  }
  tables["cmap"] = build_cmap(cmap)
  tables["name"] = build_names(font)
  tables["OS/2"] = canvas_os2(font)
  let post = Bytes::make(32, 0).to_array()
  put32(post, 0, 0x00030000U)
  tables["post"] = post
  if !tables.contains("head") || tables["head"].length() == 0 {
    tables["head"] = default_head(font.metrics.units_per_em)
  } else {
    match tables.get("head") {
      Some(head) if head.length() >= 54 => {
        let style = (if font.info.weight >= 600 { 1 } else { 0 }) |
          (if font.info.italic { 2 } else { 0 })
        put16(head, 44, style)
      }
      _ => ()
    }
  }
  let (ascent, descent) = rebuild_ascent_descent(font)
  if !tables.contains("hhea") ||
    tables["hhea"].length() == 0 ||
    !tables.contains("hmtx") ||
    tables["hmtx"].length() == 0 {
    tables["hhea"] = default_hhea(
      ascent,
      descent,
      font.metrics.units_per_em,
      glyph_count,
    )
    tables["hmtx"] = default_hmtx(font, glyph_count, advances, bearings)
  }
  if !tables.contains("maxp") || tables["maxp"].length() == 0 {
    tables["maxp"] = default_maxp(glyph_count, font.metrics.is_cff)
  }
  let tags = tables.keys().collect()
  tags.sort()
  let count = tags.length()
  if count > 4095 {
    raise InvalidFont("too many SFNT tables")
  }
  let mut selector = 0
  while 1 << (selector + 1) <= count {
    selector += 1
  }
  let search = (1 << selector) * 16
  let out = Bytes::make(12 + 16 * count, 0).to_array()
  put32(out, 0, if font.metrics.is_cff { 0x4f54544fU } else { 0x00010000U })
  put16(out, 4, count)
  put16(out, 6, search)
  put16(out, 8, selector)
  put16(out, 10, count * 16 - search)
  let mut head_offset = -1
  for i, tag in tags {
    let bytes = tables[tag]
    let offset = out.length()
    if tag == "head" {
      head_offset = offset
    }
    let record = 12 + i * 16
    let mut j = 0
    for c in tag {
      out[record + j] = c.to_int().to_byte()
      j += 1
    }
    put32(out, record + 4, checksum(bytes))
    put32(out, record + 8, offset.reinterpret_as_uint())
    put32(out, record + 12, bytes.length().reinterpret_as_uint())
    for byte in bytes {
      out.push(byte)
    }
    while out.length() % 4 != 0 {
      out.push(0)
    }
  }
  if head_offset >= 0 && head_offset + 12 <= out.length() {
    put32(out, head_offset + 8, 0U)
    put32(out, head_offset + 8, 0xb1b0afbaU - checksum(out))
  }
  Bytes::from_array(out)
}
