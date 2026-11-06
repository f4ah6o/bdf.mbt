///|
/// A MusicXML conversion failure.
pub suberror MusicXmlConvertError {
  MusicXmlInvalid(String)
}

///|
/// One scanned MusicXML measure, with events in the shared score model.
priv struct MusicXmlScannedMeasure {
  events : Array[@music.ScoreEvent]
  played : Array[MusicXmlPlayedNote]
  time : @music.TimeSig
  key : @music.KeySig?
  tempos : Array[(Int64, Double, Int32)]
  actual_end : Int64
  implicit : Bool
  repeat_start : Bool
  repeat_end : Int32
  ending_start : Bool
  ending_stop : Bool
  ending_numbers : Array[Int64]
}

///|
/// One scanned MusicXML part.
priv struct MusicXmlScannedPart {
  header : MusicXmlPartHeader
  measures : Array[MusicXmlScannedMeasure]
  clefs : Array[@music.NotationClef]
  percussion : Bool
  channel : Int32
  program : Int32
  volume : Int32
  pan : Int32
  lyrics : Array[(Int64, String, Int32)]
}

///|
/// The scanned score and its timeline.
priv struct MusicXmlScan {
  header : MusicXmlHeader
  parts : Array[MusicXmlScannedPart]
  starts : Array[Int64]
  lengths : Array[Int64]
  times : Array[(Int64, @music.TimeSig)]
  keys : Array[(Int64, @music.KeySig)]
  tempos : Array[(Int64, Double, Int32)]
  play_order : Array[Int32]
  play_starts : Array[Int64]
  warnings : Array[String]
}

///|
/// Recognize a MusicXML or MXL input.
pub fn detect(data : Bytes) -> Bool {
  let head = data[:if data.length() < 1024 { data.length() } else { 1024 }].to_owned()
  detect_musicxml(head, data)
}

///|
fn xml_attr(node : MusicXmlNode, name : String) -> String {
  node.attribute(name)
}

///|
fn same_time(a : @music.TimeSig, b : @music.TimeSig) -> Bool {
  a.beats == b.beats && a.beat_type == b.beat_type && a.symbol == b.symbol
}

///|
fn same_key(a : @music.KeySig, b : @music.KeySig) -> Bool {
  a.fifths == b.fifths && a.minor == b.minor
}

///|
fn xml_key(node : MusicXmlNode) -> @music.KeySig? {
  let fifths_node = match node.child("fifths") {
    Some(value) => value
    None => return None
  }
  let (fifths, valid) = musicxml_integer(fifths_node.text)
  if !valid {
    return None
  }
  let mode = node.child_text("mode").to_lower()
  Some({
    fifths: Int64::min(Int64::max(fifths, -7L), 7L).to_int(),
    minor: mode == "minor",
  })
}

///|
fn xml_clef(node : MusicXmlNode) -> @music.NotationClef {
  let clef = musicxml_clef(node)
  let sign = match clef.sign {
    1 => 1
    2 => 2
    3 => 3
    4 => 4
    5 => 5
    _ => 0
  }
  { sign, octave: clef.octave, }
}

///|
fn default_clefs(
  staves : Int32,
  percussion : Bool,
) -> Array[@music.NotationClef] {
  let count = Int32::min(Int32::max(staves, 1), 16)
  let result : Array[@music.NotationClef] = []
  for i in 0..<count {
    result.push({
      sign: if percussion {
        3
      } else if i == 1 {
        1
      } else {
        0
      },
      octave: 0,
    })
  }
  result
}

///|
fn ensure_clefs(
  clefs : Array[@music.NotationClef],
  staves : Int32,
  percussion : Bool,
) -> Unit {
  let wanted = Int32::min(Int32::max(staves, 1), 16)
  while clefs.length() < wanted {
    clefs.push({
      sign: if percussion {
        3
      } else if clefs.length() == 1 {
        1
      } else {
        0
      },
      octave: 0,
    })
  }
}

