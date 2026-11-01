///|
/// CCITT fax run-length codes (ITU-T T.4). The tables are from
/// golang.org/x/image/ccitt, Copyright 2019 The Go Authors, BSD-style
/// license (../../licenses/Go-x-text.txt).
let ccitt_white_codes : String = "0:00110101 1:000111 2:0111 3:1000 4:1011 5:1100 6:1110 7:1111 8:10011 9:10100 10:00111 11:01000 12:001000 13:000011 14:110100 15:110101 16:101010 17:101011 18:0100111 19:0001100 20:0001000 21:0010111 22:0000011 23:0000100 24:0101000 25:0101011 26:0010011 27:0100100 28:0011000 29:00000010 30:00000011 31:00011010 32:00011011 33:00010010 34:00010011 35:00010100 36:00010101 37:00010110 38:00010111 39:00101000 40:00101001 41:00101010 42:00101011 43:00101100 44:00101101 45:00000100 46:00000101 47:00001010 48:00001011 49:01010010 50:01010011 51:01010100 52:01010101 53:00100100 54:00100101 55:01011000 56:01011001 57:01011010 58:01011011 59:01001010 60:01001011 61:00110010 62:00110011 63:00110100 64:11011 128:10010 192:010111 256:0110111 320:00110110 384:00110111 448:01100100 512:01100101 576:01101000 640:01100111 704:011001100 768:011001101 832:011010010 896:011010011 960:011010100 1024:011010101 1088:011010110 1152:011010111 1216:011011000 1280:011011001 1344:011011010 1408:011011011 1472:010011000 1536:010011001 1600:010011010 1664:011000 1728:010011011 1792:00000001000 1856:00000001100 1920:00000001101 1984:000000010010 2048:000000010011 2112:000000010100 2176:000000010101 2240:000000010110 2304:000000010111 2368:000000011100 2432:000000011101 2496:000000011110 2560:000000011111"

///|
let ccitt_black_codes : String = "0:0000110111 1:010 2:11 3:10 4:011 5:0011 6:0010 7:00011 8:000101 9:000100 10:0000100 11:0000101 12:0000111 13:00000100 14:00000111 15:000011000 16:0000010111 17:0000011000 18:0000001000 19:00001100111 20:00001101000 21:00001101100 22:00000110111 23:00000101000 24:00000010111 25:00000011000 26:000011001010 27:000011001011 28:000011001100 29:000011001101 30:000001101000 31:000001101001 32:000001101010 33:000001101011 34:000011010010 35:000011010011 36:000011010100 37:000011010101 38:000011010110 39:000011010111 40:000001101100 41:000001101101 42:000011011010 43:000011011011 44:000001010100 45:000001010101 46:000001010110 47:000001010111 48:000001100100 49:000001100101 50:000001010010 51:000001010011 52:000000100100 53:000000110111 54:000000111000 55:000000100111 56:000000101000 57:000001011000 58:000001011001 59:000000101011 60:000000101100 61:000001011010 62:000001100110 63:000001100111 64:0000001111 128:000011001000 192:000011001001 256:000001011011 320:000000110011 384:000000110100 448:000000110101 512:0000001101100 576:0000001101101 640:0000001001010 704:0000001001011 768:0000001001100 832:0000001001101 896:0000001110010 960:0000001110011 1024:0000001110100 1088:0000001110101 1152:0000001110110 1216:0000001110111 1280:0000001010010 1344:0000001010011 1408:0000001010100 1472:0000001010101 1536:0000001011010 1600:0000001011011 1664:0000001100100 1728:0000001100101 1792:00000001000 1856:00000001100 1920:00000001101 1984:000000010010 2048:000000010011 2112:000000010100 2176:000000010101 2240:000000010110 2304:000000010111 2368:000000011100 2432:000000011101 2496:000000011110 2560:000000011111"

///|
fn ccitt_build_run_lut(list : String) -> FixedArray[Int32] {
  let lut : FixedArray[Int32] = FixedArray::make(8192, -1)
  for token in list.split(" ") {
    if token == "" {
      continue
    }
    let parts = token.split(":").to_array()
    if parts.length() != 2 {
      continue
    }
    let value = @string.parse_int(parts[0]) catch { _ => continue }
    let code = parts[1]
    let length = code.length()
    if length <= 0 || length > 13 {
      continue
    }
    let mut bits = 0
    for ch in code {
      bits = (bits << 1) | (if ch == '1' { 1 } else { 0 })
    }
    let shift = 13 - length
    let start = bits << shift
    for i in 0..<(1 << shift) {
      lut[start + i] = (value << 8) | length
    }
  }
  lut
}

