///|
priv enum OverviewBand {
  OverviewTitle(SpecimenTextLine)
  OverviewSubtitle(SpecimenTextLine)
  OverviewWarning(SpecimenTextLine)
  OverviewHeading(SpecimenTextLine)
  OverviewSpecimen(Double)
  OverviewWaterfall(SpecimenTextLine, Double, Double)
  OverviewScriptName(SpecimenTextLine)
  OverviewSample(String, Bool, String)
  OverviewTableRow(Array[SpecimenTextLine], Array[SpecimenTextLine], Double)
  OverviewPalette(SpecimenTextLine, Array[UInt32])
  OverviewTables(Array[(SpecimenTextLine, SpecimenTextLine)])
}

///|
/// A measured overview view, ready for UI font embedding and rendering.
pub struct SpecimenOverviewView {
  priv face : FileFace
  priv texter : SpecimenTexter
  priv sample : SamplePlan
  priv layout : ScrollPlan
  priv bands : Array[OverviewBand]
}

///|
fn overview_words(text : String) -> Array[String] {
  let words : Array[String] = []
  let mut current = StringBuilder()
  let mut nonempty = false
  for c in text {
    if c.is_whitespace() {
      if nonempty {
        words.push(current.to_string())
        current = StringBuilder()
        nonempty = false
      }
    } else {
      current.write_char(c)
      nonempty = true
    }
  }
  if nonempty {
    words.push(current.to_string())
  }
  words
}

///|
fn overview_script_section(face : FileFace) -> OverviewSection {
  let rows : Array[OverviewRow] = []
  for tag in ["GSUB", "GPOS"] {
    guard face.font.table(tag) is Some(data) else { continue }
    guard @otlayout.parse_layout(data[:], gpos=tag == "GPOS") is Some(table) else {
      continue
    }
    let scripts : Array[String] = []
    for sc in table.scripts {
      let name = @otlayout.script_name(sc.tag)
      let mut label = if name == "" {
        sc.tag
      } else {
        name + " (" + font_trim(sc.tag) + ")"
      }
      let langs = sc.languages.map(l => font_trim(l.tag))
      if langs.length() > 0 {
        label += ": " + langs.join(" ")
      }
      scripts.push(label)
    }
    overview_add(rows, tag + " scripts", scripts.join("; "))
    let tags : Array[String] = []
    let seen : Map[String, Bool] = Map([])
    for feature in table.features {
      if !seen.contains(feature.tag) {
        seen[feature.tag] = true
        tags.push(feature.tag)
      }
    }
    overview_add(rows, tag + " features", tags.join(" "))
  }
  let counts = face
    .script_counts()
    .map(sc => {
      sc.name.replace(old="_", new=" ") + " " + info_number(sc.count.to_int64())
    })
  overview_add(rows, "Characters by script", counts.join(", "))
  { title: "Scripts and features", rows, }
}

///|
fn overview_language(
  line : SpecimenTextLine,
  lang : String,
) -> SpecimenTextLine {
  if lang == "" {
    return line
  }
  let runs = line.runs.map(run => {
    choice: run.choice,
    text: run.text,
    lang: if run.lang == "" {
      lang
    } else {
      run.lang
    },
    x: run.x,
    width: run.width,
  })
  { runs, width: line.width, size: line.size, }
}

