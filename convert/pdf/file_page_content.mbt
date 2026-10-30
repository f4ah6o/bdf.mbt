///|
// Page content streams concatenate without inserting separators: operands
// and operators may span two adjacent streams.
fn PdfFile::page_content(
  self : PdfFile,
  page : PdfObject,
) -> Bytes raise PdfStreamError {
  let source = pdf_dict_get(page, b"Contents")
  let resolved = self.page_deref(source)
  let items : Array[PdfObject] = match resolved {
    PdfNull => return b""
    PdfArray(values) => values
    PdfDict(_) =>
      match source {
        Some(value) => [value]
        None => []
      }
    _ =>
      raise InvalidStream(
        "the content is neither a stream nor an array of streams",
      )
  }
  let result = @buffer.Buffer()
  for item in items {
    let loaded = match item {
      PdfRef(number, _) =>
        self.load(number, 0) catch {
          _ => { value: PdfNull, stream: None, }
        }
      _ => { value: item, stream: None, }
    }
    if loaded.value is PdfNull {
      continue
    }
    let data = match loaded.stream {
      Some(value) => value
      None => raise InvalidStream("the content is not a stream")
    }
    let (decoded, codec) = pdf_decode_stream(
      data,
      self.resolved_stream_filters(loaded.value),
      268435456L,
      false,
      268435456L,
    )
    if codec is Some(_) {
      raise InvalidStream("the content is encoded as an image")
    }
    if result.length().to_int64() + decoded.length().to_int64() > 268435456L {
      raise InvalidStream(
        "the content streams decode to more than 268435456 bytes",
      )
    }
    result.write_bytesview(decoded[:])
  }
  result.to_bytes()
}
