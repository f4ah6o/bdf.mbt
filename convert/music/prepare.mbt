///|
/// A staff's location in the original part and its staff number.
pub(all) struct StaffReference {
  part : Int32
  staff : Int32
}

///|
/// Events and accidental signs resolved for one staff of one measure.
pub(all) struct PreparedStaffMeasure {
  clef : EngravingClef
  clef_change : Bool
  key : KeySig
  previous_key : KeySig
  key_change : Bool
  events : Array[ScoreEvent]
  accidentals : Array[Array[Int32?]]
  voices : Int32
}

///|
/// Score state resolved for measure and staff layout.
pub(all) struct PreparedScore {
  staves : Array[StaffReference]
  grand : Bool
  starts : Array[Int64]
  times : Array[TimeSig]
  counts : Array[Int32]
  measures : Array[Array[PreparedStaffMeasure]]
}

///|
/// Resolve clefs, key changes, sorted events and accidentals for drawing.
pub fn prepare_score(score : NotatedScore) -> PreparedScore {
  let staves : Array[StaffReference] = []
  let mut grand = false
  for i, part in score.parts {
    for staff in 0..<Int32::max(part.clefs.length(), 1) {
      staves.push({ part: i, staff, })
    }
    if part.clefs.length() > 1 {
      grand = true
    }
  }
  let starts : Array[Int64] = [0L]
  let times : Array[TimeSig] = []
  let counts : Array[Int32] = []
  let mut total = 0L
  for i, measure in score.timeline.measures {
    total += measure.length
    starts.push(total)
    times.push(measure.time)
    counts.push(i + 1)
  }
  let keys : Array[KeySig] = []
  for _ in score.parts {
    keys.push({ fifths: 0, minor: false, })
  }
  let rows : Array[Array[PreparedStaffMeasure]] = []
  for mi, _ in score.timeline.measures {
    let old = keys.copy()
    for pi, part in score.parts {
      if mi < part.measures.length() {
        match part.measures[mi].key {
          Some(key) => keys[pi] = key
          None => ()
        }
      }
    }
    let row : Array[PreparedStaffMeasure] = []
    for staff_ref in staves {
      let part = score.parts[staff_ref.part]
      let chosen = if staff_ref.staff < part.clefs.length() {
        part.clefs[staff_ref.staff]
      } else {
        {
          sign: if part.percussion {
            3
          } else if staff_ref.staff == 1 {
            1
          } else {
            0
          },
          octave: 0,
        }
      }
      let clef : EngravingClef = {
        sign: chosen.sign,
        line: 0,
        octave: chosen.octave,
      }
      let key = if part.percussion {
        { fifths: 0, minor: false, }
      } else {
        keys[staff_ref.part]
      }
      let previous_key = if part.percussion {
        { fifths: 0, minor: false, }
      } else {
        old[staff_ref.part]
      }
      let key_change = !part.percussion &&
        mi > 0 &&
        !equal_key(key, previous_key)
      let ordered : Array[(Int32, ScoreEvent)] = []
      if mi < part.measures.length() {
        for i, event in part.measures[mi].events {
          if event.staff == staff_ref.staff ||
            (
              event.staff >= Int32::max(part.clefs.length(), 1) &&
              staff_ref.staff == 0
            ) {
            ordered.push((i, event))
          }
        }
      }
      ordered.sort_by((a, b) => {
        let offset = a.1.offset.compare(b.1.offset)
        let voice = a.1.voice.compare(b.1.voice)
        if offset != 0 {
          offset
        } else if voice != 0 {
          voice
        } else {
          a.0.compare(b.0)
        }
      })
      let events : Array[ScoreEvent] = []
      let engraving : Array[EngravingEvent] = []
      let seen : Map[Int32, Bool] = Map([])
      for (_, event) in ordered {
        events.push(event)
        if !(event.rest && event.measure_rest && !seen.is_empty()) {
          seen[event.voice] = true
        }
        let notes : Array[EngravingNote] = []
        for n in event.notes {
          notes.push({
            pitch: n.pitch,
            accidental: 0,
            cautionary: false,
            tie_stop: n.tie_stop,
          })
        }
        engraving.push({
          offset: event.offset,
          voice: event.voice,
          grace: false,
          notes,
        })
      }
      row.push({
        clef,
        clef_change: false,
        key,
        previous_key,
        key_change,
        events,
        accidentals: resolve_accidentals(key, engraving),
        voices: seen.length(),
      })
    }
    rows.push(row)
  }
  { staves, grand, starts, times, counts, measures: rows, }
}
