///|
fn pdf_inline_value(
  dict : Array[(Bytes, ContentValue)],
  short : Bytes,
  long : Bytes,
) -> ContentValue? {
  for (key, value) in dict {
    if key == short || key == long {
      return Some(value)
    }
  }
  None
}

///|
fn pdf_inline_int(
  dict : Array[(Bytes, ContentValue)],
  short : Bytes,
  long : Bytes,
  default : Int32,
) -> Int32 {
  match pdf_inline_value(dict, short, long) {
    Some(Integer(value)) => value.to_int()
    Some(Real(value)) => value.to_int()
    _ => default
  }
}

///|
fn pdf_inline_bool(
  dict : Array[(Bytes, ContentValue)],
  short : Bytes,
  long : Bytes,
) -> Bool {
  match pdf_inline_value(dict, short, long) {
    Some(Boolean(value)) => value
    _ => false
  }
}

///|
fn pdf_inline_decode(dict : Array[(Bytes, ContentValue)]) -> Array[Double] {
  match pdf_inline_value(dict, b"D", b"Decode") {
    Some(ArrayValue(values)) => {
      let out : Array[Double] = []
      for value in values {
        match value {
          Integer(number) => out.push(number.to_double())
          Real(number) => out.push(number)
          _ => out.push(0.0)
        }
      }
      out
    }
    _ => []
  }
}

///|
fn pdf_inline_dict_int(
  params : ContentValue?,
  key : Bytes,
  default : Int32,
) -> Int32 {
  match params {
    Some(Dictionary(entries)) => {
      for (name, value) in entries {
        if name == key {
          match value {
            Integer(number) => return number.to_int()
            Real(number) => return number.to_int()
            _ => ()
          }
        }
      }
      default
    }
    _ => default
  }
}

///|
fn pdf_inline_filters(
  dict : Array[(Bytes, ContentValue)],
) -> Array[PdfStreamFilter] raise PdfStreamError {
  let names : Array[Bytes] = []
  match pdf_inline_value(dict, b"F", b"Filter") {
    Some(Name(name)) => names.push(name)
    Some(ArrayValue(values)) =>
      for value in values {
        match value {
          Name(name) => names.push(name)
          _ => raise InvalidStream("invalid PDF inline image filter")
        }
      }
    None => ()
    _ => raise InvalidStream("invalid PDF inline image filter")
  }
  if names.is_empty() {
    return []
  }
  let parameters = pdf_inline_value(dict, b"DP", b"DecodeParms")
  let filters : Array[PdfStreamFilter] = []
  for i, name in names {
    let options = match parameters {
      Some(Dictionary(_)) if names.length() == 1 => parameters
      Some(ArrayValue(values)) if i < values.length() => Some(values[i])
      _ => None
    }
    filters.push({
      name: pdf_filter_name(name),
      predictor: pdf_inline_dict_int(options, b"Predictor", 1),
      colors: pdf_inline_dict_int(options, b"Colors", 1),
      bits: pdf_inline_dict_int(options, b"BitsPerComponent", 8),
      columns: pdf_inline_dict_int(options, b"Columns", 1),
      early_change: pdf_inline_dict_int(options, b"EarlyChange", 1),
    })
  }
  filters
}

///|
fn PdfGraphics::inline_raw_length(
  self : PdfGraphics,
  dict : Array[(Bytes, ContentValue)],
) -> Int32 raise PdfStreamError {
  let width = pdf_inline_int(dict, b"W", b"Width", 0)
  let height = pdf_inline_int(dict, b"H", b"Height", 0)
  if width <= 0 || height <= 0 {
    return -1
  }
  let is_mask = pdf_inline_bool(dict, b"IM", b"ImageMask")
  let bpc = if is_mask {
    pdf_inline_int(dict, b"BPC", b"BitsPerComponent", 1)
  } else {
    pdf_inline_int(dict, b"BPC", b"BitsPerComponent", 8)
  }
  let components = if is_mask {
    1
  } else {
    match pdf_inline_value(dict, b"CS", b"ColorSpace") {
      Some(value) =>
        match self.resolve_color_space(value) {
          PdfGray => 1
          PdfRGB => 3
          PdfCMYK => 4
          PdfIndexed(_, _, _) | PdfSeparation(_, _) => 1
          PdfDeviceN(_, _, count) => count
          PdfLab => 3
          PdfPattern => 0
        }
      None => 1
    }
  }
  if bpc <= 0 || components <= 0 {
    return -1
  }
  let bits = width.to_int64() *
    components.to_int64() *
    bpc.to_int64()
  let row_bytes = (bits + 7L) / 8L
  let length = row_bytes * height.to_int64()
  if length > 2147483647L {
    return -1
  }
  length.to_int()
}

