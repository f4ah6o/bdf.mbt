///|
/// General MIDI channel program and controller values.
pub(all) struct ChannelState {
  mut program : Int32
  mut volume : Int32
  mut expression : Int32
  mut pan : Int32
  mut duty : Int32
  mut sustain : Bool
  mut bend : Int32
} derive(Eq, Debug)

///|
/// Initial General MIDI controller state.
pub fn initial_channel() -> ChannelState {
  {
    program: 0,
    volume: 100,
    expression: 127,
    pan: 64,
    duty: 0,
    sustain: false,
    bend: 0,
  }
}

///|
/// Apply a program, pitch bend or supported controller; return whether it changed the state.
pub fn apply_channel_event(
  state : ChannelState,
  event : @core.MidiMessage,
) -> Bool {
  match event {
    Program(program~, ..) => {
      state.program = program
      true
    }
    Bend(value~, ..) => {
      state.bend = value
      true
    }
    Control(controller~, value~, ..) =>
      match controller {
        7 => {
          state.volume = value
          true
        }
        10 => {
          state.pan = value
          true
        }
        11 => {
          state.expression = value
          true
        }
        64 => {
          state.sustain = value >= 64
          true
        }
        70 => {
          state.duty = value
          true
        }
        121 => {
          state.expression = 127
          state.sustain = false
          state.bend = 0
          true
        }
        _ => false
      }
    _ => false
  }
}

///|
/// Reconstruct all channel states from events preceding the given index.
pub fn channel_states(
  events : Array[@core.MidiEvent],
  end : Int32,
) -> Array[ChannelState] {
  let states = [ for _ in 0..<16 => initial_channel() ]
  for i in 0..<end {
    match events[i].message {
      Program(channel~, ..) | Control(channel~, ..) | Bend(channel~, ..) =>
        ignore(apply_channel_event(states[channel], events[i].message))
      _ => ()
    }
  }
  states
}

///|
/// The square lead's pulse duty for MIDI controller 70.
pub fn pulse_duty(value : Int32) -> Double {
  if value < 32 {
    0.5
  } else if value < 64 {
    0.125
  } else if value < 96 {
    0.25
  } else {
    0.75
  }
}

///|
/// An oscillator sound, envelope, and optional low-pass filter coefficients.
pub(all) struct SynthPatch {
  wave : String
  gain : Double
  attack : Double
  decay : Double
  sustain : Double
  release : Double
  filter : (Double, Double)?
} derive(Eq, Debug)

///|
fn patch(
  wave : String,
  gain : Double,
  attack : Double,
  decay : Double,
  sustain : Double,
  release : Double,
  filter : (Double, Double)?,
) -> SynthPatch {
  { wave, gain, attack, decay, sustain, release, filter, }
}

///|
/// Choose the synthesized instrument for a General MIDI program.
pub fn patch_of(program : Int32) -> SynthPatch {
  if program < 8 {
    patch("piano", 0.7, 0.004, 0.9, 0.0, 0.08, Some((6.0, 600.0)))
  } else if program < 16 {
    patch("sine", 0.8, 0.002, 0.35, 0.0, 0.05, None)
  } else if program < 24 {
    patch("organ", 0.42, 0.01, 0.1, 1.0, 0.04, None)
  } else if program < 32 {
    patch("sawtooth", 0.5, 0.003, 0.45, 0.0, 0.06, Some((3.0, 400.0)))
  } else if program < 40 {
    patch("sawtooth", 0.6, 0.005, 0.5, 0.35, 0.06, Some((2.0, 200.0)))
  } else if program < 52 || program == 55 {
    patch("sawtooth", 0.3, 0.08, 0.5, 0.85, 0.2, Some((3.0, 800.0)))
  } else if program < 55 {
    patch("triangle", 0.55, 0.1, 0.5, 0.9, 0.25, None)
  } else if program < 64 {
    patch("sawtooth", 0.35, 0.03, 0.3, 0.8, 0.08, Some((5.0, 300.0)))
  } else if program < 72 {
    patch("square", 0.28, 0.02, 0.2, 0.9, 0.06, Some((4.0, 300.0)))
  } else if program < 79 {
    patch("triangle", 0.6, 0.04, 0.2, 0.9, 0.08, None)
  } else if program == 79 {
    patch("sine", 0.6, 0.03, 0.2, 0.95, 0.06, None)
  } else if program == 80 {
    patch("pulse", 0.28, 0.002, 0.1, 1.0, 0.01, None)
  } else if program == 81 {
    patch("sawtooth", 0.3, 0.002, 0.1, 1.0, 0.01, None)
  } else if program == 82 {
    patch("triangle", 0.4, 0.002, 0.1, 1.0, 0.01, None)
  } else if program < 88 {
    patch("sawtooth", 0.3, 0.005, 0.3, 0.9, 0.05, Some((4.0, 500.0)))
  } else if program < 96 {
    patch("sawtooth", 0.22, 0.3, 1.0, 0.8, 0.5, Some((2.0, 600.0)))
  } else if program < 104 {
    patch("triangle", 0.42, 0.08, 1.0, 0.7, 0.5, None)
  } else if program < 112 {
    patch("sawtooth", 0.5, 0.003, 0.45, 0.0, 0.06, Some((3.0, 400.0)))
  } else if program < 120 {
    patch("sine", 0.8, 0.002, 0.25, 0.0, 0.05, None)
  } else if program == 122 {
    patch("noise", 0.35, 0.002, 0.1, 1.0, 0.01, None)
  } else {
    patch("noise", 0.42, 0.005, 0.3, 0.6, 0.06, None)
  }
}
