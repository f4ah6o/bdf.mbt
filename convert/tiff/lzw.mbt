///|
/// Decode TIFF LZW (MSB codes, 8-bit literals, early change). The decoder
/// stops at `max` bytes; a short result means the data ended or was bad.
fn tiff_lzw_decode(data : Bytes, max : Int32) -> Bytes {
  if max <= 0 {
    return b""
  }
  let prefix : FixedArray[Int32] = FixedArray::make(4096, 0)
  let suffix : FixedArray[Byte] = FixedArray::make(4096, 0)
  let out = @buffer.Buffer()
  let mut position = 0L
  let mut width = 9
  let mut highest = 257
  let mut overflow = 512
  let mut previous = -1
  while out.length() < max {
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
    let expansion : Array[Byte] = []
    if code < 256 {
      expansion.push(code.to_byte())
    } else if code <= highest {
      let special = code == highest && previous >= 0
      let mut current = if special { previous } else { code }
      let mut count = 0
      while current >= 256 {
        if current >= 4096 || count >= 4096 {
          return out.to_bytes()
        }
        expansion.push(suffix[current])
        current = prefix[current]
        count += 1
      }
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
      return out.to_bytes()
    }
    if previous >= 0 && highest < 4096 {
      prefix[highest] = previous
      suffix[highest] = expansion[0]
    }
    previous = code
    if highest < 4096 {
      highest += 1
    }
    let adjusted = highest + 1
    if adjusted >= overflow && width < 12 {
      width += 1
      overflow *= 2
    }
    for byte in expansion {
      if out.length() >= max {
        break
      }
      out.write_byte(byte)
    }
  }
  out.to_bytes()
}
