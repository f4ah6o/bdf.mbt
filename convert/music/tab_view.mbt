///|
/// A rendered guitar TAB page, before adding it to a BDF document.
pub(all) struct GuitarTabPage {
  width : Double
  height : Double
  object : Bytes
}

///|
/// A position visited during playback of a TAB measure.
pub(all) struct GuitarTabPoint {
  measure : Int32
  offset : Int64
  system : Int32
  x : Double
}

///|
/// One estimated-fingering view and its playback positions.
pub(all) struct GuitarTabView {
  id : String
  title : String
  pages : Array[GuitarTabPage]
  systems : Array[@core.CueSystem]
  points : Array[GuitarTabPoint]
  omitted : Int32
}

///|
priv struct GuitarTabPainter {
  object : @core.ObjectBuilder
  graphics : MusicPainter
  text : MusicTextPainter
}

///|
fn new_tab_painter(
  width : Double,
  height : Double,
  sp : Double,
  texter : MusicTexter,
  fonts : MusicTextFonts,
  language : String,
) -> GuitarTabPainter {
  let object = @core.ObjectBuilder::new()
  let w = Float::from_double(width)
  let h = Float::from_double(height)
  object.set_bbox(0.0F, 0.0F, w, h)
  object.fill_color(0xffffffffU)
  object.fill_rect(0.0F, 0.0F, w, h)
  object.fill_color(0x000000ffU)
  object.stroke_color(0x000000ffU)
  let glyphs = music_glyph_paths([], sp)
  {
    object,
    graphics: MusicPainter::new(object, glyphs, ""),
    text: MusicTextPainter::new(
      object,
      texter,
      fonts,
      document_language=language,
    ),
  }
}

///|
fn GuitarTabPainter::line(
  self : GuitarTabPainter,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  width : Double,
  sp : Double,
) -> Unit raise {
  let drawing = MusicDrawing::new()
  drawing.line(x0 / sp, y0 / sp, x1 / sp, y1 / sp, width, 0.0)
  self.graphics.draw(drawing, 0.0, 0.0, (_, _, _) => ())
}

///|
fn GuitarTabPainter::title(
  self : GuitarTabPainter,
  name : String,
  preset : GuitarPreset,
  texter : MusicTexter,
  margin : Double,
  sp : Double,
) -> Unit raise {
  let title = texter.line(
    "Guitar TAB — " + name + " — " + preset.name,
    3.0 * sp,
    true,
    false,
  )
  self.text.draw(title, margin, margin + title.ascent, 0)
  self.text.draw(
    texter.line(
      preset.explanation + " · estimated fingering",
      1.75 * sp,
      false,
      false,
    ),
    margin,
    margin + title.ascent + 3.0 * sp,
    0,
  )
  self.text.draw(
    texter.line(
      "Standard tuning E A D G B E · other positions may work",
      1.75 * sp,
      false,
      false,
    ),
    margin,
    margin + title.ascent + 5.2 * sp,
    0,
  )
}

