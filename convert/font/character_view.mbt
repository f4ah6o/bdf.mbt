///|
enum CharacterBand {
  Title(SpecimenTextLine)
  Summary(SpecimenTextLine)
  Heading(SpecimenTextLine)
  Block(SpecimenTextLine, SpecimenTextLine, SpecimenTextLine, Double, String)
  ChartTitle(SpecimenTextLine, SpecimenTextLine, Array[SpecimenTextLine])
  Gap(SpecimenTextLine)
  ChartRow(SpecimenTextLine, Int32, Int32, Int32)
  More(SpecimenTextLine)
}

///|
/// A measured character-chart view, ready for UI font embedding and rendering.
pub struct SpecimenCharacterView {
  priv face : FileFace
  priv texter : SpecimenTexter
  priv layout : ScrollPlan
  priv bands : Array[CharacterBand]
}

///|
fn chart_hex(code : Int32) -> String {
  let mut hex = name_hex(code)
  while hex.length() < 4 {
    hex = "0" + hex
  }
  hex
}

///|
fn chart_assigned(code : Int32) -> Bool {
  let mut low = 0
  let mut high = specimen_assigned_ranges.length()
  while low < high {
    let mid = low + (high - low) / 2
    let (first, last) = specimen_assigned_ranges[mid]
    if code < first {
      high = mid
    } else if code > last {
      low = mid + 1
    } else {
      return true
    }
  }
  false
}

///|
/// Measure the character view's labels and layout before embedding UI fonts.
pub fn FileFace::character_view(
  self : FileFace,
  texter : SpecimenTexter,
) -> SpecimenCharacterView {
  let coverage = self.coverage()
  let scroll = ScrollLayout::new()
  let bands : Array[CharacterBand] = []
  bands.push(Title(texter.line("Characters", 18.0, true)))
  scroll.add(30.0)
  let mut summary = info_number(self.font.characters().length().to_int64()) +
    " characters in " +
    coverage.length().to_string() +
    " Unicode blocks"
  let (sequences, more) = variation_sequences(
    self.font.table("cmap").unwrap_or(b""),
  )
  if sequences > 0L {
    summary += ", and " +
      (if more { "more than " } else { "" }) +
      info_number(sequences) +
      " variation sequences"
  }
  bands.push(Summary(texter.line(summary, 9.5, false)))
  scroll.add(18.0)
  scroll.space(18.0)
  bands.push(Heading(texter.line("Unicode blocks", 13.0, true)))
  scroll.add(26.0, keep=true)
  scroll.space(4.0)
  for i, entry in coverage {
    let block = entry.block
    let name = texter.line(
      texter.fit(block.name, 9.5, false, 250.0),
      9.5,
      false,
    )
    let range = texter.line(
      "U+" + chart_hex(block.first) + "–" + chart_hex(block.last),
      8.0,
      false,
    )
    let fraction = if block.assigned > 0 {
      Double::min(1.0, entry.mapped.to_double() / block.assigned.to_double())
    } else {
      1.0
    }
    let count = if block.assigned > 0 {
      info_number(entry.mapped.to_int64()) +
      " of " +
      info_number(block.assigned.to_int64())
    } else {
      info_number(entry.mapped.to_int64())
    }
    bands.push(
      Block(
        name,
        range,
        texter.line(count, 8.0, false),
        fraction,
        "block" + i.to_string(),
      ),
    )
    scroll.add(15.0)
  }
  let mut shown = 0
  for i, entry in coverage {
    let block = entry.block
    if shown + entry.mapped > 150000 && shown > 0 {
      let message = "The charts of the " +
        (coverage.length() - i).to_string() +
        " blocks after these are left out: the font maps more than 150,000 characters."
      scroll.space(16.0)
      bands.push(More(texter.line(message, 9.5, false)))
      scroll.add(16.0)
      break
    }
    scroll.space(16.0)
    scroll.anchor("block" + i.to_string())
    let title = texter.line(block.name, 11.5, true)
    let mut info = "U+" +
      chart_hex(block.first) +
      "–" +
      chart_hex(block.last) +
      " · " +
      info_number(entry.mapped.to_int64())
    if block.assigned > 0 {
      info += " of " + info_number(block.assigned.to_int64())
    }
    let info_line = texter.line(info, 8.0, false)
    let columns = [ for k in 0..<16 => texter.line(name_hex(k), 7.5, false) ]
    bands.push(ChartTitle(title, info_line, columns))
    scroll.add(34.0, keep=true)
    let mut row = block.first & -16
    let mut gap = false
    while row <= block.last {
      let mut any = false
      for code in row..<(row + 16) {
        if code >= block.first &&
          code <= block.last &&
          self.font.glyph(code) is Some(_) {
          any = true
          break
        }
      }
      if !any {
        if !gap {
          gap = true
          bands.push(Gap(texter.line("⋯", 7.5, false)))
          scroll.add(10.0)
        }
      } else {
        gap = false
        let hex = chart_hex(row)
        let label = hex[:hex.length() - 1].to_string() + "x"
        bands.push(
          ChartRow(texter.line(label, 7.5, false), row, block.first, block.last),
        )
        scroll.add(44.0)
      }
      row += 16
    }
    shown += entry.mapped
  }
  { face: self, texter, layout: scroll.finish(), bands, }
}

