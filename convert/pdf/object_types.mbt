///|
// PDF file objects are distinct from content operands: arrays and dictionaries
// can contain indirect references, and file strings have their own rules.
priv enum PdfObject {
  PdfNull
  PdfBool(Bool)
  PdfInt(Int64)
  PdfReal(Double)
  PdfName(Bytes)
  PdfString(Bytes)
  PdfHex(Bytes)
  PdfArray(Array[PdfObject])
  PdfDict(Array[(Bytes, PdfObject)])
  PdfRef(Int64, Int64)
} derive(Debug, Eq)

///|
priv struct PdfObjectReader {
  data : Bytes
  mut pos : Int32
}

///|
fn PdfObjectReader::skip_space(self : PdfObjectReader) -> Unit {
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

///|
fn pdf_object_delimiter(c : Byte) -> Bool {
  c == b'/' ||
  c == b'<' ||
  c == b'>' ||
  c == b'(' ||
  c == b')' ||
  c == b'[' ||
  c == b']' ||
  c == b'%'
}

///|
fn PdfObjectReader::name(self : PdfObjectReader) -> Bytes raise PdfStreamError {
  self.pos += 1
  let result : Array[Byte] = []
  while self.pos < self.data.length() {
    let c = self.data[self.pos]
    if content_white(c) || pdf_object_delimiter(c) {
      break
    }
    if c == b'#' {
      if self.pos + 2 >= self.data.length() {
        raise InvalidStream("invalid PDF name escape")
      }
      let hi = content_hex_digit(self.data[self.pos + 1])
      let lo = content_hex_digit(self.data[self.pos + 2])
      if hi < 0 || lo < 0 || hi * 16 + lo == 0 {
        raise InvalidStream("invalid PDF name escape")
      }
      result.push((hi * 16 + lo).to_byte())
      self.pos += 3
    } else {
      result.push(c)
      self.pos += 1
    }
  }
  Bytes::from_array(result)
}
