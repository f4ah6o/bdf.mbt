///|
/// One labeled value in a specimen overview table.
pub(all) struct OverviewRow {
  label : String
  value : String
  lang : String
}

///|
/// A named table in a specimen overview.
pub(all) struct OverviewSection {
  title : String
  rows : Array[OverviewRow]
}

///|
fn overview_add(
  rows : Array[OverviewRow],
  label : String,
  value : String,
) -> Unit {
  if font_trim(value) != "" {
    rows.push({ label, value, lang: "", })
  }
}

///|
fn overview_name(
  rows : Array[OverviewRow],
  names : SpecimenNames,
  label : String,
  ids : Array[Int32],
  local : Bool,
) -> Unit {
  for id in ids {
    let value = names.best(id)
    if value != "" {
      overview_add(rows, label, value)
      if local {
        for record in names.local(id) {
          rows.push({
            label: label + " (" + record.lang + ")",
            value: record.text,
            lang: record.lang,
          })
        }
      }
      return
    }
  }
}

///|
fn overview_embedding(fs : Int32) -> String {
  let parts : Array[String] = []
  match fs & 15 {
    0 => parts.push("Installable")
    2 => parts.push("Restricted (may not be embedded)")
    4 => parts.push("Preview & print")
    8 => parts.push("Editable")
    _ => parts.push("0x" + name_hex(fs).to_lower())
  }
  if (fs & 0x100) != 0 {
    parts.push("no subsetting")
  }
  if (fs & 0x200) != 0 {
    parts.push("bitmap embedding only")
  }
  parts.join(", ")
}

///|
fn overview_flags(flags : Int32) -> String {
  let names = [
    "Italic", "Underscore", "Negative", "Outlined", "Strikeout", "Bold", "Regular",
    "Use typographic metrics", "WWS", "Oblique",
  ]
  let selected : Array[String] = []
  for i in 0..<names.length() {
    if (flags & (1 << i)) != 0 {
      selected.push(names[i])
    }
  }
  selected.join(", ")
}

///|
fn overview_present(
  present : Map[String, Bool],
  tags : Array[String],
) -> String {
  [ for tag in tags if present.contains(tag) => tag ].join(", ")
}

///|
fn overview_hinting(present : Map[String, Bool]) -> String {
  let parts : Array[String] = []
  if present.contains("fpgm") || present.contains("prep") {
    parts.push("TrueType instructions")
  }
  if present.contains("gasp") {
    parts.push("gasp")
  }
  if present.contains("hdmx") ||
    present.contains("VDMX") ||
    present.contains("LTSH") {
    parts.push("device metrics")
  }
  parts.join(", ")
}

///|
fn overview_variations(face : FileFace) -> Array[OverviewRow] {
  let rows : Array[OverviewRow] = []
  let variations = face.variations()
  for axis in variations.axes {
    let value = info_decimal(axis.minimum) +
      " to " +
      info_decimal(axis.maximum) +
      ", default " +
      info_decimal(axis.default_value) +
      (if axis.hidden { " (hidden)" } else { "" })
    let label = axis.tag + (if axis.name != "" { " " + axis.name } else { "" })
    overview_add(rows, "Axis " + label, value)
  }
  for instance in variations.instances {
    let coords : Array[String] = []
    for i, value in instance.coordinates {
      if i < variations.axes.length() {
        coords.push(variations.axes[i].tag + " " + info_decimal(value))
      }
    }
    let name = if instance.name == "" { "(unnamed)" } else { instance.name }
    let ps = if instance.postscript == "" {
      ""
    } else {
      " — " + instance.postscript
    }
    overview_add(rows, "Instance " + name, coords.join(", ") + ps)
  }
  if variations.axes.length() > 0 {
    overview_add(rows, "Drawn at", "the default instance")
  }
  rows
}