///|
fn ccitt_build_mode_lut() -> FixedArray[Int32] {
  let codes : Array[(String, Int32)] = [
    ("0001", 0),
    ("001", 1),
    ("1", 2),
    ("011", 3),
    ("000011", 4),
    ("0000011", 5),
    ("010", 6),
    ("000010", 7),
    ("0000010", 8),
    ("0000001", 9),
  ]
  let lut : FixedArray[Int32] = FixedArray::make(128, -1)
  for entry in codes {
    let code = entry.0
    let value = entry.1
    let length = code.length()
    let mut bits = 0
    for ch in code {
      bits = (bits << 1) | (if ch == '1' { 1 } else { 0 })
    }
    let shift = 7 - length
    let start = bits << shift
    for i in 0..<(1 << shift) {
      lut[start + i] = (value << 8) | length
    }
  }
  lut
}

///|
let ccitt_white_lut : FixedArray[Int32] = ccitt_build_run_lut(ccitt_white_codes)

///|
let ccitt_black_lut : FixedArray[Int32] = ccitt_build_run_lut(ccitt_black_codes)

///|
let ccitt_mode_lut : FixedArray[Int32] = ccitt_build_mode_lut()

///|
priv struct CcittBits {
  data : Bytes
  mut pos : Int32
}

///|
fn CcittBits::bit(self : CcittBits, offset : Int32) -> Int32 {
  let bit = self.pos + offset
  if bit < 0 || bit >= self.data.length() * 8 {
    0
  } else {
    (self.data[bit / 8].to_int() >> (7 - bit % 8)) & 1
  }
}

///|
fn CcittBits::peek(self : CcittBits, count : Int32) -> Int32 {
  let mut value = 0
  for i in 0..<count {
    value = (value << 1) | self.bit(i)
  }
  value
}

///|
fn CcittBits::skip(self : CcittBits, count : Int32) -> Unit {
  self.pos += count
}

///|
fn CcittBits::done(self : CcittBits) -> Bool {
  self.pos >= self.data.length() * 8
}

///|
fn CcittBits::align_byte(self : CcittBits) -> Unit {
  self.pos = (self.pos + 7) / 8 * 8
}

///|
fn CcittBits::zeros(self : CcittBits) -> Int32 {
  let mut count = 0
  while !self.done() && self.peek(1) == 0 {
    self.pos += 1
    count += 1
  }
  count
}

///|
fn CcittBits::eol(self : CcittBits) -> Bool {
  let start = self.pos
  if self.zeros() >= 11 && !self.done() {
    self.pos += 1
    true
  } else {
    self.pos = start
    false
  }
}

///|
fn CcittBits::next_eol(self : CcittBits) -> Bool {
  while !self.done() {
    let zeros = self.zeros()
    if self.done() {
      return false
    }
    self.pos += 1
    if zeros >= 11 {
      return true
    }
  }
  false
}

///|
fn ccitt_run(reader : CcittBits, white : Bool) -> Int32? {
  let lut = if white { ccitt_white_lut } else { ccitt_black_lut }
  let mut total = 0
  while true {
    if reader.done() {
      return None
    }
    let entry = lut[reader.peek(13)]
    if entry < 0 {
      return None
    }
    reader.skip(entry & 0xff)
    let value = entry >> 8
    total += value
    if value < 64 {
      return Some(total)
    }
  }
  None
}

///|
fn ccitt_decode_1d(reader : CcittBits, width : Int32) -> Array[Int32]? {
  let changes : Array[Int32] = []
  let mut a0 = 0
  let mut white = true
  while a0 < width {
    let run = ccitt_run(reader, white)
    let n = match run {
      Some(value) => value
      None => return None
    }
    a0 = if a0 + n < width { a0 + n } else { width }
    changes.push(a0)
    white = !white
  }
  Some(changes)
}

