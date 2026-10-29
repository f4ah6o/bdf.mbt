///|
/// Horizontal spacing requirements at one onset, in staff spaces.
pub(all) struct MusicSlot {
  offset : Int64
  duration : Int64
  pre : Double
  head : Double
  post : Double
  lyric : Double
  ideal : Double
  minimum : Double
}

///|
/// Horizontal layout requirements for a measure.
pub(all) struct MusicColumn {
  index : Int32
  header : Double
  lead : Double
  slots : Array[MusicSlot]
}

///|
priv struct MutableSlot {
  offset : Int64
  mut duration : Int64
  mut pre : Double
  mut head : Double
  mut post : Double
  mut lyric : Double
  mut ideal : Double
  mut minimum : Double
}

///|
fn glyph_advance(name : String) -> Double {
  match music_glyph(name) {
    Some(glyph) => glyph.advance
    None => 0.0
  }
}

///|
fn key_width(key : KeySig) -> Double {
  let count = if key.fifths < 0 { -key.fifths } else { key.fifths }
  if count == 0 {
    return 0.0
  }
  let name = if key.fifths < 0 { "accidentalFlat" } else { "accidentalSharp" }
  count.to_double() * (glyph_advance(name) + 0.1) + 0.6
}

///|
fn cancel_width(previous : KeySig, next : KeySig) -> Double {
  let n = cancelled_accidentals(previous, next)
  if n == 0 {
    0.0
  } else {
    n.to_double() * (glyph_advance("accidentalNatural") + 0.1) + 0.4
  }
}

///|
fn time_width(time : TimeSig) -> Double {
  if time.symbol == "common" || time.symbol == "cut" {
    return glyph_advance("timeSigCommon") + 0.8
  }
  let mut widest = 0.0
  for value in [time.beats, time.beat_type] {
    let mut width = 0.0
    for c in value.to_string() {
      width += glyph_advance("timeSig" + c.to_string())
    }
    widest = Double::max(widest, width)
  }
  widest + 0.8
}

///|
fn accidental_name(sign : Int32) -> String {
  match sign {
    2 => "accidentalSharp"
    3 => "accidentalFlat"
    5 => "accidentalDoubleSharp"
    6 => "accidentalDoubleFlat"
    _ => "accidentalNatural"
  }
}

///|
fn event_widths(
  staff : PreparedStaffMeasure,
  event : ScoreEvent,
  signs : Array[Int32?],
) -> (Double, Double, Double) {
  if event.rest {
    let rest_names = [
      "restDoubleWhole", "restWhole", "restHalf", "restQuarter", "rest8th", "rest16th",
      "rest32nd", "rest64th", "rest128th",
    ]
    let kind = if event.measure_rest {
      1
    } else {
      Int32::min(Int32::max(event.kind, 0), 8)
    }
    return (0.0, glyph_advance(rest_names[kind]), event.dots.to_double() * 0.5)
  }
  if event.notes.is_empty() {
    return (0.0, 0.0, 0.0)
  }
  let head = event.notes[0].head
  let name = if head == 1 {
    if event.kind <= 1 {
      "noteheadXWhole"
    } else if event.kind == 2 {
      "noteheadXHalf"
    } else {
      "noteheadXBlack"
    }
  } else if event.kind == 0 {
    "noteheadDoubleWhole"
  } else if event.kind == 1 {
    "noteheadWhole"
  } else if event.kind == 2 {
    "noteheadHalf"
  } else {
    "noteheadBlack"
  }
  let mut width = glyph_advance(name)
  let mut acc_width = 0.0
  let engraving : Array[EngravingNote] = []
  let positions : Array[Int32] = []
  for i, note in event.notes {
    engraving.push({
      pitch: note.pitch,
      accidental: 0,
      cautionary: false,
      tie_stop: note.tie_stop,
    })
    positions.push(staff_position(staff.clef, note.pitch))
    match signs[i] {
      Some(sign) if sign != 1 =>
        acc_width = Double::max(acc_width, glyph_advance(accidental_name(sign)))
      _ => ()
    }
  }
  let mut pre = 0.0
  if acc_width > 0.0 {
    let placed = place_accidentals(staff.clef, engraving, signs)
    let mut cols = 0
    for p in placed {
      cols = Int32::max(cols, p.column + 1)
    }
    pre = (acc_width + 0.2) * Int32::max(cols, 1).to_double()
  }
  positions.sort()
  for i in 1..<positions.length() {
    if positions[i] - positions[i - 1] == 1 {
      width *= 2.0
      break
    }
  }
  let mut post = if event.dots > 0 {
    0.3 + 0.5 * event.dots.to_double()
  } else {
    0.0
  }
  if event.kind >= 4 {
    post = Double::max(post, 0.8)
  }
  (pre, width, post)
}

