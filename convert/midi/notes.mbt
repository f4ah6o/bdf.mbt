///|
/// A note in the original file's tick units.
pub(all) struct MidiRawNote {
  channel : Int32
  key : Int32
  velocity : Int32
  on : Int64
  off : Int64
}

///|
/// A retained MIDI program, controller, or pitch-bend change.
/// `kind` is 0 for program, 1 for controller, and 2 for pitch bend.
pub(all) struct MidiRawControl {
  channel : Int32
  tick : Int64
  kind : Int32
  number : Int32
  value : Int32
}

///|
pub(all) struct MidiRawText {
  tick : Int64
  kind : Int32
  data : Bytes
}

///|
pub(all) struct MidiRawTempo {
  tick : Int64
  bpm : Double
}

///|
pub(all) struct MidiRawTime {
  tick : Int64
  beats : Int32
  beat_type : Int32
}

///|
pub(all) struct MidiRawKey {
  tick : Int64
  fifths : Int32
  minor : Bool
}

///|
pub(all) struct MidiTrackNotes {
  notes : Array[MidiRawNote]
  controls : Array[MidiRawControl]
  name : Bytes
  instrument : Bytes
  copyright : Bytes
  channel_names : Array[Bytes]
  texts : Array[MidiRawText]
  tempos : Array[MidiRawTempo]
  times : Array[MidiRawTime]
  keys : Array[MidiRawKey]
}

///|
priv struct PendingMidiNote {
  tick : Int64
  velocity : Int32
}

///|
priv struct PendingMidiQueue {
  notes : Array[PendingMidiNote]
  mut head : Int32
}

///|
/// Shared event budgets and warning state for the tracks in one file.
pub struct MidiTrackReader {
  warnings : Array[String]
  warned : Map[String, Bool]
  mut note_count : Int32
  mut control_count : Int32
  mut meta_count : Int32
}

///|
pub fn MidiTrackReader::new() -> MidiTrackReader {
  {
    warnings: [],
    warned: Map([]),
    note_count: 0,
    control_count: 0,
    meta_count: 0,
  }
}

///|
pub fn MidiTrackReader::warnings(self : MidiTrackReader) -> Array[String] {
  self.warnings.copy()
}

///|
fn MidiTrackReader::warn(
  self : MidiTrackReader,
  key : String,
  message : String,
) -> Unit {
  if !self.warned.contains(key) {
    self.warned[key] = true
    self.warnings.push(message)
  }
}

///|
fn finish_pending(
  pending : Map[Int32, PendingMidiQueue],
  notes : Array[MidiRawNote],
  channel : Int32,
  key : Int32,
  tick : Int64,
  all : Bool,
) -> Unit {
  let slot = channel * 128 + key
  match pending.get(slot) {
    None => ()
    Some(queue) =>
      while queue.head < queue.notes.length() {
        let note = queue.notes[queue.head]
        queue.head += 1
        notes.push({
          channel,
          key,
          velocity: note.velocity,
          on: note.tick,
          off: tick,
        })
        if !all {
          break
        }
      }
  }
}

///|
fn MidiTrackReader::control(
  self : MidiTrackReader,
  controls : Array[MidiRawControl],
  channel : Int32,
  tick : Int64,
  kind : Int32,
  number : Int32,
  value : Int32,
) -> Unit {
  self.control_count += 1
  if self.control_count > 2000000 {
    self.warn("controls", "controls past the first 2000000 are left out")
  } else {
    controls.push({ channel, tick, kind, number, value, })
  }
}

