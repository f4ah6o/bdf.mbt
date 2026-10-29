///|
/// One written event while a MusicXML measure is read.
pub(all) struct MusicXmlEvent {
  offset : Int32
  duration : Int32
  staff : Int32
  voice : Int32
  kind : Int32
  dots : Int32
  grace : Bool
  slash : Bool
  cue : Bool
  hidden : Bool
  stem : Int32
  rest : Bool
  measure_rest : Bool
  beams : Array[Int32]
  notes : Array[MusicXmlPitchNote]
}

///|
/// One sounding note before repeat expansion.
pub(all) struct MusicXmlPlayedNote {
  offset : Int32
  duration : Int32
  key : Int32
  staff : Int32
  voice : Int32
  grace : Bool
  velocity : Int32
  tie_start : Bool
  tie_stop : Bool
}

///|
/// State shared by successive measures in one MusicXML part.
pub(all) struct MusicXmlPartState {
  mut divisions : Double
  mut time : @music.TimeSig
  mut transpose : Int32
  mut staves : Int32
  voices : MusicXmlNumbers
  instruments : Array[MusicXmlInstrument]
  mut has_beams : Bool
  mut has_alteration : Bool
  mut has_accidental : Bool
  mut unpitched : Bool
}

///|
pub fn MusicXmlPartState::new(
  instruments~ : Array[MusicXmlInstrument] = [],
) -> MusicXmlPartState {
  {
    divisions: 1.0,
    time: { beats: 4, beat_type: 4, symbol: "", },
    transpose: 0,
    staves: 1,
    voices: MusicXmlNumbers::new(0),
    instruments,
    has_beams: false,
    has_alteration: false,
    has_accidental: false,
    unpitched: false,
  }
}

///|
/// State accumulated while reading one part's measure.
pub struct MusicXmlMeasureState {
  part : MusicXmlPartState
  mut position : Double
  mut end : Double
  events : Array[MusicXmlEvent]
  played : Array[MusicXmlPlayedNote]
  mut last : Int32
  mut last_start : Double
}

///|
pub fn MusicXmlMeasureState::new(
  part : MusicXmlPartState,
) -> MusicXmlMeasureState {
  {
    part,
    position: 0.0,
    end: 0.0,
    events: [],
    played: [],
    last: -1,
    last_start: 0.0,
  }
}

///|
pub fn MusicXmlMeasureState::events(
  self : MusicXmlMeasureState,
) -> Array[MusicXmlEvent] {
  self.events.copy()
}

///|
pub fn MusicXmlMeasureState::played(
  self : MusicXmlMeasureState,
) -> Array[MusicXmlPlayedNote] {
  self.played.copy()
}

///|
pub fn MusicXmlMeasureState::position(self : MusicXmlMeasureState) -> Double {
  self.position
}

///|
pub fn MusicXmlMeasureState::end(self : MusicXmlMeasureState) -> Double {
  self.end
}

///|
fn MusicXmlPartState::quarters(
  self : MusicXmlPartState,
  text : String,
) -> Double {
  let (value, valid) = musicxml_float(text)
  if !valid {
    0.0
  } else {
    Double::min(Double::max(value / self.divisions, -4096.0), 4096.0)
  }
}

///|
/// Apply a MusicXML backup or forward, in the current divisions.
pub fn MusicXmlMeasureState::move(
  self : MusicXmlMeasureState,
  duration : String,
  forward : Bool,
) -> Unit {
  let d = self.part.quarters(duration)
  if forward {
    self.position = Double::min(self.position + Double::max(d, 0.0), 4096.0)
    self.end = Double::max(self.end, self.position)
  } else {
    self.position = Double::max(self.position - d, 0.0)
  }
}

///|
fn musicxml_note_type(value : String) -> Int32? {
  match value {
    "maxima" | "long" | "breve" => Some(0)
    "whole" => Some(1)
    "half" => Some(2)
    "quarter" => Some(3)
    "eighth" => Some(4)
    "16th" => Some(5)
    "32nd" => Some(6)
    "64th" => Some(7)
    "128th" | "256th" | "512th" | "1024th" => Some(8)
    _ => None
  }
}

