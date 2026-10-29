///|
pub(all) struct TimeChange {
  tick : Int64
  time : TimeSig
}

///|
pub(all) struct KeyChange {
  tick : Int64
  key : KeySig
}

///|
pub(all) struct TempoChange {
  tick : Int64
  bpm : Double
}

///|
pub(all) struct TempoMark {
  offset : Int64
  dots : Int32
  per_minute : Double
}

///|
/// One notated measure on the performance timeline.
pub(all) struct MeasureSpan {
  start : Int64
  length : Int64
  time : TimeSig
  show_time : Bool
  mut key : KeySig?
  mut effective_key : KeySig
  tempo : Array[TempoMark]
}

///|
pub(all) struct ScoreTimeline {
  measures : Array[MeasureSpan]
  warnings : Array[String]
}

///|
fn equal_time(a : TimeSig, b : TimeSig) -> Bool {
  a.beats == b.beats && a.beat_type == b.beat_type && a.symbol == b.symbol
}

///|
fn equal_key(a : KeySig, b : KeySig) -> Bool {
  a.fifths == b.fifths && a.minor == b.minor
}

///|
fn measure_at(measures : Array[MeasureSpan], tick : Int64) -> Int32 {
  let mut lo = 0
  let mut hi = measures.length()
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    if measures[mid].start <= tick {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  Int32::max(lo - 1, 0)
}

///|
/// Construct measure boundaries, key changes, and visible tempo marks.
/// The histogram contains twelve pitch-class duration weights.
pub fn build_timeline(
  end : Int64,
  times : Array[TimeChange],
  keys : Array[KeyChange],
  tempos : Array[TempoChange],
  histogram : Array[Double],
  flats : Int32,
  time_override~ : TimeSig? = None,
  key_override~ : KeySig? = None,
) -> ScoreTimeline {
  let ordered_times : Array[(Int32, TimeChange)] = []
  match time_override {
    Some(time) => ordered_times.push((0, { tick: 0L, time, }))
    None =>
      for i, change in times {
        ordered_times.push((i, change))
      }
  }
  ordered_times.sort_by((a, b) => {
    let cmp = a.1.tick.compare(b.1.tick)
    if cmp != 0 {
      cmp
    } else {
      a.0.compare(b.0)
    }
  })
  let measures : Array[MeasureSpan] = []
  let warnings : Array[String] = []
  let mut current : TimeSig = { beats: 4, beat_type: 4, symbol: "", }
  let mut t = 0L
  let mut ti = 0
  while (t < end || measures.is_empty()) && measures.length() < 20000 {
    let mut changed = measures.is_empty()
    while ti < ordered_times.length() && ordered_times[ti].1.tick <= t {
      let time = ordered_times[ti].1.time
      if time.beats > 0 && time.beat_type > 0 {
        changed = changed || !equal_time(time, current)
        current = time
      }
      ti += 1
    }
    let mut length = current.length().to_int64()
    if ti < ordered_times.length() && ordered_times[ti].1.tick < t + length {
      length = ordered_times[ti].1.tick - t
    }
    measures.push({
      start: t,
      length,
      time: current,
      show_time: changed,
      key: None,
      effective_key: { fifths: 0, minor: false, },
      tempo: [],
    })
    t += length
  }
  if t < end {
    warnings.push(
      "the music is longer than 20000 measures; the rest is left out",
    )
  }
  let ordered_keys : Array[(Int32, KeyChange)] = []
  match key_override {
    Some(key) => ordered_keys.push((0, { tick: 0L, key, }))
    None =>
      if keys.length() > 1 ||
        (
          keys.length() == 1 &&
          (keys[0].key.fifths != 0 || keys[0].key.minor || keys[0].tick != 0L)
        ) {
        for i, change in keys {
          ordered_keys.push((i, change))
        }
        ordered_keys.sort_by((a, b) => {
          let cmp = a.1.tick.compare(b.1.tick)
          if cmp != 0 {
            cmp
          } else {
            a.0.compare(b.0)
          }
        })
      } else {
        ordered_keys.push(
          (0, { tick: 0L, key: estimate_key(histogram, flats), }),
        )
      }
  }
  for (_, change) in ordered_keys {
    let mut i = measure_at(measures, change.tick)
    if measures[i].start < change.tick && i + 1 < measures.length() {
      i += 1
    }
    measures[i].key = Some({
      fifths: Int32::min(7, Int32::max(-7, change.key.fifths)),
      minor: change.key.minor,
    })
  }
  let mut active : KeySig = { fifths: 0, minor: false, }
  for i, measure in measures {
    match measure.key {
      Some(key) =>
        if i > 0 && equal_key(active, key) {
          measure.key = None
        } else {
          active = key
        }
      None => ()
    }
    measure.effective_key = active
  }
  let ordered_tempos : Array[(Int32, TempoChange)] = []
  for i, tempo in tempos {
    ordered_tempos.push((i, tempo))
  }
  ordered_tempos.sort_by((a, b) => {
    let cmp = a.1.tick.compare(b.1.tick)
    if cmp != 0 {
      cmp
    } else {
      a.0.compare(b.0)
    }
  })
  let mut last = 0.0
  let mut last_measure = -1
  for i, pair in ordered_tempos {
    let tempo = pair.1
    if tempo.bpm <= 0.0 {
      continue
    }
    if i + 1 < ordered_tempos.length() &&
      ordered_tempos[i + 1].1.tick - tempo.tick < 960L {
      continue
    }
    if last > 0.0 && (tempo.bpm - last).abs() / last < 0.03 {
      continue
    }
    let m = measure_at(measures, tempo.tick)
    if m == last_measure {
      continue
    }
    let measure = measures[m]
    let (beat, compound) = measure.time.beat()
    let mut offset = tempo.tick - measure.start
    if beat > 0 {
      let grid = beat.to_int64()
      offset = (offset + grid / 2L) / grid * grid
    }
    if offset >= measure.length {
      offset = 0L
    }
    let value = if compound {
      (tempo.bpm / 1.5).round()
    } else {
      tempo.bpm.round()
    }
    measure.tempo.push({
      offset,
      dots: if compound {
        1
      } else {
        0
      },
      per_minute: value,
    })
    last = tempo.bpm
    last_measure = m
  }
  { measures, warnings, }
}
