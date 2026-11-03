///|
// CCITT fax decoding for PDF image streams. The run-length and mode tables are
// adapted from golang.org/x/image/ccitt, Copyright 2019 The Go Authors,
// BSD-style license (see licenses/Go-x-image.txt). The PDF filter parameters
// differ from TIFF's, so this is a package-local decoder rather than a shared
// dependency on convert/tiff.
priv struct PdfCcittParams {
  mut k : Int32
  mut columns : Int32
  mut rows : Int32
  mut black_is1 : Bool
  mut encoded_byte_align : Bool
  mut damaged_rows_before_error : Int32
}

///|
fn pdf_ccitt_default_params() -> PdfCcittParams {
  {
    k: 0,
    columns: 0,
    rows: 0,
    black_is1: false,
    encoded_byte_align: false,
    damaged_rows_before_error: 0,
  }
}

///|
let pdf_ccitt_white_codes : String = "0:00110101 1:000111 2:0111 3:1000 4:1011 5:1100 6:1110 7:1111 8:10011 9:10100 10:00111 11:01000 12:001000 13:000011 14:110100 15:110101 16:101010 17:101011 18:0100111 19:0001100 20:0001000 21:0010111 22:0000011 23:0000100 24:0101000 25:0101011 26:0010011 27:0100100 28:0011000 29:00000010 30:00000011 31:00011010 32:00011011 33:00010010 34:00010011 35:00010100 36:00010101 37:00010110 38:00010111 39:00101000 40:00101001 41:00101010 42:00101011 43:00101100 44:00101101 45:00000100 46:00000101 47:00001010 48:00001011 49:01010010 50:01010011 51:01010100 52:01010101 53:00100100 54:00100101 55:01011000 56:01011001 57:01011010 58:01011011 59:01001010 60:01001011 61:00110010 62:00110011 63:00110100 64:11011 128:10010 192:010111 256:0110111 320:00110110 384:00110111 448:01100100 512:01100101 576:01101000 640:01100111 704:011001100 768:011001101 832:011010010 896:011010011 960:011010100 1024:011010101 1088:011010110 1152:011010111 1216:011011000 1280:011011001 1344:011011010 1408:011011011 1472:010011000 1536:010011001 1600:010011010 1664:011000 1728:010011011 1792:00000001000 1856:00000001100 1920:00000001101 1984:000000010010 2048:000000010011 2112:000000010100 2176:000000010101 2240:000000010110 2304:000000010111 2368:000000011100 2432:000000011101 2496:000000011110 2560:000000011111"

///|
let pdf_ccitt_black_codes : String = "0:0000110111 1:010 2:11 3:10 4:011 5:0011 6:0010 7:00011 8:000101 9:000100 10:0000100 11:0000101 12:0000111 13:00000100 14:00000111 15:000011000 16:0000010111 17:0000011000 18:0000001000 19:00001100111 20:00001101000 21:00001101100 22:00000110111 23:00000101000 24:00000010111 25:00000011000 26:000011001010 27:000011001011 28:000011001100 29:000011001101 30:000001101000 31:000001101001 32:000001101010 33:000001101011 34:000011010010 35:000011010011 36:000011010100 37:000011010101 38:000011010110 39:000011010111 40:000001101100 41:000001101101 42:000011011010 43:000011011011 44:000001010100 45:000001010101 46:000001010110 47:000001010111 48:000001100100 49:000001100101 50:000001010010 51:000001010011 52:000000100100 53:000000110111 54:000000111000 55:000000100111 56:000000101000 57:000001011000 58:000001011001 59:000000101011 60:000000101100 61:000001011010 62:000001100110 63:000001100111 64:0000001111 128:000011001000 192:000011001001 256:000001011011 320:000000110011 384:000000110100 448:000000110101 512:0000001101100 576:0000001101101 640:0000001001010 704:0000001001011 768:0000001001100 832:0000001001101 896:0000001110010 960:0000001110011 1024:0000001110100 1088:0000001110101 1152:0000001110110 1216:0000001110111 1280:0000001010010 1344:0000001010011 1408:0000001010100 1472:0000001010101 1536:0000001011010 1600:0000001011011 1664:0000001100100 1728:0000001100101 1792:00000001000 1856:00000001100 1920:00000001101 1984:000000010010 2048:000000010011 2112:000000010100 2176:000000010101 2240:000000010110 2304:000000010111 2368:000000011100 2432:000000011101 2496:000000011110 2560:000000011111"

