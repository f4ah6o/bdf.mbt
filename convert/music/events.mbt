///|
pub(all) struct ScoreLyric {
  text : String
  syllabic : Int32
}

///|
pub(all) struct ScoreNote {
  pitch : Pitch
  head : Int32
  tie_start : Bool
  tie_stop : Bool
}

///|
/// A written note, chord, or rest in a measure.
pub(all) struct ScoreEvent {
  offset : Int64
  duration : Int64
  staff : Int32
  voice : Int32
  kind : Int32
  dots : Int32
  rest : Bool
  measure_rest : Bool
  tuplet_beat : Int64?
  notes : Array[ScoreNote]
  lyric : ScoreLyric?
}

///|
pub(all) struct NotationLyric {
  tick : Int64
  text : String
}

///|
priv struct EventPiece {
  start : Int64
  mut end : Int64
  triplet : BeatGrid?
}

///|
fn strip_lyric(text : String) -> ScoreLyric {
  let mut first = 0
  let mut last = text.length()
  while first < last &&
        (
          text[first] == 0x2f ||
          text[first] == 0x5c ||
          text[first] == 0x0d ||
          text[first] == 0x0a
        ) {
    first += 1
  }
  while last > first &&
        (
          text[last - 1] == 0x2f ||
          text[last - 1] == 0x5c ||
          text[last - 1] == 0x0d ||
          text[last - 1] == 0x0a
        ) {
    last -= 1
  }
  let out = StringBuilder()
  let pending = StringBuilder()
  let mut started = false
  for c in text[first:last] {
    if c.is_whitespace() {
      if started {
        pending.write_char(c)
      }
    } else {
      if started {
        out.write_string(pending.to_string())
        pending.reset()
      }
      out.write_char(c)
      started = true
    }
  }
  let s = out.to_string()
  if s.has_suffix("-") {
    { text: s[:s.length() - 1].to_owned(), syllabic: 1, }
  } else {
    { text: s, syllabic: 0, }
  }
}

///|
fn emit_segment(
  events : Array[Array[ScoreEvent]],
  measures : Array[MeasureSpan],
  beats : Array[BeatGrid],
  lyrics : Map[Int64, String],
  m : Int32,
  start : Int64,
  end : Int64,
  notes : Array[VoiceNote]?,
  staff : Int32,
  voice : Int32,
  tie_in : Bool,
  tie_out : Bool,
  percussion : Bool,
) -> Unit {
  let measure = measures[m]
  if notes is None &&
    start == measure.start &&
    end == measure.start + measure.length {
    events[m].push({
      offset: 0L,
      duration: measure.length,
      staff,
      voice,
      kind: 1,
      dots: 0,
      rest: true,
      measure_rest: true,
      tuplet_beat: None,
      notes: [],
      lyric: None,
    })
    return
  }
  let (beat, compound) = measure.time.beat()
  let pieces : Array[EventPiece] = []
  let mut x = start
  while x < end {
    let bg = grid_at(beats, x)
    let stop = Int64::min(end, bg.start + bg.length)
    if stop <= x {
      return
    }
    let straight = Int64::max(bg.length / 4L, 1L)
    if bg.triplet &&
      ((x - bg.start) % straight != 0L || (stop - bg.start) % straight != 0L) {
      pieces.push({ start: x, end: stop, triplet: Some(bg), })
    } else if !pieces.is_empty() &&
      pieces[pieces.length() - 1].triplet is None &&
      pieces[pieces.length() - 1].end == x {
      pieces[pieces.length() - 1].end = stop
    } else {
      pieces.push({ start: x, end: stop, triplet: None, })
    }
    x = stop
  }
  let values : Array[(NotationValue, Int64?)] = []
  for piece in pieces {
    match piece.triplet {
      Some(bg) => {
        let a = (piece.start - bg.start) * 3L / 2L
        let b = (piece.end - bg.start) * 3L / 2L
        for
          value in divide_values(
            a,
            b,
            bg.length * 3L / 2L,
            bg.length * 3L / 2L,
            false,
            notes is None,
          ) {
          values.push(
            (
              {
                offset: bg.start + value.offset * 2L / 3L - measure.start,
                ticks: value.ticks * 2L / 3L,
                kind: value.kind,
                dots: value.dots,
              },
              Some(bg.start),
            ),
          )
        }
      }
      None =>
        for
          value in divide_values(
            piece.start - measure.start,
            piece.end - measure.start,
            beat.to_int64(),
            measure.length,
            compound,
            notes is None,
          ) {
          values.push((value, None))
        }
    }
  }
  for i, item in values {
    let (value, triplet) = item
    let event_notes : Array[(Int32, ScoreNote)] = []
    let mut lyric : ScoreLyric? = None
    match notes {
      Some(notes) => {
        for index, entry in notes {
          let q = entry.note
          let drum = drum_of(q.key)
          let pitch = if percussion {
            drum.pitch
          } else {
            spell(q.key, measure.effective_key, q.spelling)
          }
          let head = if percussion { drum.head } else { 0 }
          event_notes.push(
            (
              index,
              {
                pitch,
                head,
                tie_stop: tie_in || i > 0,
                tie_start: tie_out || i < values.length() - 1,
              },
            ),
          )
        }
        event_notes.sort_by((a, b) => {
          let cmp = (a.1.pitch.octave * 7 + a.1.pitch.step).compare(
            b.1.pitch.octave * 7 + b.1.pitch.step,
          )
          if cmp != 0 {
            cmp
          } else {
            a.0.compare(b.0)
          }
        })
        if !tie_in && i == 0 {
          let absolute = measure.start + value.offset
          match lyrics.get(absolute) {
            Some(s) if s != "" => {
              lyric = Some(strip_lyric(s))
              lyrics.remove(absolute)
            }
            _ => ()
          }
        }
      }
      None => ()
    }
    let out_notes : Array[ScoreNote] = []
    for (_, n) in event_notes {
      out_notes.push(n)
    }
    events[m].push({
      offset: value.offset,
      duration: value.ticks,
      staff,
      voice,
      kind: value.kind,
      dots: value.dots,
      rest: notes is None,
      measure_rest: false,
      tuplet_beat: triplet,
      notes: out_notes,
      lyric,
    })
  }
}

