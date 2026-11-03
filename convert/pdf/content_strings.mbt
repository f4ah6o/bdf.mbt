///|
// PDF literal strings can nest and use octal escapes and line continuations.
fn ContentLexer::read_literal(self : ContentLexer) -> Bytes {
  let out : Array[Byte] = []
  let mut depth = 1
  while self.pos < self.data.length() {
    let c = self.data[self.pos]
    self.pos += 1
    if c == b'\\' {
      if self.pos >= self.data.length() {
        break
      }
      let e = self.data[self.pos]
      self.pos += 1
      match e {
        b'n' => out.push(b'\n')
        b'r' => out.push(b'\r')
        b't' => out.push(b'\t')
        b'b' => out.push(b'\x08')
        b'f' => out.push(b'\x0c')
        b'\r' =>
          if self.pos < self.data.length() && self.data[self.pos] == b'\n' {
            self.pos += 1
          }
        b'\n' => ()
        _ =>
          if e >= b'0' && e <= b'7' {
            let mut value = e.to_int() - 48
            let mut count = 0
            while count < 2 &&
                  self.pos < self.data.length() &&
                  self.data[self.pos] >= b'0' &&
                  self.data[self.pos] <= b'7' {
              value = value * 8 + self.data[self.pos].to_int() - 48
              self.pos += 1
              count += 1
            }
            out.push((value % 256).to_byte())
          } else {
            out.push(e)
          }
      }
    } else if c == b'(' {
      depth += 1
      out.push(c)
    } else if c == b')' {
      depth -= 1
      if depth == 0 {
        break
      }
      out.push(c)
    } else {
      out.push(c)
    }
  }
  Bytes::from_array(out)
}

///|
fn pdf_inline_data_valid(
  data : Bytes,
  filters : Array[PdfStreamFilter],
) -> Bool {
  if filters.is_empty() {
    return true
  }
  let decoded = pdf_decode_stream(
    data,
    filters,
    1073741824L,
    false,
    1073741824L,
  ) catch {
    _ => return false
  }
  match decoded.1 {
    None => true
    Some(b"DCTDecode") =>
      data.length() >= 2 &&
      data[data.length() - 2] == b'\xff' &&
      data[data.length() - 1] == b'\xd9'
    Some(b"JPXDecode") =>
      (data.length() >= 2 &&
        data[data.length() - 2] == b'\xff' &&
        data[data.length() - 1] == b'\xd9') ||
      (data.length() >= 12 &&
        data[4] == b'j' &&
        data[5] == b'P' &&
        data[6] == b' ')
    Some(b"JBIG2Decode") => true
    Some(_) => true
  }
}

///|
fn ContentLexer::read_inline_image_with_filters(
  self : ContentLexer,
  length : Int32,
  filters : Array[PdfStreamFilter],
) -> Bytes {
  if self.pos < self.data.length() && content_white(self.data[self.pos]) {
    self.pos += 1
  }
  let start = self.pos
  if length >= 0 && length <= self.data.length() - start {
    let end = start + length
    let mut p = end
    while p < self.data.length() && content_white(self.data[p]) {
      p += 1
    }
    if self.inline_end(p) {
      self.pos = p + 2
      return self.data[start:end].to_owned()
    }
  }
  let mut first_end = -1
  let mut first_data : Bytes = b""
  let mut p = start
  while p + 1 < self.data.length() {
    if self.inline_end(p) && (p == 0 || content_white(self.data[p - 1])) {
      let end = if p > start && content_white(self.data[p - 1]) {
        p - 1
      } else {
        p
      }
      let data = self.data[start:end].to_owned()
      if first_end < 0 {
        first_end = p
        first_data = data
      }
      if pdf_inline_data_valid(data, filters) {
        self.pos = p + 2
        return data
      }
    }
    p += 1
  }
  if first_end >= 0 {
    self.pos = first_end + 2
    return first_data
  }
  self.pos = self.data.length()
  self.data[start:].to_owned()
}

///|
// Match upstream's preference for a known length. Without one, choose the
// first IE-ending candidate whose filtered data actually decodes.
fn ContentLexer::read_inline_image(
  self : ContentLexer,
  length : Int32,
) -> Bytes {
  self.read_inline_image_with_filters(length, [])
}

///|
fn ContentLexer::inline_end(self : ContentLexer, pos : Int32) -> Bool {
  pos + 1 < self.data.length() &&
  self.data[pos] == b'E' &&
  self.data[pos + 1] == b'I' &&
  (
    pos + 2 >= self.data.length() ||
    content_white(self.data[pos + 2]) ||
    content_delimiter(self.data[pos + 2])
  )
}

///|
// The upstream lexer keeps hex strings encoded until they are consumed. Its
// decoder rejects odd-length and non-hex strings instead of padding them.
fn content_literal_bytes(value : ContentValue) -> Bytes? {
  match value {
    Literal(bytes) => Some(bytes)
    Hex(bytes) => {
      if bytes.length() % 2 != 0 {
        return None
      }
      let out : Array[Byte] = []
      for i in 0..<(bytes.length() / 2) {
        let hi = content_hex_digit(bytes[i * 2])
        let lo = content_hex_digit(bytes[i * 2 + 1])
        if hi < 0 || lo < 0 {
          return None
        }
        out.push((hi * 16 + lo).to_byte())
      }
      Some(Bytes::from_array(out))
    }
    _ => None
  }
}
