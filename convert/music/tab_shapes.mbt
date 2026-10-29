///|
/// A guitar string and fret, with strings numbered from the highest string.
pub(all) struct GuitarPosition {
  string : Int32
  fret : Int32
} derive(Eq, Debug)

///|
/// One sounding note to assign to the guitar.
pub(all) struct GuitarNote {
  id : Int32
  pitch : Int32
  end : Int64
  authored : GuitarPosition?
}

///|
/// A fingering policy for alternative TAB views.
pub(all) struct GuitarPreset {
  id : String
  name : String
  explanation : String
  low : Double
  shift : Double
  open : Double
  high : Double
  span_limit : Int32
}

///|
/// The four upstream guitar fingering policies, in view order.
pub fn guitar_presets() -> Array[GuitarPreset] {
  [
    {
      id: "low",
      name: "Low positions",
      explanation: "Favors notes near the nut",
      low: 1.8,
      shift: 0.65,
      open: 0.2,
      high: 0.6,
      span_limit: 5,
    },
    {
      id: "smooth",
      name: "Less shifting",
      explanation: "Favors a stable hand position across the phrase",
      low: 0.25,
      shift: 4.0,
      open: 0.3,
      high: 0.25,
      span_limit: 5,
    },
    {
      id: "open",
      name: "Open strings",
      explanation: "Favors ringing open strings",
      low: 0.4,
      shift: 1.0,
      open: 5.0,
      high: 0.35,
      span_limit: 5,
    },
    {
      id: "easy",
      name: "Beginner friendly",
      explanation: "Favors low frets, short stretches and open strings",
      low: 2.0,
      shift: 2.0,
      open: 2.0,
      high: 2.0,
      span_limit: 4,
    },
  ]
}

///|
pub(all) struct GuitarCandidate {
  position : GuitarPosition
  penalty : Double
}

///|
/// Enumerate string/fret positions in standard tuning for a pitch.
pub fn guitar_candidates(
  note : GuitarNote,
  relaxed : Bool,
) -> Array[GuitarCandidate] {
  let out : Array[GuitarCandidate] = []
  let authored = match note.authored {
    Some(pos) if pos.string >= 1 &&
      pos.string <= 6 &&
      pos.fret >= 0 &&
      pos.fret <= 24 => Some(pos)
    _ => None
  }
  match authored {
    Some(pos) => {
      out.push({ position: pos, penalty: 0.0, })
      if !relaxed {
        return out
      }
    }
    None => ()
  }
  for i, open in [64, 59, 55, 50, 45, 40] {
    let fret = note.pitch - open
    if fret < 0 || fret > 24 {
      continue
    }
    let position : GuitarPosition = { string: i + 1, fret, }
    if authored == Some(position) {
      continue
    }
    out.push({
      position,
      penalty: if authored is Some(_) {
        100.0
      } else {
        0.0
      },
    })
  }
  out
}

///|
/// A chord fingering with its static cost and base fret.
pub(all) struct GuitarShape {
  positions : Array[GuitarPosition]
  cost : Double
  base : Int32
}

///|
priv struct GuitarChoice {
  index : Int32
  candidates : Array[GuitarCandidate]
}

///|
priv struct GuitarShapeBuilder {
  choices : Array[GuitarChoice]
  positions : Array[GuitarPosition]
  shapes : Array[GuitarShape]
  preset : GuitarPreset
}

///|
fn GuitarShapeBuilder::visit(
  self : GuitarShapeBuilder,
  index : Int32,
  used : Int32,
  minimum : Int32,
  maximum : Int32,
  penalty : Double,
) -> Unit {
  if index == self.choices.length() {
    let base = if minimum <= 24 { minimum } else { 0 }
    let high = Int32::max(0, maximum - 12).to_double()
    let mut cost = penalty +
      self.preset.low * base.to_double() +
      self.preset.high * (high * high)
    for position in self.positions {
      if position.fret == 0 {
        cost -= self.preset.open
      }
    }
    self.shapes.push({ positions: self.positions.copy(), cost, base, })
    if self.shapes.length() >= 128 {
      let indexed : Array[(Int32, GuitarShape)] = [
        for i, shape in self.shapes => (i, shape)
      ]
      indexed.sort_by((a, b) => {
        let c = a.1.cost.compare(b.1.cost)
        if c == 0 {
          a.0.compare(b.0)
        } else {
          c
        }
      })
      self.shapes.clear()
      for i in 0..<64 {
        self.shapes.push(indexed[i].1)
      }
    }
    return
  }
  let choice = self.choices[index]
  for candidate in choice.candidates {
    let position = candidate.position
    let bit = 1 << (position.string - 1)
    if (used & bit) != 0 {
      continue
    }
    let lo = if position.fret > 0 {
      Int32::min(minimum, position.fret)
    } else {
      minimum
    }
    let hi = if position.fret > 0 {
      Int32::max(maximum, position.fret)
    } else {
      maximum
    }
    if lo <= 24 && hi - lo > self.preset.span_limit {
      continue
    }
    self.positions[choice.index] = position
    self.visit(index + 1, used | bit, lo, hi, penalty + candidate.penalty)
  }
}

///|
/// Enumerate up to 64 playable chord shapes, sorted by cost and position.
pub fn guitar_shapes(
  notes : Array[GuitarNote],
  preset : GuitarPreset,
  relaxed : Bool,
) -> Array[GuitarShape] {
  if notes.is_empty() || notes.length() > 6 {
    return []
  }
  let choices : Array[GuitarChoice] = []
  let positions : Array[GuitarPosition] = []
  for i, note in notes {
    let candidates = guitar_candidates(note, relaxed)
    if candidates.is_empty() {
      return []
    }
    choices.push({ index: i, candidates, })
    positions.push({ string: 0, fret: 0, })
  }
  choices.sort_by((a, b) => {
    let c = a.candidates.length().compare(b.candidates.length())
    if c == 0 {
      a.index.compare(b.index)
    } else {
      c
    }
  })
  let builder : GuitarShapeBuilder = { choices, positions, shapes: [], preset, }
  builder.visit(0, 0, 25, 0, 0.0)
  builder.shapes.sort_by((a, b) => {
    let c = a.cost.compare(b.cost)
    if c != 0 {
      return c
    }
    for i in 0..<a.positions.length() {
      let s = a.positions[i].string.compare(b.positions[i].string)
      if s != 0 {
        return s
      }
      let f = a.positions[i].fret.compare(b.positions[i].fret)
      if f != 0 {
        return f
      }
    }
    0
  })
  if builder.shapes.length() > 64 {
    builder.shapes.truncate(64)
  }
  builder.shapes
}
