///|
/// Page dimensions and engraving scale for a MIDI-derived score, in points.
pub(all) struct MusicPageOptions {
  width : Double
  height : Double
  staff_space : Double
  title : String
}

///|
/// One positioned system and the drawings for its staves and connecting marks.
pub(all) struct LaidOutMusicSystem {
  system : MusicSystem
  placement : MusicSystemPlacement
  left : Double
  staves : Array[BasicStaffLayout]
  spanning : MusicDrawing
}

///|
/// Score layout before writing the BDF document.
pub(all) struct MusicScoreLayout {
  width : Double
  height : Double
  staff_space : Double
  title : String
  title_height : Double
  systems : Array[LaidOutMusicSystem]
}

///|
/// Lay out a MIDI-derived score. Text metrics are in staff spaces and the
/// callback receives the requested font size in staff spaces and italic flag.
/// Returns None when the score has no staves or measures or has an error.
pub fn layout_midi_score(
  score : NotatedScore,
  options : MusicPageOptions,
  measure_text : (String, Double, Bool) -> MusicTextMetrics,
) -> MusicScoreLayout? {
  if score.error != "" ||
    score.parts.is_empty() ||
    score.timeline.measures.is_empty() {
    return None
  }
  let mut staff_count = 0L
  let mut event_count = 0L
  for part in score.parts {
    staff_count += Int32::max(part.clefs.length(), 1).to_int64()
    for measure in part.measures {
      event_count += measure.events.length().to_int64()
    }
  }
  if staff_count > 4096L ||
    staff_count * score.timeline.measures.length().to_int64() > 1000000L ||
    event_count > 2000000L {
    return None
  }
  let prepared = prepare_score(score)
  let (width, height) = if options.width <= 0.0 || options.height <= 0.0 {
    (595.2756, 841.8898)
  } else {
    (options.width, options.height)
  }
  let margin = 14.0 * (72.0 / 25.4)
  let mut sp = if options.staff_space <= 0.0 {
    1.75 * (72.0 / 25.4)
  } else {
    options.staff_space
  }
  let n = prepared.staves.length().to_double()
  let required = n * 4.0 + (n - 1.0) * 6.5 + 10.0
  let usable = height - 2.0 * margin
  if required * sp > usable {
    sp = Double::max(usable / required, 2.0)
  }
  let title = if options.title == "" { score.title } else { options.title }
  let mut title_height = 0.0
  if title != "" {
    title_height += 4.4 * sp * 1.2 + sp
  }
  if score.subtitle != "" {
    title_height += 2.8 * sp * 1.3
  }
  if score.composer != "" || score.lyricist != "" {
    title_height += 2.2 * sp * 1.4
  }
  if score.arranger != "" {
    title_height += 2.2 * sp * 1.3
  }
  if title_height > 0.0 {
    title_height += 3.0 * sp
  }
  let columns = build_columns(score, prepared, text => {
    measure_text(text, 2.2, false).width
  })
  let mut first_names = 0.0
  if score.parts.length() > 1 {
    for part in score.parts {
      first_names = Double::max(
        first_names,
        measure_text(part.name, 2.2, false).width,
      )
    }
  }
  let bracket = if prepared.grand {
    1.2
  } else if score.parts.length() > 1 {
    1.6
  } else {
    0.0
  }
  let first_left = bracket +
    (if first_names > 0.0 { first_names + 1.2 } else { 0.0 })
  let later_left = bracket
  let systems = break_systems(
    score,
    prepared,
    columns,
    (width - 2.0 * margin) / sp - later_left,
    first_left - later_left,
  )
  let layouts : Array[Array[BasicStaffLayout]] = []
  let extents : Array[MusicSystemExtent] = []
  for system in systems {
    let staves : Array[BasicStaffLayout] = []
    let staff_extents : Array[MusicStaffExtent] = []
    for si, reference in prepared.staves {
      let layout = layout_basic_staff(score, prepared, system, si)
      draw_staff_ties(layout, prepared, system, si)
      draw_staff_tuplets(layout, prepared, si)
      draw_staff_lyrics(layout, text => measure_text(text, 2.2, false))
      if si == 0 {
        draw_system_marks(layout, score, prepared, system, measure_text)
      }
      let drawing = layout.drawing
      staves.push(layout)
      staff_extents.push({
        part: reference.part,
        above: drawing.skyline(-1.0e9, 1.0e9, 0.0, true),
        below: drawing.skyline(-1.0e9, 1.0e9, 4.0, false),
      })
    }
    layouts.push(staves)
    extents.push({ staves: staff_extents, page_break: false, })
  }
  let positions = paginate_systems(extents, height, sp, title_height)
  let result : Array[LaidOutMusicSystem] = []
  for i, system in systems {
    let parts : Array[MusicPartSpan] = []
    for pi, part in score.parts {
      let tops : Array[Double] = []
      for si, reference in prepared.staves {
        if reference.part == pi {
          tops.push(positions[i].staff_y[si])
        }
      }
      parts.push({ name: part.name, abbreviation: "", staff_tops: tops, })
    }
    let bars : Array[MusicBarSpan] = []
    for col in system.columns {
      bars.push({
        x: col.x,
        width: col.width,
        left: 1,
        right: if col.index == score.timeline.measures.length() - 1 {
          3
        } else {
          0
        },
      })
    }
    let spanning = draw_spanning_system(parts, bars, system.first == 0, text => {
      measure_text(text, 2.2, false)
    })
    result.push({
      system,
      placement: positions[i],
      left: if i == 0 {
        first_left
      } else {
        later_left
      },
      staves: layouts[i],
      spanning,
    })
  }
  Some({ width, height, staff_space: sp, title, title_height, systems: result, })
}
