///|
priv struct BrowserSynth {
  graph : SynthGraph
  mut voices : Array[SynthVoice]
  mut states : Array[@render.ChannelState]
}

///|
fn BrowserSynth::new(ctx : SynthContext, volume : Double) -> BrowserSynth {
  {
    graph: synth_graph(ctx, volume),
    voices: [],
    states: [
      for _ in 0..<16 => @render.initial_channel()
    ],
  }
}

///|
fn BrowserSynth::level(
  self : BrowserSynth,
  ch : Int32,
  when : Double,
  jump : Bool,
) -> Unit {
  let s = self.states[ch]
  let volume = s.volume.to_double() / 127.0
  let expression = s.expression.to_double() / 127.0
  let pan = (s.pan.to_double() - 64.0) / 63.0
  synth_level(
    self.graph,
    ch,
    volume * volume * (expression * expression),
    if pan < -1.0 {
      -1.0
    } else if pan > 1.0 {
      1.0
    } else {
      pan
    },
    when,
    jump,
  )
}

///|
fn BrowserSynth::reset(
  self : BrowserSynth,
  states : Array[@render.ChannelState],
  when : Double,
) -> Unit {
  self.states = states
  for i in 0..<16 {
    self.level(i, when, true)
  }
}

///|
fn BrowserSynth::event(
  self : BrowserSynth,
  event : @core.MidiEvent,
  when : Double,
) -> Unit {
  match event.message {
    Program(channel~, ..) | Control(channel~, ..) | Bend(channel~, ..) => {
      let state = self.states[channel]
      if !@render.apply_channel_event(state, event.message) {
        return
      }
      match event.message {
        Control(controller~, ..) if controller == 7 ||
          controller == 10 ||
          controller == 11 ||
          controller == 121 => self.level(channel, when, false)
        _ => ()
      }
      match event.message {
        Bend(..) | Control(controller=121, ..) => {
          let cents = state.bend.to_double() / 8192.0 * 200.0
          for voice in self.voices {
            if voice_channel(voice) == channel && voice_end(voice) > when {
              voice_bend(voice, cents, when)
            }
          }
        }
        _ => ()
      }
    }
    _ => ()
  }
}

///|
fn BrowserSynth::prune(self : BrowserSynth, when : Double) -> Unit {
  let now = synth_now(self.graph)
  let keep : Array[SynthVoice] = []
  for voice in self.voices {
    if voice_end(voice) > now {
      keep.push(voice)
    }
  }
  while keep.length() >= 64 {
    let voice = keep.remove(0)
    voice_release(voice, if when > now { when } else { now }, 0.005)
  }
  self.voices = keep
}

///|
fn BrowserSynth::silence(self : BrowserSynth) -> Unit {
  let now = synth_now(self.graph)
  for voice in self.voices {
    voice_release(voice, now, 0.008)
  }
  self.voices = []
}

///|
fn BrowserSynth::clear_click(self : BrowserSynth) -> Unit {
  let now = synth_now(self.graph)
  let keep : Array[SynthVoice] = []
  for voice in self.voices {
    if voice_channel(voice) == -1 {
      voice_release(voice, now, 0.003)
    } else {
      keep.push(voice)
    }
  }
  self.voices = keep
}

///|
fn BrowserSynth::click(
  self : BrowserSynth,
  accent : Bool,
  when : Double,
) -> Unit {
  self.prune(when)
  self.voices.push(synth_click(self.graph, accent, when))
}

