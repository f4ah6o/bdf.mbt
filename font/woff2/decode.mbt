///|
/// WOFF2 font decoding errors.
pub suberror Woff2Error {
  Woff2Failure(String)
}

///|
let known_tags : Array[String] = [
  "cmap", "head", "hhea", "hmtx", "maxp", "name", "OS/2", "post", "cvt ", "fpgm",
  "glyf", "loca", "prep", "CFF ", "VORG", "EBDT", "EBLC", "gasp", "hdmx", "kern",
  "LTSH", "PCLT", "VDMX", "vhea", "vmtx", "BASE", "GDEF", "GPOS", "GSUB", "EBSC",
  "JSTF", "MATH", "CBDT", "CBLC", "COLR", "CPAL", "SVG ", "sbix", "acnt", "avar",
  "bdat", "bloc", "bsln", "cvar", "fdsc", "feat", "fmtx", "fvar", "gvar", "hsty",
  "just", "lcar", "mort", "morx", "opbd", "prop", "trak", "Zapf", "Silf", "Glat",
  "Gloc", "Feat", "Sill",
]

///|
fn fail() -> Unit raise {
  raise Woff2Failure("woff2: malformed font")
}

///|
fn get16(b : BytesView, p : Int32) -> Int32 {
  if p < 0 || p > b.length() - 2 {
    return 0
  }
  (b[p].to_int() << 8) | b[p + 1].to_int()
}

///|
fn get32(b : BytesView, p : Int32) -> UInt32 {
  if p < 0 || p > b.length() - 4 {
    return 0U
  }
  (b[p].to_uint() << 24) |
  (b[p + 1].to_uint() << 16) |
  (b[p + 2].to_uint() << 8) |
  b[p + 3].to_uint()
}

///|
fn put16(b : Array[Byte], p : Int32, v : Int32) -> Unit {
  b[p] = ((v >> 8) & 255).to_byte()
  b[p + 1] = (v & 255).to_byte()
}

///|
fn put32(b : Array[Byte], p : Int32, v : UInt32) -> Unit {
  b[p] = (v >> 24).to_byte()
  b[p + 1] = (v >> 16).to_byte()
  b[p + 2] = (v >> 8).to_byte()
  b[p + 3] = v.to_byte()
}

///|
fn append16(b : Array[Byte], v : Int32) -> Unit {
  b.push(((v >> 8) & 255).to_byte())
  b.push((v & 255).to_byte())
}

///|
fn append32(b : Array[Byte], v : UInt32) -> Unit {
  b.push((v >> 24).to_byte())
  b.push((v >> 16).to_byte())
  b.push((v >> 8).to_byte())
  b.push(v.to_byte())
}

///|
fn append_bytes(out : Array[Byte], data : BytesView) -> Unit {
  for b in data {
    out.push(b)
  }
}

///|
fn base128(data : BytesView, start : Int32) -> (Int32, Int32) raise {
  let mut pos = start
  let mut value = 0U
  for i in 0..<5 {
    if pos >= data.length() {
      fail()
      return (0, pos)
    }
    let byte = data[pos].to_uint()
    pos += 1
    if (i == 0 && byte == 128U) || (value & 0xfe000000U) != 0U {
      fail()
      return (0, pos)
    }
    value = (value << 7) | (byte & 127U)
    if (byte & 128U) == 0U {
      if value > 0x40000000U {
        fail()
      }
      return (value.reinterpret_as_int(), pos)
    }
  }
  fail()
  (0, pos)
}

///|
priv struct WoffEntry {
  tag : String
  transformed : Bool
  length : Int32
}

///|
fn bounded_brotli(data : BytesView, size : Int32) -> Bytes raise {
  let decoder = @brotli.Decoder()
  let result : Array[Byte] = []
  let mut rest = data
  while true {
    let capacity = Int32::min(65536, size - result.length() + 1)
    let chunk = FixedArray::make(capacity, b'\x00')
    ignore(decoder.step_into(rest, chunk, end=true)) catch {
      @codec.CodecError(@codec.Truncated, _) =>
        raise Woff2Failure("brotli: truncated input")
      _ => raise Woff2Failure("woff2: malformed Brotli stream")
    }
    rest = rest[decoder.last_consumed():]
    let count = decoder.last_produced()
    for i in 0..<count {
      if result.length() == size {
        return Bytes::from_array(result)
      }
      result.push(chunk[i])
    }
    if decoder.is_finished() {
      return Bytes::from_array(result)
    }
  }
  Bytes::from_array(result)
}