///|
fn emit_rests(
  events : Array[Array[ScoreEvent]],
  measures : Array[MeasureSpan],
  beats : Array[BeatGrid],
  lyrics : Map[Int64, String],
  used : Array[Bool],
  staff : Int32,
  voice : Int32,
  start : Int64,
  end : Int64,
  percussion : Bool,
) -> Unit {
  let mut at = start
  while at < end {
    let m = measure_at(measures, at)
    let stop = Int64::min(end, measures[m].start + measures[m].length)
    if stop <= at {
      return
    }
    if used[m] {
      emit_segment(
        events,
        measures,
        beats,
        lyrics,
        m,
        at,
        stop,
        None,
        staff,
        voice,
        false,
        false,
        percussion,
      )
    }
    at = stop
  }
}

///|
/// Produce written events for one staff, including rests, ties and tuplets.
pub fn write_staff_events(
  notes : Array[VoiceNote],
  measures : Array[MeasureSpan],
  beats : Array[BeatGrid],
  source_lyrics : Array[NotationLyric],
  staff : Int32,
  percussion : Bool,
) -> Array[Array[ScoreEvent]] {
  let lyrics = snapped_lyrics(beats, source_lyrics)
  write_staff_events_shared(notes, measures, beats, lyrics, staff, percussion)
}

///|
fn snapped_lyrics(
  beats : Array[BeatGrid],
  source_lyrics : Array[NotationLyric],
) -> Map[Int64, String] {
  let lyrics : Map[Int64, String] = Map([])
  if beats.is_empty() {
    return lyrics
  }
  for item in source_lyrics {
    let on = grid_at(beats, item.tick).snap(item.tick)
    lyrics[on] = lyrics.get(on).unwrap_or("") + item.text
  }
  lyrics
}

///|
fn write_staff_events_shared(
  notes : Array[VoiceNote],
  measures : Array[MeasureSpan],
  beats : Array[BeatGrid],
  lyrics : Map[Int64, String],
  staff : Int32,
  percussion : Bool,
) -> Array[Array[ScoreEvent]] {
  let events : Array[Array[ScoreEvent]] = []
  for _ in measures {
    events.push([])
  }
  if measures.is_empty() || beats.is_empty() {
    return events
  }
  let voices = assign_voices(notes, measures, beats, percussion)
  for v in 0..<2 {
    let used : Array[Bool] = []
    for _ in measures {
      used.push(v == 0)
    }
    if v == 1 {
      for chord in voices[v] {
        let mut m = measure_at(measures, chord.on)
        while m < measures.length() && measures[m].start < chord.off {
          used[m] = true
          m += 1
        }
      }
    }
    let mut at = 0L
    for chord in voices[v] {
      if chord.on > at {
        emit_rests(
          events,
          measures,
          beats,
          lyrics,
          used,
          staff,
          v + 1,
          at,
          chord.on,
          percussion,
        )
      }
      let on = Int64::max(chord.on, at)
      let off = chord.off
      if off <= on {
        continue
      }
      let mut first = true
      let mut a = on
      while a < off {
        let m = measure_at(measures, a)
        let stop = Int64::min(off, measures[m].start + measures[m].length)
        if stop <= a {
          break
        }
        emit_segment(
          events,
          measures,
          beats,
          lyrics,
          m,
          a,
          stop,
          Some(chord.notes),
          staff,
          v + 1,
          !first,
          stop < off,
          percussion,
        )
        first = false
        a = stop
      }
      at = off
    }
    let last = measures[measures.length() - 1]
    let end = last.start + last.length
    if at < end {
      emit_rests(
        events,
        measures,
        beats,
        lyrics,
        used,
        staff,
        v + 1,
        at,
        end,
        percussion,
      )
    }
  }
  events
}
