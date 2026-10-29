///|
priv struct FeatureLaidItem {
  item : FeatureExample
  x : Double
  width : Double
  arrow : SpecimenTextLine
  note : SpecimenTextLine?
}

///|
priv enum FeatureBand {
  FeatureTitle(SpecimenTextLine)
  FeatureSummary(SpecimenTextLine)
  FeatureHeading(SpecimenTextLine)
  FeatureSummaryRow(
    SpecimenTextLine,
    SpecimenTextLine,
    SpecimenTextLine,
    SpecimenTextLine,
    SpecimenTextLine,
    String
  )
  FeatureDetailHeading(SpecimenTextLine, SpecimenTextLine?, SpecimenTextLine?)
  FeatureInfo(SpecimenTextLine)
  FeatureItems(Array[FeatureLaidItem])
  FeatureMore(SpecimenTextLine)
}

///|
/// A measured OpenType feature view, ready for UI font embedding and rendering.
pub struct SpecimenFeatureView {
  priv face : FileFace
  priv texter : SpecimenTexter
  priv layout : ScrollPlan
  priv bands : Array[FeatureBand]
  priv glyphs : Array[SpecimenGlyph]
  priv outlines : SpecimenOutlines
}

///|
fn feature_extent(
  outlines : SpecimenOutlines,
  upem : Double,
  placed : Array[FeaturePlacedGlyph],
  width : Double,
) -> (Double, Double) {
  let mut left = 0.0
  let mut right = width
  for glyph in placed {
    match outlines.bounds(glyph.glyph) {
      Some((x0, _, x1, _)) => {
        left = Double::min(left, glyph.x + x0 / upem)
        right = Double::max(right, glyph.x + x1 / upem)
      }
      None => ()
    }
  }
  (left, right)
}