///|
fn ccitt_decode_2d(
  reader : CcittBits,
  reference : Array[Int32],
  width : Int32,
) -> Array[Int32]? {
  let changes : Array[Int32] = []
  let mut a0 = -1
  let mut white = true
  let mut k = 0
  while a0 < width {
    while k < reference.length() && reference[k] <= a0 {
      k += 1
    }
    let mut i = k
    if (i % 2 == 0) != white {
      i += 1
    }
    let mut b1 = width
    let mut b2 = width
    if i < reference.length() {
      b1 = reference[i]
    }
    if i + 1 < reference.length() {
      b2 = reference[i + 1]
    }
    if reader.done() {
      return None
    }
    let entry = ccitt_mode_lut[reader.peek(7)]
    if entry < 0 {
      return None
    }
    reader.skip(entry & 0xff)
    let mode = entry >> 8
    match mode {
      0 => a0 = b2
      1 => {
        let start = if a0 > 0 { a0 } else { 0 }
        let first = ccitt_run(reader, white)
        let n1 = match first {
          Some(value) => value
          None => return None
        }
        let second = ccitt_run(reader, !white)
        let n2 = match second {
          Some(value) => value
          None => return None
        }
        let a1 = if start + n1 < width { start + n1 } else { width }
        a0 = if a1 + n2 < width { a1 + n2 } else { width }
        changes.push(a1)
        changes.push(a0)
      }
      9 => return None
      _ => {
        let delta = match mode {
          2 => 0
          3 => 1
          4 => 2
          5 => 3
          6 => -1
          7 => -2
          _ => -3
        }
        let a1 = b1 + delta
        let minimum = if a0 > 0 { a0 } else { 0 }
        if a1 < minimum || a1 > width {
          return None
        }
        changes.push(a1)
        a0 = a1
        white = !white
      }
    }
  }
  Some(changes)
}

///|
fn ccitt_set_runs(
  out : FixedArray[Byte],
  base : Int32,
  changes : Array[Int32],
  width : Int32,
) -> Unit {
  let mut i = 0
  while i < changes.length() {
    let from = changes[i]
    let to = if i + 1 < changes.length() { changes[i + 1] } else { width }
    let mut x = from
    while x < to && x < width {
      if x >= 0 {
        out[base + x / 8] = (out[base + x / 8].to_int() | (0x80 >> (x % 8))).to_byte()
      }
      x += 1
    }
    i += 2
  }
}

///|
/// Decode CCITT fax data into packed rows (1 bits for black, rows padded
/// to bytes). `mode` is TIFF_COMPRESSION_CCITT_RLE, _G3 or _G4; `two_d`
/// is the T.4 two-dimensional option; `lsb` is FillOrder 2.
fn tiff_decode_ccitt(
  src : Bytes,
  mode : Int32,
  two_d : Bool,
  lsb : Bool,
  width : Int32,
  rows : Int32,
) -> (Bytes, Bool) {
  if width <= 0 || rows <= 0 {
    return (b"", true)
  }
  let data = if lsb { tiff_reverse_bits(src) } else { src }
  let row_bytes = (width + 7) / 8
  let out : FixedArray[Byte] = FixedArray::make(row_bytes * rows, 0)
  let reader : CcittBits = { data, pos: 0, }
  let mut reference : Array[Int32] = [width, width]
  let mut damaged = false
  for y in 0..<rows {
    if reader.done() {
      return (Bytes::from_array(out), true)
    }
    let mut row_two_d = mode == TIFF_COMPRESSION_G4
    if mode == TIFF_COMPRESSION_G3 {
      ignore(reader.eol())
      if two_d {
        row_two_d = reader.peek(1) == 0
        reader.skip(1)
      }
    }
    let decoded = if row_two_d {
      ccitt_decode_2d(reader, reference, width)
    } else {
      ccitt_decode_1d(reader, width)
    }
    match decoded {
      Some(changes) => {
        ccitt_set_runs(out, y * row_bytes, changes, width)
        let next : Array[Int32] = changes.copy()
        next.push(width)
        next.push(width)
        reference = next
        if mode == TIFF_COMPRESSION_CCITT_RLE {
          reader.align_byte()
        }
      }
      None => {
        damaged = true
        if mode != TIFF_COMPRESSION_G3 || !reader.next_eol() {
          return (Bytes::from_array(out), true)
        }
        reader.pos -= 12
        if reader.pos < 0 {
          reader.pos = 0
        }
        if two_d {
          reference = [width, width]
        }
      }
    }
  }
  (Bytes::from_array(out), damaged)
}
