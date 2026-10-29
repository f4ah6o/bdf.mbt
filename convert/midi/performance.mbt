///|
/// One performed note in 960-tick quarter-note units.
pub(all) struct MidiPlayNote {
  tick : Int64
  duration : Int64
  key : Int32
  velocity : Int32
}

///|
pub(all) struct MidiPlayControl {
  tick : Int64
  kind : Int32
  number : Int32
  value : Int32
}

///|
pub(all) struct MidiPerformanceTrack {
  name : String
  channel : Int32
  program : Int32
  volume : Int32
  pan : Int32
  notes : Array[MidiPlayNote]
  controls : Array[MidiPlayControl]
  lyrics : Array[MidiLyric]
  source_track : Int32
}

///|
/// Performed notes, controls, lyrics and timing changes.
pub(all) struct MidiPerformance {
  credits : MidiCredits
  tracks : Array[MidiPerformanceTrack]
  tempos : Array[MidiRawTempo]
  times : Array[MidiRawTime]
  keys : Array[MidiRawKey]
  end : Int64
  division : Int32
  warnings : Array[String]
}

///|
priv struct MidiInitial {
  tick : Int64
  order : Int32
  value : Int32
}

///|
priv struct MidiOrderedNote {
  note : MidiRawNote
  order : Int32
}

///|
fn initial_kind(c : MidiRawControl) -> Int32 {
  if c.kind == 0 {
    0
  } else if c.kind == 1 && c.number == 7 {
    1
  } else if c.kind == 1 && c.number == 10 {
    2
  } else {
    -1
  }
}