///|
/// Apply one attributes element to the part state and report time/key changes.
fn apply_attributes(
  node : MusicXmlNode,
  part : MusicXmlPartState,
  clefs : Array[@music.NotationClef],
  percussion : Bool,
  time_in : @music.TimeSig,
  key_in : @music.KeySig?,
) -> (@music.TimeSig, @music.KeySig?) {
  let mut time = time_in
  let mut key = key_in
  for child in node.children {
    match child.name {
      "divisions" => {
        let (value, valid) = musicxml_float(child.text)
        if valid && value > 0.0 {
          part.divisions = Double::min(Double::max(value, 0.000001), 100000.0)
        }
      }
      "staves" => {
        let (value, valid) = musicxml_integer(child.text)
        if valid && value >= 1L && value <= 16L {
          part.staves = value.to_int()
          ensure_clefs(clefs, part.staves, percussion)
        }
      }
      "transpose" => {
        let (chromatic, c_ok) = musicxml_integer(child.child_text("chromatic"))
        let (octave, o_ok) = musicxml_integer(child.child_text("octave-change"))
        let mut value = if c_ok { chromatic } else { 0L }
        if o_ok {
          value += octave * 12L
        }
        part.transpose = Int64::min(Int64::max(value, -48L), 48L).to_int()
      }
      "time" =>
        match musicxml_time_sig(child) {
          Some(value) => {
            part.time = value
            time = value
          }
          None => ()
        }
      "key" =>
        match xml_key(child) {
          Some(value) => key = Some(value)
          None => ()
        }
      "clef" => {
        let (number, valid) = musicxml_integer(xml_attr(child, "number"))
        let index = if valid && number >= 1L && number <= 16L {
          number.to_int() - 1
        } else {
          0
        }
        while clefs.length() <= index && clefs.length() < 16 {
          clefs.push({ sign: 0, octave: 0, })
        }
        if index < clefs.length() {
          clefs[index] = xml_clef(child)
        }
      }
      _ => ()
    }
  }
  (time, key)
}

///|
fn note_lyric(node : MusicXmlNode) -> (String, Int32)? {
  for child in node.children {
    if child.name != "lyric" {
      continue
    }
    let mut text = ""
    let mut syllabic = 0
    for item in child.children {
      match item.name {
        "text" => text = musicxml_trim(item.text)
        "syllabic" =>
          syllabic = match musicxml_trim(item.text).to_lower() {
            "begin" => 1
            "middle" => 2
            _ => 0
          }
        _ => ()
      }
    }
    if text != "" {
      return Some((text, syllabic))
    }
  }
  None
}

