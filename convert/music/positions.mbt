///|
/// A clef used for staff position calculations.
pub(all) struct EngravingClef {
  sign : Int32
  line : Int32
  octave : Int32
}

///|
fn clef_reference(clef : EngravingClef) -> (Int32, Int32) {
  if clef.sign == 1 {
    let line = if clef.line == 0 { 4 } else { clef.line }
    ((5 - line) * 2, 3 * 7 + 3 + 7 * clef.octave)
  } else if clef.sign == 2 {
    let line = if clef.line == 0 { 3 } else { clef.line }
    ((5 - line) * 2, 4 * 7 + 7 * clef.octave)
  } else {
    let line = if clef.line == 0 || clef.sign != 0 { 2 } else { clef.line }
    ((5 - line) * 2, 4 * 7 + 4 + 7 * clef.octave)
  }
}

///|
/// Diatonic half-space position, counted down from the top staff line.
pub fn staff_position(clef : EngravingClef, pitch : Pitch) -> Int32 {
  let (position, reference) = clef_reference(clef)
  position - (pitch.octave * 7 + pitch.step - reference)
}

///|
/// Staff positions of the sharps or flats in a key signature.
pub fn key_positions(clef : EngravingClef, key : KeySig) -> Array[Int32] {
  let sharps = [0, 3, -1, 2, 5, 1, 4]
  let flats = [4, 1, 5, 2, 6, 3, 7]
  let (position, _) = clef_reference(clef)
  let shift = if clef.sign == 1 {
    position
  } else if clef.sign == 2 {
    position - 3
  } else if clef.sign == 0 {
    position - 6
  } else {
    0
  }
  let source = if key.fifths < 0 { flats } else { sharps }
  let count = Int32::min(
    if key.fifths < 0 {
      -key.fifths
    } else {
      key.fifths
    },
    7,
  )
  let out : Array[Int32] = []
  for i in 0..<count {
    let mut value = source[i] + shift
    while value > 8 {
      value -= 7
    }
    while value < -2 {
      value += 7
    }
    out.push(value)
  }
  out
}

///|
/// Alteration of C through B in a key signature.
pub fn key_alters(key : KeySig) -> Array[Int32] {
  let sharp = [3, 0, 4, 1, 5, 2, 6]
  let flat = [6, 2, 5, 1, 4, 0, 3]
  let result = [0, 0, 0, 0, 0, 0, 0]
  for i in 0..<Int32::min(key.fifths, 7) {
    result[sharp[i]] = 1
  }
  for i in 0..<Int32::min(-key.fifths, 7) {
    result[flat[i]] = -1
  }
  result
}

///|
/// Number of naturals needed to cancel the previous key signature.
pub fn cancelled_accidentals(previous : KeySig, next : KeySig) -> Int32 {
  if previous.fifths == 0 {
    return 0
  }
  if next.fifths == 0 || (previous.fifths > 0) != (next.fifths > 0) {
    return if previous.fifths < 0 { -previous.fifths } else { previous.fifths }
  }
  0
}

///|
/// The accidental value is 0 for automatic, 1 for none, 2 sharp, 3 flat,
/// 4 natural, 5 double sharp, or 6 double flat.
pub(all) struct EngravingNote {
  pitch : Pitch
  accidental : Int32
  cautionary : Bool
  tie_stop : Bool
}

///|
pub(all) struct EngravingEvent {
  offset : Int64
  voice : Int32
  grace : Bool
  notes : Array[EngravingNote]
}

///|
fn accidental_for(alter : Int32) -> Int32 {
  match alter {
    1 => 2
    -1 => 3
    2 => 5
    -2 => 6
    _ => 4
  }
}

///|
/// Resolve accidentals independently for each staff and measure. Results
/// preserve the input event and note indices, including absent signs.
pub fn resolve_accidentals(
  key : KeySig,
  events : Array[EngravingEvent],
) -> Array[Array[Int32?]] {
  let ordered : Array[(Int32, EngravingEvent)] = []
  let result : Array[Array[Int32?]] = []
  for i, event in events {
    ordered.push((i, event))
    let signs : Array[Int32?] = []
    for _ in event.notes {
      signs.push(None)
    }
    result.push(signs)
  }
  ordered.sort_by((a, b) => {
    let offset = a.1.offset.compare(b.1.offset)
    let grace = (if a.1.grace { 0 } else { 1 }).compare(
      if b.1.grace {
        0
      } else {
        1
      },
    )
    let voice = a.1.voice.compare(b.1.voice)
    if offset != 0 {
      offset
    } else if grace != 0 {
      grace
    } else if voice != 0 {
      voice
    } else {
      a.0.compare(b.0)
    }
  })
  let state : Map[String, Int32] = Map([])
  let defaults = key_alters(key)
  for (index, event) in ordered {
    for i, note in event.notes {
      let step = (note.pitch.step % 7 + 7) % 7
      let address = "\{note.pitch.step},\{note.pitch.octave}"
      let current = state.get(address).unwrap_or(defaults[step])
      if note.accidental == 0 {
        if note.tie_stop {
          continue
        }
        if note.pitch.alter != current || note.cautionary {
          result[index][i] = Some(accidental_for(note.pitch.alter))
        }
      } else if note.accidental != 1 {
        result[index][i] = Some(note.accidental)
      }
      state[address] = note.pitch.alter
    }
  }
  result
}

///|
pub(all) struct PlacedAccidental {
  note : Int32
  accidental : Int32
  position : Int32
  column : Int32
}

///|
/// Place a chord's accidentals in columns with three spaces of clearance.
pub fn place_accidentals(
  clef : EngravingClef,
  notes : Array[EngravingNote],
  signs : Array[Int32?],
) -> Array[PlacedAccidental] {
  let ordered : Array[(Int32, Int32, Int32)] = []
  for i, note in notes {
    match signs[i] {
      Some(sign) if sign != 1 =>
        ordered.push((i, sign, staff_position(clef, note.pitch)))
      _ => ()
    }
  }
  ordered.sort_by((a, b) => {
    let cmp = a.2.compare(b.2)
    if cmp != 0 {
      cmp
    } else {
      a.0.compare(b.0)
    }
  })
  let lowest : Array[Int32] = []
  let out : Array[PlacedAccidental] = []
  for (index, sign, position) in ordered {
    let mut col = 0
    while col < lowest.length() && position - lowest[col] < 6 {
      col += 1
    }
    if col == lowest.length() {
      lowest.push(position)
    } else {
      lowest[col] = position
    }
    out.push({ note: index, accidental: sign, position, column: col, })
  }
  out
}
