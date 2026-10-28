///|
/// A timed MIDI event, with note-on and note-off pairs represented as notes.
pub(all) enum MidiMessage {
  Note(
    channel~ : Int32,
    key~ : Int32,
    velocity~ : Int32,
    duration~ : Double,
    end_tick~ : Double
  )
  Program(channel~ : Int32, program~ : Int32)
  Control(channel~ : Int32, controller~ : Int32, value~ : Int32)
  Bend(channel~ : Int32, value~ : Int32)
  Tempo(Int32)
  TimeSignature(numerator~ : Int32, denominator~ : Int32)
  KeySignature(key~ : Int32, minor~ : Bool)
} derive(Eq, Debug)

///|
pub(all) struct MidiEvent {
  tick : Double
  time : Double
  track : Int32
  mut message : MidiMessage
} derive(Eq, Debug)

///|
pub(all) struct TempoPoint {
  tick : Double
  time : Double
  tempo : Int32
} derive(Eq, Debug)

///|
pub(all) struct MidiSequence {
  format : Int32
  division : Double
  smpte : Bool
  tracks : Int32
  events : Array[MidiEvent]
  tempos : Array[TempoPoint]
  ticks : Double
  duration : Double
} derive(Eq, Debug)

///|
pub const MAX_MIDI_EVENTS : Int32 = 1048576

///|
priv enum RawMidiMessage {
  Event(MidiMessage)
  Off(Int32, Int32)
}

///|
priv struct RawMidiEvent {
  tick : Double
  track : Int32
  order : Int32
  message : RawMidiMessage
}

///|
priv struct SmfTrack {
  data : Bytes
  stop : Int32
  mut pos : Int32
}

///|
fn SmfTrack::vlq(self : SmfTrack) -> Int32 {
  let mut value = 0
  for _ in 0..<4 {
    if self.pos >= self.stop {
      return -1
    }
    let b = self.data[self.pos].to_int()
    self.pos += 1
    value = value * 128 + (b & 127)
    if (b & 128) == 0 {
      return value
    }
  }
  -1
}

///|
fn smf_u16(data : Bytes, pos : Int32) -> Int32 {
  (data[pos].to_int() << 8) | data[pos + 1].to_int()
}

///|
fn smf_u32(data : Bytes, pos : Int32) -> UInt64 {
  (data[pos].to_uint64() << 24) |
  (data[pos + 1].to_uint64() << 16) |
  (data[pos + 2].to_uint64() << 8) |
  data[pos + 3].to_uint64()
}

///|
fn smf_tag(
  data : Bytes,
  pos : Int32,
  a : Byte,
  b : Byte,
  c : Byte,
  d : Byte,
) -> Bool {
  data[pos] == a &&
  data[pos + 1] == b &&
  data[pos + 2] == c &&
  data[pos + 3] == d
}

///|
fn smf_push(
  out : Array[RawMidiEvent],
  tick : Double,
  track : Int32,
  message : RawMidiMessage,
) -> Unit {
  out.push({ tick, track, order: out.length(), message, })
}

