///|
/// Delimiter, enclosing quote and optional backslash escape used by a CSV
/// reader. Zero disables quote or escape handling.
pub(all) struct Dialect {
  delimiter : Byte
  quote : Byte
  escape : Byte
} derive(Debug, Eq)

///|
/// Parsed records and the nonfatal diagnostics used by dialect detection.
pub(all) struct Records {
  rows : Array[Array[String]]
  bad_quotes : Int32
  quoted_fields : Int32
  unfinished_quote : Bool
} derive(Debug, Eq)

///|
pub suberror CsvError {
  InvalidDialect(String)
}

///|
priv struct Reader {
  text : Bytes
  dialect : Dialect
  mut pos : Int32
  mut bad : Int32
  mut quoted : Int32
  mut unfinished : Bool
}

///|
/// Read decoded text using an explicitly chosen dialect. CRLF, LF and CR
/// end records; blank lines produce empty records. Invalid quotes are kept as
/// text, matching the upstream CSV reader's recovery behavior.
pub fn read_records(text : String, dialect : Dialect) -> Records raise {
  if dialect.delimiter == 0 ||
    dialect.delimiter >= 0x80 ||
    dialect.delimiter == b'\n' ||
    dialect.delimiter == b'\r' {
    raise InvalidDialect(
      "delimiter must be a nonzero ASCII character other than CR or LF",
    )
  }
  if dialect.quote >= 0x80 ||
    dialect.quote == b'\n' ||
    dialect.quote == b'\r' ||
    dialect.escape >= 0x80 {
    raise InvalidDialect(
      "quote and escape must be ASCII characters, and quote cannot be CR or LF",
    )
  }
  csv_read_text(text, dialect)
}

///|
fn csv_read_text(text : String, dialect : Dialect) -> Records {
  let reader : Reader = {
    text: @utf8.encode(text),
    dialect,
    pos: 0,
    bad: 0,
    quoted: 0,
    unfinished: false,
  }
  let rows : Array[Array[String]] = []
  while reader.pos < reader.text.length() {
    rows.push(reader.record())
  }
  {
    rows,
    bad_quotes: reader.bad,
    quoted_fields: reader.quoted,
    unfinished_quote: reader.unfinished,
  }
}

///|
fn Reader::skip_eol(self : Reader, at : Int32) -> Int32 {
  if self.text[at] == b'\r' &&
    at + 1 < self.text.length() &&
    self.text[at + 1] == b'\n' {
    at + 2
  } else {
    at + 1
  }
}

///|
fn Reader::record(self : Reader) -> Array[String] {
  let fields : Array[String] = []
  if self.text[self.pos] == b'\r' || self.text[self.pos] == b'\n' {
    self.pos = self.skip_eol(self.pos)
    return fields
  }
  while true {
    let (value, end) = self.field()
    fields.push(value)
    if end >= self.text.length() {
      self.pos = self.text.length()
      break
    }
    if self.text[end] == self.dialect.delimiter {
      self.pos = end + 1
    } else {
      self.pos = self.skip_eol(end)
      break
    }
  }
  fields
}

///|
fn Reader::field(self : Reader) -> (String, Int32) {
  let text = self.text
  let dialect = self.dialect
  if dialect.quote != 0 {
    let mut start = self.pos
    while start < text.length() &&
          text[start] == b' ' &&
          dialect.delimiter != b' ' {
      start += 1
    }
    if start < text.length() && text[start] == dialect.quote {
      return self.quoted_field(start + 1)
    }
  }
  let mut end = self.pos
  while end < text.length() {
    let byte = text[end]
    if byte == dialect.delimiter || byte == b'\r' || byte == b'\n' {
      break
    }
    if byte == dialect.quote && dialect.quote != 0 {
      self.bad += 1
    }
    end += 1
  }
  (@utf8.decode_lossy(text[self.pos:end]), end)
}

///|
fn Reader::quoted_field(self : Reader, start : Int32) -> (String, Int32) {
  self.quoted += 1
  let text = self.text
  let dialect = self.dialect
  let output = @buffer.Buffer()
  let mut pos = start
  let mut from = start
  while pos < text.length() {
    let byte = text[pos]
    if byte == dialect.escape &&
      dialect.escape != 0 &&
      pos + 1 < text.length() &&
      (text[pos + 1] == dialect.quote || text[pos + 1] == dialect.escape) {
      output.write_bytes(text[from:pos])
      output.write_byte(text[pos + 1])
      pos += 2
      from = pos
    } else if byte != dialect.quote {
      pos += 1
    } else if pos + 1 < text.length() && text[pos + 1] == dialect.quote {
      output.write_bytes(text[from:pos + 1])
      pos += 2
      from = pos
    } else {
      let mut end = pos + 1
      while end < text.length() &&
            text[end] == b' ' &&
            dialect.delimiter != b' ' {
        end += 1
      }
      if end >= text.length() ||
        text[end] == dialect.delimiter ||
        text[end] == b'\r' ||
        text[end] == b'\n' {
        output.write_bytes(text[from:pos])
        return (@utf8.decode_lossy(output.to_bytes()), end)
      }
      self.bad += 1
      pos += 1
    }
  }
  self.unfinished = true
  output.write_bytes(text[from:])
  (@utf8.decode_lossy(output.to_bytes()), text.length())
}
