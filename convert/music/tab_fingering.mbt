///|
/// Simultaneous notes sharing an absolute score tick.
pub(all) struct GuitarOnset {
  tick : Int64
  notes : Array[GuitarNote]
}

///|
/// Selected note positions and the number that could not be placed.
pub(all) struct GuitarFingering {
  positions : Map[Int32, GuitarPosition]
  omitted : Int32
}

///|
priv struct GuitarState {
  cost : Double
  previous : Int32
  shape : Int32
  held : Array[Int64]
  frets : Array[Int32]
  order : Int32
}

///|
priv struct GuitarStep {
  notes : Array[GuitarNote]
  shapes : Array[GuitarShape]
  states : Array[GuitarState]
}

///|
fn guitar_transition(
  a : GuitarShape,
  b : GuitarShape,
  preset : GuitarPreset,
) -> Double {
  let mut move = Int32::abs(a.base - b.base).to_double()
  for current in b.positions {
    let mut nearest = 1.7976931348623157e308
    for previous in a.positions {
      let fret = Int32::abs(current.fret - previous.fret).to_double()
      let string = Int32::abs(current.string - previous.string).to_double()
      let distance = music_mul_add(0.35, string, 0.22 * fret)
      nearest = Double::min(nearest, distance)
    }
    move += nearest / b.positions.length().to_double()
  }
  preset.shift * move
}

///|
fn GuitarState::place(
  self : GuitarState,
  notes : Array[GuitarNote],
  shape : GuitarShape,
  tick : Int64,
  limit : Int32,
) -> Bool {
  for i, end in self.held {
    if end <= tick {
      self.held[i] = 0L
      self.frets[i] = 0
    }
  }
  for i, position in shape.positions {
    let string = position.string - 1
    if self.held[string] > tick {
      return false
    }
    self.held[string] = Int64::max(notes[i].end, tick + 1L)
    self.frets[string] = position.fret
  }
  let mut minimum = 25
  let mut maximum = 0
  for i, end in self.held {
    if end > tick && self.frets[i] > 0 {
      minimum = Int32::min(minimum, self.frets[i])
      maximum = Int32::max(maximum, self.frets[i])
    }
  }
  minimum == 25 || maximum - minimum <= limit
}

///|
fn guitar_advance(
  shapes : Array[GuitarShape],
  notes : Array[GuitarNote],
  steps : Array[GuitarStep],
  tick : Int64,
  preset : GuitarPreset,
) -> Array[GuitarState] {
  let states : Array[GuitarState] = []
  for i, shape in shapes {
    if steps.is_empty() {
      let state : GuitarState = {
        cost: shape.cost,
        previous: -1,
        shape: i,
        held: [0L, 0L, 0L, 0L, 0L, 0L],
        frets: [0, 0, 0, 0, 0, 0],
        order: states.length(),
      }
      if state.place(notes, shape, tick, preset.span_limit) {
        states.push(state)
      }
    } else {
      let last = steps[steps.length() - 1]
      for j, previous in last.states {
        let state : GuitarState = {
          cost: previous.cost +
          shape.cost +
          guitar_transition(last.shapes[previous.shape], shape, preset),
          previous: j,
          shape: i,
          held: previous.held.copy(),
          frets: previous.frets.copy(),
          order: states.length(),
        }
        if state.place(notes, shape, tick, preset.span_limit) {
          states.push(state)
        }
      }
    }
  }
  states
}

///|
/// Choose bounded dynamic-programming fingerings across the entire part.
pub fn choose_guitar_fingering(
  onsets : Array[GuitarOnset],
  preset : GuitarPreset,
) -> GuitarFingering {
  let positions : Map[Int32, GuitarPosition] = Map([])
  let steps : Array[GuitarStep] = []
  let mut omitted = 0
  for onset in onsets {
    let notes : Array[GuitarNote] = []
    for note in onset.notes {
      if guitar_candidates(note, true).is_empty() {
        omitted += 1
      } else {
        notes.push(note)
      }
    }
    let mut shapes = guitar_shapes(notes, preset, false)
    let mut states = guitar_advance(shapes, notes, steps, onset.tick, preset)
    if states.is_empty() {
      shapes = guitar_shapes(notes, preset, true)
      states = guitar_advance(shapes, notes, steps, onset.tick, preset)
    }
    if states.is_empty() {
      omitted += notes.length()
      continue
    }
    states.sort_by((a, b) => {
      let c = a.cost.compare(b.cost)
      if c == 0 {
        a.order.compare(b.order)
      } else {
        c
      }
    })
    if states.length() > 32 {
      states.truncate(32)
    }
    steps.push({ notes, shapes, states, })
  }
  let mut best = 0
  for i = steps.length() - 1; i >= 0; i = i - 1 {
    let step = steps[i]
    let state = step.states[best]
    for j, note in step.notes {
      positions[note.id] = step.shapes[state.shape].positions[j]
    }
    best = state.previous
  }
  { positions, omitted, }
}
