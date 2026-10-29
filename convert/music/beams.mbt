///|
/// Consecutive notes connected by a beam and their common stem direction.
pub(all) struct MusicBeamGroup {
  indices : Array[Int32]
  up : Bool
}

///|
priv enum BeamKey {
  Tuplet(Int64)
  Half(Int64)
  Beat(Int64)
} derive(Eq)

///|
fn group_direction(
  staff : PreparedStaffMeasure,
  events : Array[ScoreEvent],
  indices : Array[Int32],
) -> Bool {
  if staff.voices > 1 {
    return events[indices[0]].voice % 2 == 1
  }
  let mut hi = 1000
  let mut lo = -1000
  for i in indices {
    for note in events[i].notes {
      let position = staff_position(staff.clef, note.pitch)
      hi = Int32::min(hi, position)
      lo = Int32::max(lo, position)
    }
  }
  lo - 4 > 4 - hi
}

///|
/// Group consecutive events of one measure and voice into beams.
pub fn beam_groups(
  time : TimeSig,
  staff : PreparedStaffMeasure,
  events : Array[ScoreEvent],
) -> Array[MusicBeamGroup] {
  let (beat, compound) = time.beat()
  let halves : Array[Bool] = [false, false]
  if !compound && time.beats == 4 && time.beat_type == 4 {
    halves[0] = true
    halves[1] = true
    for event in events {
      let half = Int32::min((event.offset / 1920L).to_int(), 1)
      if half >= 0 &&
        (event.kind != 4 || event.dots > 0 || event.tuplet_beat is Some(_)) {
        halves[half] = false
      }
    }
  }
  let result : Array[MusicBeamGroup] = []
  let mut current : Array[Int32] = []
  let mut current_key : BeamKey? = None
  for i, event in events {
    if event.rest || event.notes.is_empty() || event.kind < 4 {
      if current.length() > 1 {
        result.push({
          indices: current,
          up: group_direction(staff, events, current),
        })
      }
      current = []
      current_key = None
      continue
    }
    let key : BeamKey = match event.tuplet_beat {
      Some(tick) => Tuplet(tick)
      None => {
        let half = Int32::min((event.offset / 1920L).to_int(), 1)
        if half >= 0 && halves[half] {
          Half(half.to_int64())
        } else {
          Beat(event.offset / Int64::max(beat.to_int64(), 1L))
        }
      }
    }
    if !current.is_empty() {
      let prev = events[current[current.length() - 1]]
      if current_key != Some(key) || prev.offset + prev.duration != event.offset {
        if current.length() > 1 {
          result.push({
            indices: current,
            up: group_direction(staff, events, current),
          })
        }
        current = []
      }
    }
    current_key = Some(key)
    current.push(i)
  }
  if current.length() > 1 {
    result.push({
      indices: current,
      up: group_direction(staff, events, current),
    })
  }
  result
}