///|
/// Measure OpenType feature tables and examples before embedding UI fonts.
pub fn FileFace::feature_view(
  self : FileFace,
  texter : SpecimenTexter,
  sample : SamplePlan,
  example_limit~ : Int32 = 0,
) -> SpecimenFeatureView {
  let groups = self.feature_groups()
  let planner = self.feature_planner()
  let outlines = self.outlines()
  let upem = self.font.metrics.units_per_em.to_double()
  let scroll = ScrollLayout::new()
  let bands : Array[FeatureBand] = []
  bands.push(FeatureTitle(texter.line("OpenType features", 18.0, true)))
  scroll.add(30.0)
  let parts : Array[String] = []
  for
    (name, table) in [
      ("GSUB", planner.gsub_layout),
      ("GPOS", planner.gpos_layout),
    ] {
    match table {
      Some(table) => {
        let count = groups.filter(g => g.table == name).length()
        let mut part = name +
          ": " +
          count.to_string() +
          " features, " +
          table.lookups.length().to_string() +
          " lookups"
        if table.feature_variations > 0 {
          part += ", " +
            table.feature_variations.to_string() +
            " feature variations"
        }
        parts.push(part)
      }
      None => ()
    }
  }
  bands.push(FeatureSummary(texter.line(parts.join(" · "), 9.5, false)))
  scroll.add(18.0)
  scroll.space(18.0)
  bands.push(FeatureHeading(texter.line("Summary", 13.0, true)))
  scroll.add(26.0, keep=true)
  scroll.space(4.0)
  for i, group in groups {
    let tag = texter.line(group.tag, 9.5, true)
    let name = texter.line(
      texter.fit(group.display_name(), 9.5, false, 190.0),
      9.5,
      false,
    )
    let table = texter.line(group.table, 7.5, false)
    let note = texter.line(group.default_note(), 7.5, false)
    let scripts = texter.line(
      texter.fit(group.script_tags(), 7.5, false, 228.0),
      7.5,
      false,
    )
    bands.push(
      FeatureSummaryRow(
        tag,
        name,
        table,
        note,
        scripts,
        "feature" + i.to_string(),
      ),
    )
    scroll.add(15.0)
  }
  for i, group in groups {
    scroll.space(20.0)
    scroll.anchor("feature" + i.to_string())
    let tag = texter.line(group.tag, 14.0, true)
    let name = @otlayout.feature_name(group.tag)
    let name = if name == "" {
      None
    } else {
      Some(texter.line(name, 12.0, false))
    }
    let note = group.default_note()
    let note = if note == "" {
      None
    } else {
      Some(texter.line(note, 7.5, false))
    }
    bands.push(FeatureDetailHeading(tag, name, note))
    scroll.add(24.0, keep=true)
    let infos : Array[String] = []
    if group.ui_name != "" {
      infos.push("Name: " + group.ui_name)
    }
    if group.characters.length() > 0 {
      let chars = group.characters.map(c => {
        String::from_array([c.to_char().unwrap_or('\u{fffd}')])
      })
      infos.push("Characters: " + chars.join(" "))
    }
    infos.push(group.table + " scripts: " + group.script_list())
    let notes = group.lookups.map(index => planner.lookup_note(group, index))
    if notes.length() == 0 {
      notes.push("none")
    }
    infos.push("Lookups: " + notes.join("; "))
    for info in infos {
      for line in texter.wrap(info, 8.0, false, 648.0) {
        bands.push(FeatureInfo(texter.line(line, 8.0, false)))
        scroll.add(12.0, keep=true)
      }
    }
    scroll.space(6.0)
    let examples = if group.table == "GSUB" {
      planner.gsub_examples(group, example_limit)
    } else {
      planner.gpos_examples(group, example_limit, sample)
    }
    let mut row : Array[FeatureLaidItem] = []
    let mut x = 0.0
    for item in examples.items {
      let (b0, b1) = feature_extent(
        outlines,
        upem,
        item.before,
        item.before_width,
      )
      let (a0, a1) = feature_extent(
        outlines,
        upem,
        item.after,
        item.after_width,
      )
      let mut width = Double::max(
        (b1 - b0 + a1 - a0) * 22.0 + 20.0 + 2.0 * 8.0,
        56.0,
      )
      if x > 0.0 && x + width > 648.0 {
        bands.push(FeatureItems(row))
        scroll.add(46.0)
        row = []
        x = 0.0
      }
      width = Double::min(width, 648.0)
      let arrow = texter.line("→", 10.0, false)
      let note = if item.note == "" {
        None
      } else {
        Some(texter.line(item.note, 6.5, false))
      }
      row.push({ item, x, width, arrow, note, })
      x += width + 4.0
    }
    if row.length() > 0 {
      bands.push(FeatureItems(row))
      scroll.add(46.0)
    }
    if examples.total > examples.items.length().to_int64() {
      let more = "… and " +
        info_number(examples.total - examples.items.length().to_int64()) +
        " more"
      bands.push(FeatureMore(texter.line(more, 8.0, false)))
      scroll.add(14.0)
    }
  }
  {
    face: self,
    texter,
    layout: scroll.finish(),
    bands,
    glyphs: self.specimen_glyphs(),
    outlines,
  }
}

///|
fn SpecimenFeatureView::draw_placed(
  self : SpecimenFeatureView,
  page : SpecimenPagePainter,
  placed : Array[FeaturePlacedGlyph],
  origin : Double,
  base : Double,
  size : Double,
  asc : Double,
  desc : Double,
  box : Bool,
  advance : Double,
) -> Unit raise {
  if box {
    page.rect(
      origin,
      base - asc * size,
      advance * size,
      (asc + desc) * size,
      0xe6effbffU,
    )
  }
  for glyph in placed {
    ignore(
      page.glyph_run(
        [glyph.glyph],
        [0.0],
        origin + glyph.x * size,
        base - glyph.y * size,
        size,
        self.glyphs[glyph.glyph].alternative,
      ),
    )
  }
}

