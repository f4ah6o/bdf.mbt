///|
fn pdf_xref_int_array(value : PdfObject?) -> Array[Int64] raise PdfStreamError {
  match value {
    Some(PdfArray(values)) => {
      let result : Array[Int64] = []
      for item in values {
        match item {
          PdfInt(value) => result.push(value)
          _ => raise InvalidStream("invalid PDF cross-reference array")
        }
      }
      result
    }
    _ => raise InvalidStream("missing PDF cross-reference array")
  }
}

///|
fn pdf_xref_field(
  data : Bytes,
  start : Int32,
  width : Int32,
) -> Int64 raise PdfStreamError {
  let mut value = 0L
  for i in 0..<width {
    value = (value << 8) | data[start + i].to_int64()
  }
  value
}

///|
fn PdfFile::read_xref_stream(
  self : PdfFile,
  offset : Int64,
) -> PdfObject raise PdfStreamError {
  let (dictionary, stored) = self.read_direct_stream(offset)
  match pdf_dict_get(dictionary, b"Type") {
    Some(PdfName(b"XRef")) => ()
    _ => raise InvalidStream("not a PDF cross-reference stream")
  }
  let size = match pdf_object_int(pdf_dict_get(dictionary, b"Size")) {
    Some(value) => value
    None => raise InvalidStream("PDF cross-reference size missing")
  }
  if size < 0L || size > 10000000L {
    raise InvalidStream("PDF cross-reference size limit")
  }
  let widths = pdf_xref_int_array(pdf_dict_get(dictionary, b"W"))
  if widths.length() != 3 {
    raise InvalidStream("invalid PDF cross-reference widths")
  }
  for width in widths {
    if width < 0L || width > 268435456L {
      raise InvalidStream("invalid PDF cross-reference width")
    }
  }
  let total_width = widths[0] + widths[1] + widths[2]
  if total_width > 268435456L {
    raise InvalidStream("PDF cross-reference entry too large")
  }
  let stride = total_width.to_int()
  if stride == 0 {
    raise InvalidStream("empty PDF cross-reference entry")
  }
  let index = match pdf_dict_get(dictionary, b"Index") {
    None => [0L, size]
    value => pdf_xref_int_array(value)
  }
  if index.length() % 2 != 0 {
    raise InvalidStream("invalid PDF cross-reference index")
  }
  let filters = pdf_file_filters(dictionary)
  let (decoded, image) = pdf_decode_stream(
    stored, filters, 268435456L, false, 268435456L,
  )
  if image is Some(_) {
    raise InvalidStream("image codec in PDF cross-reference stream")
  }
  if decoded.length() % stride != 0 {
    raise InvalidStream("truncated PDF cross-reference stream")
  }
  let mut cursor = 0
  for group in 0..<(index.length() / 2) {
    let start = index[group * 2]
    let count = index[group * 2 + 1]
    if start < 0L ||
      count < 0L ||
      start > 10000000L ||
      count > 10000000L - start {
      raise InvalidStream("PDF cross-reference index limit")
    }
    if count > ((decoded.length() - cursor) / stride).to_int64() {
      raise InvalidStream("truncated PDF cross-reference entries")
    }
    for i in 0..<count.to_int() {
      let w0 = widths[0].to_int()
      let w1 = widths[1].to_int()
      let w2 = widths[2].to_int()
      let kind = if w0 == 0 { 1L } else { pdf_xref_field(decoded, cursor, w0) }
      let field1 = pdf_xref_field(decoded, cursor + w0, w1)
      let field2 = pdf_xref_field(decoded, cursor + w0 + w1, w2)
      let number = start + i.to_int64()
      if !self.entries.contains(number) {
        self.entries[number] = match kind {
          0L => XRefFree(field2)
          1L => XRefOffset(field1, field2)
          2L => XRefCompressed(field1, field2)
          _ => XRefFree(0L)
        }
      }
      cursor += stride
    }
  }
  dictionary
}
