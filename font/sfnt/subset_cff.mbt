///|
fn subset_cff_program(font : Font, codepoints : Array[Int32]) -> Bytes? raise {
  if !font.tables.contains("CFF ") {
    return None
  }
  let requested : Map[Int32, Int32] = Map([])
  let glyphs : Array[Int32] = []
  for code in codepoints {
    match font.glyph(code) {
      Some(glyph) => {
        requested[code] = glyph
        glyphs.push(glyph)
      }
      None => ()
    }
  }
  let raw = sfnt_table(font.source, font.tables, "CFF ").to_owned()
  let subset = @cff.subset(raw, glyphs) catch { _ => return None }
  let remap : Map[Int32, Int32] = Map([])
  let advances : Array[Int32] = []
  let bearings : Array[Int32] = []
  let hmtx = sfnt_table(font.source, font.tables, "hmtx")
  let nhm = font.advances.length()
  let has_bearings = nhm > 0 &&
    nhm <= font.metrics.glyph_count &&
    hmtx.length() >= nhm * 4 + (font.metrics.glyph_count - nhm) * 2
  for i, glyph in subset.order {
    remap[glyph] = i
    advances.push(font.advance_units(glyph))
    if has_bearings {
      bearings.push(
        if glyph < nhm {
          u16(hmtx, glyph * 4 + 2)
        } else {
          u16(hmtx, nhm * 4 + (glyph - nhm) * 2)
        },
      )
    }
  }
  let mapped : Map[Int32, Int32] = Map([])
  for code, glyph in requested {
    mapped[code] = remap.get(glyph).unwrap_or(0)
  }
  let tables : Map[String, Array[Byte]] = { "CFF ": subset.data.to_array() }
  Some(
    rebuild_program(
      font,
      tables,
      mapped,
      subset.order.length(),
      advances,
      bearings,
      true,
    ),
  )
}
