///|
/// Measured text width, ascent and descent in staff spaces.
pub(all) struct MusicTextMetrics {
  width : Double
  ascent : Double
  descent : Double
}

///|
priv struct PlacedLyric {
  lyric : ScoreLyric
  metrics : MusicTextMetrics
  x0 : Double
  x1 : Double
}

///|
/// Add MIDI lyric text and hyphens below a system staff.
/// The callback measures each line at the lyric font size (2.2 staff spaces).
pub fn draw_staff_lyrics(
  layout : BasicStaffLayout,
  measure : (String) -> MusicTextMetrics,
) -> Unit {
  let lines : Array[PlacedLyric] = []
  for item in layout.events {
    if item.event.rest {
      continue
    }
    match item.event.lyric {
      Some(lyric) if lyric.text != "" => {
        let note = item.note_layout.unwrap()
        if note.heads.is_empty() {
          continue
        }
        let metrics = measure(lyric.text)
        let center = item.x + glyph_advance(note.heads[0].glyph) / 2.0
        lines.push({
          lyric,
          metrics,
          x0: center - metrics.width / 2.0,
          x1: center + metrics.width / 2.0,
        })
      }
      _ => ()
    }
  }
  if lines.is_empty() {
    return
  }
  let drawing = layout.drawing
  let y = drawing.skyline(-1.0e9, 1.0e9, 4.0, false) + 0.5 + 0.85 * 2.2
  drawing.mark(0, "")
  for i, line in lines {
    if i > 0 {
      let prev = lines[i - 1].lyric.syllabic
      drawing.mark(if prev == 1 || prev == 2 { 5 } else { 1 }, "")
    }
    drawing.text(
      line.lyric.text,
      (line.x0 + line.x1) / 2.0,
      y,
      1,
      line.metrics.width,
      line.metrics.ascent,
      line.metrics.descent,
    )
  }
  let hy = y - 0.3 * 2.2
  for i, line in lines {
    if line.lyric.syllabic == 1 || line.lyric.syllabic == 2 {
      let x0 = line.x1
      let x1 = if i + 1 < lines.length() { lines[i + 1].x0 } else { x0 + 1.4 }
      let gap = x1 - x0
      if gap > 0.5 {
        let width = Double::min(0.9, gap * 0.5)
        drawing.rect((x0 + x1) / 2.0 - width / 2.0, hy - 0.06, width, 0.12)
      }
    }
  }
}