///|
fn PdfGraphics::draw_inline_image(
  self : PdfGraphics,
  dict : Array[(Bytes, ContentValue)],
  data : Bytes,
) -> Unit raise PdfStreamError {
  let is_mask = pdf_inline_bool(dict, b"IM", b"ImageMask")
  let width = pdf_inline_int(dict, b"W", b"Width", 0)
  let height = pdf_inline_int(dict, b"H", b"Height", 0)
  if width <= 0 || height <= 0 || width > 65535 || height > 65535 {
    raise InvalidStream("PDF inline image size is invalid")
  }
  let decode = pdf_inline_decode(dict)
  let filters = pdf_inline_filters(dict)
  let ccitt_filter = pdf_ccitt_filter_index(filters) >= 0
  let bpc = if is_mask {
    pdf_inline_int(dict, b"BPC", b"BitsPerComponent", 1)
  } else if ccitt_filter && pdf_inline_value(dict, b"BPC", b"BitsPerComponent") is None {
    1
  } else {
    pdf_inline_int(dict, b"BPC", b"BitsPerComponent", 8)
  }
  let space = if is_mask {
    None
  } else {
    Some(
      match pdf_inline_value(dict, b"CS", b"ColorSpace") {
        Some(value) => self.resolve_color_space(value)
        None => raise InvalidStream("PDF inline image color space is missing")
      },
    )
  }
  let mut invert = !decode.is_empty() && decode[0] == 1.0
  let (decoded_data, codec) = pdf_decode_stream(
    data,
    filters,
    1073741824L,
    false,
    1073741824L,
  )
  let mut decoded = decoded_data
  let ccitt = match codec {
    Some(b"CCITTFaxDecode") => Some(pdf_inline_ccitt_params(dict))
    _ => None
  }
  if !is_mask && !decode.is_empty() && bpc == 8 {
    match codec {
      None =>
        match space {
          Some(value) => {
            decoded = pdf_image_decode_samples(decoded, value, decode)
            invert = false
          }
          None => ()
        }
      _ => ()
    }
  }
  self.draw_image_data(
    width, height, bpc, space, is_mask, invert, decoded, codec, ccitt,
  )
}

///|
// Read the dictionary and data of an inline image after its BI operator. The
// lexer is left after the closing EI.
fn PdfGraphics::inline_image(
  self : PdfGraphics,
  lexer : ContentLexer,
) -> Unit raise PdfStreamError {
  let entries : Array[(Bytes, ContentValue)] = []
  let mut length : Int32 = -1
  while true {
    match lexer.next(0) {
      End => raise InvalidStream("PDF inline image is unterminated")
      Operator(b"ID") => break
      Operand(Name(key)) => {
        if entries.length() >= 64 {
          raise InvalidStream("PDF inline image dictionary is too large")
        }
        let value = match lexer.next(0) {
          Operand(value) => value
          _ => raise InvalidStream("PDF inline image value is missing")
        }
        if (key == b"L" || key == b"Length") && value is Integer(number) {
          if number >= 0L && number <= 2147483647L {
            length = number.to_int()
          }
        }
        entries.push((key, value))
      }
      _ => raise InvalidStream("invalid PDF inline image dictionary")
    }
  }
  let filters = pdf_inline_filters(entries)
  let effective_length = if length < 0 && filters.is_empty() {
    self.inline_raw_length(entries)
  } else {
    length
  }
  let data = lexer.read_inline_image_with_filters(effective_length, filters)
  self.draw_inline_image(entries, data)
}
