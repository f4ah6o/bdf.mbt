///|
/// A clef sign: 0 G, 1 F, 3 percussion; octave is a transposition.
pub(all) struct NotationClef {
  sign : Int32
  octave : Int32
}

///|
/// Staff selection for a quantized track.
pub(all) struct StaffPlan {
  clefs : Array[NotationClef]
  percussion : Bool
}

///|
/// The staff index for a MIDI pitch in this plan.
pub fn StaffPlan::staff_for(self : StaffPlan, key : Int32) -> Int32 {
  if self.clefs.length() == 2 && key < 60 {
    1
  } else {
    0
  }
}

///|
/// Choose clefs and a grand staff using the upstream instrument rules.
pub fn plan_staff(
  notes : Array[QuantizedNote],
  channel : Int32,
  program : Int32,
) -> StaffPlan? {
  if notes.is_empty() {
    return None
  }
  if channel == 9 {
    return Some({ clefs: [{ sign: 3, octave: 0, }], percussion: true, })
  }
  let keys : Array[Int32] = []
  let mut below = 0
  let mut lo = 127
  let mut hi = 0
  for note in notes {
    keys.push(note.key)
    if note.key < 60 {
      below += 1
    }
    lo = Int32::min(lo, note.key)
    hi = Int32::max(hi, note.key)
  }
  keys.sort()
  let median = keys[keys.length() / 2]
  let fraction = below.to_double() / notes.length().to_double()
  let keyboard = program <= 23 || program == 46
  let guitar = program >= 24 && program <= 31
  let clefs : Array[NotationClef] = if !guitar &&
    (
      (keyboard && fraction >= 0.1 && fraction <= 0.9 && lo < 55 && hi >= 60) ||
      (fraction >= 0.25 && fraction <= 0.75 && hi - lo >= 36)
    ) {
    [{ sign: 0, octave: 0, }, { sign: 1, octave: 0, }]
  } else if guitar && median < 67 {
    [{ sign: 0, octave: -1, }]
  } else if median < 57 {
    [{ sign: 1, octave: 0, }]
  } else {
    [{ sign: 0, octave: 0, }]
  }
  Some({ clefs, percussion: false, })
}

///|
/// Percussion staff pitch, notehead (0 normal, 1 X), and preferred voice.
pub(all) struct DrumNotation {
  pitch : Pitch
  head : Int32
  voice : Int32
}

///|
/// Map a General MIDI percussion key to its written staff position.
pub fn drum_of(key : Int32) -> DrumNotation {
  let (step, octave, head, voice) = match key {
    35 | 36 => (3, 4, 0, 2)
    37 | 39 => (0, 5, 1, 1)
    38 | 40 => (0, 5, 0, 1)
    41 | 43 => (5, 4, 0, 1)
    45 | 47 => (1, 5, 0, 1)
    48 | 50 => (2, 5, 0, 1)
    42 | 46 => (4, 5, 1, 1)
    44 => (1, 4, 1, 2)
    49 | 57 | 52 | 55 => (5, 5, 1, 1)
    51 | 59 | 53 => (3, 5, 1, 1)
    54 | 56 => (2, 5, 1, 1)
    _ => (0, 5, 0, 1)
  }
  { pitch: { step, alter: 0, octave, }, head, voice, }
}

///|
/// Extend percussion hits to the next hit of their voice within the beat.
pub fn percussion_durations(
  notes : Array[QuantizedNote],
  beats : Array[BeatGrid],
) -> Array[QuantizedNote] {
  if beats.is_empty() {
    return []
  }
  let out : Array[QuantizedNote] = []
  for i, note in notes {
    let beat = grid_at(beats, note.on)
    let mut off = beat.start + beat.length
    let voice = drum_of(note.key).voice
    for j in (i + 1)..<notes.length() {
      if notes[j].on > note.on && drum_of(notes[j].key).voice == voice {
        off = Int64::min(off, notes[j].on)
        break
      }
    }
    out.push({
      on: note.on,
      off,
      key: note.key,
      velocity: note.velocity,
      spelling: note.spelling,
    })
  }
  out
}
