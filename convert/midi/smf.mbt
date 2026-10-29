///|
priv struct SmfEvent {
  tick : Int64
  order : Int32
  index : Int32
  data : Bytes
}

///|
priv struct SmfTrackWriter {
  data : Array[Byte]
  mut tick : Int64
  mut running : Int32
}

///|
fn smf_varlen(out : Array[Byte], value : Int64) -> Unit {
  let bytes : Array[Byte] = [(value & 127L).to_byte()]
  let mut n = value >> 7
  while n > 0L {
    bytes.push(((n & 127L) | 128L).to_byte())
    n = n >> 7
  }
  for i = bytes.length() - 1; i >= 0; i = i - 1 {
    out.push(bytes[i])
  }
}

///|
fn SmfTrackWriter::event(
  self : SmfTrackWriter,
  tick : Int64,
  event : Bytes,
) -> Unit {
  let mut delta = Int64::max(tick - self.tick, 0L)
  while delta > 268435455L {
    smf_varlen(self.data, 268435455L)
    for b in b"\xff\x01\x00" {
      self.data.push(b)
    }
    self.running = 0
    delta -= 268435455L
  }
  smf_varlen(self.data, delta)
  self.tick = Int64::max(tick, self.tick)
  let status = event[0].to_int()
  if status >= 0xf0 {
    self.running = 0
    for b in event {
      self.data.push(b)
    }
  } else if status == self.running {
    for b in event[1:] {
      self.data.push(b)
    }
  } else {
    self.running = status
    for b in event {
      self.data.push(b)
    }
  }
}

///|
fn SmfTrackWriter::meta(
  self : SmfTrackWriter,
  tick : Int64,
  kind : Byte,
  data : Bytes,
) -> Unit {
  let event : Array[Byte] = [0xff, kind]
  smf_varlen(event, data.length().to_int64())
  for b in data {
    event.push(b)
  }
  self.event(tick, Bytes::from_array(event))
}

///|
fn SmfTrackWriter::chunk(self : SmfTrackWriter, out : Array[Byte]) -> Unit {
  for b in b"MTrk" {
    out.push(b)
  }
  append_u32(out, self.data.length())
  for b in self.data {
    out.push(b)
  }
}

///|
fn smf_add(
  events : Array[SmfEvent],
  tick : Int64,
  order : Int32,
  data : Bytes,
) -> Unit {
  events.push({ tick, order, index: events.length(), data, })
}

///|
fn smf_sort(events : Array[SmfEvent]) -> Unit {
  events.sort_by((a, b) => {
    let tick = a.tick.compare(b.tick)
    let order = a.order.compare(b.order)
    if tick != 0 {
      tick
    } else if order != 0 {
      order
    } else {
      a.index.compare(b.index)
    }
  })
}