///|
fn last_initial(values : Array[MidiInitial], tick : Int64) -> MidiInitial? {
  let mut lo = 0
  let mut hi = values.length()
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    if values[mid].tick <= tick {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  if lo == 0 {
    None
  } else {
    Some(values[lo - 1])
  }
}

///|
/// Convert raw tracks into the upstream performance model.
pub fn performance(file : MidiRawFile) -> MidiPerformance {
  let global : Array[Array[MidiInitial]] = []
  for _ in 0..<48 {
    global.push([])
  }
  let mut order = 0
  for track in file.tracks {
    for c in track.notes.controls {
      let kind = initial_kind(c)
      if kind >= 0 {
        global[c.channel * 3 + kind].push({
          tick: c.tick,
          order,
          value: c.value,
        })
        order += 1
      }
    }
  }
  for list in global {
    list.sort_by((a, b) => {
      let cmp = a.tick.compare(b.tick)
      if cmp != 0 {
        cmp
      } else {
        a.order.compare(b.order)
      }
    })
  }
  let decoder = MidiTextDecoder::new(file)
  let tracks : Array[MidiPerformanceTrack] = []
  let warnings = file.warnings.copy()
  let mut zero = false
  let mut end = 0L
  for index, track in file.tracks {
    end = Int64::max(end, file.header.ppq(track.scan.end_tick))
    let channels : Map[Int32, Bool] = Map([])
    for note in track.notes.notes {
      channels[note.channel] = true
    }
    for channel in 0..<16 {
      let raw : Array[MidiOrderedNote] = []
      for i, note in track.notes.notes {
        if note.channel == channel {
          raw.push({ note, order: i, })
        }
      }
      if raw.is_empty() {
        continue
      }
      raw.sort_by((a, b) => {
        let cmp = a.note.on.compare(b.note.on)
        let key = a.note.key.compare(b.note.key)
        let off = a.note.off.compare(b.note.off)
        if cmp != 0 {
          cmp
        } else if key != 0 {
          key
        } else if off != 0 {
          off
        } else {
          a.order.compare(b.order)
        }
      })
      let notes : Array[MidiPlayNote] = []
      for item in raw {
        let n = item.note
        if n.on == n.off && channel != 9 {
          zero = true
          continue
        }
        let tick = file.header.ppq(n.on)
        let dur = Int64::max(file.header.ppq(n.off) - tick, 1L)
        notes.push({ tick, duration: dur, key: n.key, velocity: n.velocity, })
        end = Int64::max(end, tick + dur)
      }
      if notes.is_empty() {
        continue
      }
      let first = raw[0].note.on
      let values : Array[Int32] = [0, 0, 0]
      let has : Array[Bool] = [false, false, false]
      for c in track.notes.controls {
        if c.channel != channel {
          continue
        }
        if c.tick > first {
          break
        }
        let kind = initial_kind(c)
        if kind >= 0 {
          values[kind] = c.value
          has[kind] = true
        }
      }
      for kind in 0..<3 {
        if !has[kind] {
          match last_initial(global[channel * 3 + kind], first) {
            Some(value) => {
              values[kind] = value.value
              has[kind] = true
            }
            None => ()
          }
        }
      }
      let program = if has[0] && channel != 9 { values[0] } else { 0 }
      let volume = if has[1] { values[1] } else { -1 }
      let pan = if has[2] { values[2] } else { -1 }
      let controls : Array[MidiPlayControl] = []
      for c in track.notes.controls {
        if c.channel == channel {
          controls.push({
            tick: file.header.ppq(c.tick),
            kind: c.kind,
            number: c.number,
            value: c.value,
          })
        }
      }
      let name = track_name_decoded(
        track.notes,
        decoder,
        channel,
        has[0],
        program,
        file.header.format == 0 && index == 0,
        channels.length(),
      )
      tracks.push({
        name,
        channel,
        program,
        volume,
        pan,
        notes,
        controls,
        lyrics: [],
        source_track: index,
      })
    }
  }
  if zero {
    warnings.push("notes of no length are left out")
  }
  let tempo_at : Map[Int64, Double] = Map([])
  let time_at : Map[Int64, MidiRawTime] = Map([])
  let key_at : Map[Int64, MidiRawKey] = Map([])
  for track in file.tracks {
    for t in track.notes.tempos {
      tempo_at[file.header.ppq(t.tick)] = t.bpm
    }
    for t in track.notes.times {
      time_at[file.header.ppq(t.tick)] = t
    }
    for k in track.notes.keys {
      key_at[file.header.ppq(k.tick)] = k
    }
  }
  let tempo_ticks : Array[Int64] = []
  let time_ticks : Array[Int64] = []
  let key_ticks : Array[Int64] = []
  for (tick, _) in tempo_at {
    tempo_ticks.push(tick)
  }
  for (tick, _) in time_at {
    time_ticks.push(tick)
  }
  for (tick, _) in key_at {
    key_ticks.push(tick)
  }
  tempo_ticks.sort()
  time_ticks.sort()
  key_ticks.sort()
  let tempos : Array[MidiRawTempo] = []
  let times : Array[MidiRawTime] = []
  let keys : Array[MidiRawKey] = []
  for tick in tempo_ticks {
    let bpm = tempo_at[tick]
    if tempos.is_empty() || tempos[tempos.length() - 1].bpm != bpm {
      tempos.push({ tick, bpm, })
    }
  }
  for tick in time_ticks {
    let t = time_at[tick]
    if times.is_empty() ||
      times[times.length() - 1].beats != t.beats ||
      times[times.length() - 1].beat_type != t.beat_type {
      times.push({ tick, beats: t.beats, beat_type: t.beat_type, })
    }
  }
  for tick in key_ticks {
    let k = key_at[tick]
    if keys.is_empty() ||
      keys[keys.length() - 1].fifths != k.fifths ||
      keys[keys.length() - 1].minor != k.minor {
      keys.push({ tick, fifths: k.fifths, minor: k.minor, })
    }
  }
  assign_lyrics(file, decoder, tracks)
  if file.header.smpte {
    tempos.clear()
    tempos.push({ tick: 0L, bpm: 120.0, })
  }
  {
    credits: credits(file),
    tracks,
    tempos,
    times,
    keys,
    end,
    division: if file.header.smpte {
      0
    } else {
      file.header.division
    },
    warnings,
  }
}
