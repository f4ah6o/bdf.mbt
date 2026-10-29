///|
/// A positioned onset in a measure.
pub(all) struct PositionedSlot {
  slot : MusicSlot
  x : Double
}

///|
/// A measure positioned within a system.
pub(all) struct PositionedColumn {
  index : Int32
  x : Double
  width : Double
  body_start : Double
  slots : Array[PositionedSlot]
}

///|
/// A justified system of consecutive measures.
pub(all) struct MusicSystem {
  first : Int32
  last : Int32
  header : Double
  width : Double
  columns : Array[PositionedColumn]
}

///|
priv struct PendingSystem {
  first : Int32
  last : Int32
  header : Double
  width : Double
}

///|
fn clef_name(clef : EngravingClef) -> String {
  match clef.sign {
    1 => if clef.octave == -1 { "fClef8vb" } else { "fClef" }
    2 => "cClef"
    3 => "unpitchedPercussionClef1"
    4 => "6stringTabClef"
    5 => ""
    _ =>
      if clef.octave == -1 {
        "gClef8vb"
      } else if clef.octave == 1 {
        "gClef8va"
      } else {
        "gClef"
      }
  }
}

///|
fn system_header(
  score : NotatedScore,
  prepared : PreparedScore,
  mi : Int32,
  first : Bool,
) -> Double {
  let mut width = 0.0
  for staff in prepared.measures[mi] {
    let name = clef_name(staff.clef)
    let clef_width = if name == "" { 0.8 } else { 1.6 + glyph_advance(name) }
    width = Double::max(width, clef_width + key_width(staff.key))
  }
  if first || score.timeline.measures[mi].show_time {
    width += time_width(prepared.times[mi])
  }
  width
}

///|
fn measure_width(
  columns : Array[MusicColumn],
  total : Int32,
  mi : Int32,
  starts : Bool,
) -> (Double, Double) {
  let col = columns[mi]
  let mut fixed = col.lead + 0.2 + (if mi == total - 1 { 0.9 } else { 0.2 })
  if !starts {
    fixed += col.header
  }
  let mut ideal = 0.0
  for slot in col.slots {
    ideal += slot.ideal
  }
  (fixed, ideal)
}

///|
fn spring_total(slots : Array[MusicSlot], factor : Double) -> Double {
  let mut total = 0.0
  for slot in slots {
    total += Double::max(slot.minimum, slot.ideal * factor)
  }
  total
}

///|
/// Break and justify MIDI-derived score measures into systems. Width and
/// first_indent are in staff spaces.
pub fn break_systems(
  score : NotatedScore,
  prepared : PreparedScore,
  columns : Array[MusicColumn],
  width : Double,
  first_indent : Double,
) -> Array[MusicSystem] {
  let pending : Array[PendingSystem] = []
  let mut mi = 0
  let count = score.timeline.measures.length()
  while mi < count {
    let first = pending.is_empty()
    let available = if first { width - first_indent } else { width }
    let header = system_header(score, prepared, mi, first)
    let mut used = header
    let mut last = mi
    for k in mi..<count {
      let (fixed, ideal) = measure_width(columns, count, k, k == mi)
      if k > mi && used + fixed + ideal > available {
        break
      }
      used += fixed + ideal
      last = k
    }
    pending.push({ first: mi, last, header, width: available, })
    mi = last + 1
  }
  let result : Array[MusicSystem] = []
  for index, system in pending {
    let last_system = index == pending.length() - 1
    let mut fixed = system.header
    let springs : Array[MusicSlot] = []
    for m in system.first..<=system.last {
      let (space, _) = measure_width(columns, count, m, m == system.first)
      fixed += space
      for slot in columns[m].slots {
        springs.push(slot)
      }
    }
    let target = system.width - fixed
    let natural = spring_total(springs, 1.0)
    let mut factor = 1.0
    if !last_system || natural > target * 0.8 {
      let mut low = 0.0
      let mut high = 1.0
      while spring_total(springs, high) < target && high < 64.0 {
        high *= 2.0
      }
      for _ in 0..<50 {
        let mid = (low + high) / 2.0
        if spring_total(springs, mid) < target {
          low = mid
        } else {
          high = mid
        }
      }
      factor = high
    }
    let positioned : Array[PositionedColumn] = []
    let mut x = system.header
    for m in system.first..<=system.last {
      let col = columns[m]
      let body_start = 0.2 + (if m != system.first { col.header } else { 0.0 })
      let mut sx = body_start + col.lead
      let slot_positions : Array[PositionedSlot] = []
      for slot in col.slots {
        slot_positions.push({ slot, x: sx, })
        sx += Double::max(slot.minimum, slot.ideal * factor)
      }
      let col_width = sx + (if m == count - 1 { 0.9 } else { 0.2 })
      positioned.push({
        index: m,
        x,
        width: col_width,
        body_start,
        slots: slot_positions,
      })
      x += col_width
    }
    result.push({
      first: system.first,
      last: system.last,
      header: system.header,
      width: x,
      columns: positioned,
    })
  }
  result
}
