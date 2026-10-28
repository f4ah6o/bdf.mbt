///|
/// JavaScript options for the MIDI player, or null for defaults.
#external
pub type BrowserMusicOptions

///|
/// A JavaScript MIDI player with transport and cue methods.
#external
pub type BrowserMusicPlayer

///|
extern "js" fn new_music_handle(
  cues : BrowserAudioCues,
  options : BrowserMusicOptions,
) -> BrowserMusicPlayer =
  #|(cues,options) => ({cues:cues??null,options:options??{},onUpdate:undefined,onEnd:undefined,timer:undefined})

///|
extern "js" fn music_cues(handle : BrowserMusicPlayer) -> BrowserAudioCues =
  #|(handle) => handle.cues

///|
extern "js" fn music_option(
  handle : BrowserMusicPlayer,
  key : String,
  fallback : Double,
) -> Double =
  #|(handle,key,fallback) => handle.options[key]??fallback

///|
extern "js" fn music_context(handle : BrowserMusicPlayer) -> SynthContext =
  #|(handle) => handle.options.context?.()??new AudioContext({latencyHint:'interactive'})

///|
extern "js" fn music_resume(ctx : SynthContext) -> @js_async.Promise[Unit] =
  #|(ctx) => ctx.state==='suspended'?ctx.resume():Promise.resolve()

///|
extern "js" fn music_now(ctx : SynthContext) -> Double =
  #|(ctx) => ctx.currentTime

///|
extern "js" fn music_latency(ctx : SynthContext) -> Double =
  #|(ctx) => ctx.outputLatency||0

///|
extern "js" fn music_hidden() -> Bool =
  #|() => typeof document!=='undefined'&&document.hidden

///|
extern "js" fn music_close(ctx : SynthContext) -> Unit =
  #|(ctx) => {ctx.close().catch(()=>{})}

///|
extern "js" fn music_clear_timer(handle : BrowserMusicPlayer) -> Unit =
  #|(handle) => {clearInterval(handle.timer);handle.timer=undefined}

///|
extern "js" fn music_timer(
  handle : BrowserMusicPlayer,
  callback : () -> Unit,
  milliseconds : Double,
) -> Unit =
  #|(handle,callback,milliseconds) => {handle.timer=setInterval(callback,milliseconds)}

///|
extern "js" fn music_notify(handle : BrowserMusicPlayer) -> Unit =
  #|(handle) => handle.onUpdate?.()

///|
extern "js" fn music_notify_end(handle : BrowserMusicPlayer) -> Unit =
  #|(handle) => handle.onEnd?.()

///|
extern "js" fn music_resolved() -> @js_async.Promise[Unit] =
  #|() => Promise.resolve()

///|
extern "js" fn music_ceil(value : Double) -> Double =
  #|(value) => Math.ceil(value)

///|
extern "js" fn music_min(a : Double, b : Double) -> Double =
  #|(a,b) => Math.min(a,b)

///|
extern "js" fn music_max(a : Double, b : Double) -> Double =
  #|(a,b) => Math.max(a,b)

///|
priv struct MeterPoint {
  tick : Double
  numerator : Int32
  denominator : Int32
}

///|
priv struct MusicState {
  handle : BrowserMusicPlayer
  sequence : @core.MidiSequence
  ends : Array[Double]
  meters : Array[MeterPoint]
  mut context : SynthContext?
  mut synth : BrowserSynth?
  mut current : String
  mut from : Double
  mut at : Double
  mut held : Double
  mut next : Int32
  mut click_tick : Double
  mut click_meter : Int32
  mut click_beat : Double
  mut click_enabled : Bool
  mut speed : Double
  mut scale : Double
}

///|
fn MusicState::duration(self : MusicState) -> Double {
  self.sequence.duration * self.scale
}

///|
fn MusicState::clock(self : MusicState, lag : Double) -> Double {
  match self.context {
    None => self.held
    Some(ctx) =>
      music_min(
        self.duration(),
        self.from + music_max(0.0, music_now(ctx) - lag - self.at),
      )
  }
}

///|
fn MusicState::position(self : MusicState) -> Double {
  if self.current != "playing" {
    return self.held
  }
  match self.context {
    Some(ctx) => self.clock(music_latency(ctx))
    None => self.held
  }
}