///|
fn pdf_ccitt_build_run_lut(list : String) -> FixedArray[Int32] {
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
fn pdf_ccitt_build_mode_lut() -> FixedArray[Int32] {
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
let pdf_ccitt_white_lut : FixedArray[Int32] = pdf_ccitt_build_run_lut(
  pdf_ccitt_white_codes,
)

///|
let pdf_ccitt_black_lut : FixedArray[Int32] = pdf_ccitt_build_run_lut(
  pdf_ccitt_black_codes,
)

///|
let pdf_ccitt_mode_lut : FixedArray[Int32] = pdf_ccitt_build_mode_lut()

///|
priv struct PdfCcittBits {
  data : Bytes
  mut pos : Int32
}

///|
fn PdfCcittBits::bit(self : PdfCcittBits, offset : Int32) -> Int32 {
  let bit = self.pos + offset
  if bit < 0 || bit >= self.data.length() * 8 {
    0
  } else {
    (self.data[bit / 8].to_int() >> (7 - bit % 8)) & 1
  }
}

///|
fn PdfCcittBits::peek(self : PdfCcittBits, count : Int32) -> Int32 {
  let mut value = 0
  for i in 0..<count {
    value = (value << 1) | self.bit(i)
  }
  value
}

///|
fn PdfCcittBits::skip(self : PdfCcittBits, count : Int32) -> Unit {
  self.pos += count
}

///|
fn PdfCcittBits::done(self : PdfCcittBits) -> Bool {
  self.pos >= self.data.length() * 8
}

///|
fn PdfCcittBits::align_byte(self : PdfCcittBits) -> Unit {
  self.pos = (self.pos + 7) / 8 * 8
}

///|
fn PdfCcittBits::zeros(self : PdfCcittBits) -> Int32 {
  let mut count = 0
  while !self.done() && self.peek(1) == 0 {
    self.pos += 1
    count += 1
  }
  count
}

///|
fn PdfCcittBits::eol(self : PdfCcittBits) -> Bool {
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
fn PdfCcittBits::next_eol(self : PdfCcittBits) -> Bool {
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
fn pdf_ccitt_run(reader : PdfCcittBits, white : Bool) -> Int32? {
  let lut = if white { pdf_ccitt_white_lut } else { pdf_ccitt_black_lut }
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
fn pdf_ccitt_decode_1d(reader : PdfCcittBits, width : Int32) -> Array[Int32]? {
  let changes : Array[Int32] = []
  let mut a0 = 0
  let mut white = true
  while a0 < width {
    let run = pdf_ccitt_run(reader, white)
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
fn pdf_ccitt_decode_2d(
  reader : PdfCcittBits,
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
    let entry = pdf_ccitt_mode_lut[reader.peek(7)]
    if entry < 0 {
      return None
    }
    reader.skip(entry & 0xff)
    let mode = entry >> 8
    match mode {
      0 => a0 = b2
      1 => {
        let start = if a0 > 0 { a0 } else { 0 }
        let first = pdf_ccitt_run(reader, white)
        let n1 = match first {
          Some(value) => value
          None => return None
        }
        let second = pdf_ccitt_run(reader, !white)
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
fn pdf_ccitt_set_runs(
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
        out[base + x / 8] = (out[base + x / 8].to_int() |
          (0x80 >> (x % 8))).to_byte()
      }
      x += 1
    }
    i += 2
  }
}

///|
// Decode a CCITT image into packed rows with 1 bits for black ink. The PDF
// BlackIs1 parameter describes the sample value representing black; it does
// not change which run is ink, so ink stays 1 here.
fn pdf_decode_ccitt(
  params : PdfCcittParams,
  width : Int32,
  height : Int32,
  src : Bytes,
) -> Bytes raise PdfStreamError {
  if width <= 0 || height <= 0 {
    raise InvalidStream("invalid PDF CCITT image size")
  }
  let columns = if params.columns > 0 { params.columns } else { width }
  if columns != width {
    raise InvalidStream("PDF CCITT Columns does not match the image width")
  }
  let rows = if params.rows > 0 { params.rows } else { height }
  if rows != height {
    raise InvalidStream("PDF CCITT Rows does not match the image height")
  }
  let row_bytes = (width + 7) / 8
  let needed = row_bytes.to_int64() * rows.to_int64()
  if needed > 1073741824L {
    raise InvalidStream("PDF CCITT image exceeds the decode limit")
  }
  let out : FixedArray[Byte] = FixedArray::make(needed.to_int(), 0)
  let reader : PdfCcittBits = { data: src, pos: 0 }
  let mut reference : Array[Int32] = [width, width]
  let mut damaged_rows = 0
  let tolerance = if params.damaged_rows_before_error > 0 {
    params.damaged_rows_before_error
  } else {
    0
  }
  for y in 0..<rows {
    if reader.done() {
      raise InvalidStream("PDF CCITT image data ended before all rows")
    }
    if y > 0 && params.encoded_byte_align {
      reader.align_byte()
    }
    if params.k >= 0 {
      ignore(reader.eol())
    }
    // K < 0 is pure 2-D, K = 0 is pure 1-D, and any K > 0 is T.4 mixed
    // mode: the bit after the EOL selects 1-D (1) or 2-D (0). The PDF
    // filter deliberately does not distinguish different positive K values.
    let row_two_d = if params.k < 0 {
      true
    } else if params.k == 0 {
      false
    } else {
      let tag = reader.peek(1)
      reader.skip(1)
      tag == 0
    }
    if params.encoded_byte_align {
      reader.align_byte()
    }
    let decoded = if row_two_d {
      pdf_ccitt_decode_2d(reader, reference, width)
    } else {
      pdf_ccitt_decode_1d(reader, width)
    }
    match decoded {
      Some(changes) => {
        pdf_ccitt_set_runs(out, y * row_bytes, changes, width)
        let next : Array[Int32] = changes.copy()
        next.push(width)
        next.push(width)
        reference = next
      }
      None => {
        damaged_rows += 1
        if damaged_rows > tolerance {
          raise InvalidStream("damaged PDF CCITT image data")
        }
        reference = [width, width]
        if params.k >= 0 {
          if !reader.next_eol() {
            raise InvalidStream("damaged PDF CCITT image data")
          }
        } else if reader.done() {
          raise InvalidStream("damaged PDF CCITT image data")
        }
      }
    }
  }
  Bytes::from_array(out)
}

///|
// Convert a packed CCITT row to an ink decision. black_is1 fixes which sample
// value is black and invert is the two-element Decode array.
fn pdf_ccitt_ink(bit : Int32, black_is1 : Bool, invert : Bool) -> Bool {
  let sample = if black_is1 { bit } else { 1 - bit }
  let ink = if black_is1 { sample == 1 } else { sample == 0 }
  if invert {
    !ink
  } else {
    ink
  }
}

///|
fn pdf_ccitt_rgb(
  width : Int32,
  height : Int32,
  data : Bytes,
  black_is1 : Bool,
  invert : Bool,
) -> Bytes raise PdfStreamError {
  if width <= 0 || height <= 0 {
    raise InvalidStream("invalid PDF CCITT image size")
  }
  if width.to_int64() * height.to_int64() * 3L > 1073741824L {
    raise InvalidStream("PDF CCITT image exceeds the decode limit")
  }
  let row_bytes = (width + 7) / 8
  if data.length() < row_bytes * height {
    raise InvalidStream("PDF CCITT image samples are truncated")
  }
  let rgb = @buffer.Buffer(size_hint=width * height * 3)
  for y in 0..<height {
    for x in 0..<width {
      let bit = (data[y * row_bytes + x / 8].to_int() >> (7 - x % 8)) & 1
      let value = if pdf_ccitt_ink(bit, black_is1, invert) { 0 } else { 255 }
      rgb.write_byte(value.to_byte())
      rgb.write_byte(value.to_byte())
      rgb.write_byte(value.to_byte())
    }
  }
  rgb.to_bytes()
}

///|
fn pdf_ccitt_mask_rgba(
  width : Int32,
  height : Int32,
  data : Bytes,
  black_is1 : Bool,
  invert : Bool,
  fill : UInt32,
) -> Bytes raise PdfStreamError {
  if width <= 0 || height <= 0 {
    raise InvalidStream("invalid PDF CCITT image size")
  }
  if width.to_int64() * height.to_int64() * 4L > 1073741824L {
    raise InvalidStream("PDF CCITT image exceeds the decode limit")
  }
  let row_bytes = (width + 7) / 8
  if data.length() < row_bytes * height {
    raise InvalidStream("PDF CCITT image samples are truncated")
  }
  let red = ((fill >> 24) & 0xffU).reinterpret_as_int().to_byte()
  let green = ((fill >> 16) & 0xffU).reinterpret_as_int().to_byte()
  let blue = ((fill >> 8) & 0xffU).reinterpret_as_int().to_byte()
  let rgba = @buffer.Buffer(size_hint=width * height * 4)
  for y in 0..<height {
    for x in 0..<width {
      let bit = (data[y * row_bytes + x / 8].to_int() >> (7 - x % 8)) & 1
      if pdf_ccitt_ink(bit, black_is1, invert) {
        rgba.write_byte(red)
        rgba.write_byte(green)
        rgba.write_byte(blue)
        rgba.write_byte(0xff)
      } else {
        rgba.write_byte(0)
        rgba.write_byte(0)
        rgba.write_byte(0)
        rgba.write_byte(0)
      }
    }
  }
  rgba.to_bytes()
}

///|
fn pdf_ccitt_int(object : PdfObject?, key : Bytes, default : Int32) -> Int32 {
  match object {
    Some(value) =>
      match pdf_dict_get(value, key) {
        Some(PdfInt(number)) =>
          if number >= -2147483648L && number <= 2147483647L {
            number.to_int()
          } else {
            default
          }
        Some(PdfReal(number)) => number.to_int()
        _ => default
      }
    None => default
  }
}

///|
fn pdf_ccitt_bool(object : PdfObject?, key : Bytes, default : Bool) -> Bool {
  match object {
    Some(value) =>
      match pdf_dict_get(value, key) {
        Some(PdfBool(value)) => value
        _ => default
      }
    None => default
  }
}

///|
fn pdf_ccitt_filter_index(filters : Array[PdfStreamFilter]) -> Int32 {
  for i, filter in filters {
    if filter.name == b"CCITTFaxDecode" {
      return i
    }
  }
  -1
}

///|
fn pdf_ccitt_params(file : PdfFile, dict : PdfObject) -> PdfCcittParams {
  let params = pdf_ccitt_default_params()
  let filters = file.resolved_stream_filters(dict) catch { _ => return params }
  let index = pdf_ccitt_filter_index(filters)
  if index < 0 {
    return params
  }
  let resolved = file.page_deref(pdf_dict_get(dict, b"DecodeParms"))
  let options : PdfObject? = match resolved {
    PdfArray(values) =>
      if index < values.length() {
        Some(
          file.resolve_filter_params(file.page_deref(Some(values[index]))),
        )
      } else {
        None
      }
    PdfDict(_) => Some(file.resolve_filter_params(resolved))
    _ => None
  }
  params.k = pdf_ccitt_int(options, b"K", 0)
  params.columns = pdf_ccitt_int(options, b"Columns", 0)
  params.rows = pdf_ccitt_int(options, b"Rows", 0)
  params.black_is1 = pdf_ccitt_bool(options, b"BlackIs1", false)
  params.encoded_byte_align = pdf_ccitt_bool(options, b"EncodedByteAlign", false)
  params.damaged_rows_before_error = pdf_ccitt_int(
    options, b"DamagedRowsBeforeError", 0,
  )
  params
}

///|
fn pdf_inline_ccitt_bool(
  params : ContentValue?,
  key : Bytes,
  default : Bool,
) -> Bool {
  match params {
    Some(Dictionary(entries)) => {
      for (name, value) in entries {
        if name == key {
          match value {
            Boolean(value) => return value
            Integer(value) => return value != 0L
            _ => ()
          }
        }
      }
      default
    }
    _ => default
  }
}

///|
fn pdf_inline_ccitt_params(
  dict : Array[(Bytes, ContentValue)],
) -> PdfCcittParams {
  let params = pdf_ccitt_default_params()
  let filters = pdf_inline_filters(dict) catch { _ => return params }
  let index = pdf_ccitt_filter_index(filters)
  if index < 0 {
    return params
  }
  let raw = pdf_inline_value(dict, b"DP", b"DecodeParms")
  let options : ContentValue? = match raw {
    Some(Dictionary(_)) => raw
    Some(ArrayValue(values)) =>
      if index < values.length() {
        Some(values[index])
      } else {
        None
      }
    _ => None
  }
  params.k = pdf_inline_dict_int(options, b"K", 0)
  params.columns = pdf_inline_dict_int(options, b"Columns", 0)
  params.rows = pdf_inline_dict_int(options, b"Rows", 0)
  params.black_is1 = pdf_inline_ccitt_bool(options, b"BlackIs1", false)
  params.encoded_byte_align = pdf_inline_ccitt_bool(
    options, b"EncodedByteAlign", false,
  )
  params.damaged_rows_before_error = pdf_inline_dict_int(
    options, b"DamagedRowsBeforeError", 0,
  )
  params
}