///|
fn scan_measure(
  node : MusicXmlNode,
  part : MusicXmlPartState,
  clefs : Array[@music.NotationClef],
  percussion : Bool,
  base_time : @music.TimeSig,
  base_key : @music.KeySig?,
  measure_start : Int64,
  lyrics : Array[(Int64, String, Int32)],
) -> (MusicXmlScannedMeasure, MusicXmlPartState) {
  let state = MusicXmlMeasureState::new(part)
  let mut event_time = base_time
  let mut event_key = base_key
  let tempos : Array[(Int64, Double, Int32)] = []
  let mut repeat_start = false
  let mut repeat_end = 0
  let mut ending_start = false
  let mut ending_stop = false
  let mut ending_numbers : Array[Int64] = []
  for child in node.children {
    match child.name {
      "attributes" => {
        let (time, key) = apply_attributes(
          child,
          state.part,
          clefs,
          percussion,
          event_time,
          event_key,
        )
        event_time = time
        event_key = key
      }
      "note" => {
        let chord = child.child("chord") is Some(_)
        let start = if chord { state.last_start } else { state.position() }
        let lyric = note_lyric(child)
        state.add_note(child)
        match lyric {
          Some((text, syllabic)) => {
            let offset = measure_start + musicxml_tick_of(start).to_int64()
            lyrics.push((offset, text, syllabic))
          }
          None => ()
        }
      }
      "forward" => state.move(child.child_text("duration"), true)
      "backup" => state.move(child.child_text("duration"), false)
      "sound" => {
        let tempo = xml_attr(child, "tempo")
        if tempo != "" {
          let (bpm, valid) = musicxml_float(tempo)
          if valid && bpm > 0.0 {
            let offset = musicxml_tick_of(state.position()).to_int64()
            tempos.push((offset, Double::min(Double::max(bpm, 1.0), 1000.0), 0))
          }
        }
      }
      "barline" =>
        for item in child.children {
          if item.name == "repeat" {
            let direction = xml_attr(item, "direction")
            if direction == "forward" {
              repeat_start = true
            } else if direction == "backward" {
              let (times, valid) = musicxml_integer(xml_attr(item, "times"))
              repeat_end = if valid && times >= 1L && times <= 32L {
                Int64::min(times, 8L).to_int()
              } else {
                2
              }
            }
          } else if item.name == "ending" {
            let kind = xml_attr(item, "type")
            if kind == "start" {
              ending_start = true
              ending_numbers = musicxml_ending_numbers(xml_attr(item, "number")).0
            } else if kind == "stop" || kind == "discontinue" {
              ending_stop = true
            }
          }
        }
      "direction" =>
        for item in child.children {
          if item.name == "sound" {
            let tempo = xml_attr(item, "tempo")
            if tempo != "" {
              let (bpm, valid) = musicxml_float(tempo)
              if valid && bpm > 0.0 {
                let offset = musicxml_tick_of(state.position()).to_int64()
                tempos.push(
                  (offset, Double::min(Double::max(bpm, 1.0), 1000.0), 0),
                )
              }
            }
          } else if item.name == "metronome" {
            let (per_minute, valid) = musicxml_float(
              item.child_text("per-minute"),
            )
            if valid && per_minute > 0.0 {
              let quarters = match item.child_text("beat-unit") {
                "whole" => 4.0
                "half" => 2.0
                "eighth" => 0.5
                "16th" => 0.25
                "32nd" => 0.125
                _ => 1.0
              }
              let bpm = per_minute * quarters
              let offset = musicxml_tick_of(state.position()).to_int64()
              tempos.push(
                (offset, Double::min(Double::max(bpm, 1.0), 1000.0), 0),
              )
            }
          }
        }
      _ => ()
    }
  }
  let events : Array[@music.ScoreEvent] = []
  for event in state.events() {
    if event.cue {
      continue
    }
    let notes : Array[@music.ScoreNote] = []
    for note in event.notes {
      notes.push({
        pitch: note.pitch,
        head: note.head,
        tie_start: note.tie_start,
        tie_stop: note.tie_stop,
      })
    }
    let mut lyric : @music.ScoreLyric? = None
    let offset = measure_start + event.offset.to_int64()
    for item in lyrics {
      if item.0 == offset && lyric is None {
        lyric = Some({ text: item.1, syllabic: item.2, })
      }
    }
    events.push({
      offset: event.offset.to_int64(),
      duration: Int64::max(event.duration.to_int64(), 1L),
      staff: event.staff,
      voice: event.voice,
      kind: event.kind,
      dots: event.dots,
      rest: event.rest,
      measure_rest: event.measure_rest,
      tuplet_beat: None,
      notes,
      lyric,
    })
  }
  let part_after = state.part
  (
    {
      events,
      played: state.played(),
      time: event_time,
      key: event_key,
      tempos,
      actual_end: musicxml_tick_of(state.end()).to_int64(),
      implicit: xml_attr(node, "implicit") == "yes",
      repeat_start,
      repeat_end,
      ending_start,
      ending_stop,
      ending_numbers,
    },
    part_after,
  )
}

///|
fn find_header(
  headers : Array[MusicXmlPartHeader],
  id : String,
  index : Int32,
) -> MusicXmlPartHeader {
  for header in headers {
    if header.id == id {
      return header
    }
  }
  if headers.is_empty() {
    { id, name: "", abbreviation: "", track_name: "", instruments: [], }
  } else {
    headers[Int32::min(Int32::max(index, 0), headers.length() - 1)]
  }
}