///|
/// Decode a WOFF2 font into an SFNT, with transformed glyf, loca and hmtx
/// reconstructed and the decompressed table data bounded to 256 MiB.
pub fn decode(data : Bytes) -> Bytes raise {
  if data.length() < 48 || !data.has_prefix(b"wOF2") {
    raise Woff2Failure("woff2: not a WOFF2 font")
  }
  let view = data[:]
  let flavor = get32(view, 4)
  if flavor == 0x74746366U {
    raise Woff2Failure("woff2: font collections are not supported")
  }
  let count = get16(view, 12)
  let compressed = get32(view, 20).to_uint64()
  let entries : Array[WoffEntry] = []
  let mut pos = 48
  let mut size : Int64 = 0L
  for _ in 0..<count {
    if pos >= data.length() {
      fail()
    }
    let flags = data[pos].to_int()
    pos += 1
    let index = flags & 63
    let tag = if index == 63 {
      if pos > data.length() - 4 {
        fail()
      }
      let text = @utf8.decode_lossy(data[pos:pos + 4])
      pos += 4
      text
    } else {
      known_tags[index]
    }
    let (original, next) = base128(view, pos)
    pos = next
    let version = flags >> 6
    let transformed = if tag == "glyf" || tag == "loca" {
      version == 0
    } else {
      version != 0
    }
    let length = if transformed {
      let (length, next) = base128(view, pos)
      pos = next
      length
    } else {
      original
    }
    size += length.to_int64()
    if size > 268435456L {
      raise Woff2Failure("woff2: the tables of the font are too large")
    }
    entries.push({ tag, transformed, length, })
  }
  if compressed > (data.length() - pos).to_uint64() {
    fail()
  }
  let stream = bounded_brotli(
    data[pos:pos + compressed.to_int()],
    size.to_int(),
  )
  let tables : Map[String, Bytes] = Map([])
  let mut offset = 0
  for entry in entries {
    if entry.length > stream.length() - offset {
      fail()
    }
    if !entry.transformed {
      tables[entry.tag] = stream[offset:offset + entry.length].to_owned()
    }
    offset += entry.length
  }
  offset = 0
  for entry in entries {
    if entry.transformed {
      match entry.tag {
        "glyf" => {
          let (glyf, loca) = rebuild_glyf(stream[offset:offset + entry.length])
          tables["glyf"] = glyf
          tables["loca"] = loca
          match tables.get("head") {
            Some(head) if head.length() >= 54 => {
              let h = head.to_array()
              put16(h, 50, 1)
              tables["head"] = Bytes::from_array(h)
            }
            _ => ()
          }
        }
        "loca" | "hmtx" => ()
        _ =>
          raise Woff2Failure("woff2: unknown transform of table " + entry.tag)
      }
    }
    offset += entry.length
  }
  offset = 0
  for entry in entries {
    if entry.transformed && entry.tag == "hmtx" {
      tables["hmtx"] = rebuild_hmtx(
        stream[offset:offset + entry.length],
        tables,
      )
    }
    offset += entry.length
  }
  build_sfnt(flavor, tables)
}

///|
fn build_sfnt(flavor : UInt32, tables : Map[String, Bytes]) -> Bytes {
  let tags = tables.keys().collect()
  tags.sort()
  let n = tags.length()
  let mut exponent = 0
  let mut range = 1
  while range * 2 <= n {
    range *= 2
    exponent += 1
  }
  let out = Bytes::make(12 + 16 * n, 0).to_array()
  put32(out, 0, flavor)
  put16(out, 4, n)
  put16(out, 6, range * 16)
  put16(out, 8, exponent)
  put16(out, 10, n * 16 - range * 16)
  for i, tag in tags {
    let bytes = @utf8.encode(tag)
    let data = tables[tag]
    let record = 12 + 16 * i
    for j in 0..<Int32::min(4, bytes.length()) {
      out[record + j] = bytes[j]
    }
    let mut sum = 0U
    let mut p = 0
    while p < data.length() {
      let mut word = 0U
      for j in 0..<4 {
        word = word << 8
        if p + j < data.length() {
          word = word | data[p + j].to_uint()
        }
      }
      sum += word
      p += 4
    }
    put32(out, record + 4, sum)
    put32(out, record + 8, out.length().reinterpret_as_uint())
    put32(out, record + 12, data.length().reinterpret_as_uint())
    append_bytes(out, data[:])
    while out.length() % 4 != 0 {
      out.push(0)
    }
  }
  Bytes::from_array(out)
}
