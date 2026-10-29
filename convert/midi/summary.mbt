///|
/// Played duration in seconds, rounded to a tenth as in the upstream converter.
pub fn performance_seconds(performance : MidiPerformance) -> Double {
  let mut end = performance.end
  for track in performance.tracks {
    for note in track.notes {
      end = Int64::max(end, note.tick + note.duration)
    }
  }
  let tempos : Array[(Int32, MidiRawTempo)] = [
    for i, tempo in performance.tempos => (i, tempo)
  ]
  tempos.sort_by((a, b) => {
    let c = a.1.tick.compare(b.1.tick)
    if c == 0 {
      a.0.compare(b.0)
    } else {
      c
    }
  })
  let mut bpm = 120.0
  let mut last = 0L
  let mut seconds = 0.0
  for (_, tempo) in tempos {
    if tempo.tick >= end {
      break
    }
    if tempo.bpm <= 0.0 {
      continue
    }
    seconds += (tempo.tick - last).to_double() / 960.0 * 60.0 / bpm
    bpm = tempo.bpm
    last = tempo.tick
  }
  seconds += (end - last).to_double() / 960.0 * 60.0 / bpm
  (seconds * 10.0).round() / 10.0
}

///|
/// Format the upstream music conversion summary.
pub fn MidiScoreResult::summary(self : MidiScoreResult) -> String {
  let mut text = self.pages.to_string() +
    " pages, " +
    self.systems.to_string() +
    " systems, " +
    self.measures.to_string() +
    " measures, " +
    self.parts.to_string() +
    " parts on " +
    self.staves.to_string() +
    " staves, " +
    self.notes.to_string() +
    " notes"
  if self.seconds > 0.0 {
    let seconds = self.seconds.to_int()
    let minutes = seconds / 60
    let remainder = seconds % 60
    text += ", " +
      minutes.to_string() +
      ":" +
      (if remainder < 10 { "0" } else { "" }) +
      remainder.to_string() +
      " played"
  }
  if self.embedded_fonts > 0 {
    text += ", " + self.embedded_fonts.to_string() + " embedded font(s)"
  }
  text
}
