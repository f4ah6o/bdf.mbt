///|
/// MIDI bytes or a parsed upstream-compatible JavaScript MIDI sequence.
#external
pub type BrowserMidiInput

///|
#external
priv type BrowserMidiValue

///|
extern "js" fn midi_input_from_bytes(data : Bytes) -> BrowserMidiInput =
  #|(data) => data

///|
extern "js" fn midi_input_is_bytes(data : BrowserMidiInput) -> Bool =
  #|(data) => data instanceof Uint8Array

///|
extern "js" fn midi_input_bytes(data : BrowserMidiInput) -> Bytes =
  #|(data) => data

///|
extern "js" fn midi_sequence_from_json(data : String) -> BrowserMidiInput =
  #|(data) => JSON.parse(data)

///|
extern "js" fn midi_number(data : BrowserMidiInput, key : String) -> Double =
  #|(data,key) => data[key]

///|
extern "js" fn midi_int(data : BrowserMidiInput, key : String) -> Int32 =
  #|(data,key) => data[key]

///|
extern "js" fn midi_bool(data : BrowserMidiInput, key : String) -> Bool =
  #|(data,key) => data[key]

///|
extern "js" fn midi_count(data : BrowserMidiInput, key : String) -> Int32 =
  #|(data,key) => data[key].length

///|
extern "js" fn midi_item(
  data : BrowserMidiInput,
  key : String,
  i : Int32,
) -> BrowserMidiValue =
  #|(data,key,i) => data[key][i]

///|
extern "js" fn midi_item_number(
  data : BrowserMidiValue,
  key : String,
) -> Double =
  #|(data,key) => data[key]

///|
extern "js" fn midi_item_int(data : BrowserMidiValue, key : String) -> Int32 =
  #|(data,key) => data[key]

///|
extern "js" fn midi_item_bool(data : BrowserMidiValue, key : String) -> Bool =
  #|(data,key) => data[key]

///|
extern "js" fn midi_item_kind(data : BrowserMidiValue) -> String =
  #|(data) => data.type

///|
fn midi_sequence_input(input : BrowserMidiInput) -> @core.MidiSequence raise {
  if midi_input_is_bytes(input) {
    return @core.parse_smf(midi_input_bytes(input))
  }
  let events : Array[@core.MidiEvent] = []
  for i in 0..<midi_count(input, "events") {
    let value = midi_item(input, "events", i)
    let channel = midi_item_int(value, "channel")
    let message : @core.MidiMessage = match midi_item_kind(value) {
      "note" =>
        Note(
          channel~,
          key=midi_item_int(value, "key"),
          velocity=midi_item_int(value, "velocity"),
          duration=midi_item_number(value, "duration"),
          end_tick=midi_item_number(value, "endTick"),
        )
      "program" => Program(channel~, program=midi_item_int(value, "program"))
      "control" =>
        Control(
          channel~,
          controller=midi_item_int(value, "controller"),
          value=midi_item_int(value, "value"),
        )
      "bend" => Bend(channel~, value=midi_item_int(value, "value"))
      "tempo" => Tempo(midi_item_int(value, "tempo"))
      "timeSignature" =>
        TimeSignature(
          numerator=midi_item_int(value, "numerator"),
          denominator=midi_item_int(value, "denominator"),
        )
      "keySignature" =>
        KeySignature(
          key=midi_item_int(value, "key"),
          minor=midi_item_bool(value, "minor"),
        )
      _ => Tempo(500000)
    }
    events.push({
      tick: midi_item_number(value, "tick"),
      time: midi_item_number(value, "time"),
      track: midi_item_int(value, "track"),
      message,
    })
  }
  let tempos : Array[@core.TempoPoint] = []
  for i in 0..<midi_count(input, "tempos") {
    let value = midi_item(input, "tempos", i)
    tempos.push({
      tick: midi_item_number(value, "tick"),
      time: midi_item_number(value, "time"),
      tempo: midi_item_int(value, "tempo"),
    })
  }
  {
    format: midi_int(input, "format"),
    division: midi_number(input, "division"),
    smpte: midi_bool(input, "smpte"),
    tracks: midi_int(input, "tracks"),
    events,
    tempos,
    ticks: midi_number(input, "ticks"),
    duration: midi_number(input, "duration"),
  }
}
