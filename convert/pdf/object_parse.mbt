///|
// Parse one object from a PDF file, preserving the position after its value.
// This is independent of the content-stream lexer because file arrays can
// contain indirect references and malformed file objects use different rules.
fn PdfObjectReader::read(
  self : PdfObjectReader,
  depth : Int32,
) -> PdfObject raise PdfStreamError {
  if depth > 100 {
    raise InvalidStream("PDF object nesting too deep")
  }
  self.skip_space()
  if self.pos >= self.data.length() {
    raise InvalidStream("missing PDF object")
  }
  let c = self.data[self.pos]
  if c == b'/' {
    return PdfName(self.name())
  }
  if c == b'(' {
    return PdfString(self.literal())
  }
  if c == b'[' {
    self.pos += 1
    let values : Array[PdfObject] = []
    while true {
      self.skip_space()
      if self.pos >= self.data.length() {
        raise InvalidStream("unterminated PDF array")
      }
      if self.data[self.pos] == b']' {
        self.pos += 1
        return PdfArray(values)
      }
      values.push(self.read(depth + 1))
    }
  }
  if c == b'<' {
    if self.pos + 1 < self.data.length() && self.data[self.pos + 1] == b'<' {
      return PdfDict(self.dictionary(depth + 1))
    }
    return self.hex_string()
  }
  for
    (word, value) in [
      (b"true", PdfBool(true)),
      (b"false", PdfBool(false)),
      (b"null", PdfNull),
    ] {
    if self.word_matches(word) {
      self.pos += word.length()
      return value
    }
  }
  self.number_or_reference()
}

///|
fn PdfObjectReader::dictionary(
  self : PdfObjectReader,
  depth : Int32,
) -> Array[(Bytes, PdfObject)] raise PdfStreamError {
  self.pos += 2
  let entries : Array[(Bytes, PdfObject)] = []
  let mut skipped_junk = false
  while true {
    self.skip_space()
    if self.pos + 1 < self.data.length() &&
      self.data[self.pos] == b'>' &&
      self.data[self.pos + 1] == b'>' {
      self.pos += 2
      return entries.filter(entry => entry.1 != PdfNull)
    }
    if self.pos >= self.data.length() {
      if skipped_junk {
        return entries.filter(entry => entry.1 != PdfNull)
      }
      raise InvalidStream("invalid PDF dictionary")
    }
    if self.data[self.pos] != b'/' {
      skipped_junk = true
      self.pos += 1
      continue
    }
    let key = self.name()
    let value = self.read(depth)
    let mut found = false
    for i in 0..<entries.length() {
      if entries[i].0 == key {
        if value != PdfNull {
          entries[i] = (key, value)
        }
        found = true
        break
      }
    }
    if !found {
      entries.push((key, value))
    }
  }
  entries
}

///|
fn PdfObjectReader::literal(
  self : PdfObjectReader,
) -> Bytes raise PdfStreamError {
  let start = self.pos
  self.pos += 1
  let mut depth = 1
  while self.pos < self.data.length() && depth > 0 {
    let c = self.data[self.pos]
    self.pos += 1
    if c == b'\\' {
      if self.pos < self.data.length() {
        self.pos += 1
      }
    } else if c == b'(' {
      depth += 1
    } else if c == b')' {
      depth -= 1
    }
  }
  if depth != 0 {
    raise InvalidStream("unterminated PDF string")
  }
  let lexer : ContentLexer = { data: self.data, pos: start + 1, }
  lexer.read_literal()
}

///|
fn PdfObjectReader::hex_string(
  self : PdfObjectReader,
) -> PdfObject raise PdfStreamError {
  self.pos += 1
  let start = self.pos
  while self.pos < self.data.length() && self.data[self.pos] != b'>' {
    self.pos += 1
  }
  if self.pos >= self.data.length() {
    raise InvalidStream("unterminated PDF hexadecimal string")
  }
  let encoded = self.data[start:self.pos].to_owned()
  self.pos += 1
  let decoded : Bytes? = Some(pdf_decode_ascii_hex(encoded)) catch { _ => None }
  match decoded {
    Some(value) => PdfHex(value)
    None => PdfNull
  }
}

///|
fn PdfObjectReader::word_matches(self : PdfObjectReader, word : Bytes) -> Bool {
  if word.length() > self.data.length() - self.pos {
    return false
  }
  for i in 0..<word.length() {
    let c = self.data[self.pos + i].to_int()
    let lower = if c >= 65 && c <= 90 { c + 32 } else { c }
    if lower != word[i].to_int() {
      return false
    }
  }
  true
}
