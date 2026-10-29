///|
/// A part's name and top lines of its staves in system coordinates.
pub(all) struct MusicPartSpan {
  name : String
  abbreviation : String
  staff_tops : Array[Double]
}

///|
/// Barline positions and styles at one measure in system coordinates.
pub(all) struct MusicBarSpan {
  x : Double
  width : Double
  left : Int32
  right : Int32
}

///|
/// Width reserved to the left of a system for braces and brackets.
pub fn music_bracket_width(parts : Array[MusicPartSpan]) -> Double {
  let mut grand = false
  for part in parts {
    if part.staff_tops.length() > 1 {
      grand = true
    }
  }
  if grand {
    1.2
  } else if parts.length() > 1 {
    1.6
  } else {
    0.0
  }
}

///|
/// Draw lines, braces, brackets, names and barlines that span staves.
/// Parts must each contain at least one staff; text metrics are in staff spaces.
pub fn draw_spanning_system(
  parts : Array[MusicPartSpan],
  measures : Array[MusicBarSpan],
  first_system : Bool,
  measure_text : (String) -> MusicTextMetrics,
) -> MusicDrawing {
  let drawing = MusicDrawing::new()
  if parts.is_empty() {
    return drawing
  }
  let last = parts[parts.length() - 1].staff_tops
  let bottom = last[last.length() - 1] + 4.0
  let mut staff_count = 0
  let mut grand = false
  for part in parts {
    staff_count += part.staff_tops.length()
    if part.staff_tops.length() > 1 {
      grand = true
    }
  }
  if staff_count > 1 {
    drawing.rect(0.0, 0.0, 0.16, bottom)
  }
  for part in parts {
    let tops = part.staff_tops
    if tops.length() > 1 {
      let end = tops[tops.length() - 1] + 4.0
      let height = end - tops[0]
      drawing.spanning_glyph(
        "brace",
        -0.4 - glyph_advance("brace") * height / 4.0 * 1.2,
        end,
        height / 4.0 * 1.2,
        height / 4.0,
      )
    }
  }
  if parts.length() > 1 && !grand {
    drawing.rect(-1.5, -0.2, 0.5, bottom + 0.4)
    drawing.glyph("bracketTop", -1.5, -0.2, 1.0)
    drawing.glyph("bracketBottom", -1.5, bottom + 0.2, 1.0)
  }
  if parts.length() > 1 {
    let bracket = music_bracket_width(parts)
    for part in parts {
      let name = if first_system { part.name } else { part.abbreviation }
      if name != "" {
        let metric = measure_text(name)
        let tops = part.staff_tops
        let y = (tops[0] + tops[tops.length() - 1] + 4.0) / 2.0 +
          (metric.ascent - metric.descent) / 2.0
        drawing.mark(0, "")
        drawing.text(
          name,
          -bracket - 1.0,
          y,
          2,
          metric.width,
          metric.ascent,
          metric.descent,
          size=2.2,
        )
      }
    }
  }
  for bar in measures {
    for part in parts {
      let tops = part.staff_tops
      let top = tops[0]
      let end = tops[tops.length() - 1] + 4.0
      if bar.left == 4 || bar.left == 5 {
        draw_barline(drawing, bar.left, bar.x, top, end, tops, true)
      }
      draw_barline(drawing, bar.right, bar.x + bar.width, top, end, tops, false)
    }
  }
  drawing
}