///|
fn BrowserSynth::note(
  self : BrowserSynth,
  ch : Int32,
  key : Int32,
  velocity : Int32,
  when : Double,
  end : Double,
  into : Double,
) -> Unit {
  self.prune(when)
  if ch == 9 {
    self.drum(key, velocity, when)
    return
  }
  let state = self.states[ch]
  let patch = @render.patch_of(state.program)
  let frequency = 440.0 * synth_pow(2.0, (key.to_double() - 69.0) / 12.0)
  let rate0 = synth_pow(2.0, (key.to_double() - 60.0) / 12.0)
  let rate = if rate0 < 0.03125 {
    0.03125
  } else if rate0 > 8.0 {
    8.0
  } else {
    rate0
  }
  let filter = match patch.filter {
    None => -1.0
    Some((mul, add)) => {
      let f = frequency * mul + add
      let limit = synth_rate(self.graph) * 0.45
      if f < limit {
        f
      } else {
        limit
      }
    }
  }
  let vel = velocity.to_double() / 127.0
  let peak = patch.gain * (vel * vel)
  let decay = if patch.sustain == 0.0 {
    patch.decay * synth_pow(2.0, (60.0 - key.to_double()) / 24.0)
  } else {
    patch.decay
  }
  let held = if into > 0.0 {
    when + 0.01
  } else {
    let len = end - when
    let len = if len > 0.001 { len } else { 0.001 }
    when + (if patch.attack < len { patch.attack } else { len })
  }
  let attack_level = if into > 0.0 {
    let elapsed = into - patch.attack
    peak *
    (
      patch.sustain +
      (1.0 - patch.sustain) *
      synth_exp(-(if elapsed > 0.0 { elapsed } else { 0.0 }) / decay)
    )
  } else {
    peak
  }
  let off = if end > held { end } else { held }
  self.voices.push(
    synth_melodic(
      self.graph,
      ch,
      patch.wave,
      frequency,
      rate,
      state.bend.to_double() / 8192.0 * 200.0,
      @render.pulse_duty(state.duty),
      filter,
      peak,
      held,
      attack_level,
      patch.sustain,
      decay,
      off,
      patch.release,
      when,
    ),
  )
}

///|
fn BrowserSynth::drum(
  self : BrowserSynth,
  key : Int32,
  velocity : Int32,
  when : Double,
) -> Unit {
  let voice = synth_drum_new(self.graph, when)
  let v = velocity.to_double() / 127.0
  let v = v * v
  let len = match key {
    35 | 36 => {
      synth_drum_tone(
        self.graph,
        voice,
        "sine",
        150.0,
        45.0,
        0.12,
        2.0 * v,
        0.35,
        when,
      )
      0.35
    }
    38 | 40 => {
      synth_drum_noise(self.graph, voice, "highpass", 1500.0, v, 0.18, when)
      synth_drum_tone(
        self.graph,
        voice,
        "triangle",
        190.0,
        160.0,
        0.05,
        0.8 * v,
        0.09,
        when,
      )
      0.18
    }
    37 => {
      synth_drum_noise(self.graph, voice, "bandpass", 2500.0, v, 0.04, when)
      0.04
    }
    39 => {
      synth_drum_noise(
        self.graph,
        voice,
        "bandpass",
        1200.0,
        2.5 * v,
        0.12,
        when,
      )
      0.12
    }
    42 => {
      synth_drum_noise(
        self.graph,
        voice,
        "highpass",
        7000.0,
        0.6 * v,
        0.05,
        when,
      )
      0.05
    }
    44 => {
      synth_drum_noise(
        self.graph,
        voice,
        "highpass",
        7000.0,
        0.6 * v,
        0.07,
        when,
      )
      0.07
    }
    46 => {
      synth_drum_noise(
        self.graph,
        voice,
        "highpass",
        7000.0,
        0.6 * v,
        0.35,
        when,
      )
      0.35
    }
    41 | 43 | 45 | 47 | 48 | 50 => {
      let f = 70.0 + (key - 41).to_double() * 15.0
      synth_drum_tone(
        self.graph,
        voice,
        "sine",
        f * 1.6,
        f,
        0.15,
        1.6 * v,
        0.35,
        when,
      )
      0.35
    }
    49 | 57 => {
      synth_drum_noise(
        self.graph,
        voice,
        "highpass",
        5000.0,
        0.6 * v,
        1.2,
        when,
      )
      1.2
    }
    51 | 59 => {
      synth_drum_noise(
        self.graph,
        voice,
        "highpass",
        6000.0,
        0.45 * v,
        0.6,
        when,
      )
      0.6
    }
    52 | 55 => {
      synth_drum_noise(
        self.graph,
        voice,
        "highpass",
        4000.0,
        0.6 * v,
        0.8,
        when,
      )
      0.8
    }
    53 => {
      synth_drum_tone(
        self.graph,
        voice,
        "sine",
        820.0,
        800.0,
        0.05,
        0.4 * v,
        0.6,
        when,
      )
      synth_drum_noise(
        self.graph,
        voice,
        "highpass",
        6000.0,
        0.3 * v,
        0.5,
        when,
      )
      0.6
    }
    _ => {
      synth_drum_noise(
        self.graph,
        voice,
        "bandpass",
        300.0 * synth_pow(2.0, (key.to_double() - 35.0) / 12.0),
        0.8 * v,
        0.1,
        when,
      )
      0.1
    }
  }
  synth_drum_finish(voice, when + len + 0.05)
  self.voices.push(voice)
}
