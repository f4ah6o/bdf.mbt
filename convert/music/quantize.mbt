///|
/// The quantization grid chosen for one beat.
pub(all) struct BeatGrid {
  start : Int64
  length : Int64
  compound : Bool
  grid : Int64
  triplet : Bool
}

///|
/// Snap a tick to this beat's selected grid.
pub fn BeatGrid::snap(self : BeatGrid, tick : Int64) -> Int64 {
  if self.grid <= 0L {
    return tick
  }
  self.start + (tick - self.start + self.grid / 2L) / self.grid * self.grid
}

///|
/// Select the coarsest grid that fits the note onsets in each beat.
pub fn beat_grids(
  measures : Array[MeasureSpan],
  onsets : Array[Int64],
) -> Array[BeatGrid] {
  let beats : Array[BeatGrid] = []
  for measure in measures {
    let (beat, compound) = measure.time.beat()
    if beat <= 0 {
      return []
    }
    let mut pos = 0L
    while pos < measure.length {
      let length = Int64::min(beat.to_int64(), measure.length - pos)
      beats.push({
        start: measure.start + pos,
        length,
        compound,
        grid: 0L,
        triplet: false,
      })
      pos += beat.to_int64()
    }
  }
  let ordered = onsets.copy()
  ordered.sort()
  let mut j = 0
  for i, beat in beats {
    while j < ordered.length() && ordered[j] < beat.start {
      j += 1
    }
    let mut k = j
    while k < ordered.length() && ordered[k] < beat.start + beat.length {
      k += 1
    }
    let cands : Array[(Int64, Bool)] = if beat.compound {
      [
        (beat.length / 3L, false),
        (beat.length / 6L, false),
        (beat.length / 12L, false),
      ]
    } else {
      [
        (beat.length / 2L, false),
        (beat.length / 3L, true),
        (beat.length / 4L, false),
        (beat.length / 6L, true),
        (beat.length / 8L, false),
        (beat.length / 12L, true),
      ]
    }
    let mut best = cands[cands.length() - 1]
    let mut best_err = 9223372036854775807L
    for c in cands {
      if c.0 <= 0L {
        continue
      }
      let mut max_err = 0L
      let mut sum = 0L
      for n in j..<k {
        let rem = (ordered[n] - beat.start) % c.0
        let err = Int64::min(rem, c.0 - rem)
        max_err = Int64::max(max_err, err)
        sum += err
      }
      if max_err <= Int64::min(c.0 / 4L, 40L) {
        best = c
        break
      }
      if sum < best_err {
        best = c
        best_err = sum
      }
    }
    beats[i] = {
      start: beat.start,
      length: beat.length,
      compound: beat.compound,
      grid: best.0,
      triplet: best.1 && best.0 > 0L,
    }
    j = k
  }
  beats
}

///|
fn grid_at(beats : Array[BeatGrid], tick : Int64) -> BeatGrid {
  let mut lo = 0
  let mut hi = beats.length()
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    if beats[mid].start <= tick {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  beats[Int32::min(Int32::max(lo - 1, 0), beats.length() - 1)]
}

///|
/// A performance note before notation.
pub(all) struct NotationNote {
  tick : Int64
  duration : Int64
  key : Int32
  velocity : Int32
  spelling : Int32
}

///|
/// A note after grid snapping and duplicate removal.
pub(all) struct QuantizedNote {
  on : Int64
  off : Int64
  key : Int32
  velocity : Int32
  spelling : Int32
}

///|
priv struct OrderedQuantizedNote {
  note : QuantizedNote
  order : Int32
}

///|
/// Snap and deduplicate notes before staff and voice assignment.
pub fn quantize_notes(
  measures : Array[MeasureSpan],
  notes : Array[NotationNote],
) -> Array[QuantizedNote] {
  if measures.is_empty() {
    return []
  }
  let onsets : Array[Int64] = []
  for n in notes {
    onsets.push(n.tick)
  }
  let beats = beat_grids(measures, onsets)
  if beats.is_empty() {
    return []
  }
  let last = measures[measures.length() - 1]
  let end = last.start + last.length
  let ordered : Array[OrderedQuantizedNote] = []
  for i, n in notes {
    if n.tick >= end || n.key < 0 || n.key > 127 {
      continue
    }
    let on = grid_at(beats, n.tick).snap(n.tick)
    let mut off = grid_at(beats, n.tick + Int64::max(n.duration, 1L)).snap(
      n.tick + Int64::max(n.duration, 1L),
    )
    if off <= on {
      off = on + Int64::max(grid_at(beats, on).grid, 1L)
    }
    off = Int64::min(off, end)
    if on >= end {
      continue
    }
    ordered.push({
      note: { on, off, key: n.key, velocity: n.velocity, spelling: n.spelling, },
      order: i,
    })
  }
  ordered.sort_by((a, b) => {
    let on = a.note.on.compare(b.note.on)
    let key = b.note.key.compare(a.note.key)
    if on != 0 {
      on
    } else if key != 0 {
      key
    } else {
      a.order.compare(b.order)
    }
  })
  let out : Array[QuantizedNote] = []
  for entry in ordered {
    let note = entry.note
    if out.is_empty() ||
      out[out.length() - 1].on != note.on ||
      out[out.length() - 1].key != note.key {
      out.push(note)
    }
  }
  out
}