///|
/// Build the upstream font overview's names, license, font, metrics and
/// variation tables. Pass whether license restrictions caused outlines to be used.
pub fn FontFile::overview(
  self : FontFile,
  face : FileFace,
  outlines~ : Bool = false,
) -> Array[OverviewSection] {
  let font = face.font
  let names = face.specimen_names()
  let present : Map[String, Bool] = Map([])
  for (tag, _) in font.table_lengths() {
    present[tag] = true
  }
  let name_rows : Array[OverviewRow] = []
  overview_name(name_rows, names, "Family", [16, 1], true)
  overview_name(name_rows, names, "Style", [17, 2], false)
  overview_name(name_rows, names, "Full name", [4], true)
  overview_name(name_rows, names, "PostScript name", [6], false)
  overview_name(name_rows, names, "Version", [5], false)
  overview_name(name_rows, names, "Unique ID", [3], false)
  overview_name(name_rows, names, "Designer", [9], false)
  overview_name(name_rows, names, "Designer URL", [12], false)
  overview_name(name_rows, names, "Manufacturer", [8], false)
  overview_name(name_rows, names, "Vendor URL", [11], false)
  let os2 = font.table("OS/2").unwrap_or(b"")
  if os2.length() >= 62 {
    let mut end = 62
    while end > 58 && (os2[end - 1] == b' ' || os2[end - 1] == 0) {
      end -= 1
    }
    overview_add(name_rows, "Vendor ID", @utf8.decode_lossy(os2[58:end]))
  }
  overview_name(name_rows, names, "Description", [10], false)
  overview_name(name_rows, names, "Sample text", [19], false)
  overview_name(name_rows, names, "WWS family", [21], false)
  overview_name(name_rows, names, "WWS style", [22], false)
  overview_name(name_rows, names, "Variations PostScript prefix", [25], false)
  let license : Array[OverviewRow] = []
  overview_add(license, "Copyright", names.best(0))
  overview_add(license, "Trademark", names.best(7))
  overview_add(license, "License", names.best(13))
  overview_add(license, "License URL", names.best(14))
  if os2.length() >= 10 {
    let value = overview_embedding(be16(os2[:], 8)) +
      (if outlines {
        " — drawn as outlines here, the font is not embedded"
      } else {
        ""
      })
    overview_add(license, "Embedding", value)
  }
  let info : Array[OverviewRow] = []
  let format = if present.contains("CFF2") {
    "OpenType with CFF2 outlines"
  } else if present.contains("CFF ") {
    "OpenType with CFF outlines"
  } else if present.contains("glyf") {
    "TrueType outlines"
  } else if present.contains("sbix") ||
    present.contains("CBDT") ||
    present.contains("EBDT") {
    "Bitmaps only"
  } else {
    "No outlines"
  }
  overview_add(
    info,
    "Format",
    format +
    (if self.container == "WOFF" {
      ", in a WOFF web font"
    } else if self.container == "WOFF2" {
      ", in a WOFF2 web font"
    } else {
      ""
    }),
  )
  if self.collection {
    overview_add(
      info,
      "Collection",
      "font " +
      (face.index + 1).to_string() +
      " of " +
      self.faces().length().to_string(),
    )
  }
  overview_add(info, "File size", info_bytesize(self.size))
  overview_add(info, "Glyphs", info_number(font.metrics.glyph_count.to_int64()))
  overview_add(
    info,
    "Characters",
    info_number(font.characters().length().to_int64()),
  )
  let (sequences, more) = variation_sequences(font.table("cmap").unwrap_or(b""))
  if sequences > 0L {
    overview_add(
      info,
      "Variation sequences",
      (if more { "more than " } else { "" }) + info_number(sequences),
    )
  }
  overview_add(
    info,
    "Units per em",
    info_number(font.metrics.units_per_em.to_int64()),
  )
  let head = font.table("head").unwrap_or(b"")
  if head.length() >= 54 {
    overview_add(info, "Revision", info_decimal(info_fixed(head[:], 4)))
    let (created, _) = info_head_time(head[:], 20)
    let (modified, _) = info_head_time(head[:], 28)
    overview_add(info, "Created", created)
    overview_add(info, "Modified", modified)
  }
  if os2.length() >= 8 {
    let weight = be16(os2[:], 4)
    let weight_name = match weight {
      100 => "Thin"
      200 => "Extra Light"
      300 => "Light"
      400 => "Regular"
      500 => "Medium"
      600 => "Semi Bold"
      700 => "Bold"
      800 => "Extra Bold"
      900 => "Black"
      _ => ""
    }
    overview_add(
      info,
      "Weight class",
      weight.to_string() +
      (if weight_name == "" { "" } else { " (" + weight_name + ")" }),
    )
    let width = be16(os2[:], 6)
    let widths = [
      "", "Ultra-condensed", "Extra-condensed", "Condensed", "Semi-condensed", "Normal",
      "Semi-expanded", "Expanded", "Extra-expanded", "Ultra-expanded",
    ]
    if width >= 1 && width <= 9 {
      overview_add(
        info,
        "Width class",
        width.to_string() + " (" + widths[width] + ")",
      )
    }
    if os2.length() >= 64 {
      overview_add(info, "Style flags", overview_flags(be16(os2[:], 62)))
    }
    if os2.length() >= 42 {
      let mut nonzero = false
      let values : Array[String] = []
      for i in 32..<42 {
        let value = os2[i].to_int()
        if value != 0 {
          nonzero = true
        }
        values.push(value.to_string())
      }
      if nonzero {
        overview_add(info, "PANOSE", values.join(" "))
      }
    }
    if be16(os2[:], 0) >= 5 && os2.length() >= 100 {
      overview_add(
        info,
        "Optical sizes",
        info_decimal(be16(os2[:], 96).to_double() / 20.0) +
        "–" +
        info_decimal(be16(os2[:], 98).to_double() / 20.0) +
        " pt",
      )
    }
  }
  let post = font.table("post").unwrap_or(b"")
  if post.length() >= 16 {
    let angle = info_fixed(post[:], 4)
    if angle != 0.0 {
      overview_add(info, "Italic angle", info_decimal(angle) + "°")
    }
    if be32(post[:], 12) != 0U {
      overview_add(info, "Monospaced", "yes")
    }
  }
  overview_add(info, "Hinting", overview_hinting(present))
  overview_add(
    info,
    "Vertical metrics",
    overview_present(present, ["vhea", "vmtx", "VORG"]),
  )
  overview_add(
    info,
    "Color",
    color_formats(
      font.table("COLR").unwrap_or(b""),
      font.table("CPAL").unwrap_or(b""),
      font.table("sbix").unwrap_or(b""),
      font.table("CBLC").unwrap_or(b""),
      font.table("SVG ").unwrap_or(b""),
    ),
  )
  let strikes = bitmap_strikes(font.table("EBLC").unwrap_or(b""))
  if strikes != "" {
    overview_add(info, "Embedded bitmaps", strikes + " ppem")
  }
  if present.contains("MATH") {
    overview_add(info, "Math", "MATH table (formula layout)")
  }
  overview_add(info, "Kerning", face.kerning())
  let other : Array[String] = []
  if present.contains("morx") || present.contains("mort") {
    other.push("AAT (morx)")
  }
  if present.contains("Silf") {
    other.push("Graphite (Silf)")
  }
  overview_add(info, "Other layout", other.join(", "))
  let (design, supported) = metadata_languages(
    font.table("meta").unwrap_or(b""),
  )
  overview_add(info, "Design languages", design)
  overview_add(info, "Supported languages", supported)
  let metrics : Array[OverviewRow] = []
  let hhea = font.table("hhea").unwrap_or(b"")
  let (asc, desc, gap) = if hhea.length() >= 36 {
    (
      info_signed16(hhea[:], 4),
      info_signed16(hhea[:], 6),
      info_signed16(hhea[:], 8),
    )
  } else {
    (0, 0, 0)
  }
  overview_add(
    metrics,
    "Ascender, descender, line gap (hhea)",
    asc.to_string() + ", " + desc.to_string() + ", " + gap.to_string(),
  )
  if os2.length() >= 78 {
    overview_add(
      metrics,
      "Typographic ascender, descender, line gap (OS/2)",
      info_signed16(os2[:], 68).to_string() +
      ", " +
      info_signed16(os2[:], 70).to_string() +
      ", " +
      info_signed16(os2[:], 72).to_string(),
    )
    overview_add(
      metrics,
      "Windows ascent, descent (OS/2)",
      be16(os2[:], 74).to_string() + ", " + be16(os2[:], 76).to_string(),
    )
    if be16(os2[:], 0) >= 2 && os2.length() >= 90 {
      overview_add(
        metrics,
        "x-height, cap height",
        info_signed16(os2[:], 86).to_string() +
        ", " +
        info_signed16(os2[:], 88).to_string(),
      )
    }
  }
  if head.length() >= 54 {
    overview_add(
      metrics,
      "Bounding box",
      info_signed16(head[:], 36).to_string() +
      ", " +
      info_signed16(head[:], 38).to_string() +
      " – " +
      info_signed16(head[:], 40).to_string() +
      ", " +
      info_signed16(head[:], 42).to_string(),
    )
  }
  if post.length() >= 12 {
    overview_add(
      metrics,
      "Underline position, thickness",
      info_signed16(post[:], 8).to_string() +
      ", " +
      info_signed16(post[:], 10).to_string(),
    )
  }
  let result : Array[OverviewSection] = [
    { title: "Names", rows: name_rows, },
    { title: "License", rows: license, },
    { title: "Font", rows: info, },
    { title: "Metrics (font units)", rows: metrics, },
  ]
  let variations = overview_variations(face)
  if variations.length() > 0 {
    result.push({ title: "Variations", rows: variations, })
  }
  result
}

///|
/// The face's SFNT tables, sorted by tag, with sizes formatted for the overview.
pub fn FileFace::table_list(self : FileFace) -> Array[OverviewRow] {
  [
    for (tag, size) in self.font.table_lengths() => {
      { label: tag, value: info_bytesize(size), lang: "", }
    }
  ]
}
