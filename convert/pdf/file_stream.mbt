///|
fn pdf_filter_name(name : Bytes) -> Bytes {
  match name {
    b"AHx" => b"ASCIIHexDecode"
    b"A85" => b"ASCII85Decode"
    b"LZW" => b"LZWDecode"
    b"Fl" => b"FlateDecode"
    b"RL" => b"RunLengthDecode"
    b"CCF" => b"CCITTFaxDecode"
    b"DCT" => b"DCTDecode"
    _ => name
  }
}

///|
fn pdf_filter_integer(
  parameters : PdfObject?,
  key : Bytes,
  default : Int32,
) -> Int32 {
  match parameters {
    Some(object) =>
      match pdf_object_int(pdf_dict_get(object, key)) {
        Some(value) =>
          if value >= -2147483648L && value <= 2147483647L {
            value.to_int()
          } else {
            default
          }
        None => default
      }
    None => default
  }
}

///|
fn pdf_file_filters(
  dictionary : PdfObject,
) -> Array[PdfStreamFilter] raise PdfStreamError {
  let names = match pdf_dict_get(dictionary, b"Filter") {
    None | Some(PdfNull) => []
    Some(PdfName(name)) => [PdfName(name)]
    Some(PdfArray(values)) => values
    _ => raise InvalidStream("invalid PDF stream filters")
  }
  let parameters = match pdf_dict_get(dictionary, b"DecodeParms") {
    Some(PdfArray(values)) => values
    Some(value) => [value]
    None => []
  }
  let filters : Array[PdfStreamFilter] = []
  for i in 0..<names.length() {
    let name = match names[i] {
      PdfName(value) => pdf_filter_name(value)
      _ => raise InvalidStream("invalid PDF stream filter name")
    }
    let options = if i < parameters.length() {
      Some(parameters[i])
    } else {
      None
    }
    filters.push({
      name,
      predictor: pdf_filter_integer(options, b"Predictor", 1),
      colors: pdf_filter_integer(options, b"Colors", 1),
      bits: pdf_filter_integer(options, b"BitsPerComponent", 8),
      columns: pdf_filter_integer(options, b"Columns", 1),
      early_change: pdf_filter_integer(options, b"EarlyChange", 1),
    })
  }
  filters
}

///|
// Read a cross-reference stream whose /Length is a direct integer. Indirect
// lengths require the general object resolver.
fn PdfFile::read_direct_stream(
  self : PdfFile,
  offset : Int64,
) -> (PdfObject, Bytes) raise PdfStreamError {
  if offset < 0L || offset >= self.data.length().to_int64() {
    raise InvalidStream("invalid PDF object offset")
  }
  let reader : PdfObjectReader = { data: self.data, pos: offset.to_int(), }
  let number = reader.raw_integer()
  let generation = reader.raw_integer()
  if number < 0L || generation < 0L {
    raise InvalidStream("invalid PDF object header")
  }
  reader.expect_word(b"obj")
  let dictionary = reader.read(0)
  match dictionary {
    PdfDict(_) => ()
    _ => raise InvalidStream("PDF stream dictionary missing")
  }
  reader.expect_word(b"stream")
  if reader.pos < self.data.length() && self.data[reader.pos] == b'\r' {
    reader.pos += 1
    if reader.pos < self.data.length() && self.data[reader.pos] == b'\n' {
      reader.pos += 1
    }
  } else if reader.pos < self.data.length() && self.data[reader.pos] == b'\n' {
    reader.pos += 1
  } else {
    raise InvalidStream("PDF stream newline missing")
  }
  let length = match pdf_object_int(pdf_dict_get(dictionary, b"Length")) {
    Some(value) => value
    None => raise InvalidStream("PDF stream length is not a direct integer")
  }
  if length < 0L || length > (self.data.length() - reader.pos).to_int64() {
    raise InvalidStream("PDF stream exceeds file")
  }
  let data = self.data[reader.pos:reader.pos + length.to_int()].to_owned()
  (dictionary, data)
}

///|
// Ordinary stream dictionaries may use indirect filter names and parameters.
// Cross-reference streams are read before references are available and use
// the direct form above during bootstrap.
fn PdfFile::resolved_stream_filters(
  self : PdfFile,
  dictionary : PdfObject,
) -> Array[PdfStreamFilter] raise PdfStreamError {
  let filter = self.page_deref(pdf_dict_get(dictionary, b"Filter"))
  let filter = match filter {
    PdfArray(values) =>
      PdfArray(values.map(fn(value) { self.page_deref(Some(value)) }))
    _ => filter
  }
  let parameters = self.page_deref(pdf_dict_get(dictionary, b"DecodeParms"))
  let parameters = match parameters {
    PdfArray(values) =>
      PdfArray(values.map(fn(value) { self.resolve_filter_params(value) }))
    _ => self.resolve_filter_params(parameters)
  }
  pdf_file_filters(PdfDict([(b"Filter", filter), (b"DecodeParms", parameters)]))
}

///|
fn PdfFile::resolve_filter_params(
  self : PdfFile,
  object : PdfObject,
) -> PdfObject {
  match self.page_deref(Some(object)) {
    PdfDict(entries) =>
      PdfDict(
        entries.map(fn(entry) {
          let (key, value) = entry
          (key, self.page_deref(Some(value)))
        }),
      )
    value => value
  }
}
