///|
fn offset_x(
  score : NotatedScore,
  system : MusicSystem,
  measure : Int32,
  offset : Int64,
) -> Double {
  let col = system.columns[measure - system.first]
  let slots = col.slots
  if slots.is_empty() {
    return col.x + col.body_start
  }
  if offset <= slots[0].slot.offset {
    return col.x + slots[0].x
  }
  for i in 0..<slots.length() {
    let slot = slots[i]
    if slot.slot.offset == offset {
      return col.x + slot.x
    }
    if slot.slot.offset > offset {
      let prev = slots[i - 1]
      let fraction = (offset - prev.slot.offset).to_double() /
        (slot.slot.offset - prev.slot.offset).to_double()
      return col.x + prev.x + fraction * (slot.x - prev.x)
    }
  }
  let last = slots[slots.length() - 1]
  let right = col.width -
    (if measure == score.timeline.measures.length() - 1 { 0.9 } else { 0.2 })
  let fraction = (offset - last.slot.offset).to_double() /
    Int64::max(score.timeline.measures[measure].length - last.slot.offset, 1L).to_double()
  col.x + last.x + Double::min(fraction, 1.0) * (right - last.x)
}

///|
/// Add measure numbers and metronome marks to the top staff of a MIDI score.
/// The callback measures text at the supplied size in staff spaces; its last
/// argument requests italic text.
pub fn draw_system_marks(
  layout : BasicStaffLayout,
  score : NotatedScore,
  prepared : PreparedScore,
  system : MusicSystem,
  measure_text : (String, Double, Bool) -> MusicTextMetrics,
) -> Unit {
  let drawing = layout.drawing
  if system.first > 0 {
    let text = prepared.counts[system.first].to_string()
    let metrics = measure_text(text, 1.6, true)
    let y = drawing.skyline(0.0, metrics.width, 0.0, true) -
      0.6 -
      metrics.descent
    drawing.mark(3, "")
    drawing.text(
      text,
      0.0,
      y,
      0,
      metrics.width,
      metrics.ascent,
      metrics.descent,
    )
  }
  for mi in system.first..<=system.last {
    let measure = score.timeline.measures[mi]
    let col = system.columns[mi - system.first]
    for tempo in measure.tempo {
      let mut x = offset_x(score, system, mi, tempo.offset)
      if tempo.offset == 0L {
        x = if mi == system.first {
          system.header
        } else {
          col.x + col.body_start
        }
      }
      let text = " = " + tempo.per_minute.to_int64().to_string()
      let metrics = measure_text(text, 2.4, false)
      let symbol = "metNoteQuarterUp"
      let symbol_width = glyph_advance(symbol)
      let total_width = symbol_width +
        tempo.dots.to_double() * 0.6 +
        metrics.width
      let y = drawing.skyline(x, x + total_width, 0.0, true) - 1.0
      drawing.mark(3, "")
      drawing.glyph(symbol, x, y - 0.2, 0.8)
      x += symbol_width * 0.8
      for _ in 0..<tempo.dots {
        drawing.glyph("metAugmentationDot", x + 0.2, y - 0.2, 0.8)
        x += 0.6
      }
      drawing.mark(4, "♩")
      drawing.text(
        text,
        x,
        y,
        0,
        metrics.width,
        metrics.ascent,
        metrics.descent,
      )
    }
  }
}