///|
/// Draw a beam group and its stems. Layouts must be arranged with the
/// group's common direction and `beamed=true`.
pub fn draw_beam(
  drawing : MusicDrawing,
  events : Array[ScoreEvent],
  layouts : Array[NoteLayout],
  indices : Array[Int32],
  up : Bool,
  scale : Double,
) -> Unit {
  if indices.length() < 2 {
    return
  }
  let thick = 0.12 * scale
  let beam_thick = 0.5 * scale
  let gap = 0.75 * scale
  let first = layouts[indices[0]]
  let last = layouts[indices[indices.length() - 1]]
  let first_end = if up {
    first.heads[first.heads.length() - 1].position.to_double() / 2.0
  } else {
    first.heads[0].position.to_double() / 2.0
  }
  let last_end = if up {
    last.heads[last.heads.length() - 1].position.to_double() / 2.0
  } else {
    last.heads[0].position.to_double() / 2.0
  }
  let x0 = first.stem_x + thick / 2.0
  let x1 = last.stem_x + thick / 2.0
  let mut delta = last_end - first_end
  for i in 1..<(indices.length() - 1) {
    let l = layouts[indices[i]]
    let y = if up {
      l.heads[l.heads.length() - 1].position.to_double() / 2.0
    } else {
      l.heads[0].position.to_double() / 2.0
    }
    if (up && y < Double::min(first_end, last_end)) ||
      (!up && y > Double::max(first_end, last_end)) {
      delta = 0.0
    }
  }
  delta = Double::max(Double::min(delta, 1.0), -1.0)
  let slope = if x1 > x0 { delta / (x1 - x0) } else { 0.0 }
  let mut beams = 1
  for i in indices {
    beams = Int32::max(beams, Int32::max(events[i].kind - 3, 0))
  }
  let min_length = (3.25 + (beams - 1).to_double() * 0.75) * scale
  let mut y0 = if up { 1.0e9 } else { -1.0e9 }
  for i in indices {
    let l = layouts[i]
    let end = if up {
      l.heads[l.heads.length() - 1].position.to_double() / 2.0
    } else {
      l.heads[0].position.to_double() / 2.0
    }
    let shift = slope * (l.stem_x + thick / 2.0 - x0)
    if up {
      y0 = Double::min(y0, end - min_length - shift)
      if scale == 1.0 {
        y0 = Double::min(y0, 2.0 - shift)
      }
    } else {
      y0 = Double::max(y0, end + min_length - shift)
      if scale == 1.0 {
        y0 = Double::max(y0, 2.0 - shift)
      }
    }
  }
  for i in indices {
    let l = layouts[i]
    let y = y0 + slope * (l.stem_x + thick / 2.0 - x0)
    l.stem_y1 = y
    if l.stem {
      drawing.rect(
        l.stem_x,
        Double::min(l.stem_y0, y),
        thick,
        (y - l.stem_y0).abs(),
      )
    }
  }
  draw_beam_segment(
    drawing,
    first.stem_x,
    last.stem_x + thick,
    0,
    gap,
    beam_thick,
    x0,
    y0,
    slope,
    up,
  )
  let hook = 1.1 * scale
  for level in 1..<beams {
    let mut i = 0
    while i < indices.length() {
      if events[indices[i]].kind - 3 <= level {
        i += 1
        continue
      }
      let mut j = i
      while j + 1 < indices.length() && events[indices[j + 1]].kind - 3 > level {
        j += 1
      }
      if j > i {
        draw_beam_segment(
          drawing,
          layouts[indices[i]].stem_x,
          layouts[indices[j]].stem_x + thick,
          level,
          gap,
          beam_thick,
          x0,
          y0,
          slope,
          up,
        )
      } else if i == 0 {
        let left = layouts[indices[i]].stem_x
        draw_beam_segment(
          drawing,
          left,
          left + hook,
          level,
          gap,
          beam_thick,
          x0,
          y0,
          slope,
          up,
        )
      } else {
        let right = layouts[indices[i]].stem_x + thick
        draw_beam_segment(
          drawing,
          right - hook,
          right,
          level,
          gap,
          beam_thick,
          x0,
          y0,
          slope,
          up,
        )
      }
      i = j + 1
    }
  }
}

///|
fn draw_beam_segment(
  drawing : MusicDrawing,
  xa : Double,
  xb : Double,
  level : Int32,
  gap : Double,
  thick : Double,
  x0 : Double,
  y0 : Double,
  slope : Double,
  up : Bool,
) -> Unit {
  let offset = level.to_double() * gap
  let ya = y0 + slope * (xa - x0)
  let yb = y0 + slope * (xb - x0)
  if up {
    drawing.fill(
      music_quad(
        xa,
        ya + offset,
        xb,
        yb + offset,
        xb,
        yb + offset + thick,
        xa,
        ya + offset + thick,
      ),
    )
  } else {
    drawing.fill(
      music_quad(
        xa,
        ya - offset,
        xb,
        yb - offset,
        xb,
        yb - offset - thick,
        xa,
        ya - offset - thick,
      ),
    )
  }
}
