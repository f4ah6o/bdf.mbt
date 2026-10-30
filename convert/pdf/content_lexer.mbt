///|
// Adapted from shibukawa/bdf converter/pdf/lexer.go (MIT).
// Arrays and dictionaries are limited to the same nesting depth as upstream.
fn ContentLexer::next(self : ContentLexer, depth : Int32) -> ContentToken {
  while true {
    self.skip_space()
    if self.pos >= self.data.length() {
      return End
    }
    let c = self.data[self.pos]
    if c == b'/' {
      self.pos += 1
      return Operand(Name(self.read_name()))
    } else if c == b'(' {
      self.pos += 1
      return Operand(Literal(self.read_literal()))
    } else if c == b'<' {
      self.pos += 1
      if self.pos < self.data.length() && self.data[self.pos] == b'<' {
        self.pos += 1
        if depth >= 32 {
          continue
        }
        return Operand(Dictionary(self.read_dict(depth + 1)))
      }
      return Operand(Hex(self.read_hex()))
    } else if c == b'[' {
      self.pos += 1
      if depth >= 32 {
        continue
      }
      return Operand(ArrayValue(self.read_array(depth + 1)))
    } else if c == b']' || c == b'>' || c == b')' || c == b'{' || c == b'}' {
      self.pos += 1
      continue
    } else if (c >= b'0' && c <= b'9') || c == b'+' || c == b'-' || c == b'.' {
      return Operand(self.read_number())
    }
    let start = self.pos
    while self.pos < self.data.length() &&
          !content_white(self.data[self.pos]) &&
          !content_delimiter(self.data[self.pos]) {
      self.pos += 1
    }
    if self.pos == start {
      self.pos += 1
      continue
    }
    let word = self.data[start:self.pos].to_owned()
    return match word {
      b"true" => Operand(Boolean(true))
      b"false" => Operand(Boolean(false))
      b"null" => Operand(Null)
      _ => Operator(word)
    }
  }
  End
}

///|
fn ContentLexer::read_name(self : ContentLexer) -> Bytes {
  let out : Array[Byte] = []
  while self.pos < self.data.length() {
    let c = self.data[self.pos]
    if content_white(c) || content_delimiter(c) {
      break
    }
    if c == b'#' && self.pos + 2 < self.data.length() {
      let hi = content_hex_digit(self.data[self.pos + 1])
      let lo = content_hex_digit(self.data[self.pos + 2])
      if hi >= 0 && lo >= 0 {
        out.push((hi * 16 + lo).to_byte())
        self.pos += 3
        continue
      }
    }
    out.push(c)
    self.pos += 1
  }
  Bytes::from_array(out)
}

///|
fn ContentLexer::read_number(self : ContentLexer) -> ContentValue {
  let start = self.pos
  self.pos += 1
  while self.pos < self.data.length() {
    let c = self.data[self.pos]
    if (c >= b'0' && c <= b'9') ||
      c == b'.' ||
      c == b'-' ||
      c == b'+' ||
      c == b'e' ||
      c == b'E' {
      self.pos += 1
    } else {
      break
    }
  }
  let bytes = self.data[start:self.pos]
  let text = @utf8.decode_lossy(bytes)
  let integer : Int64? = Some(@string.parse_int64(text)) catch { _ => None }
  if integer is Some(value) {
    return Integer(value)
  }
  let mut end = bytes.length()
  while end > 0 {
    let part = @utf8.decode_lossy(bytes[:end])
    let parsed : Double? = Some(@string.parse_double(part)) catch { _ => None }
    if parsed is Some(value) {
      return Real(value)
    }
    end -= 1
  }
  Real(0.0)
}

///|
fn ContentLexer::read_hex(self : ContentLexer) -> Bytes {
  let out : Array[Byte] = []
  while self.pos < self.data.length() && self.data[self.pos] != b'>' {
    let c = self.data[self.pos]
    self.pos += 1
    if !content_white(c) {
      out.push(c)
    }
  }
  if self.pos < self.data.length() {
    self.pos += 1
  }
  Bytes::from_array(out)
}

///|
fn ContentLexer::read_array(
  self : ContentLexer,
  depth : Int32,
) -> Array[ContentValue] {
  let out : Array[ContentValue] = []
  while true {
    self.skip_space()
    if self.pos >= self.data.length() {
      return out
    }
    if self.data[self.pos] == b']' {
      self.pos += 1
      return out
    }
    match self.next(depth) {
      End => return out
      Operand(value) => out.push(value)
      Operator(_) => ()
    }
  }
  out
}

///|
fn ContentLexer::read_dict(
  self : ContentLexer,
  depth : Int32,
) -> Array[(Bytes, ContentValue)] {
  let out : Array[(Bytes, ContentValue)] = []
  while true {
    self.skip_space()
    if self.pos >= self.data.length() {
      return out
    }
    if self.data[self.pos] == b'>' {
      self.pos += 1
      if self.pos < self.data.length() && self.data[self.pos] == b'>' {
        self.pos += 1
      }
      return out
    }
    match self.next(depth) {
      End => return out
      Operand(Name(key)) =>
        match self.next(depth) {
          Operand(value) => {
            let mut found = false
            for i in 0..<out.length() {
              if out[i].0 == key {
                out[i] = (key, value)
                found = true
                break
              }
            }
            if !found {
              out.push((key, value))
            }
          }
          _ => return out
        }
      _ => ()
    }
  }
  out
}
