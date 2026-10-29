///|
/// Bounds of a placed rest in staff spaces.
pub(all) struct RestLayout {
  x : Double
  right : Double
  top : Double
  bottom : Double
}

///|
fn rest_name(kind : Int32) -> String {
  let names = [
    "restDoubleWhole", "restWhole", "restHalf", "restQuarter", "rest8th", "rest16th",
    "rest32nd", "rest64th", "rest128th",
  ]
  names[Int32::min(Int32::max(kind, 0), 8)]
}

///|
/// Draw a rest, including augmentation dots and any ledger line.
pub fn draw_staff_rest(
  drawing : MusicDrawing,
  score : NotatedScore,
  prepared : PreparedScore,
  system : MusicSystem,
  staff : Int32,
  measure : Int32,
  event : ScoreEvent,
  slot_x : Double,
) -> RestLayout {
  let sm = prepared.measures[measure][staff]
  let mut kind = event.kind
  let mut x = slot_x
  if event.measure_rest {
    kind = if score.timeline.measures[measure].length >= 7680L { 0 } else { 1 }
    let col = system.columns[measure - system.first]
    let width = glyph_advance(rest_name(kind))
    let x0 = col.x + col.body_start
    let x1 = col.x +
      col.width -
      (if measure == score.timeline.measures.length() - 1 { 0.9 } else { 0.2 })
    x = (x0 + x1) / 2.0 - width / 2.0
  }
  let name = rest_name(kind)
  let glyph = music_glyph(name).unwrap()
  let mut y = if kind == 1 { 1.0 } else { 2.0 }
  if sm.voices > 1 {
    let distance = if kind <= 2 { 1.0 } else { 2.0 }
    if event.voice % 2 == 1 {
      y -= distance
    } else {
      y += distance
    }
  }
  drawing.glyph(name, x, y, 1.0)
  for i in 0..<event.dots {
    drawing.glyph(
      "augmentationDot",
      x + glyph.advance + 0.3 + 0.5 * i.to_double(),
      1.5,
      1.0,
    )
  }
  if kind <= 2 && (y < 0.0 || y > 4.0) {
    drawing.rect(x - 0.4, y.round() - 0.16 / 2.0, glyph.advance + 0.8, 0.16)
  }
  let (_, y0, _, y1) = glyph.bbox
  { x, right: x + glyph.advance, top: y + y0, bottom: y + y1, }
}