///|
fn read_smf_track(
  reader : SmfTrack,
  track : Int32,
  start_tick : Double,
  out : Array[RawMidiEvent],
) -> Double {
  let mut tick = start_tick
  let mut running = 0
  while reader.pos < reader.stop && out.length() < MAX_MIDI_EVENTS {
    let delta = reader.vlq()
    if delta < 0 || reader.pos >= reader.stop {
      break
    }
    let now = tick + delta.to_double()
    let mut status = reader.data[reader.pos].to_int()
    if (status & 128) != 0 {
      reader.pos += 1
    } else if running != 0 {
      status = running
    } else {
      break
    }
    if status == 255 {
      if reader.pos >= reader.stop {
        break
      }
      let kind = reader.data[reader.pos].to_int()
      reader.pos += 1
      let len = reader.vlq()
      if len < 0 || len > reader.stop - reader.pos {
        break
      }
      let start = reader.pos
      reader.pos += len
      tick = now
      if kind == 47 {
        return tick
      } else if kind == 81 && len >= 3 {
        let tempo = (reader.data[start].to_int() << 16) |
          (reader.data[start + 1].to_int() << 8) |
          reader.data[start + 2].to_int()
        if tempo > 0 {
          smf_push(out, tick, track, Event(Tempo(tempo)))
        }
      } else if kind == 88 && len >= 2 {
        let exponent = reader.data[start + 1].to_int()
        let denominator = 1 << (if exponent > 16 { 16 } else { exponent })
        smf_push(
          out,
          tick,
          track,
          Event(
            TimeSignature(numerator=reader.data[start].to_int(), denominator~),
          ),
        )
      } else if kind == 89 && len >= 2 {
        let value = reader.data[start].to_int()
        smf_push(
          out,
          tick,
          track,
          Event(
            KeySignature(
              key=if value >= 128 { value - 256 } else { value },
              minor=reader.data[start + 1].to_int() == 1,
            ),
          ),
        )
      }
      continue
    }
    if status == 240 || status == 247 {
      let len = reader.vlq()
      if len < 0 || len > reader.stop - reader.pos {
        break
      }
      reader.pos += len
      tick = now
      continue
    }
    if status > 240 {
      break
    }
    running = status
    let kind = status & 240
    let channel = status & 15
    let len = if kind == 192 || kind == 208 { 1 } else { 2 }
    if len > reader.stop - reader.pos {
      break
    }
    let a = reader.data[reader.pos].to_int() & 127
    let b = if len == 2 {
      reader.data[reader.pos + 1].to_int() & 127
    } else {
      0
    }
    reader.pos += len
    tick = now
    match kind {
      128 => smf_push(out, tick, track, Off(channel, a))
      144 =>
        if b == 0 {
          smf_push(out, tick, track, Off(channel, a))
        } else {
          smf_push(
            out,
            tick,
            track,
            Event(
              Note(channel~, key=a, velocity=b, duration=0.0, end_tick=tick),
            ),
          )
        }
      176 =>
        smf_push(
          out,
          tick,
          track,
          Event(Control(channel~, controller=a, value=b)),
        )
      192 => smf_push(out, tick, track, Event(Program(channel~, program=a)))
      224 =>
        smf_push(
          out,
          tick,
          track,
          Event(Bend(channel~, value=((b << 7) | a) - 8192)),
        )
      _ => ()
    }
  }
  tick
}

///|
fn close_midi_note(
  events : Array[MidiEvent],
  index : Int32,
  tick : Double,
  time : Double,
  sounding : Array[Int32],
) -> Unit {
  let event = events[index]
  if event.message is Note(channel~, key~, velocity~, ..) {
    event.message = Note(
      channel~,
      key~,
      velocity~,
      duration=time - event.time,
      end_tick=tick,
    )
    sounding[channel] -= 1
  }
}

///|
fn midi_time(
  point : TempoPoint,
  tick : Double,
  division : Double,
  smpte : Bool,
) -> Double {
  if smpte {
    tick / division
  } else {
    point.time +
    (tick - point.tick) * point.tempo.to_double() / 1000000.0 / division
  }
}

