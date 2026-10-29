///|
/// Options for drawing a MIDI-derived score into BDF page objects.
pub(all) struct MusicRenderOptions {
  page : MusicPageOptions
  system_fonts : Bool
  no_subset : Bool
  ignore_restrictions : Bool
  no_woff2 : Bool
  document_language : String
}

///|
/// Rendered page object references and the shared path collection.
pub(all) struct MusicRenderedPages {
  layout : MusicScoreLayout
  objects : Array[String]
  glyph_paths : String?
  embedded_fonts : Int32
  warnings : Array[String]
}

///|
pub suberror MusicRenderError {
  InvalidMusicScore(String)
}

///|
/// Render the pages of a MIDI-derived score into a supplied document writer.
/// The caller can attach the resulting objects to a fixed view and add playback.
pub fn render_midi_pages(
  score : NotatedScore,
  db : @db.Database,
  document : @core.DocumentWriter,
  options : MusicRenderOptions,
) -> MusicRenderedPages raise {
  if score.error != "" {
    raise InvalidMusicScore(score.error)
  }
  if score.parts.is_empty() || score.timeline.measures.is_empty() {
    raise InvalidMusicScore("music: the score has no notes")
  }
  let mut count = 0
  for part in score.parts {
    count += Int32::max(part.clefs.length(), 1)
  }
  let height = if options.page.width <= 0.0 || options.page.height <= 0.0 {
    841.8898
  } else {
    options.page.height
  }
  let margin = 14.0 * (72.0 / 25.4)
  let mut sp = if options.page.staff_space <= 0.0 {
    1.75 * (72.0 / 25.4)
  } else {
    options.page.staff_space
  }
  let n = count.to_double()
  let required = n * 4.0 + (n - 1.0) * 6.5 + 10.0
  let usable = height - 2.0 * margin
  if required * sp > usable {
    sp = Double::max(usable / required, 2.0)
  }
  let texter = MusicTexter::new(db)
  let layout = match
    layout_midi_score(score, options.page, (text, size, italic) => {
      let line = texter.line(text, size * sp, false, italic)
      {
        width: line.width / sp,
        ascent: line.ascent / sp,
        descent: line.descent / sp,
      }
    }) {
    Some(layout) => layout
    None => raise InvalidMusicScore("music: score exceeds engraving limits")
  }
  let drawings : Array[MusicDrawing] = []
  for system in layout.systems {
    for staff in system.staves {
      drawings.push(staff.drawing)
    }
    drawings.push(system.spanning)
  }
  let glyphs = music_glyph_paths(drawings, sp)
  let glyph_hash = if glyphs.paths.is_empty() {
    None
  } else {
    Some(document.add_part("path", glyphs.encode()))
  }
  let pages = layout.systems[layout.systems.length() - 1].placement.page + 1
  if layout.title != "" {
    ignore(texter.line(layout.title, 4.4 * sp, true, false))
  }
  if score.subtitle != "" {
    ignore(texter.line(score.subtitle, 2.8 * sp, false, false))
  }
  if score.composer != "" {
    ignore(texter.line(score.composer, 2.2 * sp, false, false))
  }
  if score.lyricist != "" {
    ignore(texter.line(score.lyricist, 2.2 * sp, false, false))
  }
  if score.arranger != "" {
    ignore(texter.line(score.arranger, 2.2 * sp, false, false))
  }
  for pi in 1..<pages {
    ignore(texter.line((pi + 1).to_string(), 2.0 * sp, false, false))
  }
  let fonts = if options.system_fonts {
    { hashes: Map([]), warnings: [], }
  } else {
    texter.embed(
      document,
      no_subset=options.no_subset,
      ignore_restrictions=options.ignore_restrictions,
      no_woff2=options.no_woff2,
    )
  }
  let objects : Array[String] = []
  for pi in 0..<pages {
    let object = @core.ObjectBuilder::new()
    object.set_bbox(
      0.0F,
      0.0F,
      music_f32(layout.width),
      music_f32(layout.height),
    )
    object.fill_color(0xffffffffU)
    object.fill_rect(
      0.0F,
      0.0F,
      music_f32(layout.width),
      music_f32(layout.height),
    )
    object.fill_color(0x000000ffU)
    object.stroke_color(0x000000ffU)
    let painter = MusicPainter::new(object, glyphs, glyph_hash.unwrap_or(""))
    let text = MusicTextPainter::new(
      object,
      texter,
      fonts,
      document_language=options.document_language,
    )
    if pi == 0 {
      let mut y = margin
      if layout.title != "" {
        let line = texter.line(layout.title, 4.4 * sp, true, false)
        y += line.ascent
        object.mark(6, "1")
        text.draw(line, layout.width / 2.0, y, 1)
        y += line.descent + sp
      }
      if score.subtitle != "" {
        let line = texter.line(score.subtitle, 2.8 * sp, false, false)
        y += line.ascent
        object.mark(0, "")
        text.draw(line, layout.width / 2.0, y, 1)
        y += line.descent + 0.5 * sp
      }
      if score.composer != "" || score.lyricist != "" {
        let size = 2.2 * sp
        y += 0.8 * size
        if score.lyricist != "" {
          object.mark(0, "")
          text.draw(
            texter.line(score.lyricist, size, false, false),
            margin,
            y,
            0,
          )
        }
        if score.composer != "" {
          object.mark(0, "")
          text.draw(
            texter.line(score.composer, size, false, false),
            layout.width - margin,
            y,
            2,
          )
        }
        y += 0.5 * size
      }
      if score.arranger != "" {
        let size = 2.2 * sp
        y += 0.8 * size
        object.mark(0, "")
        text.draw(
          texter.line(score.arranger, size, false, false),
          layout.width - margin,
          y,
          2,
        )
      }
    }
    for system in layout.systems {
      if system.placement.page != pi {
        continue
      }
      let ox = music_mul_add(system.left, sp, margin)
      let oy = system.placement.top
      let first = system.system.first + 1
      let last = system.system.last + 1
      object.mark(
        10,
        if first == last {
          "Measure " + first.to_string()
        } else {
          "Measures " + first.to_string() + "–" + last.to_string()
        },
      )
      painter.draw(system.spanning, ox, oy, (p, x, y) => {
        text.draw(
          texter.line(p.text, p.text_size * sp, p.text_bold, p.text_italic),
          x,
          y,
          p.align,
        )
      })
      for si, staff in system.staves {
        let sy = music_mul_add(system.placement.staff_y[si], sp, oy)
        painter.draw(staff.drawing, ox, sy, (p, x, y) => {
          text.draw(
            texter.line(p.text, p.text_size * sp, p.text_bold, p.text_italic),
            x,
            y,
            p.align,
          )
        })
      }
      object.mark(11, "")
    }
    if pi > 0 {
      object.mark(0, "")
      text.draw(
        texter.line((pi + 1).to_string(), 2.0 * sp, false, false),
        layout.width / 2.0,
        layout.height - margin / 2.0,
        1,
      )
    }
    objects.push(document.add_part("obj", object.encode()))
  }
  let warnings = fonts.warnings.copy()
  match texter.missing_warning() {
    Some(warning) => warnings.push(warning)
    None => ()
  }
  {
    layout,
    objects,
    glyph_paths: glyph_hash,
    embedded_fonts: fonts.hashes.length(),
    warnings,
  }
}