///|
fn scan_part(
  node : MusicXmlNode,
  header : MusicXmlPartHeader,
  starts : Array[Int64],
  warnings : Array[String],
) -> MusicXmlScannedPart {
  let instruments = header.instruments
  let percussion = instruments.any(fn(item) { item.unpitched >= 0 }) ||
    instruments.any(fn(item) { item.channel == 9 })
  let mut part = MusicXmlPartState::new(instruments~)
  let clefs = default_clefs(part.staves, percussion)
  let mut channel = -1
  let mut program = -1
  let mut volume = 100
  let mut pan = 64
  for instrument in instruments {
    if channel < 0 && instrument.channel >= 0 {
      channel = instrument.channel
    }
    if program < 0 && instrument.program >= 0 {
      program = instrument.program
    }
    if instrument.volume >= 0 {
      volume = instrument.volume
    }
    if instrument.pan >= 0 {
      pan = instrument.pan
    }
  }
  if channel < 0 {
    channel = 0
  }
  if program < 0 {
    program = 0
  }
  let measures : Array[MusicXmlScannedMeasure] = []
  let lyrics : Array[(Int64, String, Int32)] = []
  let mut time = part.time
  let mut key : @music.KeySig? = None
  let mut mi = 0
  for child in node.children {
    if child.name != "measure" {
      continue
    }
    let start = if mi < starts.length() { starts[mi] } else { 0L }
    let (scanned, next) = scan_measure(
      child, part, clefs, percussion, time, key, start, lyrics,
    )
    part = next
    time = scanned.time
    key = scanned.key
    measures.push(scanned)
    mi += 1
  }
  let _ = warnings
  {
    header,
    measures,
    clefs,
    percussion,
    channel,
    program,
    volume,
    pan,
    lyrics,
  }
}

///|
fn expand_play_order(measures : Array[MusicXmlScannedMeasure]) -> Array[Int32] {
  let order : Array[Int32] = []
  let pending : Array[Int32] = []
  let mut i = 0
  while i < measures.length() {
    let measure = measures[i]
    if measure.repeat_start {
      for value in pending {
        order.push(value)
      }
      pending.clear()
    }
    pending.push(i)
    if measure.repeat_end > 0 {
      for value in pending {
        order.push(value)
      }
      let mut ending_two_start = -1
      let mut ending_two_stop = -1
      for j in (i + 1)..<measures.length() {
        if measures[j].ending_start && measures[j].ending_numbers.contains(2L) {
          ending_two_start = j
          let mut k = j
          while k < measures.length() {
            if measures[k].ending_stop {
              break
            }
            k += 1
          }
          ending_two_stop = if k < measures.length() {
            k
          } else {
            measures.length() - 1
          }
          break
        }
      }
      for _ in 1..<measure.repeat_end {
        for value in pending {
          let skip = measures[value].ending_start &&
            (
              measures[value].ending_numbers.contains(1L) ||
              measures[value].ending_numbers.contains(3L)
            )
          if !skip {
            order.push(value)
          }
        }
        if ending_two_start >= 0 {
          for j in ending_two_start..<=ending_two_stop {
            order.push(j)
          }
        }
      }
      pending.clear()
      i = if ending_two_stop >= 0 { ending_two_stop + 1 } else { i + 1 }
    } else {
      i += 1
    }
  }
  for value in pending {
    order.push(value)
  }
  order
}

///|
fn scan_score(root : MusicXmlNode) -> MusicXmlScan {
  let header = musicxml_header(root)
  let warnings = header.warnings.copy()
  let raw_parts : Array[(MusicXmlNode, MusicXmlPartHeader)] = []
  let mut index = 0
  for child in root.children {
    if child.name != "part" {
      continue
    }
    raw_parts.push(
      (child, find_header(header.parts, xml_attr(child, "id"), index)),
    )
    index += 1
  }
  let provisional : Array[MusicXmlScannedPart] = []
  for pair in raw_parts {
    provisional.push(scan_part(pair.0, pair.1, [], warnings))
  }
  let mut measure_count = 0
  for part in provisional {
    measure_count = Int32::max(measure_count, part.measures.length())
  }
  let starts : Array[Int64] = Array::make(measure_count, 0L)
  let lengths : Array[Int64] = Array::make(measure_count, 3840L)
  let mut at = 0L
  for mi in 0..<measure_count {
    let mut nominal = 3840L
    let mut actual = 0L
    let mut implicit = false
    for part in provisional {
      if mi < part.measures.length() {
        let measure = part.measures[mi]
        nominal = measure.time.length().to_int64()
        actual = Int64::max(actual, measure.actual_end)
        implicit = implicit || measure.implicit
      }
    }
    let length = if actual <= 0L {
      nominal
    } else if implicit {
      Int64::max(actual, 1L)
    } else if actual > nominal {
      actual
    } else {
      nominal
    }
    starts[mi] = at
    lengths[mi] = length
    at += length
  }
  let parts : Array[MusicXmlScannedPart] = []
  for pair in raw_parts {
    parts.push(scan_part(pair.0, pair.1, starts, warnings))
  }
  let times : Array[(Int64, @music.TimeSig)] = []
  let keys : Array[(Int64, @music.KeySig)] = []
  let tempos : Array[(Int64, Double, Int32)] = []
  if !parts.is_empty() {
    let part = parts[0]
    for mi, measure in part.measures {
      let start = if mi < starts.length() { starts[mi] } else { 0L }
      if times.is_empty() ||
        !same_time(times[times.length() - 1].1, measure.time) {
        times.push((start, measure.time))
      }
      match measure.key {
        Some(value) =>
          if keys.is_empty() || !same_key(keys[keys.length() - 1].1, value) {
            keys.push((start, value))
          }
        None => ()
      }
      for tempo in measure.tempos {
        tempos.push((start + tempo.0, tempo.1, tempo.2))
      }
    }
  }
  let play_order = if parts.is_empty() {
    []
  } else {
    expand_play_order(parts[0].measures)
  }
  let play_starts : Array[Int64] = []
  let mut play_at = 0L
  for mi in play_order {
    play_starts.push(play_at)
    if mi >= 0 && mi < lengths.length() {
      play_at += lengths[mi]
    }
  }
  {
    header,
    parts,
    starts,
    lengths,
    times,
    keys,
    tempos,
    play_order,
    play_starts,
    warnings,
  }
}

