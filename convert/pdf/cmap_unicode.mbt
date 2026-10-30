///|
// Upstream interprets pairs as big-endian UTF-16, combines a high surrogate
// with the following unit, and treats a single byte as its own code point.
fn pdf_utf16_runes(bytes : Bytes) -> Array[Int32] {
  let out : Array[Int32] = []
  let mut i = 0
  while i + 1 < bytes.length() {
    let mut value = bytes[i].to_int() * 256 + bytes[i + 1].to_int()
    if value >= 0xd800 && value < 0xdc00 && i + 3 < bytes.length() {
      let low = bytes[i + 2].to_int() * 256 + bytes[i + 3].to_int()
      value = 0x10000 + ((value - 0xd800) << 10) + low - 0xdc00
      i += 2
    }
    out.push(value)
    i += 2
  }
  if bytes.length() == 1 {
    out.push(bytes[0].to_int())
  }
  out
}

///|
fn pdf_runes_string(runes : Array[Int32]) -> String {
  let out = StringBuilder()
  for value in runes {
    let value = if value < 0 ||
      value > 0x10ffff ||
      (value >= 0xd800 && value <= 0xdfff) {
      0xfffd
    } else {
      value
    }
    out.write_char(value.unsafe_to_char())
  }
  out.to_string()
}

///|
fn PdfCMap::to_unicode(self : PdfCMap, code : Int64) -> String {
  match self.unicode.get(code) {
    Some(value) => return value
    None => ()
  }
  for range in self.unicode_ranges {
    if code >= range.low && code <= range.high && !range.destination.is_empty() {
      let runes = range.destination.copy()
      let last = runes.length() - 1
      // Go's rune arithmetic wraps at 32 bits.
      runes[last] = (runes[last].to_int64() + code - range.low).to_int()
      return pdf_runes_string(runes)
    }
  }
  ""
}

///|
fn PdfCMap::note_length(self : PdfCMap, n : Int32) -> Unit {
  if n == 1 {
    self.seen1 = true
  }
  if n == 2 {
    self.seen2 = true
  }
}
