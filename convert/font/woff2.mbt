///|
// Validate the WOFF2 table directory before reporting that this build has no
// Brotli decoder, just as the upstream no-converter browser build does.
fn woff2_input_error(data : Bytes) -> String {
  if data.length() < 48 {
    return "font: woff2: not a WOFF2 font"
  }
  if be32(data[:], 4) == 0x74746366U {
    return "font: woff2: font collections are not supported"
  }
  let count = be16(data[:], 12)
  let compressed = be32(data[:], 20)
  let mut pos = 48
  let mut total : UInt64 = 0UL
  for _ in 0..<count {
    if pos >= data.length() {
      return "font: woff2: malformed font"
    }
    let flags = data[pos].to_int()
    pos += 1
    let tag_index = flags & 63
    let mut glyf_loca = tag_index == 10 || tag_index == 11
    if tag_index == 63 {
      if pos > data.length() - 4 {
        return "font: woff2: malformed font"
      }
      let tag = be32(data[:], pos)
      glyf_loca = tag == 0x676c7966U || tag == 0x6c6f6361U
      pos += 4
    }
    let (original, next) = match woff2_base128(data, pos) {
      Some(value) => value
      None => return "font: woff2: malformed font"
    }
    pos = next
    let version = flags >> 6
    let transformed = if glyf_loca { version == 0 } else { version != 0 }
    let length = if transformed {
      match woff2_base128(data, pos) {
        Some((length, next)) => {
          pos = next
          length
        }
        None => return "font: woff2: malformed font"
      }
    } else {
      original
    }
    total += length.to_uint64()
    if total > 268435456UL {
      return "font: woff2: the tables of the font are too large"
    }
  }
  if compressed > (data.length() - pos).reinterpret_as_uint() {
    return "font: woff2: malformed font"
  }
  "font: WOFF2 fonts cannot be read in this build (it has no Brotli decoder)"
}

///|
fn woff2_base128(data : Bytes, start : Int32) -> (UInt32, Int32)? {
  let mut pos = start
  let mut value = 0U
  for i in 0..<5 {
    if pos >= data.length() {
      return None
    }
    let byte = data[pos].to_uint()
    pos += 1
    if (i == 0 && byte == 0x80U) || (value & 0xfe000000U) != 0U {
      return None
    }
    value = (value << 7) | (byte & 0x7fU)
    if (byte & 0x80U) == 0U {
      if value > 0x40000000U {
        return None
      }
      return Some((value, pos))
    }
  }
  None
}
