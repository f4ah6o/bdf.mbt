///|
struct GlyphCellPlan {
  id : Int32
  id_line : SpecimenTextLine
  class_line : SpecimenTextLine?
  name_line : SpecimenTextLine?
  character_line : SpecimenTextLine?
  alternative : String
  size : Double
  ink_center : Double?
  advance : Double
  ascent : Double
  descent : Double
}

///|
/// A measured glyph-grid view ready for font embedding and page rendering.
pub struct SpecimenGlyphView {
  priv face : FileFace
  priv texter : SpecimenTexter
  priv layout : ScrollPlan
  priv heading : SpecimenTextLine
  priv info : SpecimenTextLine
  priv cells : Array[GlyphCellPlan]
}

///|
/// One encoded scroll-page object with its height in points.
pub(all) struct SpecimenRenderedPage {
  height : Double
  object : Bytes
}

///|
fn specimen_vertical(face : FileFace) -> (Double, Double) {
  let hhea = face.font.table("hhea").unwrap_or(b"")
  let os2 = face.font.table("OS/2").unwrap_or(b"")
  let upem = face.font.metrics.units_per_em.to_double()
  let mut asc = if hhea.length() >= 36 {
    info_signed16(hhea[:], 4).to_double() / upem
  } else {
    0.0
  }
  let mut desc = if hhea.length() >= 36 {
    -info_signed16(hhea[:], 6).to_double() / upem
  } else {
    0.0
  }
  if os2.length() >= 72 && (asc + desc <= 0.0 || asc <= 0.0) {
    asc = info_signed16(os2[:], 68).to_double() / upem
    desc = -info_signed16(os2[:], 70).to_double() / upem
  }
  if asc + desc <= 0.2 || asc <= 0.0 {
    (0.8, 0.2)
  } else {
    (asc, desc)
  }
}

///|
/// Measure a font specimen's glyph-grid headings and cells. Call before
/// embedding UI fonts so its glyph usage is included in the subset.
pub fn FileFace::glyph_view(
  self : FileFace,
  texter : SpecimenTexter,
) -> SpecimenGlyphView {
  let glyphs = self.specimen_glyphs()
  let n = glyphs.length()
  let mut named = 0
  let mut mapped = 0
  for glyph in glyphs {
    if glyph.name != "" {
      named += 1
    }
    if glyph.characters.length() > 0 {
      mapped += 1
    }
  }
  let mut info = info_number(n.to_int64()) + " glyphs"
  if named == 0 {
    info += ", without names"
  } else if named < n {
    info += ", " + info_number(named.to_int64()) + " of them named"
  }
  info += "; " + info_number(mapped.to_int64()) + " mapped from characters"
  let heading = texter.line("Glyphs", 18.0, true)
  let info_line = texter.line(info, 9.5, false)
  let definitions = self.glyph_definitions()
  let outlines = self.outlines()
  let upem = self.font.metrics.units_per_em.to_double()
  let (asc, desc) = specimen_vertical(self)
  let cells : Array[GlyphCellPlan] = []
  let cell_width = 648.0 / 10.0
  for id, glyph in glyphs {
    let id_line = texter.line(id.to_string(), 6.5, true)
    let class = match definitions {
      Some(gdef) =>
        match gdef.classes.get(id).unwrap_or(0) {
          2 => "ligature"
          3 => "mark"
          4 => "component"
          _ => ""
        }
      None => ""
    }
    let class_line = if class != "" {
      Some(texter.line(class, 6.0, false))
    } else {
      None
    }
    let advance_em = self.font.advance(id)
    let mut size = (54.0 - 14.0) / (asc + desc)
    let bounds = outlines.bounds(id)
    match bounds {
      Some((x0, _, x1, _)) =>
        size = Double::min(
          size,
          (cell_width - 10.0) /
          Double::max(Double::max(x1 / upem - x0 / upem, advance_em), 0.01),
        )
      None =>
        if advance_em > 0.0 {
          size = Double::min(size, (cell_width - 10.0) / advance_em)
        }
    }
    let advance = advance_em * size
    let mut ink_center : Double? = None
    match bounds {
      Some((x0, _, x1, _)) => {
        let left = x0 / upem
        let right = x1 / upem
        if left * size < -(cell_width - 10.0) / 2.0 + advance / 2.0 ||
          right * size > advance / 2.0 + (cell_width - 10.0) / 2.0 {
          ink_center = Some((left + right) / 2.0 * size)
        }
      }
      None => ()
    }
    let name_line = if glyph.name == "" {
      None
    } else {
      Some(
        texter.line(
          texter.fit(glyph.name, 6.5, false, cell_width - 6.0),
          6.5,
          false,
        ),
      )
    }
    let character_line = if glyph.label == "" {
      None
    } else {
      Some(texter.line(glyph.label, 6.5, false))
    }
    cells.push({
      id,
      id_line,
      class_line,
      name_line,
      character_line,
      alternative: glyph.alternative,
      size,
      ink_center,
      advance,
      ascent: asc,
      descent: desc,
    })
  }
  let scroll = ScrollLayout::new()
  scroll.add(30.0)
  scroll.add(18.0)
  scroll.space(10.0)
  for _ in 0..<((n + 9) / 10) {
    scroll.add(82.0)
  }
  {
    face: self,
    texter,
    layout: scroll.finish(),
    heading,
    info: info_line,
    cells,
  }
}

