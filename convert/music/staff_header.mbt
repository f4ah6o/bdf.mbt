///|
fn draw_key_signature(
  drawing : MusicDrawing,
  x : Double,
  clef : EngravingClef,
  previous : KeySig,
  key : KeySig,
) -> Double {
  if clef.sign == 3 || clef.sign == 4 {
    return x
  }
  let mut pos = x
  if cancelled_accidentals(previous, key) > 0 {
    let width = glyph_advance("accidentalNatural")
    for p in key_positions(clef, previous) {
      drawing.glyph("accidentalNatural", pos, p.to_double() / 2.0, 1.0)
      pos += width + 0.1
    }
    pos += 0.4
  }
  let name = if key.fifths < 0 { "accidentalFlat" } else { "accidentalSharp" }
  let positions = key_positions(clef, key)
  let width = glyph_advance(name)
  for p in positions {
    drawing.glyph(name, pos, p.to_double() / 2.0, 1.0)
    pos += width + 0.1
  }
  if !positions.is_empty() {
    pos += 0.6
  }
  pos
}

///|
fn draw_time_signature(
  drawing : MusicDrawing,
  x : Double,
  time : TimeSig,
) -> Unit {
  if time.symbol == "common" || time.symbol == "cut" {
    drawing.glyph(
      if time.symbol == "cut" {
        "timeSigCutCommon"
      } else {
        "timeSigCommon"
      },
      x,
      2.0,
      1.0,
    )
    return
  }
  let strings = [time.beats.to_string(), time.beat_type.to_string()]
  let widths : Array[Double] = []
  for value in strings {
    let mut width = 0.0
    for c in value {
      width += glyph_advance("timeSig" + c.to_string())
    }
    widths.push(width)
  }
  let width = Double::max(widths[0], widths[1])
  for i, value in strings {
    let mut pos = x + (width - widths[i]) / 2.0
    for c in value {
      let name = "timeSig" + c.to_string()
      drawing.glyph(name, pos, (1 + 2 * i).to_double(), 1.0)
      pos += glyph_advance(name)
    }
  }
}

///|
/// Draw five staff lines and the clef, key and time at a system start.
pub fn staff_header(
  score : NotatedScore,
  prepared : PreparedScore,
  system : MusicSystem,
  staff : Int32,
) -> MusicDrawing {
  let drawing = MusicDrawing::new()
  for k in 0..<5 {
    drawing.rect(0.0, k.to_double() - 0.13 / 2.0, system.width, 0.13)
  }
  let sm = prepared.measures[system.first][staff]
  let mut x = 0.8
  let name = clef_name(sm.clef)
  if name != "" {
    let (pos, _) = clef_reference(sm.clef)
    let y = if sm.clef.sign == 3 || sm.clef.sign == 4 {
      2.0
    } else {
      pos.to_double() / 2.0
    }
    drawing.glyph(name, x, y, 1.0)
    x += glyph_advance(name) + 0.8
  }
  x = draw_key_signature(
    drawing,
    x,
    sm.clef,
    { fifths: 0, minor: false, },
    sm.key,
  )
  if system.first == 0 || score.timeline.measures[system.first].show_time {
    draw_time_signature(drawing, x, prepared.times[system.first])
  }
  drawing
}

///|
/// Draw key or time changes at a measure inside an existing system.
pub fn staff_measure_header(
  drawing : MusicDrawing,
  score : NotatedScore,
  prepared : PreparedScore,
  system : MusicSystem,
  staff : Int32,
  measure : Int32,
) -> Unit {
  if measure == system.first {
    return
  }
  let col = system.columns[measure - system.first]
  let sm = prepared.measures[measure][staff]
  let mut x = col.x + 0.6
  if sm.key_change {
    x = draw_key_signature(drawing, x, sm.clef, sm.previous_key, sm.key)
  }
  if score.timeline.measures[measure].show_time {
    draw_time_signature(drawing, x, score.timeline.measures[measure].time)
  }
}
