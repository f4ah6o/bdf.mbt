///|
/// The Standard MIDI File and optional raw RIFF INFO fields.
pub(all) struct MidiInput {
  smf : Bytes
  title : Bytes
  copyright : Bytes
}

///|
pub suberror MidiInputError {
  InvalidMidiInput(String)
}

///|
/// Identify the file headers accepted by the upstream MIDI converter.
pub fn detect(head : Bytes) -> Bool {
  if head.length() >= 8 && head[:4] == b"MThd"[:] {
    let n = be32(head[:], 4)
    return n >= 6L && n < 65536L
  }
  head.length() >= 12 && head[:4] == b"RIFF"[:] && head[8:12] == b"RMID"[:]
}

///|
fn be32(data : BytesView, p : Int32) -> Int64 {
  (data[p].to_int64() << 24) |
  (data[p + 1].to_int64() << 16) |
  (data[p + 2].to_int64() << 8) |
  data[p + 3].to_int64()
}

///|
fn le32(data : BytesView, p : Int32) -> Int64 {
  data[p].to_int64() |
  (data[p + 1].to_int64() << 8) |
  (data[p + 2].to_int64() << 16) |
  (data[p + 3].to_int64() << 24)
}

///|
fn be16(data : BytesView, p : Int32) -> Int32 {
  (data[p].to_int() << 8) | data[p + 1].to_int()
}

///|
/// Extract the first data chunk and the last INAM and ICOP fields. RIFF
/// chunk lengths can extend past the available bytes, as in the Go parser.
pub fn unwrap_rmid(data : Bytes) -> MidiInput raise MidiInputError {
  if data.length() < 12 || data[:4] != b"RIFF"[:] || data[8:12] != b"RMID"[:] {
    return { smf: data, title: b"", copyright: b"", }
  }
  let view = data[:]
  let mut smf : Bytes? = None
  let mut title = b""
  let mut copyright = b""
  let mut pos = 12L
  let size = data.length().to_int64()
  while pos + 8L <= size {
    let p = pos.to_int()
    let n = le32(view, p + 4)
    let end = Int64::min(pos + 8L + n, size).to_int()
    let body = view[p + 8:end]
    if view[p:p + 4] == b"data"[:] {
      if smf is None {
        smf = Some(body.to_owned())
      }
    } else if view[p:p + 4] == b"LIST"[:] &&
      body.length() >= 4 &&
      body[:4] == b"INFO"[:] {
      let mut q = 4L
      let body_size = body.length().to_int64()
      while q + 8L <= body_size {
        let i = q.to_int()
        let m = le32(body, i + 4)
        let subend = Int64::min(q + 8L + m, body_size).to_int()
        if body[i:i + 4] == b"INAM"[:] {
          title = body[i + 8:subend].to_owned()
        } else if body[i:i + 4] == b"ICOP"[:] {
          copyright = body[i + 8:subend].to_owned()
        }
        q += 8L + m + (m & 1L)
      }
    }
    pos += 8L + n + (n & 1L)
  }
  match smf {
    Some(smf) => { smf, title, copyright, }
    None => raise InvalidMidiInput("midi: the RIFF MIDI file has no data chunk")
  }
}

///|
/// Header and timing information used by MIDI notation.
pub(all) struct MidiHeader {
  format : Int32
  tracks : Int32
  division : Int32
  header_length : Int64
  smpte : Bool
  timing_numerator : Int64
  timing_denominator : Int64
  max_tick : Int64
  warnings : Array[String]
}

///|
fn hex_division(n : Int32) -> String {
  let digits : Array[Char] = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
  ]
  let out : Array[Char] = ['0', 'x']
  for shift in [12, 8, 4, 0] {
    out.push(digits[(n >> shift) & 15])
  }
  String::from_array(out)
}

///|
/// Read and validate the header of an unwrapped SMF.
pub fn read_header(smf : Bytes) -> MidiHeader raise MidiInputError {
  if smf.length() < 8 || smf[:4] != b"MThd"[:] {
    raise InvalidMidiInput("midi: not a Standard MIDI File")
  }
  let b = smf[:]
  let hl = be32(b, 4)
  if hl < 6L {
    raise InvalidMidiInput("midi: the header chunk is too short (\{hl} bytes)")
  }
  if hl > (smf.length() - 8).to_int64() {
    raise InvalidMidiInput("midi: the file is truncated in its header")
  }
  let format = be16(b, 8)
  let tracks = be16(b, 10)
  let division = be16(b, 12)
  let smpte = (division & 0x8000) != 0
  let warnings : Array[String] = []
  let mut num = division.to_int64()
  let mut den = 1L
  if smpte {
    let fps = 256 - (division >> 8)
    let tpf = division & 255
    if (fps != 24 && fps != 25 && fps != 29 && fps != 30) || tpf == 0 {
      raise InvalidMidiInput(
        "midi: the SMPTE division \{hex_division(division)} is invalid",
      )
    }
    num = (fps * tpf).to_int64()
    den = 2L
    if fps == 29 {
      num = (2997 * tpf).to_int64()
      den = 200L
    }
    warnings.push(
      "the file is timed in SMPTE frames (\{fps} fps × \{tpf}): it is notated at 120 BPM and played from a file written from its notes",
    )
  } else if division == 0 {
    raise InvalidMidiInput("midi: the division of the header is 0")
  }
  if format == 2 {
    warnings.push(
      "the patterns of a format 2 file are read as tracks that start together",
    )
  } else if format > 2 {
    warnings.push("format \{format} is read as format 1")
  }
  {
    format,
    tracks,
    division,
    header_length: hl,
    smpte,
    timing_numerator: num,
    timing_denominator: den,
    max_tick: 1000000L * num / den,
    warnings,
  }
}

///|
/// Convert an absolute file tick to the upstream 960-tick quarter note.
pub fn MidiHeader::ppq(self : MidiHeader, tick : Int64) -> Int64 {
  (2L * tick * 960L * self.timing_denominator + self.timing_numerator) /
  (2L * self.timing_numerator)
}

///|
/// Read a MIDI variable-length quantity. The second value is 0 for a
/// truncated quantity and -1 for a quantity longer than four bytes.
pub fn read_varlen(data : Bytes) -> (Int32, Int32) {
  let mut value = 0
  for i in 0..<4 {
    if i >= data.length() {
      return (0, 0)
    }
    let b = data[i].to_int()
    value = (value << 7) | (b & 0x7f)
    if b < 0x80 {
      return (value, i + 1)
    }
  }
  (0, -1)
}
