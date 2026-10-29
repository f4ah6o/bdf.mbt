///|
/// Errors reading or selecting the faces of a font file.
pub suberror FontInputError {
  InvalidFontInput(String)
}

///|
fn be16(data : BytesView, at : Int32) -> Int32 {
  if at < 0 || at + 1 >= data.length() {
    return 0
  }
  (data[at].to_int() << 8) | data[at + 1].to_int()
}

///|
fn be32(data : BytesView, at : Int32) -> UInt32 {
  if at < 0 || at + 3 >= data.length() {
    return 0U
  }
  (data[at].to_uint() << 24) |
  (data[at + 1].to_uint() << 16) |
  (data[at + 2].to_uint() << 8) |
  data[at + 3].to_uint()
}

///|
/// Detect a TrueType, OpenType, TTC, WOFF or WOFF2 signature using the
/// upstream converter's bounded header check.
pub fn detect(head : Bytes) -> Bool {
  if head.length() < 12 {
    return false
  }
  let tag = be32(head[:], 0)
  if tag == 0x774f4646U || tag == 0x774f4632U {
    return true
  }
  if tag == 0x74746366U {
    let version = be16(head[:], 4)
    let count = be32(head[:], 8)
    return (version == 1 || version == 2) && count >= 1U && count <= 65536U
  }
  if tag != 0x00010000U && tag != 0x4f54544fU && tag != 0x74727565U {
    return false
  }
  let count = be16(head[:], 4)
  if count < 1 || count > 256 {
    return false
  }
  let shown = Int32::min(count, (head.length() - 12) / 16)
  let mut seen = 0
  for i in 0..<shown {
    let pos = 12 + i * 16
    for j in 0..<4 {
      let byte = head[pos + j].to_int()
      if byte < 0x20 || byte > 0x7e {
        return false
      }
    }
    let table = be32(head[:], pos)
    if table == 0x636d6170U || table == 0x68656164U || table == 0x6d617870U {
      seen += 1
    }
  }
  shown > 0 && (seen == 3 || shown < count)
}

///|
/// One readable face, with its original zero-based collection index.
pub struct FileFace {
  index : Int32
  font : @sfnt.Font
  size : Int64
}

///|
/// Parsed font file and its readable faces (at most 64).
pub struct FontFile {
  container : String
  collection : Bool
  size : Int32
  priv faces : Array[FileFace]
}

///|
pub fn FontFile::faces(self : FontFile) -> Array[FileFace] {
  self.faces.copy()
}

///|
/// Read SFNT, TTC, or WOFF 1.0. WOFF2 requires a Brotli decoder and is not
/// yet supported. Faces that cannot be read are skipped in a collection.
pub fn load(data : Bytes) -> FontFile raise {
  if data.length() > 268435456 {
    raise InvalidFontInput("font: the file is larger than 268435456 bytes")
  }
  let container = if data.has_prefix(b"wOFF") {
    "WOFF"
  } else if data.has_prefix(b"wOF2") {
    "WOFF2"
  } else {
    ""
  }
  if container == "WOFF2" {
    raise InvalidFontInput(woff2_input_error(data))
  }
  let decoded = if container == "WOFF" {
    @sfnt.decode_woff(data) catch {
      @sfnt.InvalidFont(message) => raise InvalidFontInput("font: " + message)
      error => raise InvalidFontInput("font: " + error.to_string())
    }
  } else {
    data
  }
  if decoded.length() < 12 {
    raise InvalidFontInput("font: not a font file")
  }
  let collection = decoded.has_prefix(b"ttcf")
  let raw_count = if collection { be32(decoded[:], 8) } else { 1U }
  if raw_count == 0U {
    raise InvalidFontInput("font: not a font file")
  }
  let count = if raw_count > 64U { 64 } else { raw_count.reinterpret_as_int() }
  let faces : Array[FileFace] = []
  for index in 0..<count {
    let parsed = Some(@sfnt.parse(decoded, index~)) catch {
      @sfnt.InvalidFont(message) => {
        if count == 1 {
          let message = if collection && decoded.length() < 16 {
            "not an sfnt font"
          } else {
            message
          }
          raise InvalidFontInput("font: " + message)
        }
        None
      }
      _ => None
    }
    match parsed {
      Some(font) if font.metrics.glyph_count > 0 =>
        faces.push({
          index,
          font,
          size: if collection || container != "" {
            font.standalone_size()
          } else {
            decoded.length().to_int64()
          },
        })
      Some(_) if count == 1 =>
        raise InvalidFontInput("font: the font has no glyphs")
      _ => ()
    }
  }
  if faces.length() == 0 {
    raise InvalidFontInput("font: no font of the collection can be read")
  }
  { container, collection, size: data.length(), faces, }
}