///|
/// Encode a MIDI performance as a format 1 SMF at 960 ticks per quarter.
/// This is used for SMPTE-timed input, whose original file cannot be replayed
/// directly by the BDF viewer's score timing.
pub fn performance_smf(performance : MidiPerformance) -> Bytes {
  let mut end = performance.end
  for track in performance.tracks {
    for note in track.notes {
      end = Int64::max(end, note.tick + note.duration)
    }
  }
  let out : Array[Byte] = []
  for b in b"MThd\x00\x00\x00\x06" {
    out.push(b)
  }
  append_u16(out, 1)
  append_u16(out, 1 + performance.tracks.length())
  append_u16(out, 960)
  let conductor : SmfTrackWriter = { data: [], tick: 0L, running: 0, }
  if performance.credits.title != "" {
    conductor.meta(0L, 3, @utf8.encode(performance.credits.title))
  }
  if performance.credits.copyright != "" {
    conductor.meta(0L, 2, @utf8.encode(performance.credits.copyright))
  }
  let events : Array[SmfEvent] = []
  for time in performance.times {
    let mut power = 0
    let mut base = 1L
    while base < time.beat_type.to_int64() {
      power += 1
      base *= 2L
    }
    smf_add(
      events,
      time.tick,
      0,
      Bytes::from_array([
        0xff,
        0x58,
        4,
        time.beats.to_byte(),
        power.to_byte(),
        24,
        8,
      ]),
    )
  }
  for key in performance.keys {
    smf_add(
      events,
      key.tick,
      1,
      Bytes::from_array([
        0xff,
        0x59,
        2,
        key.fifths.to_byte(),
        if key.minor {
          1
        } else {
          0
        },
      ]),
    )
  }
  for tempo in performance.tempos {
    if tempo.bpm <= 0.0 {
      continue
    }
    let value = 60000000.0 / tempo.bpm + 0.5
    let us = if value >= 16777215.0 {
      0xffffff
    } else if value < 1.0 {
      1
    } else {
      value.to_int()
    }
    smf_add(
      events,
      tempo.tick,
      2,
      Bytes::from_array([
        0xff,
        0x51,
        3,
        (us >> 16).to_byte(),
        (us >> 8).to_byte(),
        us.to_byte(),
      ]),
    )
  }
  smf_sort(events)
  for event in events {
    conductor.event(event.tick, event.data)
  }
  conductor.meta(end, 0x2f, b"")
  conductor.chunk(out)
  for track in performance.tracks {
    let ch = track.channel & 15
    let events : Array[SmfEvent] = []
    if track.program >= 0 && track.channel != 9 {
      smf_add(
        events,
        0L,
        0,
        Bytes::from_array([
          (0xc0 | ch).to_byte(),
          (track.program & 127).to_byte(),
        ]),
      )
    }
    if track.volume >= 0 {
      smf_add(
        events,
        0L,
        0,
        Bytes::from_array([
          (0xb0 | ch).to_byte(),
          7,
          Int32::min(track.volume, 127).to_byte(),
        ]),
      )
    }
    if track.pan >= 0 {
      smf_add(
        events,
        0L,
        0,
        Bytes::from_array([
          (0xb0 | ch).to_byte(),
          10,
          Int32::min(track.pan, 127).to_byte(),
        ]),
      )
    }
    for control in track.controls {
      match control.kind {
        0 =>
          smf_add(
            events,
            control.tick,
            1,
            Bytes::from_array([
              (0xc0 | ch).to_byte(),
              (control.value & 127).to_byte(),
            ]),
          )
        1 =>
          smf_add(
            events,
            control.tick,
            1,
            Bytes::from_array([
              (0xb0 | ch).to_byte(),
              (control.number & 127).to_byte(),
              Int32::min(Int32::max(control.value, 0), 127).to_byte(),
            ]),
          )
        2 => {
          let v = Int32::min(Int32::max(control.value + 8192, 0), 16383)
          smf_add(
            events,
            control.tick,
            1,
            Bytes::from_array([
              (0xe0 | ch).to_byte(),
              (v & 127).to_byte(),
              (v >> 7).to_byte(),
            ]),
          )
        }
        _ => ()
      }
    }
    for lyric in track.lyrics {
      let content = @utf8.encode(lyric.text)
      let data : Array[Byte] = [0xff, 5]
      smf_varlen(data, content.length().to_int64())
      for b in content {
        data.push(b)
      }
      smf_add(events, lyric.tick, 2, Bytes::from_array(data))
    }
    for note in track.notes {
      if note.duration <= 0L || note.key < 0 || note.key > 127 {
        continue
      }
      let velocity = Int32::min(Int32::max(note.velocity, 1), 127)
      smf_add(
        events,
        note.tick + note.duration,
        -1,
        Bytes::from_array([(0x80 | ch).to_byte(), note.key.to_byte(), 64]),
      )
      smf_add(
        events,
        note.tick,
        3,
        Bytes::from_array([
          (0x90 | ch).to_byte(),
          note.key.to_byte(),
          velocity.to_byte(),
        ]),
      )
    }
    smf_sort(events)
    let writer : SmfTrackWriter = { data: [], tick: 0L, running: 0, }
    if track.name != "" {
      writer.meta(0L, 3, @utf8.encode(track.name))
    }
    for event in events {
      writer.event(event.tick, event.data)
    }
    let last = if events.is_empty() {
      0L
    } else {
      events[events.length() - 1].tick
    }
    writer.meta(Int64::max(end, last), 0x2f, b"")
    writer.chunk(out)
  }
  Bytes::from_array(out)
}