///|
fn build_score(scan : MusicXmlScan) -> @music.NotatedScore {
  let measures : Array[@music.MeasureSpan] = []
  let count = scan.lengths.length()
  let mut effective_key : @music.KeySig = { fifths: 0, minor: false, }
  let mut previous_time : @music.TimeSig = {
    beats: 4,
    beat_type: 4,
    symbol: "",
  }
  let mut previous_key : @music.KeySig? = None
  for mi in 0..<count {
    let start = scan.starts[mi]
    let length = scan.lengths[mi]
    let mut time = previous_time
    for item in scan.times {
      if item.0 <= start {
        time = item.1
      }
    }
    let mut current_key = previous_key
    for item in scan.keys {
      if item.0 <= start {
        current_key = Some(item.1)
      }
    }
    let mut key_mark : @music.KeySig? = None
    match current_key {
      Some(value) => {
        effective_key = value
        if previous_key is None || !same_key(previous_key.unwrap(), value) {
          key_mark = Some(value)
        }
      }
      None => ()
    }
    let show_time = mi == 0 || !same_time(previous_time, time)
    let tempo_marks : Array[@music.TempoMark] = []
    for tempo in scan.tempos {
      if tempo.0 >= start && tempo.0 < start + length {
        let mut offset = tempo.0 - start
        let beat = Int64::max(
          length / Int64::max(time.beats.to_int64(), 1L),
          1L,
        )
        offset = (offset + beat / 2L) / beat * beat
        if offset >= length {
          offset = 0L
        }
        let mut duplicate = false
        for item in tempo_marks {
          if item.offset == offset {
            duplicate = true
          }
        }
        if !duplicate {
          tempo_marks.push({
            offset,
            dots: tempo.2,
            per_minute: tempo.1.round(),
          })
        }
      }
    }
    let measure : @music.MeasureSpan = {
      start,
      length,
      time,
      show_time,
      key: key_mark,
      effective_key,
      tempo: tempo_marks,
    }
    measures.push(measure)
    previous_time = time
    previous_key = current_key
  }
  let timeline : @music.ScoreTimeline = {
    measures,
    warnings: scan.warnings.copy(),
  }
  let parts : Array[@music.NotatedPart] = []
  for part in scan.parts {
    let part_measures : Array[@music.NotatedPartMeasure] = []
    let mut previous : @music.KeySig? = None
    for mi in 0..<count {
      let mut events : Array[@music.ScoreEvent] = []
      let mut key : @music.KeySig? = None
      let mut ending : Array[Int64]? = None
      let mut repeat_start = false
      let mut repeat_end = 0
      if mi < part.measures.length() {
        let measure = part.measures[mi]
        events = measure.events.copy()
        match measure.key {
          Some(value) =>
            if previous is None || !same_key(previous.unwrap(), value) {
              key = Some(value)
            }
          None => ()
        }
        previous = measure.key
        if measure.ending_start {
          ending = Some(measure.ending_numbers)
        }
        repeat_start = measure.repeat_start
        repeat_end = measure.repeat_end
      }
      part_measures.push({ key, events, ending, repeat_start, repeat_end, })
    }
    let clefs = if part.clefs.is_empty() {
      default_clefs(1, part.percussion)
    } else {
      part.clefs.copy()
    }
    parts.push({
      name: if part.header.track_name != "" {
        part.header.track_name
      } else {
        part.header.name
      },
      clefs,
      percussion: part.percussion,
      measures: part_measures,
    })
  }
  {
    title: scan.header.title,
    subtitle: scan.header.subtitle,
    composer: scan.header.composer,
    lyricist: scan.header.lyricist,
    arranger: scan.header.arranger,
    copyright: scan.header.rights,
    timeline,
    parts,
    error: "",
  }
}