///|
/// Render an estimated guitar TAB alternative for one pitched MIDI score part.
/// All text is measured through the supplied texter. Returns None if no notes
/// can be placed on the instrument.
pub fn render_guitar_tab(
  score : NotatedScore,
  layout : MusicScoreLayout,
  part_index : Int32,
  preset : GuitarPreset,
  texter : MusicTexter,
  fonts : MusicTextFonts,
  document_language~ : String = "",
) -> GuitarTabView? raise {
  let part = score.parts[part_index]
  let input = guitar_score_onsets(score, part_index)
  let fingering = choose_guitar_fingering(input.onsets, preset)
  if fingering.positions.is_empty() {
    return None
  }
  let name = if part.name == "" {
    "Part " + (part_index + 1).to_string()
  } else {
    part.name
  }
  let sp = layout.staff_space
  let margin = 14.0 * (72.0 / 25.4)
  let step = 1.35 * sp
  let staff_height = 5.0 * step
  let block_height = staff_height + 6.5 * sp
  let page_height = Double::min(
    layout.height,
    Double::max(
      270.0,
      2.0 * margin +
      13.0 * sp +
      layout.systems.length().to_double() * block_height,
    ),
  )
  let pages : Array[GuitarTabPage] = []
  let systems : Array[@core.CueSystem] = []
  let points : Array[GuitarTabPoint] = []
  let mut painter = new_tab_painter(
    layout.width,
    page_height,
    sp,
    texter,
    fonts,
    document_language,
  )
  painter.title(name, preset, texter, margin, sp)
  let mut y = margin + 13.0 * sp
  for sys in layout.systems {
    if y + staff_height + 3.0 * sp > page_height - margin {
      pages.push({
        width: layout.width,
        height: page_height,
        object: painter.object.encode(),
      })
      painter = new_tab_painter(
        layout.width,
        page_height,
        sp,
        texter,
        fonts,
        document_language,
      )
      y = margin + 5.0 * sp
    }
    let x0 = music_mul_add(sys.left, sp, margin)
    let x1 = music_mul_add(sys.system.width, sp, x0)
    let first = sys.system.first + 1
    let last = sys.system.last + 1
    let label = if first == last {
      "Measure " + first.to_string()
    } else {
      "Measures " + first.to_string() + "–" + last.to_string()
    }
    painter.object.mark(10, "Guitar TAB, " + name + ", " + label)
    for string, name in ["e", "B", "G", "D", "A", "E"] {
      let sy = music_mul_add(string.to_double(), step, y)
      painter.text.draw(
        texter.line(name, 1.8 * sp, false, false),
        x0 - 2.0 * sp,
        music_mul_add(0.35, sp, sy),
        0,
      )
      painter.line(x0, sy, x1, sy, 0.08, sp)
    }
    painter.text.draw(
      texter.line(first.to_string(), 1.6 * sp, false, false),
      music_mul_add(0.4, sp, x0),
      y - 2.0 * sp,
      0,
    )
    for col in sys.system.columns {
      let mi = col.index
      let bx = music_mul_add(col.x + col.width, sp, x0)
      painter.line(bx, y, bx, y + staff_height, 0.12, sp)
      if mi > sys.system.first && mi % 4 == 0 {
        painter.text.draw(
          texter.line((mi + 1).to_string(), 1.5 * sp, false, false),
          music_mul_add(col.x + 0.3, sp, x0),
          y - 2.0 * sp,
          0,
        )
      }
      for slot in col.slots {
        let x = music_mul_add(col.x + slot.x + 0.6, sp, x0)
        if mi < part.measures.length() {
          for ei, event in part.measures[mi].events {
            if event.offset != slot.slot.offset || event.rest {
              continue
            }
            for ni, _ in event.notes {
              let id = input.note_ids[mi][ei][ni]
              match fingering.positions.get(id) {
                None => ()
                Some(position) => {
                  let line_y = music_mul_add(
                    (position.string - 1).to_double(),
                    step,
                    y,
                  )
                  let fret = texter.line(
                    position.fret.to_string(),
                    1.85 * sp,
                    true,
                    false,
                  )
                  painter.object.fill_color(0xffffffffU)
                  painter.object.fill_rect(
                    Float::from_double(x - fret.width / 2.0 - 0.2 * sp),
                    Float::from_double(line_y - 0.8 * sp),
                    Float::from_double(fret.width + 0.4 * sp),
                    Float::from_double(1.2 * sp),
                  )
                  painter.object.fill_color(0x000000ffU)
                  painter.text.draw(fret, x, music_mul_add(0.38, sp, line_y), 1)
                }
              }
            }
          }
        }
        points.push({
          measure: mi,
          offset: slot.slot.offset,
          system: systems.length(),
          x,
        })
      }
      points.push({
        measure: mi,
        offset: score.timeline.measures[mi].length,
        system: systems.length(),
        x: bx,
      })
    }
    painter.object.mark(11, "")
    systems.push({
      page: pages.length().to_uint(),
      x: Float::from_double(x0).to_double(),
      y: Float::from_double(y - sp).to_double(),
      width: Float::from_double(x1 - x0).to_double(),
      height: Float::from_double(staff_height + 2.0 * sp).to_double(),
    })
    y += block_height
  }
  pages.push({
    width: layout.width,
    height: page_height,
    object: painter.object.encode(),
  })
  Some({
    id: "guitar-tab-p" + (part_index + 1).to_string() + "-" + preset.id,
    title: "TAB " +
    (part_index + 1).to_string() +
    ": " +
    preset.name +
    " · " +
    name +
    " (estimated)",
    pages,
    systems,
    points,
    omitted: fingering.omitted,
  })
}