///|
fn MusicState::reset_click(self : MusicState, tick : Double) -> Unit {
  let mut lo = 0
  let mut hi = self.meters.length()
  while lo < hi {
    let mid = (lo + hi) / 2
    if self.meters[mid].tick <= tick {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  self.click_meter = if lo > 0 { lo - 1 } else { 0 }
  let meter = self.meters[self.click_meter]
  let step = self.sequence.division * 4.0 / meter.denominator.to_double()
  let step = music_max(1.0, step)
  let beat = music_ceil((tick - meter.tick) / step - 0.000000001)
  self.click_beat = music_max(0.0, beat)
  self.click_tick = meter.tick + self.click_beat * step
  if self.meters.get(self.click_meter + 1) is Some(next) &&
    self.click_tick >= next.tick - 0.000000001 {
    self.click_meter += 1
    self.click_beat = 0.0
    self.click_tick = next.tick
  }
}

///|
extern "js" fn music_beat_accent(beat : Double, numerator : Int32) -> Bool =
  #|(beat,numerator) => beat%numerator===0

///|
fn MusicState::schedule_click(
  self : MusicState,
  until : Double,
  synth : BrowserSynth,
) -> Unit {
  if !self.click_enabled || self.sequence.smpte {
    return
  }
  for _ in 0..<4096 {
    let time = @core.tick_to_seconds(self.sequence, self.click_tick) *
      self.scale
    if time >= self.duration() || time >= until {
      return
    }
    let meter = self.meters[self.click_meter]
    synth.click(
      music_beat_accent(self.click_beat, meter.numerator),
      self.at + time - self.from,
    )
    self.click_beat += 1.0
    let step = self.sequence.division * 4.0 / meter.denominator.to_double()
    self.click_tick += music_max(1.0, step)
    if self.meters.get(self.click_meter + 1) is Some(next) &&
      self.click_tick >= next.tick - 0.000000001 {
      self.click_meter += 1
      self.click_beat = 0.0
      self.click_tick = next.tick
    }
  }
}

///|
fn MusicState::schedule(self : MusicState) -> Unit {
  if self.current != "playing" {
    return
  }
  guard self.synth is Some(synth) else { return }
  if self.position() >= self.duration() {
    self.finish()
    return
  }
  let ahead = music_option(self.handle, "lookahead", 0.15)
  let ahead = if music_hidden() && ahead < 1.0 { 1.0 } else { ahead }
  let until = self.clock(0.0) + ahead
  let end = @render.midi_due(
    self.sequence.events,
    self.next,
    until / self.scale,
  )
  while self.next < end {
    let i = self.next
    let e = self.sequence.events[i]
    let when = self.at + e.time * self.scale - self.from
    match e.message {
      Note(channel~, key~, velocity~, ..) =>
        synth.note(
          channel,
          key,
          velocity,
          when,
          self.at + self.ends[i] * self.scale - self.from,
          0.0,
        )
      _ => synth.event(e, when)
    }
    self.next += 1
  }
  self.schedule_click(until, synth)
}

///|
fn MusicState::start(self : MusicState, from : Double) -> Unit {
  guard self.context is Some(ctx) else { return }
  guard self.synth is Some(synth) else { return }
  music_clear_timer(self.handle)
  self.from = from
  self.at = music_now(ctx) + 0.05
  let file_time = from / self.scale
  self.next = @render.midi_event_at(self.sequence.events, file_time)
  self.reset_click(@core.seconds_to_tick(self.sequence, file_time))
  synth.reset(@render.channel_states(self.sequence.events, self.next), self.at)
  for i in 0..<self.next {
    let event = self.sequence.events[i]
    if event.message is Note(channel~, key~, velocity~, ..) &&
      channel != 9 &&
      self.ends[i] > file_time + 0.02 {
      synth.note(
        channel,
        key,
        velocity,
        self.at,
        self.at + (self.ends[i] - file_time) * self.scale,
        (file_time - event.time) * self.scale,
      )
    }
  }
  music_timer(
    self.handle,
    () => self.schedule(),
    music_option(self.handle, "interval", 30.0),
  )
  self.schedule()
}

///|
fn MusicState::halt(self : MusicState) -> Unit {
  music_clear_timer(self.handle)
  if self.synth is Some(synth) {
    synth.silence()
  }
}

///|
fn MusicState::finish(self : MusicState) -> Unit {
  music_clear_timer(self.handle)
  self.current = "stopped"
  self.held = 0.0
  music_notify(self.handle)
  music_notify_end(self.handle)
}

///|
fn MusicState::play(self : MusicState) -> @js_async.Promise[Unit] {
  if self.current == "playing" {
    return music_resolved()
  }
  let ctx = match self.context {
    Some(ctx) => ctx
    None => {
      let ctx = music_context(self.handle)
      let synth = BrowserSynth::new(
        ctx,
        music_option(self.handle, "volume", 0.5),
      )
      self.context = Some(ctx)
      self.synth = Some(synth)
      ctx
    }
  }
  let running = music_resume(ctx)
  self.current = "playing"
  self.start(if self.held >= self.duration() { 0.0 } else { self.held })
  if self.current == "playing" {
    music_notify(self.handle)
  }
  running
}

///|
fn MusicState::pause(self : MusicState) -> Unit {
  if self.current != "playing" {
    return
  }
  self.held = self.position()
  self.halt()
  self.current = "paused"
  music_notify(self.handle)
}

///|
fn MusicState::stop(self : MusicState) -> Unit {
  if self.current == "stopped" {
    return
  }
  self.halt()
  self.current = "stopped"
  self.held = 0.0
  music_notify(self.handle)
}

///|
extern "js" fn music_clamp_seek(seconds : Double, duration : Double) -> Double =
  #|(seconds,duration) => Math.max(0,Math.min(duration,seconds))

///|
fn MusicState::seek(self : MusicState, seconds : Double) -> Unit {
  let t = music_clamp_seek(seconds, self.duration())
  if self.current == "playing" {
    if self.synth is Some(synth) {
      synth.silence()
    }
    self.start(t)
  } else {
    self.held = t
    self.current = "paused"
  }
  music_notify(self.handle)
}

///|
fn MusicState::set_speed(self : MusicState, value : Double) -> Unit {
  let next = audio_normal_speed(value)
  if next <= 0.0 || next == self.speed {
    return
  }
  let was_playing = self.current == "playing"
  let was_paused = self.current == "paused"
  let tick = @core.seconds_to_tick(self.sequence, self.position() / self.scale)
  self.speed = next
  self.scale = 100.0 / next
  let at = @core.tick_to_seconds(self.sequence, tick) * self.scale
  if was_playing {
    if self.synth is Some(synth) {
      synth.silence()
    }
    self.start(at)
  } else if was_paused {
    self.held = at
  }
  music_notify(self.handle)
}

///|
fn MusicState::set_metronome(self : MusicState, enabled : Bool) -> Unit {
  self.click_enabled = enabled && !self.sequence.smpte
  if self.click_enabled && self.current == "playing" {
    self.reset_click(
      @core.seconds_to_tick(self.sequence, self.position() / self.scale),
    )
  }
  if !self.click_enabled {
    if self.synth is Some(synth) {
      synth.clear_click()
    }
  } else {
    self.schedule()
  }
  music_notify(self.handle)
}

///|
fn MusicState::dispose(self : MusicState) -> Unit {
  self.halt()
  self.current = "stopped"
  self.held = 0.0
  if self.synth is Some(synth) {
    synth.silence()
    synth_disconnect(synth.graph)
  }
  if self.context is Some(ctx) {
    music_close(ctx)
  }
  self.context = None
  self.synth = None
}

///|
extern "js" fn music_install(
  handle : BrowserMusicPlayer,
  sequence : BrowserMidiInput,
  base_bpm : Double,
  state : () -> String,
  position : () -> Double,
  duration : () -> Double,
  speed : () -> Double,
  scale : () -> Double,
  metronome : () -> Bool,
  available : Bool,
  play : () -> @js_async.Promise[Unit],
  pause : () -> Unit,
  stop : () -> Unit,
  seek : (Double) -> Unit,
  set_speed : (Double) -> Unit,
  set_metronome : (Bool) -> Unit,
  cursor : (Double) -> BrowserAudioCursor,
  time : (Double, Double) -> BrowserAudioTime,
  dispose : () -> Unit,
) -> Unit =
  #|(h,sequence,baseBpm,state,position,duration,speed,scale,metronome,available,play,pause,stop,seek,setSpeed,setMetronome,cursor,time,dispose) => {
  #| h.sequence=sequence;h.baseBpm=baseBpm;Object.defineProperties(h,{state:{get:state},playing:{get:()=>state()==='playing'},position:{get:position},duration:{get:duration},speedPercent:{get:speed},tempoScale:{get:scale},bpm:{get:()=>baseBpm*speed()/100},bpmAvailable:{get:()=>available},metronomeAvailable:{get:()=>available},metronomeEnabled:{get:metronome}});
  #| Object.assign(h,{play,pause,stop,seek,setSpeedPercent:setSpeed,setMetronome,cursorAt:cursor,timeAt:time,dispose});
  #|}

///|
fn make_music_player(
  data : BrowserMidiInput,
  cues : BrowserAudioCues,
  options : BrowserMusicOptions,
) -> BrowserMusicPlayer raise {
  let sequence = midi_sequence_input(data)
  let exposed = if midi_input_is_bytes(data) {
    midi_sequence_from_json(music_sequence_json(sequence))
  } else {
    data
  }
  let meters : Array[MeterPoint] = [
    { tick: 0.0, numerator: 4, denominator: 4, },
  ]
  for event in sequence.events {
    if event.message is TimeSignature(numerator~, denominator~) {
      let meter : MeterPoint = {
        tick: event.tick,
        numerator: if numerator > 1 {
          numerator
        } else {
          1
        },
        denominator: if denominator > 1 {
          denominator
        } else {
          1
        },
      }
      let last = meters.length() - 1
      if meters[last].tick == meter.tick {
        meters[last] = meter
      } else {
        meters.push(meter)
      }
    }
  }
  let base_bpm = 60000000.0 /
    (match sequence.tempos.get(0) {
      Some(point) => point.tempo.to_double()
      None => 500000.0
    })
  let handle = new_music_handle(cues, options)
  let player : MusicState = {
    handle,
    sequence,
    ends: @render.sounding_ends(sequence.events, end=sequence.duration),
    meters,
    context: None,
    synth: None,
    current: "stopped",
    from: 0.0,
    at: 0.0,
    held: 0.0,
    next: 0,
    click_tick: 0.0,
    click_meter: 0,
    click_beat: 0.0,
    click_enabled: false,
    speed: 100.0,
    scale: 1.0,
  }
  music_install(
    handle,
    exposed,
    base_bpm,
    () => player.current,
    () => player.position(),
    () => player.duration(),
    () => player.speed,
    () => player.scale,
    () => player.click_enabled,
    !sequence.smpte,
    () => player.play(),
    () => player.pause(),
    () => player.stop(),
    seconds => player.seek(seconds),
    value => player.set_speed(value),
    value => player.set_metronome(value),
    seconds => {
      score_cursor(
        music_cues(handle),
        @core.seconds_to_tick(sequence, seconds / player.scale) + 0.000001,
      )
    },
    (system, x) => {
      match
        score_tick_at(
          music_cues(handle),
          system,
          x,
          @core.seconds_to_tick(sequence, player.position() / player.scale),
        ) {
        None => audio_no_time()
        Some(tick) => {
          let seconds = @core.tick_to_seconds(sequence, tick) * player.scale
          audio_time(music_min(player.duration(), seconds))
        }
      }
    },
    () => player.dispose(),
  )
  handle
}

///|
extern "js" fn music_throw(message : String) -> BrowserMusicPlayer =
  #|(message) => {throw new Error(message)}

///|
/// Create a MIDI player from SMF bytes, optional score cues and Web Audio options.
#export_name("bdf_music_player")
pub fn bdf_music_player(
  data : BrowserMidiInput,
  cues : BrowserAudioCues,
  options : BrowserMusicOptions,
) -> BrowserMusicPlayer {
  make_music_player(data, cues, options) catch {
    error => music_throw(error.to_string())
  }
}