///|
/// Add a note, rest or chord tone at the current measure position.
pub fn MusicXmlMeasureState::add_note(
  self : MusicXmlMeasureState,
  node : MusicXmlNode,
) -> Unit {
  let p = self.part
  let grace_node = node.child("grace")
  let grace = grace_node is Some(_)
  let chord = node.child("chord") is Some(_)
  let rest_node = node.child("rest")
  let rest = rest_node is Some(_)
  let type_node = node.child("type")
  let type_text = match type_node {
    Some(n) => musicxml_trim(n.text)
    None => ""
  }
  let cue = node.child("cue") is Some(_) ||
    (match type_node {
      Some(n) => n.attribute("size") == "cue"
      None => false
    })
  let duration_node = node.child("duration")
  let has_duration = !grace && duration_node is Some(_)
  let mut dur = if has_duration {
    Double::max(p.quarters(duration_node.unwrap().text), 0.0)
  } else {
    0.0
  }
  let mut actual = 1
  let mut normal = 1
  match node.child("time-modification") {
    Some(tm) => {
      let (a, _) = musicxml_integer(tm.child_text("actual-notes"))
      let (b, _) = musicxml_integer(tm.child_text("normal-notes"))
      if a >= 1L && b >= 1L && a <= 1000L && b <= 1000L {
        actual = a.to_int()
        normal = b.to_int()
      }
    }
    None => ()
  }
  let mut dots = 0
  for child in node.children {
    if child.name == "dot" && dots < 4 {
      dots += 1
    }
  }
  let kind_opt = musicxml_note_type(type_text)
  let typed = kind_opt is Some(_)
  let kind = match kind_opt {
    Some(kind) => kind
    None =>
      if grace {
        4
      } else if has_duration {
        let (kind, inferred_dots) = musicxml_infer_type(
          musicxml_tick_of(dur) * actual / normal,
        )
        dots = inferred_dots
        kind
      } else {
        3
      }
  }
  if !has_duration && !grace {
    dur = (musicxml_note_ticks(kind, dots) * normal).to_double() /
      actual.to_double() /
      960.0
  }
  let voice = p.voices.get(node.child_text("voice"))
  let (raw_staff, valid_staff) = musicxml_integer(node.child_text("staff"))
  let staff = if valid_staff && raw_staff >= 1L {
    Int64::min(raw_staff, 16L).to_int() - 1
  } else {
    0
  }
  p.staves = Int32::max(p.staves, staff + 1)
  let mut event_index = -1
  let mut start = self.position
  if chord && self.last >= 0 {
    start = self.last_start
    let last = self.events[self.last]
    if !last.rest && !rest && last.grace == grace {
      event_index = self.last
    }
  }
  if event_index < 0 {
    let offset = musicxml_tick_of(start)
    let duration = if grace {
      0
    } else {
      musicxml_tick_of(start + dur) - offset
    }
    let is_rest = rest ||
      (node.child("pitch") is None && node.child("unpitched") is None)
    let measure_rest = is_rest &&
      (
        (match rest_node {
          Some(n) => n.attribute("measure") == "yes"
          None => false
        }) ||
        (!typed && start == 0.0 && Int32::abs(duration - p.time.length()) <= 2)
      )
    let slash = match grace_node {
      Some(n) => n.attribute("slash") == "yes"
      None => false
    }
    let stem = match node.child_text("stem") {
      "up" => 1
      "down" => 2
      "none" => 3
      _ => 0
    }
    self.events.push({
      offset,
      duration,
      staff,
      voice,
      kind,
      dots,
      grace,
      slash,
      cue,
      hidden: node.attribute("print-object") == "no",
      stem,
      rest: is_rest,
      measure_rest,
      beams: [],
      notes: [],
    })
    event_index = self.events.length() - 1
    self.last = event_index
    self.last_start = start
    if !chord && !grace {
      self.position = Double::min(start + dur, 4096.0)
      self.end = Double::max(self.end, self.position)
    }
  }
  let event = self.events[event_index]
  let beams : Array[Int32] = []
  for child in node.children {
    if child.name != "beam" {
      continue
    }
    p.has_beams = true
    let (raw, valid) = musicxml_integer(child.attribute("number"))
    let number = if valid { raw } else { 1L }
    if number < 1L || number > 6L {
      continue
    }
    while beams.length() < number.to_int() {
      beams.push(0)
    }
    beams[number.to_int() - 1] = match musicxml_trim(child.text) {
      "begin" => 1
      "continue" => 2
      "end" => 3
      "forward hook" => 4
      "backward hook" => 5
      _ => 0
    }
  }
  if !beams.is_empty() && event.beams.is_empty() {
    for b in beams {
      event.beams.push(b)
    }
  }
  if event.rest {
    return
  }
  let note = match
    musicxml_pitch_note(node, transpose=p.transpose, instruments=p.instruments) {
    Some(n) => n
    None => return
  }
  event.notes.push(note)
  p.has_alteration = p.has_alteration || note.has_alteration
  p.has_accidental = p.has_accidental || note.has_accidental
  p.unpitched = p.unpitched || !note.pitched
  if cue {
    return
  }
  let nd = if !has_duration || (chord && dur <= 0.0) {
    event.duration.to_double() / 960.0
  } else {
    dur
  }
  let offset = musicxml_tick_of(start)
  let (dynamic, valid) = musicxml_float(node.attribute("dynamics"))
  let velocity = if valid {
    Double::min(Double::max(musicxml_round(dynamic * 90.0 / 100.0), 1.0), 127.0).to_int()
  } else {
    0
  }
  self.played.push({
    offset,
    duration: if grace {
      0
    } else {
      musicxml_tick_of(start + nd) - offset
    },
    key: note.sounding_key,
    staff,
    voice,
    grace,
    velocity,
    tie_start: note.sound_tie_start,
    tie_stop: note.sound_tie_stop,
  })
}
