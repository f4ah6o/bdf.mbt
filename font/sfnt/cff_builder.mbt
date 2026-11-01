///|
/// Build an OpenType/CFF face from a bare CFF program. The caller supplies the
/// glyph count, advances and character map; the CFF table is embedded as-is.
pub fn from_cff(
  cff : Bytes,
  units_per_em : Int32,
  glyph_count : Int32,
  advances : Array[Int32],
  cmap : Map[Int32, Int32],
  family : String,
  weight : Int32,
  italic : Bool,
) -> Bytes raise {
  if cff.length() == 0 || glyph_count <= 0 || units_per_em < 16 {
    raise InvalidFont("invalid bare CFF")
  }
  let name = if family == "" { "CFF" } else { family }
  let style = if weight >= 600 && italic {
    "Bold Italic"
  } else if weight >= 600 {
    "Bold"
  } else if italic {
    "Italic"
  } else {
    "Regular"
  }
  let font : Font = {
    metrics: {
      units_per_em,
      glyph_count,
      is_cff: true,
      ascent: units_per_em.to_double() * 0.8,
      descent: -units_per_em.to_double() * 0.2,
      underline_position: -units_per_em.to_double() * 0.1,
      underline_thickness: units_per_em.to_double() * 0.05,
      cap_height: units_per_em.to_double() * 0.7,
      embeddable: true,
      subsettable: true,
    },
    info: {
      family: name,
      style,
      weight,
      italic,
      monospace: false,
      has_math: false,
    },
    cmap,
    advances,
    source: b"",
    tables: Map([]),
  }
  rebuild_program(
    font,
    Map([("CFF ", cff.to_array())]),
    cmap,
    glyph_count,
    advances,
    [],
    true,
  )
}
