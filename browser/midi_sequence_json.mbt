///|
fn music_event_json(event : @core.MidiEvent) -> Json {
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
fn music_sequence_json(seq : @core.MidiSequence) -> String {
  let events : Array[Json] = [
    for event in seq.events => music_event_json(event)
  ]
  let tempos : Array[Json] = [
    for point in seq.tempos => {
      { "tick": point.tick, "time": point.time, "tempo": point.tempo }
    }
  ]
  let value : Json = {
    "format": seq.format,
    "division": seq.division,
    "smpte": seq.smpte,
    "tracks": seq.tracks,
    "events": events,
    "tempos": tempos,
    "ticks": seq.ticks,
    "duration": seq.duration,
  }
  value.stringify()
}
