///|
// PDF cross-reference entries include free, ordinary and object-stream items.
priv enum PdfXRefEntry {
  XRefFree(Int64)
  XRefOffset(Int64, Int64)
  XRefCompressed(Int64, Int64)
} derive(Debug, Eq)

///|
priv struct PdfFile {
  data : Bytes
  entries : Map[Int64, PdfXRefEntry]
  objects : Map[Int64, PdfLoaded]
  loading : Map[Int64, Bool]
  object_streams : Map[Int64, PdfObjectStream]
  trailers : Array[PdfObject]
  mut trailer : PdfObject
}

///|
priv struct PdfLoaded {
  value : PdfObject
  stream : Bytes?
} derive(Debug, Eq)

///|
priv struct PdfObjectStream {
  data : Bytes
  first : Int32
  numbers : Array[Int64]
  offsets : Array[Int32]
}

///|
fn pdf_dict_get(object : PdfObject, key : Bytes) -> PdfObject? {
  match object {
    PdfDict(entries) => {
      for (name, value) in entries {
        if name == key {
          return Some(value)
        }
      }
      None
    }
    _ => None
  }
}

///|
fn pdf_object_int(object : PdfObject?) -> Int64? {
  match object {
    Some(PdfInt(value)) => Some(value)
    _ => None
  }
}

///|
// Newer trailers override older values; unchanged keys may be inherited
// from an earlier incremental revision.
fn PdfFile::trailer_entry(self : PdfFile, key : Bytes) -> PdfObject? {
  for trailer in self.trailers {
    match pdf_dict_get(trailer, key) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  None
}

///|
fn PdfObjectReader::raw_token(
  self : PdfObjectReader,
) -> Bytes raise PdfStreamError {
  self.skip_space()
  let start = self.pos
  while self.pos < self.data.length() &&
        !content_white(self.data[self.pos]) &&
        !pdf_object_delimiter(self.data[self.pos]) {
    self.pos += 1
  }
  if self.pos == start {
    raise InvalidStream("missing PDF cross-reference token")
  }
  self.data[start:self.pos].to_owned()
}

///|
fn PdfObjectReader::raw_integer(
  self : PdfObjectReader,
) -> Int64 raise PdfStreamError {
  let token = self.raw_token()
  match pdf_generation_integer(token) {
    Some(value) => value
    None => raise InvalidStream("invalid PDF cross-reference integer")
  }
}

///|
fn PdfObjectReader::expect_word(
  self : PdfObjectReader,
  expected : Bytes,
) -> Unit raise PdfStreamError {
  if self.raw_token() != expected {
    raise InvalidStream("unexpected PDF keyword")
  }
}
