///|
/// A syllable assigned to a performed note, in 960-tick quarter notes.
pub(all) struct MidiLyric {
  tick : Int64
  text : String
}

///|
priv struct MidiSyllable {
  tick : Int64
  mut text : String
  lead : Bool
  mut trail : Bool
}

///|
fn lyric_spaced(c : Char) -> Bool {
  let n = c.to_int()
  for (lo, hi, stride) in lyric_script_ranges {
    if n >= lo && n <= hi && (n - lo) % stride == 0 {
      return true
    }
  }
  false
}

///|
fn first_char(text : String) -> Char? {
  for c in text {
    return Some(c)
  }
  None
}

///|
fn last_char(text : String) -> Char? {
  let mut result = None
  for c in text {
    result = Some(c)
  }
  result
}

///|
fn spaced_ends(left : String, right : String) -> Bool {
  match (last_char(left), first_char(right)) {
    (Some(a), Some(b)) => lyric_spaced(a) && lyric_spaced(b)
    _ => false
  }
}

///|
fn join_lyrics(a : String, b : String) -> String {
  if a.has_suffix("-") {
    return a[:a.length() - 1].to_owned() + b
  }
  if spaced_ends(a, b) {
    return a + " " + b
  }
  a + b
}

///|
fn lyric_syllables(
  track : MidiTrackNotes,
  header : MidiHeader,
  decoder : MidiTextDecoder,
) -> Array[MidiSyllable] {
  let events : Array[MidiRawText] = []
  for text in track.texts {
    if text.kind == 5 {
      events.push(text)
    }
  }
  let is_karaoke = events.is_empty() && karaoke(track, decoder)
  if is_karaoke {
    for text in track.texts {
      if text.kind == 1 && !text.data.has_prefix(b"@") {
        events.push(text)
      }
    }
  }
  let out : Array[MidiSyllable] = []
  let mut marks = 0
  let mut newline = false
  for event in events {
    let buffer = StringBuilder()
    for c in decoder.text(event.data) {
      let n = c.to_int()
      if c == '\r' || c == '\n' || c == '\t' {
        buffer.write_char(' ')
      } else if n < 0x20 || (n >= 0x7f && n <= 0x9f) {
        ()
      } else {
        buffer.write_char(c)
      }
    }
    let mut text = buffer.to_string()
    let mut lead = newline
    while text.has_prefix("/") || text.has_prefix("\\") {
      text = text[1:].to_owned()
      lead = true
    }
    let trimmed = trim_text(text)
    if trimmed != text || lead {
      marks += 1
    }
    match first_char(text) {
      Some(c) if c.is_whitespace() => lead = true
      _ => ()
    }
    let trail = match last_char(text) {
      Some(c) => c.is_whitespace()
      None => false
    }
    if trimmed == "" {
      if !out.is_empty() && (lead || trail) {
        out[out.length() - 1].trail = true
      }
      newline = lead || trail
      continue
    }
    newline = false
    out.push({ tick: header.ppq(event.tick), text: trimmed, lead, trail, })
  }
  if is_karaoke || marks * 5 >= events.length() {
    for i in 0..<Int32::max(0, out.length() - 1) {
      let a = out[i]
      let b = out[i + 1]
      if !a.trail &&
        !b.lead &&
        !a.text.has_suffix("-") &&
        spaced_ends(a.text, b.text) {
        a.text = a.text + "-"
      }
    }
  }
  out
}

///|
fn note_at(track : MidiPerformanceTrack, tick : Int64) -> Int64? {
  let mut lo = 0
  let mut hi = track.notes.length()
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    if track.notes[mid].tick < tick {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  let mut at : Int64? = None
  if lo < track.notes.length() && track.notes[lo].tick - tick <= 60L {
    at = Some(track.notes[lo].tick)
  }
  if lo > 0 && tick - track.notes[lo - 1].tick <= 60L {
    let candidate = track.notes[lo - 1].tick
    match at {
      Some(current) if tick - candidate >= current - tick => ()
      _ => at = Some(candidate)
    }
  }
  at
}

///|
fn assign_lyrics(
  file : MidiRawFile,
  decoder : MidiTextDecoder,
  tracks : Array[MidiPerformanceTrack],
) -> Unit {
  if tracks.is_empty() {
    return
  }
  let mut budget = 50000000
  for index, raw in file.tracks {
    let syllables = lyric_syllables(raw.notes, file.header, decoder)
    if syllables.is_empty() {
      continue
    }
    let candidates : Array[MidiPerformanceTrack] = []
    for track in tracks {
      if track.source_track == index {
        candidates.push(track)
      }
    }
    if candidates.is_empty() {
      for track in tracks {
        candidates.push(track)
      }
    }
    let tonal : Array[MidiPerformanceTrack] = []
    for track in candidates {
      if track.channel != 9 {
        tonal.push(track)
      }
    }
    let choices = if tonal.is_empty() { candidates } else { tonal }
    let mut best = choices[0]
    let mut best_score = 0
    for track in choices {
      if choices.length() == 1 || budget < syllables.length() {
        break
      }
      budget -= syllables.length()
      let mut score = 0
      for syl in syllables {
        if note_at(track, syl.tick) is Some(_) {
          score += 1
        }
      }
      if score > best_score {
        best = track
        best_score = score
      }
    }
    for syl in syllables {
      let tick = note_at(best, syl.tick).unwrap_or(syl.tick)
      best.lyrics.push({ tick, text: syl.text, })
    }
  }
  for track in tracks {
    let ordered : Array[(Int32, MidiLyric)] = []
    for index, lyric in track.lyrics {
      ordered.push((index, lyric))
    }
    ordered.sort_by((a, b) => {
      let cmp = a.1.tick.compare(b.1.tick)
      if cmp != 0 {
        cmp
      } else {
        a.0.compare(b.0)
      }
    })
    track.lyrics.clear()
    for (_, lyric) in ordered {
      if !track.lyrics.is_empty() &&
        track.lyrics[track.lyrics.length() - 1].tick == lyric.tick {
        let prev = track.lyrics.pop().unwrap()
        track.lyrics.push({
          tick: lyric.tick,
          text: join_lyrics(prev.text, lyric.text),
        })
      } else {
        track.lyrics.push(lyric)
      }
    }
  }
}
