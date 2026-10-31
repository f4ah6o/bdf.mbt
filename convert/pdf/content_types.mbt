///|
// Values produced by the PDF content-stream lexer. Strings and names hold
// bytes rather than text: PDF names and strings may use arbitrary encodings.
priv enum ContentValue {
  Integer(Int64)
  Real(Double)
  Boolean(Bool)
  Null
  Name(Bytes)
  Literal(Bytes)
  Hex(Bytes)
  ArrayValue(Array[ContentValue])
  Dictionary(Array[(Bytes, ContentValue)])
} derive(Debug, Eq)

///|
priv enum ContentToken {
  End
  Operand(ContentValue)
  Operator(Bytes)
} derive(Debug, Eq)

///|
priv struct ContentLexer {
  data : Bytes
  mut pos : Int32
}

///|
fn content_white(c : Byte) -> Bool {
  c == b' ' ||
  c == b'\n' ||
  c == b'\r' ||
  c == b'\t' ||
  c == b'\x0c' ||
  c == b'\x00'
}

///|
fn content_delimiter(c : Byte) -> Bool {
  match c {
    b'(' | b')' | b'<' | b'>' | b'[' | b']' | b'{' | b'}' | b'/' | b'%' => true
    _ => false
  }
}

///|
fn content_hex_digit(c : Byte) -> Int32 {
  let n = c.to_int()
  if n >= 48 && n <= 57 {
    n - 48
  } else if n >= 65 && n <= 70 {
    n - 55
  } else if n >= 97 && n <= 102 {
    n - 87
  } else {
    -1
  }
}

///|
fn ContentLexer::skip_space(self : ContentLexer) -> Unit {
  while self.pos < self.data.length() {
    let c = self.data[self.pos]
    if content_white(c) {
      self.pos += 1
    } else if c == b'%' {
      while self.pos < self.data.length() &&
            self.data[self.pos] != b'\n' &&
            self.data[self.pos] != b'\r' {
        self.pos += 1
      }
    } else {
      return
    }
  }
}
