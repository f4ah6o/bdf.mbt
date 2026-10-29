///|
fn read_metrics(
  data : Bytes,
  tables : Map[String, (Int32, Int32)],
  units : Int32,
  glyph_count : Int32,
  cff_tag : Bool,
) -> Metrics {
  let os2 = sfnt_table(data, tables, "OS/2")
  let hhea = sfnt_table(data, tables, "hhea")
  let scale = units.to_double()
  let win_asc = if os2.length() >= 78 { u16(os2, 74) } else { 0 }
  let win_desc = if os2.length() >= 78 { u16(os2, 76) } else { 0 }
  let has_hhea = hhea.length() >= 36 && (s16(hhea, 4) != 0 || s16(hhea, 6) != 0)
  let (ascent, descent) = if win_asc + win_desc > 0 {
    (win_asc.to_double() / scale, win_desc.to_double() / scale)
  } else if has_hhea {
    (
      s16(hhea, 4).to_double() / scale,
      (-s16(hhea, 6) + s16(hhea, 8)).to_double() / scale,
    )
  } else {
    (0.9, 0.3)
  }
  let cap_height = if os2.length() >= 90 && u16(os2, 0) >= 2 && s16(os2, 88) > 0 {
    s16(os2, 88).to_double() / scale
  } else {
    0.7
  }
  let flags = if os2.length() >= 78 { u16(os2, 8) } else { 0 }
  let embeddable = (flags & 0x000f) != 0x0002 && (flags & 0x0200) == 0
  let subsettable = embeddable && (flags & 0x0100) == 0
  let post = sfnt_table(data, tables, "post")
  let pos = if post.length() >= 12 { s16(post, 8) } else { -(units / 10) }
  let thickness = if post.length() >= 12 && s16(post, 10) > 0 {
    s16(post, 10)
  } else {
    units / 20
  }
  {
    units_per_em: units,
    glyph_count,
    is_cff: cff_tag || (tables.contains("CFF ") && !tables.contains("glyf")),
    ascent,
    descent,
    underline_position: pos.to_double() / scale,
    underline_thickness: thickness.to_double() / scale,
    cap_height,
    embeddable,
    subsettable,
  }
}