///|
/// Render measured glyph-grid pages using the selected specimen and UI fonts.
pub fn SpecimenGlyphView::render(
  self : SpecimenGlyphView,
  programs : SpecimenFacePrograms,
  ui_fonts : SpecimenUIFonts,
) -> Array[SpecimenRenderedPage] raise {
  let result : Array[SpecimenRenderedPage] = []
  let text : UInt32 = 0x1f1f1fffU
  let gray : UInt32 = 0x6b6b6bffU
  let accent : UInt32 = 0x1f5fbfffU
  let rule : UInt32 = 0xd9d9d9ffU
  let guide : UInt32 = 0xc8d8f0ffU
  let cell_width = 648.0 / 10.0
  for strip in self.layout.strips {
    let page = SpecimenPagePainter::new(
      self.face,
      programs,
      self.texter,
      ui_fonts,
      self.layout,
      strip.height,
    )
    for (index, y) in strip.bands {
      if index == 0 {
        page.mark(6, "1")
        ignore(page.label(self.heading, 36.0, y + 22.0, text, 0))
      } else if index == 1 {
        page.mark(0, "")
        ignore(page.label(self.info, 36.0, y + 12.0, gray, 0))
      } else {
        let first = (index - 2) * 10
        for k in 0..<10 {
          let id = first + k
          if id >= self.cells.length() {
            break
          }
          let cell = self.cells[id]
          let x = 36.0 + k.to_double() * cell_width
          page.mark(0, "")
          ignore(page.label(cell.id_line, x + 3.0, y + 9.0, gray, 0))
          match cell.class_line {
            Some(line) =>
              ignore(page.label(line, x + cell_width - 3.0, y + 9.0, accent, 2))
            None => ()
          }
          let origin = match cell.ink_center {
            Some(center) => x + cell_width / 2.0 - center
            None => x + cell_width / 2.0 - cell.advance / 2.0
          }
          let base = y + 14.0 + 3.0 + cell.ascent * cell.size
          page.rect(origin, base, cell.advance, 0.5, guide)
          page.rect(
            origin - 0.25,
            base - cell.ascent * cell.size,
            0.5,
            (cell.ascent + cell.descent) * cell.size,
            guide,
          )
          page.rect(
            origin + cell.advance - 0.25,
            base - cell.ascent * cell.size,
            0.5,
            (cell.ascent + cell.descent) * cell.size,
            guide,
          )
          ignore(
            page.glyph_run(
              [id],
              [0.0],
              origin,
              base,
              cell.size,
              cell.alternative,
            ),
          )
          let ly = y + 54.0 + 15.0
          match cell.name_line {
            Some(line) =>
              ignore(page.label(line, x + cell_width / 2.0, ly, text, 1))
            None => ()
          }
          match cell.character_line {
            Some(line) =>
              ignore(
                page.label(line, x + cell_width / 2.0, ly + 9.0, accent, 1),
              )
            None => ()
          }
        }
        page.rect(36.0, y, 648.0, 0.5, rule)
        page.rect(36.0, y + 82.0 - 0.5, 648.0, 0.5, rule)
        for k in 0..<=10 {
          page.rect(
            36.0 + k.to_double() * cell_width - 0.25,
            y,
            0.5,
            82.0,
            rule,
          )
        }
      }
    }
    result.push({ height: strip.height, object: page.encode(), })
  }
  result
}
