///|
// PDF LZW decoding adapted from pdfcpu's internal/filter/lzw/reader.go.
// Copyright 2011 The Go Authors; Copyright 2026 The pdfcpu Authors.
// BSD-style license: ../../licenses/Go-x-text.txt.
fn pdf_decode_lzw(
  data : Bytes,
  early_change : Int32,
  predictor : Int32,
  max : Int64,
) -> Bytes raise PdfStreamError {
  if predictor > 1 {
    raise InvalidStream("LZW predictor unsupported")
  }
  let limit = if max >= 2147483646L { 2147483647L } else { max + 1L }
  if limit <= 0L {
    return b""
  }
  let prefix : FixedArray[Int32] = FixedArray::make(4096, 0)
  let suffix : FixedArray[Byte] = FixedArray::make(4096, b'\x00')
  let result = @buffer.Buffer()
  let mut position = 0L
  let mut width = 9
  let mut highest = 257
  let mut overflow = 512
  let mut previous = -1
  while result.length().to_int64() < limit {
    if data.length().to_int64() * 8L - position < width.to_int64() {
      break
    }
    let mut code = 0
    for _ in 0..<width {
      let index = (position / 8L).to_int()
      let shift = 7 - (position % 8L).to_int()
      code = (code << 1) | ((data[index].to_int() >> shift) & 1)
      position += 1L
    }
    if code == 256 {
      width = 9
      highest = 257
      overflow = 512
      previous = -1
      continue
    }
    if code == 257 {
      break
    }
    let mut head = 0
    let expansion : Array[Byte] = []
    if code < 256 {
      head = code
      expansion.push(code.to_byte())
    } else if code <= highest {
      let special = code == highest && previous >= 0
      let mut current = if special { previous } else { code }
      let mut count = 0
      while current >= 256 {
        if current >= 4096 || count >= 4096 {
          raise InvalidStream("invalid LZW code chain")
        }
        expansion.push(suffix[current])
        current = prefix[current]
        count += 1
      }
      head = current
      expansion.push(current.to_byte())
      for i in 0..<(expansion.length() / 2) {
        let j = expansion.length() - 1 - i
        let value = expansion[i]
        expansion[i] = expansion[j]
        expansion[j] = value
      }
      if special {
        expansion.push(current.to_byte())
      }
    } else {
      raise InvalidStream("invalid LZW code")
    }
    if previous >= 0 && highest < 4096 {
      prefix[highest] = previous
      suffix[highest] = head.to_byte()
    }
    previous = code
    if highest < 4096 {
      highest += 1
    }
    let adjusted = highest + (if early_change == 1 { 1 } else { 0 })
    if adjusted >= overflow && width < 12 {
      width += 1
      overflow *= 2
    }
    for byte in expansion {
      if result.length().to_int64() >= limit {
        break
      }
      result.write_byte(byte)
    }
  }
  result.to_bytes()
}
