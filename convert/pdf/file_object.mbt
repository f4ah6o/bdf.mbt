///|
// Resolve a reference through the cross-reference table. Undefined and free
// references are PDF null objects, as in pdfcpu's Dereference method.
fn PdfFile::load(
  self : PdfFile,
  number : Int64,
  depth : Int32,
) -> PdfLoaded raise PdfStreamError {
  if depth > 100 || self.loading.contains(number) {
    raise InvalidStream("cyclic PDF object reference")
  }
  match self.objects.get(number) {
    Some(value) => return value
    None => ()
  }
  let entry = match self.entries.get(number) {
    Some(value) => value
    None => return { value: PdfNull, stream: None, }
  }
  self.loading[number] = true
  defer self.loading.remove(number)
  let object = match entry {
    XRefFree(_) => { value: PdfNull, stream: None, }
    XRefOffset(offset, generation) =>
      self.load_at(offset, number, generation, depth)
    XRefCompressed(stream, index) =>
      self.load_compressed(number, stream, index, depth)
  }
  self.objects[number] = object
  object
}

///|
fn PdfFile::load_at(
  self : PdfFile,
  offset : Int64,
  number : Int64,
  generation : Int64,
  depth : Int32,
) -> PdfLoaded raise PdfStreamError {
  if offset < 0L || offset >= self.data.length().to_int64() {
    raise InvalidStream("invalid PDF object offset")
  }
  let reader : PdfObjectReader = { data: self.data, pos: offset.to_int(), }
  let actual = reader.raw_integer()
  let actual_generation = reader.raw_integer()
  if actual != number || actual_generation != generation {
    raise InvalidStream("PDF object header mismatch")
  }
  reader.expect_word(b"obj")
  let value = reader.read(0)
  if value is PdfDict(_) {
    let saved = reader.pos
    reader.skip_space()
    if reader.pos + 6 <= self.data.length() &&
      self.data[reader.pos:reader.pos + 6].to_owned() == b"stream" {
      reader.pos += 6
      if reader.pos < self.data.length() && self.data[reader.pos] == b'\r' {
        reader.pos += 1
        if reader.pos < self.data.length() && self.data[reader.pos] == b'\n' {
          reader.pos += 1
        }
      } else if reader.pos < self.data.length() &&
        self.data[reader.pos] == b'\n' {
        reader.pos += 1
      } else {
        raise InvalidStream("PDF stream newline missing")
      }
      let length = self.resolve_integer(
        pdf_dict_get(value, b"Length"),
        depth + 1,
      )
      if length < 0L || length > (self.data.length() - reader.pos).to_int64() {
        raise InvalidStream("PDF stream exceeds file")
      }
      return {
        value,
        stream: Some(
          self.data[reader.pos:reader.pos + length.to_int()].to_owned(),
        ),
      }
    }
    reader.pos = saved
  }
  { value, stream: None, }
}

///|
fn PdfFile::resolve_integer(
  self : PdfFile,
  value : PdfObject?,
  depth : Int32,
) -> Int64 raise PdfStreamError {
  if depth > 100 {
    raise InvalidStream("cyclic PDF integer reference")
  }
  match value {
    Some(PdfInt(number)) => number
    Some(PdfRef(number, _)) =>
      self.resolve_integer(Some(self.load(number, depth + 1).value), depth + 1)
    _ => raise InvalidStream("PDF integer missing")
  }
}

///|
fn PdfFile::load_compressed(
  self : PdfFile,
  number : Int64,
  stream_number : Int64,
  index : Int64,
  depth : Int32,
) -> PdfLoaded raise PdfStreamError {
  let stream = match self.object_streams.get(stream_number) {
    Some(value) => value
    None => {
      let source = self.load(stream_number, depth + 1)
      match pdf_dict_get(source.value, b"Type") {
        Some(PdfName(b"ObjStm")) => ()
        _ => raise InvalidStream("PDF object stream type missing")
      }
      let count = self.resolve_integer(
        pdf_dict_get(source.value, b"N"),
        depth + 1,
      )
      let first = self.resolve_integer(
        pdf_dict_get(source.value, b"First"),
        depth + 1,
      )
      if count < 0L || count > 1000000L || first < 0L || first > 16777216L {
        raise InvalidStream("PDF object stream limit")
      }
      let raw = match source.stream {
        Some(value) => value
        None => raise InvalidStream("PDF object stream missing")
      }
      let (data, image) = pdf_decode_stream(
        raw,
        self.resolved_stream_filters(source.value),
        268435456L,
        false,
        268435456L,
      )
      if image is Some(_) || first > data.length().to_int64() {
        raise InvalidStream("invalid PDF object stream")
      }
      let reader : PdfObjectReader = { data, pos: 0, }
      let numbers : Array[Int64] = []
      let offsets : Array[Int32] = []
      for _ in 0..<count.to_int() {
        let id = reader.raw_integer()
        let offset = reader.raw_integer()
        if id < 0L || offset < 0L || offset > data.length().to_int64() - first {
          raise InvalidStream("invalid PDF object stream entry")
        }
        numbers.push(id)
        offsets.push(offset.to_int())
      }
      if reader.pos > first.to_int() {
        raise InvalidStream("invalid PDF object stream header")
      }
      let value : PdfObjectStream = {
        data,
        first: first.to_int(),
        numbers,
        offsets,
      }
      self.object_streams[stream_number] = value
      value
    }
  }
  if index < 0L || index >= stream.numbers.length().to_int64() {
    raise InvalidStream("invalid PDF object stream index")
  }
  let i = index.to_int()
  if stream.numbers[i] != number {
    raise InvalidStream("PDF object stream number mismatch")
  }
  let reader : PdfObjectReader = {
    data: stream.data,
    pos: stream.first + stream.offsets[i],
  }
  { value: reader.read(0), stream: None, }
}
