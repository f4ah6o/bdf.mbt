///|
fn append_base128(out : Array[Byte], value : UInt32) -> Unit {
  let bytes : Array[Byte] = [(value & 127U).to_byte()]
  let mut remaining = value >> 7
  while remaining != 0U {
    bytes.push(((remaining & 127U) | 128U).to_byte())
    remaining = remaining >> 7
  }
  for i = bytes.length() - 1; i >= 0; i = i - 1 {
    out.push(bytes[i])
  }
}

///|
/// Encode a TrueType or CFF OpenType SFNT as a WOFF2 font. Glyph tables are
/// stored using the glyf transform where possible; unsupported outlines use
/// the null transform. The Brotli stream is bounded by the SFNT table size.
pub fn encode(font : Bytes) -> Bytes raise {
  if font.length() < 12 {
    raise Woff2Failure("woff2: font too short")
  }
  let data = font[:]
  let flavor = get32(data, 0)
  if flavor != 0x00010000U && flavor != 0x74727565U && flavor != 0x4f54544fU {
    raise Woff2Failure("woff2: not a TrueType or OpenType font")
  }
  let count = get16(data, 4)
  if count > (data.length() - 12) / 16 {
    raise Woff2Failure("woff2: truncated table directory")
  }
  let tables : Map[String, Bytes] = Map([])
  for i in 0..<count {
    let rec = 12 + i * 16
    let tag = @utf8.decode_lossy(data[rec:rec + 4])
    let offset = get32(data, rec + 8).to_uint64()
    let length = get32(data, rec + 12).to_uint64()
    if offset > font.length().to_uint64() ||
      length > font.length().to_uint64() - offset {
      raise Woff2Failure("woff2: table " + tag + " out of range")
    }
    tables[tag] = data[offset.to_int():offset.to_int() + length.to_int()].to_owned()
  }
  let mut transformed : Bytes? = None
  let mut loca_length = 0
  match
    (
      tables.get("head"),
      tables.get("maxp"),
      tables.get("glyf"),
      tables.get("loca"),
    ) {
    (Some(head), Some(maxp), Some(glyf), Some(loca)) if flavor != 0x4f54544fU &&
      head.length() >= 54 &&
      maxp.length() >= 6 => {
      let count = get16(maxp[:], 4)
      transformed = transform_glyf(glyf, loca, count, get16(head[:], 50) != 0)
      if transformed is Some(_) {
        let h = head.to_array()
        put16(h, 50, 1)
        put16(h, 16, get16(head[:], 16) | (1 << 11))
        tables["head"] = Bytes::from_array(h)
        loca_length = (count + 1) * 4
      }
    }
    _ => ()
  }
  let tags = tables.keys().collect()
  tags.sort()
  let directory : Array[Byte] = []
  let stream : Array[Byte] = []
  let mut total = 12L + 16L * tags.length().to_int64()
  for tag in tags {
    let contents = tables[tag]
    let original_length = if transformed is Some(_) && tag == "loca" {
      loca_length
    } else {
      contents.length()
    }
    total += (original_length.to_int64() + 3L) & -4L
    let stored_length = if transformed is Some(bytes) && tag == "glyf" {
      bytes.length()
    } else if transformed is Some(_) && tag == "loca" {
      0
    } else {
      contents.length()
    }
    if stream.length().to_int64() + stored_length.to_int64() > 268435456L {
      raise Woff2Failure("woff2: the tables of the font are too large")
    }
    let mut index = 63
    for i, known in known_tags {
      if known == tag {
        index = i
        break
      }
    }
    let flags = if (tag == "glyf" || tag == "loca") && transformed is None {
      index | 0xc0
    } else {
      index
    }
    directory.push(flags.to_byte())
    if index == 63 {
      append_bytes(directory, @utf8.encode(tag)[:])
    }
    append_base128(directory, original_length.reinterpret_as_uint())
    if transformed is Some(bytes) && tag == "glyf" {
      append_base128(directory, bytes.length().reinterpret_as_uint())
      append_bytes(stream, bytes[:])
    } else if transformed is Some(_) && tag == "loca" {
      append_base128(directory, 0U)
    } else {
      append_bytes(stream, contents[:])
    }
  }
  let compressed = @brotli.compress(
    Bytes::from_array(stream)[:],
    window_bits=22,
  )
  let out = Bytes::make(48, 0).to_array()
  append_bytes(out, Bytes::from_array(directory)[:])
  append_bytes(out, compressed[:])
  while out.length() % 4 != 0 {
    out.push(0)
  }
  if stream.length().to_int64() >= 100L * out.length().to_int64() {
    raise Woff2Failure("woff2: the font compresses more than decoders accept")
  }
  total = Int64::max(total, out.length().to_int64())
  if total > 0xffffffffL {
    raise Woff2Failure("woff2: the tables of the font are too large")
  }
  out[0] = b'w'
  out[1] = b'O'
  out[2] = b'F'
  out[3] = b'2'
  put32(out, 4, flavor)
  put32(out, 8, out.length().reinterpret_as_uint())
  put16(out, 12, tags.length())
  put32(out, 16, total.to_int().reinterpret_as_uint())
  put32(out, 20, compressed.length().reinterpret_as_uint())
  put16(out, 24, 1)
  Bytes::from_array(out)
}
