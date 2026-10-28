///|
fn event_json(event : @core.MidiEvent) -> Json {
  let tick = event.tick
  let time = event.time
  let track = event.track
  match event.message {
    Note(channel~, key~, velocity~, duration~, end_tick~) =>
      {
        "type": "note",
        "tick": tick,
        "time": time,
        "track": track,
        "channel": channel,
        "key": key,
        "velocity": velocity,
        "duration": duration,
        "endTick": end_tick,
      }
    Program(channel~, program~) =>
      {
        "type": "program",
        "tick": tick,
        "time": time,
        "track": track,
        "channel": channel,
        "program": program,
      }
    Control(channel~, controller~, value~) =>
      {
        "type": "control",
        "tick": tick,
        "time": time,
        "track": track,
        "channel": channel,
        "controller": controller,
        "value": value,
      }
    Bend(channel~, value~) =>
      {
        "type": "bend",
        "tick": tick,
        "time": time,
        "track": track,
        "channel": channel,
        "value": value,
      }
    Tempo(tempo) =>
      {
        "type": "tempo",
        "tick": tick,
        "time": time,
        "track": track,
        "tempo": tempo,
      }
    TimeSignature(numerator~, denominator~) =>
      {
        "type": "timeSignature",
        "tick": tick,
        "time": time,
        "track": track,
        "numerator": numerator,
        "denominator": denominator,
      }
    KeySignature(key~, minor~) =>
      {
        "type": "keySignature",
        "tick": tick,
        "time": time,
        "track": track,
        "key": key,
        "minor": minor,
      }
  }
}

///|
fn inspect_smf_impl(data : Bytes) -> String raise {
  let seq = @core.parse_smf(data)
  let events : Array[Json] = [ for event in seq.events => event_json(event) ]
  let tempos : Array[Json] = [
    for point in seq.tempos => {
      { "tick": point.tick, "time": point.time, "tempo": point.tempo }
    }
  ]
  let result : Json = {
    "format": seq.format,
    "division": seq.division,
    "smpte": seq.smpte,
    "tracks": seq.tracks,
    "events": events,
    "tempos": tempos,
    "ticks": seq.ticks,
    "duration": seq.duration,
  }
  result.stringify()
}

///|
fn inspect_cues_impl(data : Bytes) -> String raise {
  let cues = @core.decode_cues(data)
  cues_json(cues).stringify()
}

///|
fn cues_json(cues : @core.Cues) -> Json {
  let systems : Array[Json] = [
    for s in cues.systems => {
      {
        "page": s.page.to_double(),
        "x": s.x,
        "y": s.y,
        "w": s.width,
        "h": s.height,
      }
    }
  ]
  let entries : Array[Json] = [
    for c in cues.cues => {
      { "tick": c.tick.to_double(), "system": c.system.to_double(), "x": c.x }
    }
  ]
  let result : Json = { "systems": systems, "cues": entries }
  result
}

///|
fn inspect_document_music_impl(data : Bytes) -> String raise {
  let document = @core.open_single(data)
  let view = document.manifest.views[0]
  match document.play(view) {
    None => Json::null().stringify()
    Some(music) => {
      let bytes : Array[Int32] = [ for b in music.seq => b.to_int() ]
      let cues = match music.cues {
        Some(value) => cues_json(value)
        None => Json::null()
      }
      let result : Json = { "seq": bytes, "cues": cues }
      result.stringify()
    }
  }
}

///|
fn inspect_times_impl(
  data : Bytes,
  tick : Double,
  seconds : Double,
) -> String raise {
  let seq = @core.parse_smf(data)
  let result : Json = {
    "seconds": @core.tick_to_seconds(seq, tick),
    "tick": @core.seconds_to_tick(seq, seconds),
    "at": @render.midi_event_at(seq.events, seconds),
    "due": @render.midi_due(seq.events, 0, seconds),
    "ends": @render.sounding_ends(seq.events, end=seq.duration),
  }
  result.stringify()
}

///|
fn cursor_json(cursor : @render.MusicCursor?) -> Json {
  match cursor {
    None => Json::null()
    Some(c) =>
      match c.width {
        Some(width) =>
          {
            "page": c.page.to_double(),
            "system": c.system.to_double(),
            "x": c.x,
            "y": c.y,
            "h": c.height,
            "w": width,
          }
        None =>
          {
            "page": c.page.to_double(),
            "system": c.system.to_double(),
            "x": c.x,
            "y": c.y,
            "h": c.height,
          }
      }
  }
}

///|
fn optional_number(value : Double?) -> Json {
  match value {
    Some(number) => Json::number(number)
    None => Json::null()
  }
}

///|
fn inspect_cue_position_impl(
  data : Bytes,
  tick : Double,
  system : UInt32,
  x : Double,
  near : Double,
) -> String raise {
  let cues = @core.decode_cues(data)
  let position = @render.tick_at(cues, system, x, near~)
  let line = @render.time_of_line(cues, system, near~)
  let result : Json = {
    "cursor": cursor_json(@render.cursor_at_tick(cues, tick)),
    "line": cursor_json(@render.line_at_time(cues, tick)),
    "tickAt": optional_number(position),
    "lineTime": optional_number(line),
  }
  result.stringify()
}

///|
extern "js" fn throw_music_error(message : String) -> String =
  #|(message) => { throw new Error(message); }

///|
#export_name("inspect_smf")
pub fn inspect_smf(data : Bytes) -> String {
  inspect_smf_impl(data) catch {
    error => throw_music_error(error.to_string())
  }
}

///|
#export_name("inspect_document_music")
pub fn inspect_document_music(data : Bytes) -> String {
  inspect_document_music_impl(data) catch {
    error => throw_music_error(error.to_string())
  }
}

///|
#export_name("inspect_cues")
pub fn inspect_cues(data : Bytes) -> String {
  inspect_cues_impl(data) catch {
    error => throw_music_error(error.to_string())
  }
}

///|
#export_name("inspect_times")
pub fn inspect_times(data : Bytes, tick : Double, seconds : Double) -> String {
  inspect_times_impl(data, tick, seconds) catch {
    error => throw_music_error(error.to_string())
  }
}

///|
#export_name("inspect_cue_position")
pub fn inspect_cue_position(
  data : Bytes,
  tick : Double,
  system : UInt32,
  x : Double,
  near : Double,
) -> String {
  inspect_cue_position_impl(data, tick, system, x, near) catch {
    error => throw_music_error(error.to_string())
  }
}