///|
/// Measure the overview, including sample text, metadata tables and palettes.
/// Call before embedding UI fonts so all labels are included in the subset.
pub fn FontFile::overview_view(
  self : FontFile,
  face : FileFace,
  texter : SpecimenTexter,
  sample : SamplePlan,
  outlined : Bool,
) -> SpecimenOverviewView {
  let scroll = ScrollLayout::new()
  let bands : Array[OverviewBand] = []
  let heading = (text : String) => {
    scroll.space(18.0)
    bands.push(OverviewHeading(texter.line(text, 13.0, true)))
    scroll.add(26.0, keep=true)
    scroll.space(4.0)
  }
  let names = face.specimen_names()
  let name = names.full()
  bands.push(
    OverviewTitle(
      texter.line(if name == "" { "Untitled font" } else { name }, 22.0, true),
    ),
  )
  scroll.add(34.0)
  let facts : Array[String] = []
  let version = names.best(5)
  if version != "" {
    facts.push(version)
  }
  facts.push(info_number(face.font.metrics.glyph_count.to_int64()) + " glyphs")
  facts.push(
    info_number(face.font.characters().length().to_int64()) + " characters",
  )
  let format = if face.font.table("CFF2") is Some(_) {
    "OpenType with CFF2 outlines"
  } else if face.font.table("CFF ") is Some(_) {
    "OpenType with CFF outlines"
  } else if face.font.table("glyf") is Some(_) {
    "TrueType outlines"
  } else if face.font.table("sbix") is Some(_) ||
    face.font.table("CBDT") is Some(_) ||
    face.font.table("EBDT") is Some(_) {
    "Bitmaps only"
  } else {
    "No outlines"
  }
  facts.push(format)
  if self.container != "" {
    facts.push(self.container)
  }
  bands.push(
    OverviewSubtitle(
      texter.line(texter.fit(facts.join(" · "), 9.5, false, 648.0), 9.5, false),
    ),
  )
  scroll.add(18.0)
  if outlined {
    bands.push(
      OverviewWarning(
        texter.line(
          "The font's license does not allow embedding it: its glyphs are drawn as outlines, without hinting or shaping.",
          7.5, false,
        ),
      ),
    )
    scroll.add(16.0)
  }
  scroll.space(10.0)
  if sample.specimen != "" {
    let mut width = 0.0
    for c in sample.specimen {
      width += face.font.advance(face.font.glyph(c.to_int()).unwrap_or(0)) *
        120.0
    }
    bands.push(OverviewSpecimen(Double::min(width, 648.0 * 0.55)))
    scroll.add(160.0)
  }
  if sample.waterfall != "" {
    heading("Sizes (pt)")
    for size in [8, 9, 10, 12, 14, 18, 24, 30, 36, 48, 60, 72] {
      let size_f = size.to_double()
      let height = size_f * 1.3 + 6.0
      bands.push(
        OverviewWaterfall(
          texter.line(size.to_string(), 7.5, false),
          size_f,
          height,
        ),
      )
      scroll.add(height)
    }
  }
  if sample.scripts.length() > 0 {
    heading("Sample text")
    for script in sample.scripts {
      bands.push(OverviewScriptName(texter.line(script.name, 7.5, false)))
      scroll.add(15.0)
      let mut line = ""
      let mut width = 0.0
      for word in overview_words(script.text) {
        let mut ww = 0.0
        for c in " " + word {
          ww += face.font.advance(face.font.glyph(c.to_int()).unwrap_or(0)) *
            18.0
        }
        if line != "" && width + ww > 648.0 * 0.9 {
          bands.push(OverviewSample(line, script.rtl, script.lang))
          scroll.add(27.0)
          line = ""
          width = 0.0
        }
        if line != "" {
          line += " "
        }
        line += word
        width += ww
      }
      if line != "" {
        bands.push(OverviewSample(line, script.rtl, script.lang))
        scroll.add(27.0)
      }
      scroll.space(6.0)
    }
  }
  let sections = self.overview(face, outlines=outlined)
  sections.push(overview_script_section(face))
  for section in sections {
    if section.rows.length() == 0 {
      continue
    }
    heading(section.title)
    for row in section.rows {
      let values = texter
        .wrap(row.value, 9.5, false, 450.0)
        .map(line => overview_language(texter.line(line, 9.5, false), row.lang))
      let labels = texter
        .wrap(row.label, 8.0, false, 180.0)
        .map(line => texter.line(line, 8.0, false))
      let height = Int32::max(values.length(), labels.length()).to_double() *
        13.0 +
        6.0
      bands.push(OverviewTableRow(labels, values, height))
      scroll.add(height)
    }
  }
  let palettes = color_palettes(face.font.table("CPAL").unwrap_or(b""))
  if palettes.length() > 0 {
    heading("Color palettes")
    for i, palette in palettes {
      let rows = (palette.length() + 34 - 1) / 34
      let height = Int32::max(rows, 1).to_double() * 17.0 + 6.0
      bands.push(
        OverviewPalette(
          texter.line("Palette " + i.to_string(), 7.5, false),
          palette,
        ),
      )
      scroll.add(height)
    }
  }
  let tables = face.table_list()
  if tables.length() > 0 {
    heading("Tables")
    let mut first = 0
    while first < tables.length() {
      let line : Array[(SpecimenTextLine, SpecimenTextLine)] = []
      for k in first..<Int32::min(first + 4, tables.length()) {
        line.push(
          (
            texter.line(tables[k].label, 9.5, true),
            texter.line(tables[k].value, 8.0, false),
          ),
        )
      }
      bands.push(OverviewTables(line))
      scroll.add(15.0)
      first += 4
    }
  }
  { face, texter, sample, layout: scroll.finish(), bands, }
}

