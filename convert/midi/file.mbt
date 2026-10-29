///|
/// A track chunk and its interpreted notes and controls.
pub(all) struct MidiRawTrack {
  body : Bytes
  scan : MidiTrackScan
  notes : MidiTrackNotes
}

///|
/// Parsed SMF chunks before performance and notation construction.
pub(all) struct MidiRawFile {
  input : MidiInput
  header : MidiHeader
  tracks : Array[MidiRawTrack]
  smf : Bytes?
  warnings : Array[String]
}

///|
fn chunk_id(data : BytesView, pos : Int32) -> Bool {
  for i in 0..<4 {
    let c = data[pos + i].to_int()
    if c < 0x20 || c > 0x7e {
      return false
    }
  }
  true
}

///|
fn next_track(data : BytesView, pos : Int32) -> Int32 {
  let mut i = pos + 1
  while i + 4 <= data.length() {
    if data[i:i + 4] == b"MTrk"[:] {
      return i
    }
    i += 1
  }
  -1
}

///|
fn append_u16(out : Array[Byte], value : Int32) -> Unit {
  out.push((value >> 8).to_byte())
  out.push(value.to_byte())
}

///|
fn append_u32(out : Array[Byte], value : Int32) -> Unit {
  out.push((value >> 24).to_byte())
  out.push((value >> 16).to_byte())
  out.push((value >> 8).to_byte())
  out.push(value.to_byte())
}

///|
fn rebuild_smf(
  format : Int32,
  division : Int32,
  tracks : Array[MidiRawTrack],
) -> Bytes {
  let out : Array[Byte] = []
  for c in b"MThd\x00\x00\x00\x06" {
    out.push(c)
  }
  append_u16(out, format)
  append_u16(out, tracks.length())
  append_u16(out, division)
  for track in tracks {
    for c in b"MTrk" {
      out.push(c)
    }
    let length = track.scan.parsed + (if track.scan.saw_end { 0 } else { 4 })
    append_u32(out, length)
    for c in track.body[:track.scan.parsed] {
      out.push(c)
    }
    if !track.scan.saw_end {
      for c in b"\x00\xff\x2f\x00" {
        out.push(c)
      }
    }
  }
  Bytes::from_array(out)
}

///|
/// Read SMF chunks, track events, and the repaired playback file. Building a
/// music performance and BDF notation requires additional processing.
pub fn read_file(data : Bytes) -> MidiRawFile raise MidiInputError {
  let input = unwrap_rmid(data)
  let header = read_header(input.smf)
  let smf = input.smf[:]
  let reader = MidiTrackReader::new()
  for warning in header.warnings {
    if warning.has_prefix("the file is timed in SMPTE") {
      reader.warn("smpte", warning)
    } else if header.format == 2 {
      reader.warn("format2", warning)
    } else {
      reader.warn("format", warning)
    }
  }
  let mut format = header.format
  let mut clean = !header.smpte
  if format >= 2 {
    format = 1
    clean = false
  }
  let tracks : Array[MidiRawTrack] = []
  let mut pos = (8L + header.header_length).to_int()
  while pos < smf.length() {
    let rest = smf.length() - pos
    if rest < 8 || !chunk_id(smf, pos) {
      let next = next_track(smf, pos)
      if next < 0 {
        let mut nonzero = false
        for c in smf[pos:] {
          if c != b'\x00' {
            nonzero = true
            break
          }
        }
        if nonzero {
          reader.warn(
            "trailing",
            "\{rest} bytes after the last track are ignored",
          )
        }
        clean = false
        break
      }
      reader.warn(
        "skipped",
        "\{next - pos} bytes that are not a chunk are skipped",
      )
      pos = next
      clean = false
      continue
    }
    let length = be32(smf, pos + 4)
    let end64 = pos.to_int64() + 8L + length
    let end = if end64 > smf.length().to_int64() {
      clean = false
      smf.length()
    } else {
      end64.to_int()
    }
    if smf[pos:pos + 4] == b"MTrk"[:] {
      if tracks.length() == 1024 {
        raise InvalidMidiInput("midi: the file has more than 1024 tracks")
      }
      let body = smf[pos + 8:end].to_owned()
      let scan = scan_track(body, header.max_tick)
      let notes = reader.read(scan, tracks.length())
      if scan.damaged || !scan.saw_end {
        clean = false
      }
      tracks.push({ body, scan, notes, })
    }
    pos = end
  }
  if tracks.is_empty() {
    raise InvalidMidiInput("midi: the file has no tracks")
  }
  if header.tracks != tracks.length() {
    reader.warn(
      "count",
      "the header counts \{header.tracks} tracks, the file has \{tracks.length()}",
    )
    clean = false
  }
  if format == 0 && tracks.length() > 1 {
    reader.warn(
      "format0",
      "a format 0 file of \{tracks.length()} tracks is read as format 1",
    )
    format = 1
    clean = false
  }
  let playback = if header.smpte {
    None
  } else if clean {
    Some(input.smf)
  } else {
    Some(rebuild_smf(format, header.division, tracks))
  }
  { input, header, tracks, smf: playback, warnings: reader.warnings(), }
}
