///|
/// Reconstruct an SFNT from a WOFF 1.0 container. Table output is limited to
/// 256 MiB, matching the upstream font converter's decompression limit.
pub fn decode_woff(data : Bytes) -> Bytes raise {
  if data.length() < 44 {
    raise InvalidFont("WOFF file too short")
  }
  let flavor = u32(data[:], 4)
  if flavor == 0x74746366U {
    raise InvalidFont("WOFF font collections are not supported")
  }
  let count = u16(data[:], 12)
  let mut total : UInt64 = 0UL
  for i in 0..<count {
    let rec = 44 + i * 20
    if rec <= data.length() - 20 {
      total += u32(data[:], rec + 12).to_uint64()
    }
    if total > 268435456UL {
      raise InvalidFont(
        "the tables of the WOFF file are larger than 268435456 bytes",
      )
    }
  }
  let tables : Map[String, Array[Byte]] = Map([])
  for i in 0..<count {
    let rec = 44 + i * 20
    if rec > data.length() - 20 {
      raise InvalidFont("WOFF table directory truncated")
    }
    let chars : Array[Char] = []
    for j in 0..<4 {
      chars.push(data[rec + j].to_int().unsafe_to_char())
    }
    let tag = String::from_array(chars)
    let quoted = woff_quote_tag(data[rec:rec + 4])
    let offset = u32(data[:], rec + 4)
    let compressed = u32(data[:], rec + 8)
    let original = u32(data[:], rec + 12)
    if offset > data.length().reinterpret_as_uint() ||
      compressed > data.length().reinterpret_as_uint() - offset ||
      original > 268435456U {
      raise InvalidFont("WOFF table " + quoted + " out of range")
    }
    let start = offset.reinterpret_as_int()
    let length = compressed.reinterpret_as_int()
    let bytes = data[start:start + length]
    if compressed < original {
      match woff_header_error(bytes) {
        Some(message) =>
          raise InvalidFont("WOFF table " + quoted + ": " + message)
        None => ()
      }
      let decoded = woff_inflate(bytes, original.reinterpret_as_int())
      match decoded {
        Some(bytes) => tables[tag] = bytes.to_array()
        None =>
          raise InvalidFont("WOFF table " + quoted + " does not decompress")
      }
    } else {
      tables[tag] = bytes.to_owned().to_array()
    }
  }
  build_tables(tables, flavor == 0x4f54544fU)
}

///|
fn woff_header_error(input : BytesView) -> String? {
  if input.length() < 2 {
    return Some("unexpected EOF")
  }
  let first = input[0].to_int()
  let second = input[1].to_int()
  if (first & 15) != 8 || first >> 4 > 7 || (first * 256 + second) % 31 != 0 {
    return Some("zlib: invalid header")
  }
  if (second & 32) != 0 {
    if input.length() < 6 {
      return Some("unexpected EOF")
    }
    if u32(input, 2) != 1U {
      return Some("zlib: invalid dictionary")
    }
  }
  None
}

///|
fn woff_inflate(input : BytesView, expected : Int32) -> Bytes? {
  let decoder = @zlib.Decoder(dictionary=b""[:], until=EndOfMember)
  let output = @buffer.Buffer()
  let mut offset = 0
  let mut size = 0
  while true {
    let room = Int32::min(16384, expected - size + 1)
    let chunk : FixedArray[Byte] = FixedArray::make(room, 0)
    let status = decoder.step_into(input[offset:], chunk, end=true) catch {
      _ => return None
    }
    let consumed = decoder.last_consumed()
    let produced = decoder.last_produced()
    size += produced
    if size > expected {
      return None
    }
    output.write_bytes(Bytes::from_array(chunk[:produced]))
    offset += consumed
    if status is Done {
      return if size == expected { Some(output.to_bytes()) } else { None }
    }
    if consumed == 0 && produced == 0 {
      return None
    }
  } nobreak {
    None
  }
}

///|
// Go formats table tags as quoted byte strings, preserving invalid UTF-8.
fn woff_quote_tag(data : BytesView) -> String {
  let hex = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
  ]
  let out = StringBuilder()
  out.write_char('"')
  let mut i = 0
  while i < data.length() {
    let first = data[i].to_int()
    let mut code = first
    let mut width = 1
    let needed = if first >= 0xc2 && first <= 0xdf {
      2
    } else if first >= 0xe0 && first <= 0xef {
      3
    } else if first >= 0xf0 && first <= 0xf4 {
      4
    } else {
      1
    }
    if needed > 1 && i + needed <= data.length() {
      let mut value = first & (0x7f >> needed)
      let mut valid = true
      for j in 1..<needed {
        let byte = data[i + j].to_int()
        if (byte & 0xc0) != 0x80 {
          valid = false
        }
        value = (value << 6) | (byte & 0x3f)
      }
      let minimum = if needed == 2 {
        0x80
      } else if needed == 3 {
        0x800
      } else {
        0x10000
      }
      if valid &&
        value >= minimum &&
        value <= 0x10ffff &&
        !(value >= 0xd800 && value <= 0xdfff) {
        code = value
        width = needed
      }
    }
    if first >= 0x80 && width == 1 {
      out.write_string("\\x")
      out.write_char(hex[first >> 4])
      out.write_char(hex[first & 15])
      i += 1
      continue
    }
    let c = code.unsafe_to_char()
    if c == '"' || c == '\\' {
      out.write_char('\\')
      out.write_char(c)
    } else {
      match c {
        '\u{07}' => out.write_string("\\a")
        '\b' => out.write_string("\\b")
        '\u{0c}' => out.write_string("\\f")
        '\n' => out.write_string("\\n")
        '\r' => out.write_string("\\r")
        '\t' => out.write_string("\\t")
        '\u{0b}' => out.write_string("\\v")
        _ => {
          let group = @ucd.general_category(c).group()
          if c == ' ' || (group != @ucd.C && group != @ucd.Z) {
            out.write_char(c)
          } else {
            let digits = if code < 0x20 || code == 0x7f {
              out.write_string("\\x")
              2
            } else if code < 0x10000 {
              out.write_string("\\u")
              4
            } else {
              out.write_string("\\U")
              8
            }
            for j = digits - 1; j >= 0; j = j - 1 {
              out.write_char(hex[(code >> (j * 4)) & 15])
            }
          }
        }
      }
    }
    i += width
  }
  out.write_char('"')
  out.to_string()
}
