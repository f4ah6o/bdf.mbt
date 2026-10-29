///|
fn tie_side(
  item : StaffPlacedEvent,
  layout : NoteLayout,
  head_index : Int32,
  voices : Int32,
) -> Double {
  if voices > 1 {
    return if item.event.voice % 2 == 1 { -1.0 } else { 1.0 }
  }
  let n = layout.heads.length()
  if n > 1 {
    if 2 * head_index + 1 < n {
      return 1.0
    }
    if 2 * head_index + 1 > n {
      return -1.0
    }
  }
  if layout.up {
    1.0
  } else {
    -1.0
  }
}

///|
fn same_pitch(a : Pitch, b : Pitch) -> Bool {
  a.step == b.step && a.alter == b.alter && a.octave == b.octave
}

///|
fn draw_tie(
  drawing : MusicDrawing,
  x0 : Double,
  y : Double,
  x1 : Double,
  side : Double,
) -> Unit {
  drawing.fill(
    music_curve(
      x0,
      y,
      x1,
      y,
      side * Double::min(0.2 + 0.06 * (x1 - x0), 0.9),
      0.1,
      0.22,
    ),
  )
}

///|
/// Draw note ties, including halves crossing system boundaries.
pub fn draw_staff_ties(
  layout : BasicStaffLayout,
  prepared : PreparedScore,
  system : MusicSystem,
  staff : Int32,
) -> Unit {
  let items = layout.events
  let drawing = layout.drawing
  let ended : Map[String, Bool] = Map([])
  for i, item in items {
    if item.event.rest {
      continue
    }
    let l = item.note_layout.unwrap()
    for hi, head in l.heads {
      let note = item.event.notes[head.note]
      if !note.tie_start {
        continue
      }
      let side = tie_side(
        item,
        l,
        hi,
        prepared.measures[item.measure][staff].voices,
      )
      let x0 = head.x + glyph_advance(head.glyph) + 0.12
      let y0 = head.position.to_double() / 2.0 + side * 0.5
      let mut found = false
      for j in (i + 1)..<items.length() {
        let later = items[j]
        if later.event.rest {
          continue
        }
        let next = later.note_layout.unwrap()
        for target in next.heads {
          let target_note = later.event.notes[target.note]
          let id = "\{j},\{target.note}"
          if target_note.tie_stop &&
            same_pitch(note.pitch, target_note.pitch) &&
            !ended.contains(id) {
            ended[id] = true
            let x1 = Double::max(target.x - 0.12, x0 + 0.6)
            draw_tie(drawing, x0, y0, x1, side)
            found = true
            break
          }
        }
        if found ||
          (
            later.event.voice == item.event.voice &&
            later.event.offset > item.event.offset &&
            later.measure > item.measure + 1
          ) {
          break
        }
      }
      if !found && item.measure == system.last {
        let x1 = system.width - 0.3
        if x1 > x0 + 0.3 {
          draw_tie(drawing, x0, y0, x1, side)
        }
      }
    }
  }
  if system.first > 0 {
    for i, item in items {
      if item.event.rest || item.measure != system.first {
        continue
      }
      let l = item.note_layout.unwrap()
      for hi, head in l.heads {
        let note = item.event.notes[head.note]
        let id = "\{i},\{head.note}"
        if note.tie_stop && !ended.contains(id) {
          let x0 = system.header - 0.5
          let x1 = head.x - 0.12
          let side = tie_side(
            item,
            l,
            hi,
            prepared.measures[item.measure][staff].voices,
          )
          let y = head.position.to_double() / 2.0 + side * 0.5
          if x1 > x0 + 0.3 {
            draw_tie(drawing, x0, y, x1, side)
          }
          ended[id] = true
        }
      }
    }
  }
}

///|
fn placed_x(item : StaffPlacedEvent) -> Double {
  match item.rest_layout {
    Some(rest) => rest.x
    None => item.x
  }
}

///|
fn placed_right(item : StaffPlacedEvent) -> Double {
  match item.rest_layout {
    Some(rest) => rest.right
    None => item.note_layout.unwrap().right
  }
}

///|
fn placed_top(item : StaffPlacedEvent) -> Double {
  match item.rest_layout {
    Some(rest) => rest.top
    None => item.note_layout.unwrap().top
  }
}

///|
fn placed_bottom(item : StaffPlacedEvent) -> Double {
  match item.rest_layout {
    Some(rest) => rest.bottom
    None => item.note_layout.unwrap().bottom
  }
}

///|
/// Draw the number and bracket for each notated triplet in a system.
pub fn draw_staff_tuplets(
  layout : BasicStaffLayout,
  prepared : PreparedScore,
  staff : Int32,
) -> Unit {
  let groups : Map[String, Array[Int32]] = Map([])
  let order : Array[String] = []
  for i, item in layout.events {
    match item.event.tuplet_beat {
      None => ()
      Some(beat) => {
        let id = "\{item.measure},\{item.event.voice},\{beat}"
        let list = match groups.get(id) {
          Some(list) => list
          None => {
            let list : Array[Int32] = []
            groups[id] = list
            order.push(id)
            list
          }
        }
        list.push(i)
      }
    }
  }
  for id in order {
    let indices = groups[id]
    let first = layout.events[indices[0]]
    let last = layout.events[indices[indices.length() - 1]]
    let mut up = 0
    let mut down = 0
    let mut beam : Int32? = None
    let mut one_beam = true
    for i, index in indices {
      let item = layout.events[index]
      if item.event.rest {
        one_beam = false
        continue
      }
      let l = item.note_layout.unwrap()
      if l.stem {
        if l.up {
          up += 1
        } else {
          down += 1
        }
      }
      if i == 0 || item.beam != beam {
        if i > 0 {
          one_beam = false
        }
        beam = item.beam
      }
    }
    if beam is None {
      one_beam = false
    }
    let mut above = down == 0 || (up > 0 && up >= down)
    if prepared.measures[first.measure][staff].voices > 1 {
      above = first.event.voice % 2 == 1
    }
    let x0 = placed_x(first)
    let mut x1 = placed_right(last)
    if !last.event.rest {
      let l = last.note_layout.unwrap()
      if l.stem && l.up {
        x1 = Double::max(x1, l.stem_x + 0.12)
      }
    }
    let mut y = if above { 0.0 } else { 4.0 }
    for index in indices {
      let item = layout.events[index]
      if above {
        y = Double::min(y, placed_top(item))
        match item.note_layout {
          Some(l) if l.stem && l.up => y = Double::min(y, l.stem_y1 - 0.5)
          _ => ()
        }
      } else {
        y = Double::max(y, placed_bottom(item))
        match item.note_layout {
          Some(l) if l.stem && !l.up => y = Double::max(y, l.stem_y1 + 0.5)
          _ => ()
        }
      }
    }
    y += if above { -1.0 } else { 1.0 }
    let width = glyph_advance("tuplet3")
    let center = (x0 + x1) / 2.0
    layout.drawing.glyph("tuplet3", center - width / 2.0, y + 0.7, 1.0)
    if !one_beam {
      let hook = if above { 0.6 } else { -0.6 }
      let left = center - width / 2.0 - 0.3
      let right = center + width / 2.0 + 0.3
      layout.drawing.line(x0, y + hook, x0, y, 0.16, 0.0)
      layout.drawing.line(x0, y, left, y, 0.16, 0.0)
      layout.drawing.line(right, y, x1, y, 0.16, 0.0)
      layout.drawing.line(x1, y, x1, y + hook, 0.16, 0.0)
    }
  }
}
