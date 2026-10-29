///|
/// TAB onsets and stable note IDs for a score part. The IDs correspond to
/// `note_ids[measure][event][note]` for use while drawing the same score.
pub(all) struct GuitarScoreOnsets {
  onsets : Array[GuitarOnset]
  note_ids : Array[Array[Array[Int32]]]
}

///|
/// Collect a MIDI-derived part's notes in absolute onset order.
pub fn guitar_score_onsets(
  score : NotatedScore,
  part : Int32,
) -> GuitarScoreOnsets {
  let grouped : Map[Int64, Array[GuitarNote]] = Map([])
  let ticks : Array[Int64] = []
  let ids : Array[Array[Array[Int32]]] = []
  let mut id = 0
  let selected = score.parts[part]
  for mi, measure in score.timeline.measures {
    let row : Array[Array[Int32]] = []
    if mi < selected.measures.length() {
      for event in selected.measures[mi].events {
        let event_ids : Array[Int32] = []
        if !event.rest {
          let tick = measure.start + event.offset
          for note in event.notes {
            let step = (note.pitch.step % 7 + 7) % 7
            let pitch = (note.pitch.octave + 1) * 12 +
              [0, 2, 4, 5, 7, 9, 11][step] +
              note.pitch.alter
            let group = match grouped.get(tick) {
              Some(group) => group
              None => {
                let group : Array[GuitarNote] = []
                grouped[tick] = group
                ticks.push(tick)
                group
              }
            }
            group.push({
              id,
              pitch,
              end: tick + Int64::max(event.duration, 1L),
              authored: None,
            })
            event_ids.push(id)
            id += 1
          }
        }
        row.push(event_ids)
      }
    }
    ids.push(row)
  }
  ticks.sort()
  { onsets: ticks.map(tick => { tick, notes: grouped[tick], }), note_ids: ids, }
}