///|
/// Compute measure columns. `lyric_width` measures a text line in staff
/// spaces at the score's lyric font size.
pub fn build_columns(
  score : NotatedScore,
  prepared : PreparedScore,
  lyric_width : (String) -> Double,
) -> Array[MusicColumn] {
  let columns : Array[MusicColumn] = []
  for mi, measure in score.timeline.measures {
    let row = prepared.measures[mi]
    let mut header = 0.0
    for staff in row {
      let width = if staff.key_change {
        cancel_width(staff.previous_key, staff.key) + key_width(staff.key)
      } else {
        0.0
      }
      header = Double::max(header, width)
    }
    if mi > 0 && measure.show_time {
      header += time_width(measure.time)
    }
    let offsets : Map[Int64, MutableSlot] = Map([])
    for staff in row {
      for event in staff.events {
        if !offsets.contains(event.offset) {
          offsets[event.offset] = {
            offset: event.offset,
            duration: 0L,
            pre: 0.0,
            head: 0.0,
            post: 0.0,
            lyric: 0.0,
            ideal: 0.0,
            minimum: 0.0,
          }
        }
      }
    }
    if offsets.is_empty() {
      offsets[0L] = {
        offset: 0L,
        duration: 0L,
        pre: 0.0,
        head: 0.0,
        post: 0.0,
        lyric: 0.0,
        ideal: 0.0,
        minimum: 0.0,
      }
    }
    let slots : Array[MutableSlot] = []
    for (_, slot) in offsets {
      slots.push(slot)
    }
    slots.sort_by((a, b) => a.offset.compare(b.offset))
    let length = Int64::max(measure.length, 1L)
    for i, slot in slots {
      let next = if i + 1 < slots.length() {
        slots[i + 1].offset
      } else {
        length
      }
      slot.duration = Int64::max(next - slot.offset, 1L)
    }
    for staff in row {
      for i, event in staff.events {
        let slot = offsets[event.offset]
        let (pre, head, post) = event_widths(staff, event, staff.accidentals[i])
        slot.pre = Double::max(slot.pre, pre)
        slot.head = Double::max(slot.head, head)
        slot.post = Double::max(slot.post, post)
        match event.lyric {
          Some(l) =>
            slot.lyric = Double::max(slot.lyric, lyric_width(l.text) / 2.0)
          None => ()
        }
      }
    }
    let mut shortest = 480L
    for slot in slots {
      shortest = Int64::min(shortest, slot.duration)
    }
    for i, slot in slots {
      slot.ideal = 2.6 +
        1.6 * @math.log2(slot.duration.to_double() / shortest.to_double())
      if slot.head == 0.0 {
        slot.head = 1.18
      }
      slot.minimum = slot.head + slot.post + 0.5
      if i + 1 < slots.length() {
        let next = slots[i + 1]
        slot.minimum += next.pre
        if slot.lyric > 0.0 || next.lyric > 0.0 {
          slot.minimum = Double::max(
            slot.minimum,
            slot.lyric + next.lyric + 0.9,
          )
        }
      } else {
        slot.minimum += 0.6
        if slot.lyric > 0.0 {
          slot.minimum = Double::max(slot.minimum, slot.lyric + 0.4)
        }
      }
      slot.ideal = Double::max(slot.ideal, slot.minimum)
    }
    let first = slots[0]
    let mut lead = 1.0 + first.pre
    if first.lyric > lead + first.head / 2.0 {
      lead = first.lyric - first.head / 2.0
    }
    columns.push({
      index: mi,
      header,
      lead,
      slots: slots.map(s => {
        offset: s.offset,
        duration: s.duration,
        pre: s.pre,
        head: s.head,
        post: s.post,
        lyric: s.lyric,
        ideal: s.ideal,
        minimum: s.minimum,
      }),
    })
  }
  columns
}
