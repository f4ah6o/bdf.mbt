///|
/// One placed score event within a staff system.
pub(all) struct StaffPlacedEvent {
  measure : Int32
  staff_event : Int32
  event : ScoreEvent
  x : Double
  mut note_layout : NoteLayout?
  rest_layout : RestLayout?
  mut beam : Int32?
}

///|
/// Staff drawing and event placements before ties, tuplets and text.
pub(all) struct BasicStaffLayout {
  drawing : MusicDrawing
  events : Array[StaffPlacedEvent]
}

///|
priv struct StaffBeam {
  indices : Array[Int32]
  up : Bool
}

///|
fn draw_note_dots(
  drawing : MusicDrawing,
  event : ScoreEvent,
  layout : NoteLayout,
  scale : Double,
) -> Unit {
  if event.dots <= 0 || layout.heads.is_empty() {
    return
  }
  let mut x = layout.right + 0.3 * scale
  if layout.up && layout.flags > 0 {
    x = Double::max(x, layout.stem_x + 0.9 * scale)
  }
  let seen : Map[Int32, Bool] = Map([])
  for head in layout.heads {
    let mut pos = head.position
    if pos % 2 == 0 {
      if layout.up || event.voice % 2 == 1 {
        pos -= 1
      } else {
        pos += 1
      }
    }
    if seen.contains(pos) {
      continue
    }
    seen[pos] = true
    for i in 0..<event.dots {
      drawing.glyph(
        "augmentationDot",
        x + 0.5 * scale * i.to_double(),
        pos.to_double() / 2.0,
        scale,
      )
    }
  }
}

///|
/// Lay out a system staff through noteheads, stems, beams and augmentation
/// dots. Ties, tuplets, text and system-level marks are added separately.
pub fn layout_basic_staff(
  score : NotatedScore,
  prepared : PreparedScore,
  system : MusicSystem,
  staff : Int32,
) -> BasicStaffLayout {
  let drawing = staff_header(score, prepared, system, staff)
  let items : Array[StaffPlacedEvent] = []
  for mi in system.first..<=system.last {
    staff_measure_header(drawing, score, prepared, system, staff, mi)
    let col = system.columns[mi - system.first]
    let sm = prepared.measures[mi][staff]
    for index, event in sm.events {
      for slot in col.slots {
        if slot.slot.offset != event.offset {
          continue
        }
        let x = col.x + slot.x
        let rest = if event.rest {
          Some(
            draw_staff_rest(
              drawing, score, prepared, system, staff, mi, event, x,
            ),
          )
        } else {
          None
        }
        items.push({
          measure: mi,
          staff_event: index,
          event,
          x,
          note_layout: None,
          rest_layout: rest,
          beam: None,
        })
        break
      }
    }
  }
  let order : Array[(Int32, Int32)] = []
  let lists : Map[String, Array[Int32]] = Map([])
  for index, item in items {
    if item.event.rest {
      continue
    }
    let id = "\{item.measure},\{item.event.voice}"
    let list = match lists.get(id) {
      Some(list) => list
      None => {
        let list : Array[Int32] = []
        lists[id] = list
        order.push((item.measure, item.event.voice))
        list
      }
    }
    list.push(index)
  }
  let beams : Array[StaffBeam] = []
  for (mi, voice) in order {
    let ids = lists["\{mi},\{voice}"]
    let events = ids.map(i => items[i].event)
    for
      group in beam_groups(
        prepared.times[mi],
        prepared.measures[mi][staff],
        events,
      ) {
      let indices = group.indices.map(i => ids[i])
      let id = beams.length()
      for i in indices {
        items[i].beam = Some(id)
      }
      beams.push({ indices, up: group.up, })
    }
  }
  for item in items {
    if item.event.rest {
      continue
    }
    let sm = prepared.measures[item.measure][staff]
    let direction = match item.beam {
      Some(id) => Some(beams[id].up)
      None => None
    }
    item.note_layout = Some(
      arrange_staff_note(
        drawing,
        sm,
        item.event,
        sm.accidentals[item.staff_event],
        item.x,
        1.0,
        beam_direction=direction,
        beamed=item.beam is Some(_),
      ),
    )
  }
  let drawn : Map[Int32, Bool] = Map([])
  for item in items {
    if item.event.rest {
      continue
    }
    match item.beam {
      None => draw_isolated_stem(drawing, item.note_layout.unwrap(), 1.0)
      Some(id) =>
        if !drawn.contains(id) {
          drawn[id] = true
          let beam = beams[id]
          let selected : Array[ScoreEvent] = []
          let layouts : Array[NoteLayout] = []
          let indices : Array[Int32] = []
          for i in beam.indices {
            indices.push(selected.length())
            selected.push(items[i].event)
            layouts.push(items[i].note_layout.unwrap())
          }
          draw_beam(drawing, selected, layouts, indices, beam.up, 1.0)
        }
    }
  }
  for item in items {
    if !item.event.rest {
      draw_note_dots(drawing, item.event, item.note_layout.unwrap(), 1.0)
    }
  }
  { drawing, events: items, }
}
