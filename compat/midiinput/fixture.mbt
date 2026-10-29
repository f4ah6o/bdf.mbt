///|
#export_name("detect")
pub fn detect(data : Bytes) -> Bool {
  @midi.detect(data)
}

///|
#export_name("unwrap")
pub fn unwrap(data : Bytes) -> String {
  try {
    let result = @midi.unwrap_rmid(data)
    Json::object({
      "error": Json::string(""),
      "smf": Json::array(
        result.smf.to_array().map(b => Json::number(b.to_double())),
      ),
      "title": Json::array(
        result.title.to_array().map(b => Json::number(b.to_double())),
      ),
      "copyright": Json::array(
        result.copyright.to_array().map(b => Json::number(b.to_double())),
      ),
    }).stringify()
  } catch {
    @midi.InvalidMidiInput(message) =>
      Json::object({ "error": Json::string(message) }).stringify()
  }
}

///|
#export_name("header")
pub fn header(data : Bytes, tick : Int32) -> String {
  try {
    let h = @midi.read_header(data)
    Json::object({
      "error": Json::string(""),
      "format": Json::number(h.format.to_double()),
      "tracks": Json::number(h.tracks.to_double()),
      "division": Json::number(h.division.to_double()),
      "length": Json::number(h.header_length.to_double()),
      "smpte": Json::boolean(h.smpte),
      "num": Json::number(h.timing_numerator.to_double()),
      "den": Json::number(h.timing_denominator.to_double()),
      "maxTick": Json::number(h.max_tick.to_double()),
      "ppq": Json::number(h.ppq(tick.to_int64()).to_double()),
      "warnings": Json::array(h.warnings.map(Json::string)),
    }).stringify()
  } catch {
    @midi.InvalidMidiInput(message) =>
      Json::object({ "error": Json::string(message) }).stringify()
  }
}

///|
#export_name("varlen")
pub fn varlen(data : Bytes) -> String {
  let (value, count) = @midi.read_varlen(data)
  Json::array([Json::number(value.to_double()), Json::number(count.to_double())]).stringify()
}

///|
#export_name("scan_track")
pub fn scan_track(data : Bytes, max_tick : Int32) -> String {
  let track = @midi.scan_track(data, max_tick.to_int64())
  Json::object({
    "parsed": Json::number(track.parsed.to_double()),
    "sawEnd": Json::boolean(track.saw_end),
    "damaged": Json::boolean(track.damaged),
    "endTick": Json::number(track.end_tick.to_double()),
    "problem": Json::string(track.problem),
  }).stringify()
}

///|
#export_name("track_notes")
pub fn track_notes(data : Bytes, max_tick : Int32) -> String {
  let reader = @midi.MidiTrackReader::new()
  try {
    let track = @midi.scan_track(data, max_tick.to_int64())
    let result = reader.read(track, 0)
    let notes : Array[Json] = []
    let controls : Array[Json] = []
    for ch in 0..<16 {
      for note in result.notes {
        if note.channel == ch {
          notes.push(
            Json::array([
              Json::number(ch.to_double()),
              Json::number(note.on.to_double()),
              Json::number(note.off.to_double()),
              Json::number(note.key.to_double()),
              Json::number(note.velocity.to_double()),
            ]),
          )
        }
      }
      for control in result.controls {
        if control.channel == ch {
          controls.push(
            Json::array([
              Json::number(ch.to_double()),
              Json::number(control.tick.to_double()),
              Json::number(control.kind.to_double()),
              Json::number(control.number.to_double()),
              Json::number(control.value.to_double()),
            ]),
          )
        }
      }
    }
    Json::object({
      "error": Json::string(""),
      "notes": Json::array(notes),
      "controls": Json::array(controls),
      "warnings": Json::array(reader.warnings().map(Json::string)),
    }).stringify()
  } catch {
    @midi.InvalidMidiInput(message) =>
      Json::object({ "error": Json::string(message) }).stringify()
  }
}

///|
#export_name("read_file")
pub fn read_file(data : Bytes) -> String {
  try {
    let file = @midi.read_file(data)
    let smf = match file.smf {
      Some(bytes) =>
        Json::array(bytes.to_array().map(b => Json::number(b.to_double())))
      None => Json::null()
    }
    Json::object({
      "error": Json::string(""),
      "format": Json::number(file.header.format.to_double()),
      "tracks": Json::number(file.tracks.length().to_double()),
      "smf": smf,
      "warnings": Json::array(file.warnings.map(Json::string)),
    }).stringify()
  } catch {
    @midi.InvalidMidiInput(message) =>
      Json::object({ "error": Json::string(message) }).stringify()
  }
}
