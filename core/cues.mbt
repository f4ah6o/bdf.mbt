///|
/// A score system's rectangle in page coordinates.
pub(all) struct CueSystem {
  page : UInt32
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Eq, Debug)

///|
/// The horizontal position on a system at a MIDI tick or audio millisecond.
pub(all) struct Cue {
  tick : UInt32
  system : UInt32
  x : Double
} derive(Eq, Debug)

///|
pub(all) struct Cues {
  systems : Array[CueSystem]
  cues : Array[Cue]
} derive(Eq, Debug)

///|
// BCUE uses Go's unsigned varints, with the same safe-integer bound as the
// upstream JavaScript reader. The stored page, tick and system wrap to u32.
fn cue_varuint(reader : Reader) -> UInt64 raise {
  let mut value : UInt64 = 0UL
  let mut shift = 0
  for _ in 0..<10 {
    let b = reader.u8()
    let digit = (b & 127).to_uint64()
    if shift >= 56 && digit != 0UL {
      raise BadFormat("varuint out of range")
    }
    let part = digit << shift
    if part > 9007199254740991UL || value > 9007199254740991UL - part {
      raise BadFormat("varuint out of range")
    }
    value += part
    if (b & 128) == 0 {
      return value
    }
    shift += 7
    if shift > 63 {
      raise BadFormat("bad varuint")
    }
  }
  raise BadFormat("bad varuint")
}

///|
/// Decode a BCUE cue index, including unsigned 32-bit tick wrapping.
pub fn decode_cues(data : Bytes) -> Cues raise {
  if data.length() < 4 ||
    data[0] != b'B' ||
    data[1] != b'C' ||
    data[2] != b'U' ||
    data[3] != b'E' {
    raise BadFormat("not a cue index part")
  }
  let reader = Reader::new(data)
  reader.skip(4)
  let version = reader.u16()
  if version > 1 {
    raise BadFormat("unsupported cue index version " + version.to_string())
  }
  let n = cue_varuint(reader)
  if n > data.length().to_uint64() {
    raise BadFormat("bad system count")
  }
  let systems : Array[CueSystem] = []
  for _ in 0..<n.to_int() {
    systems.push({
      page: cue_varuint(reader).to_uint(),
      x: reader.f32(),
      y: reader.f32(),
      width: reader.f32(),
      height: reader.f32(),
    })
  }
  let count = cue_varuint(reader)
  if count > data.length().to_uint64() {
    raise BadFormat("bad cue count")
  }
  let cues : Array[Cue] = []
  let mut tick : UInt32 = 0U
  for _ in 0..<count.to_int() {
    tick = tick + cue_varuint(reader).to_uint()
    let system = cue_varuint(reader).to_uint()
    let x = reader.f32()
    if system.to_uint64() >= systems.length().to_uint64() {
      raise BadFormat("cue refers to a missing system")
    }
    cues.push({ tick, system, x, })
  }
  { systems, cues, }
}

///|
/// Encode a cue index, preserving the upstream unsigned tick delta behavior.
pub fn encode_cues(cues : Cues) -> Bytes {
  let out = @buffer.Buffer()
  out.write_bytes(b"BCUE\x01\x00")
  out.write_leb128(cues.systems.length().reinterpret_as_uint())
  for system in cues.systems {
    out.write_leb128(system.page)
    out.write_float_le(Float::from_double(system.x))
    out.write_float_le(Float::from_double(system.y))
    out.write_float_le(Float::from_double(system.width))
    out.write_float_le(Float::from_double(system.height))
  }
  out.write_leb128(cues.cues.length().reinterpret_as_uint())
  let mut previous : UInt32 = 0U
  for cue in cues.cues {
    out.write_leb128(cue.tick - previous)
    previous = cue.tick
    out.write_leb128(cue.system)
    out.write_float_le(Float::from_double(cue.x))
  }
  out.to_bytes()
}
