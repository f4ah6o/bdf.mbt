///|
/// An event read from an SMF track, in the file's original tick units.
/// For meta events `kind` is the meta type. For other events it is -1.
pub(all) struct RawMidiEvent {
  tick : Int64
  status : Int32
  kind : Int32
  data : Bytes
}

///|
/// The complete events read from one track and its repair boundary.
pub(all) struct MidiTrackScan {
  events : Array[RawMidiEvent]
  parsed : Int32
  saw_end : Bool
  damaged : Bool
  end_tick : Int64
  problem : String
}

///|
/// Scan one track body using the upstream converter's running-status and
/// truncation rules. The event data retains top bits for later interpretation.
pub fn scan_track(body : Bytes, max_tick : Int64) -> MidiTrackScan {
  let b = body[:]
  let events : Array[RawMidiEvent] = []
  let mut pos = 0
  let mut tick = 0L
  let mut running = 0
  let mut parsed = 0
  let mut end_tick = 0L
  let mut saw_end = false
  let mut damaged = false
  let mut problem = ""
  while pos < b.length() {
    let (delta, n) = read_varlen_view(b[pos:])
    if n <= 0 {
      damaged = true
      if n < 0 {
        problem = "a delta time longer than 4 bytes"
      }
      break
    }
    pos += n
    tick += delta.to_int64()
    if tick > max_tick {
      damaged = true
      problem = "long"
      break
    }
    if pos >= b.length() {
      damaged = true
      break
    }
    let mut status = b[pos].to_int()
    if status >= 0x80 {
      pos += 1
    } else if running != 0 {
      status = running
    } else {
      damaged = true
      problem = "a data byte without a status"
      break
    }
    let mut kind = -1
    let mut start = 0
    let mut end = 0
    if status < 0xf0 {
      let count = if (status & 0xe0) == 0xc0 { 1 } else { 2 }
      if b.length() - pos < count {
        damaged = true
        break
      }
      running = status
      start = pos
      pos += count
      end = pos
    } else if status == 0xff {
      if pos >= b.length() {
        damaged = true
        break
      }
      kind = b[pos].to_int()
      let (length, size) = read_varlen_view(b[pos + 1:])
      if size <= 0 || length > b.length() - (pos + 1 + size) {
        damaged = true
        break
      }
      start = pos + 1 + size
      pos = start + length
      end = pos
    } else if status == 0xf0 || status == 0xf7 {
      let (length, size) = read_varlen_view(b[pos:])
      if size <= 0 || length > b.length() - (pos + size) {
        damaged = true
        break
      }
      start = pos + size
      pos = start + length
      end = pos
    } else {
      let count = if status == 0xf1 || status == 0xf3 {
        1
      } else if status == 0xf2 {
        2
      } else {
        0
      }
      if b.length() - pos < count {
        damaged = true
        break
      }
      start = pos
      pos += count
      end = pos
    }
    events.push({ tick, status, kind, data: b[start:end].to_owned(), })
    end_tick = tick
    parsed = pos
    if status == 0xff && kind == 0x2f {
      saw_end = true
      break
    }
  }
  { events, parsed, saw_end, damaged, end_tick, problem, }
}