///|
/// Interpret channel events and warnings in a scanned track. The reader must
/// be reused for all tracks of a file so that upstream budgets are shared.
pub fn MidiTrackReader::read(
  self : MidiTrackReader,
  track : MidiTrackScan,
  index : Int32,
) -> MidiTrackNotes raise MidiInputError {
  let notes : Array[MidiRawNote] = []
  let controls : Array[MidiRawControl] = []
  let pending : Map[Int32, PendingMidiQueue] = Map([])
  let mut name = b""
  let mut instrument = b""
  let mut copyright = b""
  let channel_names : Array[Bytes] = Array::make(16, b"")
  let texts : Array[MidiRawText] = []
  let tempos : Array[MidiRawTempo] = []
  let times : Array[MidiRawTime] = []
  let keys : Array[MidiRawKey] = []
  let mut prefix = -1
  for event in track.events {
    let status = event.status
    if status < 0xf0 {
      let d = event.data
      let mut d1 = d[0].to_int()
      let mut d2 = if d.length() == 2 { d[1].to_int() } else { 0 }
      if ((d1 | d2) & 0x80) != 0 {
        self.warn(
          "data", "data bytes out of range are read without their top bit",
        )
        d1 = d1 & 0x7f
        d2 = d2 & 0x7f
      }
      prefix = -1
      let channel = status & 15
      let typ = status & 0xf0
      if typ == 0x90 && d2 > 0 {
        self.note_count += 1
        if self.note_count > 2000000 {
          raise InvalidMidiInput("midi: the file has more than 2000000 notes")
        }
        let slot = channel * 128 + d1
        let queue = match pending.get(slot) {
          Some(queue) => queue
          None => {
            let queue : PendingMidiQueue = { notes: [], head: 0, }
            pending[slot] = queue
            queue
          }
        }
        queue.notes.push({ tick: event.tick, velocity: d2, })
      } else if typ == 0x80 || typ == 0x90 {
        finish_pending(pending, notes, channel, d1, event.tick, false)
      } else if typ == 0xb0 {
        if d1 == 120 || d1 == 123 {
          for key in 0..<128 {
            finish_pending(pending, notes, channel, key, event.tick, true)
          }
        } else if d1 == 7 || d1 == 10 || d1 == 11 || d1 == 64 || d1 == 70 {
          self.control(controls, channel, event.tick, 1, d1, d2)
        }
      } else if typ == 0xc0 {
        self.control(controls, channel, event.tick, 0, 0, d1)
      } else if typ == 0xe0 {
        self.control(
          controls,
          channel,
          event.tick,
          2,
          0,
          ((d2 << 7) | d1) - 8192,
        )
      }
    } else if status == 0xff && event.kind != 0x2f {
      let kind = event.kind
      if kind == 0x01 ||
        kind == 0x03 ||
        kind == 0x04 ||
        kind == 0x05 ||
        kind == 0x51 ||
        kind == 0x58 ||
        kind == 0x59 {
        self.meta_count += 1
        if self.meta_count > 1000000 {
          self.warn("events", "meta events past the first 1000000 are left out")
          continue
        }
      }
      let d = event.data
      if kind == 0x01 || kind == 0x05 {
        texts.push({ tick: event.tick, kind, data: d, })
      } else if kind == 0x02 {
        if copyright.length() == 0 {
          copyright = d
        }
      } else if kind == 0x03 || kind == 0x04 {
        if prefix >= 0 {
          if channel_names[prefix].length() == 0 {
            channel_names[prefix] = d
          }
        } else if kind == 0x03 && name.length() == 0 {
          name = d
        } else if kind == 0x04 && instrument.length() == 0 {
          instrument = d
        }
      } else if kind == 0x20 {
        if d.length() >= 1 {
          prefix = d[0].to_int() & 15
        }
      } else if kind == 0x51 {
        if d.length() >= 3 {
          let micros = (d[0].to_int() << 16) |
            (d[1].to_int() << 8) |
            d[2].to_int()
          if micros > 0 {
            let bpm = 60000000.0 / micros.to_double()
            let rounded = bpm.round()
            let exact = if (60000000.0 / rounded).round() == micros.to_double() {
              rounded
            } else {
              bpm
            }
            tempos.push({ tick: event.tick, bpm: exact, })
          }
        }
      } else if kind == 0x58 {
        if d.length() < 2 || d[0].to_int() == 0 || d[1].to_int() > 6 {
          self.warn("time", "invalid time signatures are ignored")
        } else {
          times.push({
            tick: event.tick,
            beats: d[0].to_int(),
            beat_type: 1 << d[1].to_int(),
          })
        }
      } else if kind == 0x59 {
        if d.length() < 2 {
          self.warn("key", "invalid key signatures are ignored")
        } else {
          let raw = d[0].to_int()
          let fifths = if raw >= 128 { raw - 256 } else { raw }
          if fifths < -7 || fifths > 7 || d[1].to_int() > 1 {
            self.warn("key", "invalid key signatures are ignored")
          } else {
            keys.push({ tick: event.tick, fifths, minor: d[1].to_int() == 1, })
          }
        }
      }
    } else if status != 0xf0 && status != 0xf7 && status != 0xff {
      self.warn("system", "system messages in tracks are ignored")
    }
  }
  if track.damaged {
    if track.problem == "long" {
      self.warn("long", "tracks longer than 1000000 quarter notes are cut")
    } else if track.problem == "" {
      self.warn(
        "truncated",
        "track \{index + 1} is cut short; it is read up to the cut",
      )
    } else {
      self.warn(
        "damaged",
        "track \{index + 1} is damaged (\{track.problem}); it is read up to the damage",
      )
    }
  }
  for channel in 0..<16 {
    for key in 0..<128 {
      let slot = channel * 128 + key
      match pending.get(slot) {
        Some(queue) if queue.head < queue.notes.length() => {
          self.warn("unended", "notes without a note-off end with their track")
          finish_pending(pending, notes, channel, key, track.end_tick, true)
        }
        _ => ()
      }
    }
  }
  {
    notes,
    controls,
    name,
    instrument,
    copyright,
    channel_names,
    texts,
    tempos,
    times,
    keys,
  }
}