///|
fn build_performance(scan : MusicXmlScan) -> @midi.MidiPerformance {
  let tracks : Array[@midi.MidiPerformanceTrack] = []
  let mut end = 0L
  for index, part in scan.parts {
    let mut notes : Array[@midi.MidiPlayNote] = []
    let open : Array[Int32] = []
    for k, mi in scan.play_order {
      if mi < 0 || mi >= part.measures.length() {
        continue
      }
      let measure = part.measures[mi]
      if mi == 0 && k > 0 {
        open.clear()
      }
      let start = if k < scan.play_starts.length() {
        scan.play_starts[k]
      } else {
        0L
      }
      for note in measure.played {
        if note.duration <= 0 {
          continue
        }
        let tick = start + note.offset.to_int64()
        let duration = note.duration.to_int64()
        end = Int64::max(end, tick + duration)
        let velocity = if note.velocity > 0 {
          Int32::min(Int32::max(note.velocity, 1), 127)
        } else {
          80
        }
        if note.tie_stop && !open.is_empty() {
          let mut found = -1
          let mut i = open.length() - 1
          while i >= 0 {
            let candidate = open[i]
            if candidate >= 0 &&
              candidate < notes.length() &&
              notes[candidate].key == note.key {
              found = candidate
              break
            }
            i -= 1
          }
          if found >= 0 {
            let previous = notes[found]
            notes[found] = {
              tick: previous.tick,
              duration: tick + duration - previous.tick,
              key: previous.key,
              velocity: previous.velocity,
            }
            if note.tie_start {
              open[open.length() - 1] = found
            } else {
              let _ = open.pop()
            }
            continue
          }
        }
        let note_index = notes.length()
        notes.push({ tick, duration, key: note.key, velocity, })
        if note.tie_start {
          open.push(note_index)
        }
      }
    }
    if notes.is_empty() {
      continue
    }
    notes = notes.copy()
    notes.sort_by(fn(a, b) {
      let c = a.tick.compare(b.tick)
      if c != 0 {
        c
      } else {
        a.key.compare(b.key)
      }
    })
    let lyrics : Array[@midi.MidiLyric] = []
    for lyric in part.lyrics {
      lyrics.push({ tick: lyric.0, text: lyric.1, })
    }
    tracks.push({
      name: part.header.track_name,
      channel: part.channel,
      program: part.program,
      volume: part.volume,
      pan: part.pan,
      notes,
      controls: [],
      lyrics,
      source_track: index,
    })
  }
  let tempos : Array[@midi.MidiRawTempo] = []
  let times : Array[@midi.MidiRawTime] = []
  let keys : Array[@midi.MidiRawKey] = []
  if !scan.parts.is_empty() {
    let measures = scan.parts[0].measures
    let mut previous_time : @music.TimeSig? = None
    let mut previous_key : @music.KeySig? = None
    for k, mi in scan.play_order {
      if mi < 0 || mi >= measures.length() {
        continue
      }
      let start = if k < scan.play_starts.length() {
        scan.play_starts[k]
      } else {
        0L
      }
      let measure = measures[mi]
      if previous_time is None ||
        !same_time(previous_time.unwrap(), measure.time) {
        times.push({
          tick: start,
          beats: measure.time.beats,
          beat_type: measure.time.beat_type,
        })
        previous_time = Some(measure.time)
      }
      match measure.key {
        Some(key) =>
          if previous_key is None || !same_key(previous_key.unwrap(), key) {
            keys.push({ tick: start, fifths: key.fifths, minor: key.minor, })
            previous_key = Some(key)
          }
        None => ()
      }
      for tempo in measure.tempos {
        tempos.push({ tick: start + tempo.0, bpm: tempo.1, })
      }
    }
  }
  if tempos.is_empty() {
    tempos.push({ tick: 0L, bpm: 120.0, })
  }
  let credits : @midi.MidiCredits = {
    title: scan.header.title,
    composer: scan.header.composer,
    lyricist: scan.header.lyricist,
    arranger: scan.header.arranger,
    copyright: scan.header.rights,
  }
  if !scan.play_starts.is_empty() {
    let last = scan.play_starts.length() - 1
    let mi = scan.play_order[last]
    if mi >= 0 && mi < scan.lengths.length() {
      end = Int64::max(end, scan.play_starts[last] + scan.lengths[mi])
    }
  } else if end <= 0L {
    for length in scan.lengths {
      end += length
    }
  }
  {
    credits,
    tracks,
    tempos,
    times,
    keys,
    end,
    division: 960,
    warnings: scan.warnings.copy(),
  }
}