///|
/// Parse an SMF, retaining whole events before truncated or damaged track data.
pub fn parse_smf(data : Bytes) -> MidiSequence raise {
  if data.length() < 14 || !smf_tag(data, 0, b'M', b'T', b'h', b'd') {
    raise BadFormat("not a Standard MIDI File")
  }
  let header = smf_u32(data, 4)
  if header < 6UL {
    raise BadFormat("bad MIDI header")
  }
  let format = smf_u16(data, 8)
  let raw_division = smf_u16(data, 12)
  let smpte = (raw_division & 32768) != 0
  let division = if smpte {
    let fps = 256 - (raw_division >> 8)
    (if fps == 29 { 29.97 } else { fps.to_double() }) *
    (raw_division & 255).to_double()
  } else {
    raw_division.to_double()
  }
  if division <= 0.0 {
    raise BadFormat("bad MIDI division")
  }
  let raw : Array[RawMidiEvent] = []
  let mut tracks = 0
  let mut offset = 0.0
  let mut end = 0.0
  let mut pos = if header > (data.length() - 8).to_uint64() {
    data.length()
  } else {
    8 + header.to_int()
  }
  while pos <= data.length() - 8 &&
        tracks < 4096 &&
        raw.length() < MAX_MIDI_EVENTS {
    let size = smf_u32(data, pos + 4)
    let start = pos + 8
    let available = data.length() - start
    let stop = if size > available.to_uint64() {
      data.length()
    } else {
      start + size.to_int()
    }
    if smf_tag(data, pos, b'M', b'T', b'r', b'k') {
      let track = { data, pos: start, stop, }
      let last = read_smf_track(
        track,
        tracks,
        if format == 2 {
          offset
        } else {
          0.0
        },
        raw,
      )
      tracks += 1
      if last > end {
        end = last
      }
      if format == 2 {
        offset = last
      }
    }
    if size > available.to_uint64() {
      break
    }
    pos = stop
  }
  raw.sort_by((a, b) => {
    let time = a.tick.compare(b.tick)
    if time != 0 {
      time
    } else if a.track != b.track {
      a.track.compare(b.track)
    } else {
      a.order.compare(b.order)
    }
  })
  let mut point : TempoPoint = { tick: 0.0, time: 0.0, tempo: 500000, }
  let tempos : Array[TempoPoint] = [point]
  let events : Array[MidiEvent] = []
  let open : Map[Int32, Array[Int32]] = Map([])
  let sounding : Array[Int32] = Array::make(16, 0)
  for raw_event in raw {
    let tick = raw_event.tick
    let time = midi_time(point, tick, division, smpte)
    if tick > end {
      end = tick
    }
    match raw_event.message {
      Off(channel, key) =>
        if open.get(channel * 128 + key) is Some(queue) && !queue.is_empty() {
          let index = queue.remove(0)
          close_midi_note(events, index, tick, time, sounding)
        }
      Event(message) => {
        match message {
          Note(channel~, key~, ..) => {
            let id = channel * 128 + key
            let queue = match open.get(id) {
              Some(value) => value
              None => {
                let value : Array[Int32] = []
                open[id] = value
                value
              }
            }
            if queue.length() >= 64 {
              close_midi_note(events, queue.remove(0), tick, time, sounding)
            }
            queue.push(events.length())
            sounding[channel] += 1
          }
          Tempo(value) if !smpte => {
            point = { tick, time, tempo: value, }
            if tempos[tempos.length() - 1].tick == tick {
              tempos[tempos.length() - 1] = point
            } else {
              tempos.push(point)
            }
          }
          Control(channel~, controller~, ..) if (
              controller == 120 || controller == 123
            ) &&
            sounding[channel] > 0 =>
            for key in 0..<128 {
              let id = channel * 128 + key
              if open.get(id) is Some(queue) {
                for index in queue {
                  close_midi_note(events, index, tick, time, sounding)
                }
                open.remove(id)
              }
            }
          _ => ()
        }
        events.push({ tick, time, track: raw_event.track, message, })
      }
    }
  }
  let duration = midi_time(point, end, division, smpte)
  for _, queue in open {
    for index in queue {
      close_midi_note(events, index, end, duration, sounding)
    }
  }
  { format, division, smpte, tracks, events, tempos, ticks: end, duration, }
}

///|
fn midi_point(
  sequence : MidiSequence,
  value : Double,
  by_time : Bool,
) -> TempoPoint {
  let mut lo = 0
  let mut hi = sequence.tempos.length() - 1
  while lo < hi {
    let mid = (lo + hi + 1) / 2
    let at = if by_time {
      sequence.tempos[mid].time
    } else {
      sequence.tempos[mid].tick
    }
    if at <= value {
      lo = mid
    } else {
      hi = mid - 1
    }
  }
  sequence.tempos[lo]
}

///|
/// Convert a MIDI tick, including fractional ticks, to seconds.
pub fn tick_to_seconds(sequence : MidiSequence, tick : Double) -> Double {
  if sequence.smpte {
    return tick / sequence.division
  }
  midi_time(
    midi_point(sequence, tick, false),
    tick,
    sequence.division,
    sequence.smpte,
  )
}

///|
/// Convert seconds to a MIDI tick using the tempo map.
pub fn seconds_to_tick(sequence : MidiSequence, seconds : Double) -> Double {
  if sequence.smpte {
    return seconds * sequence.division
  }
  let point = midi_point(sequence, seconds, true)
  point.tick +
  (seconds - point.time) *
  1000000.0 *
  sequence.division /
  point.tempo.to_double()
}