///|
/// Render a measured font overview.
pub fn SpecimenOverviewView::render(
  self : SpecimenOverviewView,
  programs : SpecimenFacePrograms,
  fonts : SpecimenUIFonts,
) -> Array[SpecimenRenderedPage] raise {
  let pages : Array[SpecimenRenderedPage] = []
  let text : UInt32 = 0x1f1f1fffU
  let gray : UInt32 = 0x6b6b6bffU
  for strip in self.layout.strips {
    let page = SpecimenPagePainter::new(
      self.face,
      programs,
      self.texter,
      fonts,
      self.layout,
      strip.height,
    )
    for (index, y) in strip.bands {
      match self.bands[index] {
        OverviewTitle(line) => {
          page.mark(6, "1")
          ignore(page.label(line, 36.0, y + 24.0, text, 0))
        }
        OverviewSubtitle(line) => {
          page.mark(0, "")
          ignore(page.label(line, 36.0, y + 12.0, gray, 0))
        }
        OverviewWarning(line) => {
          page.mark(0, "")
          ignore(page.label(line, 36.0, y + 11.0, 0xc03030ffU, 0))
        }
        OverviewHeading(line) => {
          page.mark(6, "2")
          ignore(page.label(line, 36.0, y + 16.0, text, 0))
          page.rect(36.0, y + 22.0, 648.0, 0.75, text)
        }
        OverviewSpecimen(width) => {
          page.mark(10, "")
          page.save()
          page.clip_rect(36.0, y, 648.0, 160.0)
          let base = y + 0.72 * 160.0
          ignore(
            page.sample(
              self.sample.specimen,
              if self.sample.rtl {
                36.0 + width
              } else {
                36.0
              },
              base,
              120.0,
              self.sample.rtl,
              self.sample.lang,
            ),
          )
          let size = if self.sample.charset.length() > 0 {
            Double::min(
              22.0,
              (160.0 - 10.0) / self.sample.charset.length().to_double() / 1.35,
            )
          } else {
            20.0
          }
          let mut ly = y + 8.0
          for line in self.sample.charset {
            ly += size * 1.3
            ignore(
              page.sample(
                line,
                if self.sample.rtl {
                  684.0
                } else {
                  36.0 + width + 28.0
                },
                ly,
                size,
                self.sample.rtl,
                self.sample.lang,
              ),
            )
          }
          page.restore()
          page.mark(11, "")
        }
        OverviewWaterfall(line, size, height) => {
          page.mark(0, "")
          let base = y + size * 1.02 + 3.0
          ignore(page.label(line, 36.0, base, gray, 0))
          page.save()
          page.clip_rect(66.0, y, 618.0, height)
          ignore(
            page.sample(
              self.sample.waterfall,
              if self.sample.rtl {
                684.0
              } else {
                66.0
              },
              base,
              size,
              self.sample.rtl,
              self.sample.lang,
            ),
          )
          page.restore()
        }
        OverviewScriptName(line) => {
          page.mark(0, "")
          ignore(page.label(line, 36.0, y + 11.0, gray, 0))
        }
        OverviewSample(line, rtl, lang) => {
          page.mark(0, "")
          page.save()
          page.clip_rect(36.0, y, 648.0, 27.0)
          ignore(
            page.sample(
              line,
              if rtl {
                684.0
              } else {
                36.0
              },
              y + 18.0 * 1.1,
              18.0,
              rtl,
              lang,
            ),
          )
          page.restore()
        }
        OverviewTableRow(labels, values, height) => {
          page.mark(0, "")
          for k, line in labels {
            ignore(
              page.label(line, 36.0, y + 12.0 + k.to_double() * 13.0, gray, 0),
            )
          }
          for k, line in values {
            page.mark(1, "")
            ignore(
              page.label(line, 226.0, y + 12.0 + k.to_double() * 13.0, text, 0),
            )
          }
          page.rect(36.0, y + height - 0.5, 648.0, 0.5, 0xd9d9d9ffU)
        }
        OverviewPalette(line, palette) => {
          page.mark(0, "")
          ignore(page.label(line, 36.0, y + 11.0, gray, 0))
          for k, color in palette {
            let x = 106.0 + (k % 34).to_double() * 17.0
            let yy = y + (k / 34).to_double() * 17.0
            page.rect(x, yy, 14.0, 14.0, 0xe2e2e2ffU)
            page.rect(x + 0.5, yy + 0.5, 13.0, 13.0, color)
          }
        }
        OverviewTables(line) => {
          page.mark(0, "")
          for k, (label, value) in line {
            if k > 0 {
              page.mark(1, "")
            }
            let x = 36.0 + k.to_double() * 162.0
            ignore(page.label(label, x, y + 11.0, text, 0))
            ignore(page.label(value, x + 162.0 - 16.0, y + 11.0, gray, 2))
          }
          page.rect(36.0, y + 14.5, 648.0, 0.5, 0xd9d9d9ffU)
        }
      }
    }
    pages.push({ height: strip.height, object: page.encode(), })
  }
  pages
}