///|
/// Render a measured character view using prepared specimen and UI fonts.
pub fn SpecimenCharacterView::render(
  self : SpecimenCharacterView,
  programs : SpecimenFacePrograms,
  fonts : SpecimenUIFonts,
) -> Array[SpecimenRenderedPage] raise {
  let result : Array[SpecimenRenderedPage] = []
  let text : UInt32 = 0x1f1f1fffU
  let gray : UInt32 = 0x6b6b6bffU
  let accent : UInt32 = 0x1f5fbfffU
  let rule : UInt32 = 0xd9d9d9ffU
  let empty : UInt32 = 0xf3f3f3ffU
  let void : UInt32 = 0xe2e2e2ffU
  let width = 600.0 / 16.0
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
        Title(line) => {
          page.mark(6, "1")
          ignore(page.label(line, 36.0, y + 22.0, text, 0))
        }
        Summary(line) | More(line) => {
          page.mark(0, "")
          let offset = match self.bands[index] {
            Summary(_) => 12.0
            _ => 11.0
          }
          ignore(page.label(line, 36.0, y + offset, gray, 0))
        }
        Heading(line) => {
          page.mark(6, "2")
          ignore(page.label(line, 36.0, y + 16.0, text, 0))
          page.rect(36.0, y + 22.0, 648.0, 0.75, text)
        }
        Block(name, range, count, fraction, anchor) => {
          page.mark(0, "")
          let w = page.label(name, 36.0, y + 11.0, accent, 0)
          page.link_to(36.0, y, w, 15.0, anchor)
          ignore(page.label(range, 296.0, y + 11.0, gray, 0))
          ignore(page.label(count, 564.0, y + 11.0, text, 2))
          page.rect(574.0, y + 4.0, 110.0, 7.0, empty)
          page.rect(574.0, y + 4.0, 110.0 * fraction, 7.0, accent)
        }
        ChartTitle(title, info, columns) => {
          page.mark(6, "2")
          let w = page.label(title, 36.0, y + 16.0, text, 0)
          page.mark(0, "")
          ignore(page.label(info, 36.0 + w + 10.0, y + 16.0, gray, 0))
          for k, column in columns {
            let x = 36.0 + 48.0 + (k.to_double() + 0.5) * width
            ignore(page.label(column, x, y + 30.0, gray, 1))
          }
        }
        Gap(line) => ignore(page.label(line, 60.0, y + 8.0, gray, 1))
        ChartRow(line, row, first, last) => {
          page.mark(0, "")
          ignore(page.label(line, 76.0, y + 44.0 / 2.0 + 3.0, gray, 2))
          for k in 0..<16 {
            let code = row + k
            let x = 36.0 + 48.0 + k.to_double() * width
            if code >= first && code <= last {
              match self.face.font.glyph(code) {
                Some(glyph) =>
                  ignore(
                    page.cell_glyph(
                      glyph,
                      x,
                      y,
                      width,
                      44.0,
                      String::from_array([code.to_char().unwrap_or('\u{fffd}')]),
                    ),
                  )
                None =>
                  page.rect(
                    x,
                    y,
                    width,
                    44.0,
                    if chart_assigned(code) {
                      empty
                    } else {
                      void
                    },
                  )
              }
            }
          }
          page.rect(84.0, y, 600.0, 0.5, rule)
          page.rect(84.0, y + 44.0 - 0.5, 600.0, 0.5, rule)
          for k in 0..<=16 {
            page.rect(84.0 + k.to_double() * width - 0.25, y, 0.5, 44.0, rule)
          }
        }
      }
    }
    result.push({ height: strip.height, object: page.encode(), })
  }
  result
}