///|
fn SpecimenFeatureView::draw_item(
  self : SpecimenFeatureView,
  page : SpecimenPagePainter,
  laid : FeatureLaidItem,
  y : Double,
) -> Unit raise {
  let item = laid.item
  let x = 36.0 + laid.x
  let (asc, desc) = specimen_vertical(self.face)
  let size = 22.0
  let base = y + (42.0 - (asc + desc) * size) / 2.0 + asc * size
  let upem = self.face.font.metrics.units_per_em.to_double()
  page.mark(0, "")
  page.rect(x, y, laid.width, 42.0, 0xf3f3f3ffU)
  let (b0, b1) = feature_extent(
    self.outlines,
    upem,
    item.before,
    item.before_width,
  )
  let (a0, _) = feature_extent(
    self.outlines,
    upem,
    item.after,
    item.after_width,
  )
  let bx = x + 8.0 - b0 * size
  self.draw_placed(
    page,
    item.before,
    bx,
    base,
    size,
    asc,
    desc,
    item.boxes,
    item.before_advance,
  )
  let ax = x + 8.0 + (b1 - b0) * size
  ignore(
    page.label(laid.arrow, ax + 20.0 / 2.0, base - size * 0.25, 0x6b6b6bffU, 1),
  )
  let ox = ax + 20.0 - a0 * size
  self.draw_placed(
    page,
    item.after,
    ox,
    base,
    size,
    asc,
    desc,
    item.boxes,
    item.after_advance,
  )
  if item.alternatives && item.after.length() > 1 {
    for i in 1..<item.after.length() {
      let dx = ox + (item.after[i].x - 0.125) * size
      page.rect(dx - 0.75, base + desc * size * 0.5, 1.5, 1.5, 0x6b6b6bffU)
    }
  }
  match laid.note {
    Some(note) =>
      ignore(
        page.label(note, x + laid.width - 3.0, y + 42.0 - 3.0, 0x6b6b6bffU, 2),
      )
    None => ()
  }
}

///|
/// Render a measured OpenType feature view.
pub fn SpecimenFeatureView::render(
  self : SpecimenFeatureView,
  programs : SpecimenFacePrograms,
  fonts : SpecimenUIFonts,
) -> Array[SpecimenRenderedPage] raise {
  let result : Array[SpecimenRenderedPage] = []
  let text : UInt32 = 0x1f1f1fffU
  let gray : UInt32 = 0x6b6b6bffU
  let accent : UInt32 = 0x1f5fbfffU
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
        FeatureTitle(line) => {
          page.mark(6, "1")
          ignore(page.label(line, 36.0, y + 22.0, text, 0))
        }
        FeatureSummary(line) => {
          page.mark(0, "")
          ignore(page.label(line, 36.0, y + 12.0, gray, 0))
        }
        FeatureHeading(line) => {
          page.mark(6, "2")
          ignore(page.label(line, 36.0, y + 16.0, text, 0))
          page.rect(36.0, y + 22.0, 648.0, 0.75, text)
        }
        FeatureSummaryRow(tag, name, table, note, scripts, anchor) => {
          page.mark(0, "")
          let w = page.label(tag, 36.0, y + 11.0, accent, 0)
          page.link_to(36.0, y, w, 15.0, anchor)
          ignore(page.label(name, 78.0, y + 11.0, text, 0))
          ignore(page.label(table, 276.0, y + 11.0, gray, 0))
          ignore(page.label(note, 311.0, y + 11.0, accent, 0))
          ignore(page.label(scripts, 456.0, y + 11.0, gray, 0))
        }
        FeatureDetailHeading(tag, name, note) => {
          page.mark(6, "2")
          let mut w = page.label(tag, 36.0, y + 17.0, text, 0)
          match name {
            Some(line) =>
              w += page.label(line, 36.0 + w + 10.0, y + 17.0, text, 0) + 10.0
            None => ()
          }
          match note {
            Some(line) => {
              let bx = 36.0 + w + 12.0
              page.rect(bx, y + 7.0, line.width + 10.0, 13.0, 0xe6effbffU)
              ignore(page.label(line, bx + 5.0, y + 16.5, accent, 0))
            }
            None => ()
          }
          page.rect(36.0, y + 22.0, 648.0, 0.5, 0xd9d9d9ffU)
        }
        FeatureInfo(line) => {
          page.mark(0, "")
          ignore(page.label(line, 36.0, y + 9.0, gray, 0))
        }
        FeatureMore(line) => {
          page.mark(0, "")
          ignore(page.label(line, 36.0, y + 10.0, gray, 0))
        }
        FeatureItems(items) =>
          for item in items {
            self.draw_item(page, item, y)
          }
      }
    }
    result.push({ height: strip.height, object: page.encode(), })
  }
  result
}
