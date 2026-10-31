///|
fn PdfObjectReader::number_or_reference(
  self : PdfObjectReader,
) -> PdfObject raise PdfStreamError {
  let start = self.pos
  while self.pos < self.data.length() &&
        !content_white(self.data[self.pos]) &&
        !pdf_object_delimiter(self.data[self.pos]) {
    self.pos += 1
  }
  if self.pos == start {
    raise InvalidStream("invalid PDF object token")
  }
  let end = self.pos
  let token = self.data[start:end].to_owned()
  let value = pdf_file_integer(token)
  match value {
    Some(number) => {
      let start = pdf_file_numeric_start(token)
      if pdf_generation_integer(token[start:].to_owned()) is None {
        return PdfInt(number)
      }
      if self.pos < self.data.length() && content_white(self.data[self.pos]) {
        self.skip_space()
        let second_start = self.pos
        while self.pos < self.data.length() &&
              !content_white(self.data[self.pos]) &&
              !pdf_object_delimiter(self.data[self.pos]) {
          self.pos += 1
        }
        let second_end = self.pos
        if second_end > second_start &&
          self.pos < self.data.length() &&
          content_white(self.data[self.pos]) {
          let second = pdf_generation_integer(
            self.data[second_start:second_end].to_owned(),
          )
          if second is Some(generation) {
            self.skip_space()
            if self.pos < self.data.length() && self.data[self.pos] == b'R' {
              self.pos += 1
              return PdfRef(number, generation)
            }
          }
        }
        self.pos = end
      }
      PdfInt(number)
    }
    None =>
      match pdf_file_real(token) {
        Some(number) => PdfReal(number)
        None => PdfNull
      }
  }
}

///|
fn pdf_generation_integer(data : Bytes) -> Int64? {
  if data.is_empty() {
    return None
  }
  let mut i = 0
  if data[i] == b'+' || data[i] == b'-' {
    i += 1
  }
  if i >= data.length() {
    return None
  }
  while i < data.length() {
    if data[i] < b'0' || data[i] > b'9' {
      return None
    }
    i += 1
  }
  let text = @utf8.decode_lossy(data[:])
  Some(@string.parse_int64(text)) catch {
    _ => None
  }
}

///|
// pdfcpu accepts several zero prefixes in malformed numeric values and maps
// integer overflow to zero. Non-numeric tokens are handled as null values.
fn pdf_file_numeric_start(data : Bytes) -> Int32 {
  if data.length() > 1 && data[0] == b'0' {
    if data[1] == b'+' || data[1] == b'-' {
      return 1
    }
    if data[1] == b'.' {
      let mut i = 2
      while i < data.length() && data[i] == b'0' {
        i += 1
      }
      if i < data.length() && (data[i] == b'+' || data[i] == b'-') {
        return i
      }
    }
  }
  0
}

///|
fn pdf_file_integer(data : Bytes) -> Int64? {
  let start = pdf_file_numeric_start(data)
  if start >= data.length() {
    return None
  }
  let mut i = start
  if data[i] == b'+' || data[i] == b'-' {
    i += 1
  }
  if i >= data.length() {
    return None
  }
  while i < data.length() {
    if data[i] < b'0' || data[i] > b'9' {
      return None
    }
    i += 1
  }
  let text = @utf8.decode_lossy(data[start:])
  Some(@string.parse_int64(text)) catch {
    _ => Some(0L)
  }
}

///|
fn pdf_file_real(data : Bytes) -> Double? {
  let start = pdf_file_numeric_start(data)
  let text = StringBuilder()
  let mut digits = false
  let mut period = false
  let mut comma_used = false
  let mut dot_minus_used = false
  let mut index = start
  let mut output_length = 0
  while index < data.length() {
    let c = data[index].to_int()
    if c == 44 && !comma_used {
      comma_used = true
      if period {
        return None
      }
      period = true
      text.write_char('.')
      if !dot_minus_used && index + 1 < data.length() && data[index + 1] == b'-' {
        dot_minus_used = true
        index += 1
      }
    } else if c == 46 {
      if period {
        return None
      }
      period = true
      text.write_char('.')
      if !dot_minus_used && index + 1 < data.length() && data[index + 1] == b'-' {
        dot_minus_used = true
        index += 1
      }
    } else if c >= 48 && c <= 57 {
      digits = true
      text.write_char(c.unsafe_to_char())
    } else if (c == 43 || c == 45) && output_length == 0 {
      text.write_char(c.unsafe_to_char())
    } else {
      return None
    }
    output_length += 1
    index += 1
  }
  if !digits {
    return None
  }
  Some(@string.parse_double(text.to_string())) catch {
    _ => None
  }
}