///|
/// Convert MusicXML (or an MXL archive) to a score BDF document.
pub fn convert(
  data : Bytes,
  db : @db.Database,
  options~ : @midi.MidiScoreOptions = @midi.MidiScoreOptions::new(),
  guitar_tab~ : Bool = true,
  page_ranges~ : Array[@convert.PageSpan]? = None,
) -> @midi.MidiScoreResult raise {
  if data.length() > 67108864 {
    raise MusicXmlInvalid("musicxml: the file is larger than 67108864 bytes")
  }
  let parsed = musicxml_read_tree(data) catch {
    InvalidMusicXmlInput(message) => raise MusicXmlInvalid(message)
  }
  if parsed.name != "score-partwise" && parsed.name != "score-timewise" {
    raise MusicXmlInvalid("musicxml: no score in the file")
  }
  let root = if parsed.name == "score-timewise" {
    timewise_to_partwise(parsed)
  } else {
    parsed
  }
  let scan = scan_score(root)
  let score = build_score(scan)
  let performance = build_performance(scan)
  let sequence = @midi.performance_smf(performance)
  @midi.render_music_performance(
    score,
    performance,
    db,
    options,
    "musicxml",
    sequence=Some(sequence),
    guitar_tab~,
    page_ranges~,
    cue_order=Some(scan.play_order),
    cue_starts=Some(scan.play_starts),
  ) catch {
    @music.InvalidMusicScore(message) => raise MusicXmlInvalid(message)
    error => raise error
  }
}

///|
fn timewise_part_order(root : MusicXmlNode) -> Array[String] {
  let order : Array[String] = []
  for child in root.children {
    if child.name == "part-list" {
      for item in child.children {
        if item.name == "score-part" {
          let id = xml_attr(item, "id")
          if id != "" && !order.contains(id) {
            order.push(id)
          }
        }
      }
    }
  }
  if !order.is_empty() {
    return order
  }
  for child in root.children {
    if child.name != "measure" {
      continue
    }
    for item in child.children {
      if item.name == "part" {
        let id = xml_attr(item, "id")
        if id != "" && !order.contains(id) {
          order.push(id)
        }
      }
    }
  }
  order
}

///|
/// Rewrite a score-timewise tree as the partwise shape the rest of the
/// converter reads.
fn timewise_to_partwise(root : MusicXmlNode) -> MusicXmlNode {
  let ids = timewise_part_order(root)
  let parts : Array[MusicXmlNode] = []
  for id in ids {
    let part : MusicXmlNode = {
      name: "part",
      attributes: [{ name: "id", value: id, }],
      children: [],
      text: "",
    }
    for child in root.children {
      if child.name != "measure" {
        continue
      }
      let measure : MusicXmlNode = {
        name: "measure",
        attributes: child.attributes.copy(),
        children: [],
        text: "",
      }
      for item in child.children {
        if item.name == "part" && xml_attr(item, "id") == id {
          for note in item.children {
            measure.children.push(note)
          }
        }
      }
      part.children.push(measure)
    }
    parts.push(part)
  }
  let score : MusicXmlNode = {
    name: "score-partwise",
    attributes: root.attributes.copy(),
    children: [],
    text: "",
  }
  for child in root.children {
    if child.name != "measure" {
      score.children.push(child)
    }
  }
  for part in parts {
    score.children.push(part)
  }
  score
}
