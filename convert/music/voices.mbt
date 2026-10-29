///|
/// A quantized note and its preferred percussion voice, when applicable.
pub(all) struct VoiceNote {
  note : QuantizedNote
  voice_hint : Int32
}

///|
/// Notes beginning together and assigned to one voice.
pub(all) struct VoiceChord {
  on : Int64
  mut off : Int64
  notes : Array[VoiceNote]
}

///|
priv struct VoiceAverage {
  sum : Array[Int64]
  count : Array[Int32]
}

///|
/// Group quantized notes into at most two voices on one staff.
pub fn assign_voices(
  input : Array[VoiceNote],
  measures : Array[MeasureSpan],
  beats : Array[BeatGrid],
  percussion : Bool,
) -> Array[Array[VoiceChord]] {
  let voices : Array[Array[VoiceChord]] = [[], []]
  if input.is_empty() || measures.is_empty() || beats.is_empty() {
    return voices
  }
  let notes : Array[VoiceNote] = []
  for i, entry in input {
    let note = entry.note
    let mut off = note.off
    if !percussion {
      for j in (i + 1)..<input.length() {
        let next = input[j].note
        if next.on > note.on {
          let overlap = off - next.on
          if overlap > 0L &&
            overlap <=
            Int64::max(grid_at(beats, note.on).grid, (off - note.on) / 4L) {
            off = next.on
          }
          break
        }
      }
    }
    notes.push({
      note: {
        on: note.on,
        off,
        key: note.key,
        velocity: note.velocity,
        spelling: note.spelling,
      },
      voice_hint: entry.voice_hint,
    })
  }
  let chords : Array[VoiceChord] = []
  for entry in notes {
    let note = entry.note
    if !chords.is_empty() {
      let last = chords[chords.length() - 1]
      if last.on == note.on &&
        last.off == note.off &&
        last.notes[0].voice_hint == entry.voice_hint {
        last.notes.push(entry)
        continue
      }
    }
    chords.push({ on: note.on, off: note.off, notes: [entry], })
  }
  let busy : Array[Int64] = [0L, 0L]
  for chord in chords {
    let pref = if chord.notes[0].voice_hint == 2 { [1, 0] } else { [0, 1] }
    let mut placed = false
    for v in pref {
      if busy[v] <= chord.on {
        voices[v].push(chord)
        busy[v] = chord.off
        placed = true
        break
      }
    }
    if placed {
      continue
    }
    let mut joined = false
    for v in 0..<2 {
      let list = voices[v]
      if !list.is_empty() && list[list.length() - 1].on == chord.on {
        let last = list[list.length() - 1]
        for note in chord.notes {
          last.notes.push(note)
        }
        last.off = Int64::max(last.off, chord.off)
        busy[v] = last.off
        joined = true
        break
      }
    }
    if joined {
      continue
    }
    let v = pref[0]
    let list = voices[v]
    if list.is_empty() {
      continue
    }
    list[list.length() - 1].off = chord.on
    list.push(chord)
    busy[v] = chord.off
  }
  if voices[1].is_empty() || percussion {
    return voices
  }
  let averages : Map[Int32, VoiceAverage] = Map([])
  for v in 0..<2 {
    for chord in voices[v] {
      let m = measure_at(measures, chord.on)
      let a = match averages.get(m) {
        Some(a) => a
        None => {
          let a : VoiceAverage = { sum: [0L, 0L], count: [0, 0], }
          averages[m] = a
          a
        }
      }
      for note in chord.notes {
        a.sum[v] += note.note.key.to_int64()
        a.count[v] += 1
      }
    }
  }
  let swap : Map[Int32, Bool] = Map([])
  for (m, a) in averages {
    if a.count[0] > 0 &&
      a.count[1] > 0 &&
      a.sum[1].to_double() / a.count[1].to_double() >
      a.sum[0].to_double() / a.count[0].to_double() {
      swap[m] = true
    }
  }
  if swap.is_empty() {
    return voices
  }
  let sorted : Array[Array[(Int32, VoiceChord)]] = [[], []]
  let mut order = 0
  for v in 0..<2 {
    for chord in voices[v] {
      let target = if swap.contains(measure_at(measures, chord.on)) {
        1 - v
      } else {
        v
      }
      sorted[target].push((order, chord))
      order += 1
    }
  }
  let result : Array[Array[VoiceChord]] = [[], []]
  for v in 0..<2 {
    sorted[v].sort_by((a, b) => {
      let cmp = a.1.on.compare(b.1.on)
      if cmp != 0 {
        cmp
      } else {
        a.0.compare(b.0)
      }
    })
    for (_, chord) in sorted[v] {
      result[v].push(chord)
    }
  }
  result
}
