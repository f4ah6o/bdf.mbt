///|
// ASCIIHexDecode as used by upstream pdfcpu (Apache-2.0). Unlike content
// string operands, a final single hex digit is padded with zero.
fn pdf_decode_ascii_hex(data : Bytes) -> Bytes raise PdfStreamError {
  let out : Array[Byte] = []
  let mut high = -1
  for byte in data {
    if byte == b'>' {
      break
    }
    if content_white(byte) {
      continue
    }
    let value = content_hex_digit(byte)
    if value < 0 {
      raise InvalidStream("invalid ASCIIHex data")
    }
    if high < 0 {
      high = value
    } else {
      out.push((high * 16 + value).to_byte())
      high = -1
    }
  }
  if high >= 0 {
    out.push((high * 16).to_byte())
  }
  Bytes::from_array(out)
}

///|
// PDF's ASCII85 decoder uses Go's encoding/ascii85 (Go BSD license) and
// requires an end marker unless the input itself is empty.
fn pdf_decode_ascii85(data : Bytes) -> Bytes raise PdfStreamError {
  if data.is_empty() {
    return b""
  }
  let mut end = -1
  for i in 0..<(data.length() - 1) {
    if data[i] == b'~' && data[i + 1] == b'>' {
      end = i
      break
    }
  }
  if end < 0 {
    raise InvalidStream("ASCII85 end marker missing")
  }
  let out : Array[Byte] = []
  let mut value = 0L
  let mut count = 0
  for i in 0..<end {
    let byte = data[i].to_int()
    if byte <= 32 {
      continue
    }
    if byte == 122 && count == 0 {
      count = 5
      value = 0L
    } else if byte >= 33 && byte <= 117 {
      value = (value * 85L + (byte - 33).to_int64()) & 0xffffffffL
      count += 1
    } else {
      raise InvalidStream("invalid ASCII85 data")
    }
    if count == 5 {
      out.push(((value >> 24) & 255L).to_byte())
      out.push(((value >> 16) & 255L).to_byte())
      out.push(((value >> 8) & 255L).to_byte())
      out.push((value & 255L).to_byte())
      count = 0
      value = 0L
    }
  }
  if count == 1 {
    raise InvalidStream("incomplete ASCII85 data")
  }
  if count > 1 {
    for _ in count..<5 {
      value = (value * 85L + 84L) & 0xffffffffL
    }
    for _ in 0..<(count - 1) {
      out.push(((value >> 24) & 255L).to_byte())
      value = (value << 8) & 0xffffffffL
    }
  }
  Bytes::from_array(out)
}
