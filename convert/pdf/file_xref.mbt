///|
// Locate the last startxref marker, as required for incremental updates.
fn pdf_start_xref(data : Bytes) -> Int64 raise PdfStreamError {
  let marker = b"startxref"
  if data.length() < marker.length() {
    raise InvalidStream("PDF startxref missing")
  }
  let mut i = data.length() - marker.length()
  while i >= 0 {
    let mut found = true
    for j in 0..<marker.length() {
      if data[i + j] != marker[j] {
        found = false
        break
      }
    }
    if found {
      let reader : PdfObjectReader = { data, pos: i + marker.length(), }
      return reader.raw_integer()
    }
    i -= 1
  }
  raise InvalidStream("PDF startxref missing")
}

///|
fn pdf_open_file(data : Bytes) -> PdfFile raise PdfStreamError {
  let file : PdfFile = {
    data,
    entries: Map([]),
    objects: Map([]),
    loading: Map([]),
    object_streams: Map([]),
    trailers: [],
    trailer: PdfNull,
  }
  let visited : Map[Int64, Bool] = Map([])
  let mut offset = pdf_start_xref(data)
  let mut first = true
  while offset > 0L {
    if offset >= data.length().to_int64() || visited.contains(offset) {
      raise InvalidStream("invalid or cyclic PDF cross-reference")
    }
    visited[offset] = true
    if visited.length() > 10000 {
      raise InvalidStream("too many PDF revisions")
    }
    let reader : PdfObjectReader = { data, pos: offset.to_int(), }
    let token = reader.raw_token()
    let trailer = if token == b"xref" {
      let value = file.read_xref_table(reader)
      match pdf_object_int(pdf_dict_get(value, b"XRefStm")) {
        Some(stream_offset) => {
          if stream_offset < 0L ||
            stream_offset >= data.length().to_int64() ||
            visited.contains(stream_offset) {
            raise InvalidStream("invalid hybrid PDF cross-reference stream")
          }
          visited[stream_offset] = true
          ignore(file.read_xref_stream(stream_offset))
        }
        None => ()
      }
      value
    } else {
      file.read_xref_stream(offset)
    }
    file.trailers.push(trailer)
    if first {
      file.trailer = trailer
      first = false
    }
    match pdf_object_int(pdf_dict_get(trailer, b"Prev")) {
      Some(value) => offset = value
      None => offset = 0L
    }
  }
  if first {
    raise InvalidStream("PDF cross-reference missing")
  }
  file
}

///|
fn PdfFile::read_xref_table(
  self : PdfFile,
  reader : PdfObjectReader,
) -> PdfObject raise PdfStreamError {
  while true {
    reader.skip_space()
    if reader.pos >= self.data.length() {
      raise InvalidStream("missing PDF trailer")
    }
    let token = reader.raw_token()
    if token == b"trailer" {
      let object = reader.read(0)
      if object is PdfDict(_) {
        return object
      }
      raise InvalidStream("invalid PDF trailer")
    }
    let start = match pdf_generation_integer(token) {
      Some(value) => value
      None => raise InvalidStream("invalid PDF cross-reference section")
    }
    let count = reader.raw_integer()
    if start < 0L ||
      count < 0L ||
      start > 10000000L ||
      count > 10000000L - start {
      raise InvalidStream("PDF cross-reference limit exceeded")
    }
    for i in 0..<count.to_int() {
      let offset = reader.raw_integer()
      let generation = reader.raw_integer()
      let flag = reader.raw_token()
      let number = start + i.to_int64()
      if flag != b"n" && flag != b"f" {
        raise InvalidStream("invalid PDF cross-reference entry")
      }
      if !self.entries.contains(number) {
        if flag == b"f" || (number == 0L && offset == 0L) {
          self.entries[number] = XRefFree(generation)
        } else if offset >= 9L {
          self.entries[number] = XRefOffset(offset, generation)
        }
      }
    }
  }
  PdfNull
}
