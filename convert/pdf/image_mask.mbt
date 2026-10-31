///|
// A decoded image mask at its own resolution. `stencil` masks remove the
// pixels they paint; soft masks supply the opacity directly.
priv struct PdfImageMask {
  width : Int32
  height : Int32
  values : Bytes
  stencil : Bool
}

///|
fn pdf_mask_stream(
  file : PdfFile,
  object : PdfObject,
) -> (PdfObject, Bytes) raise PdfStreamError {
  match object {
    PdfRef(number, _) => {
      let loaded = file.load(number, 0)
      match loaded.stream {
        Some(raw) => (loaded.value, raw)
        None => raise InvalidStream("PDF image mask is not a stream")
      }
    }
    _ => raise InvalidStream("PDF image mask is not a stream")
  }
}

///|
fn pdf_decode_mask_values(
  file : PdfFile,
  dict : PdfObject,
  raw : Bytes,
  width : Int32,
  height : Int32,
) -> Bytes raise PdfStreamError {
  let (data, codec) = pdf_decode_stream(
    raw,
    file.resolved_stream_filters(dict),
    1073741824L,
    false,
    1073741824L,
  )
  if codec is Some(_) {
    raise InvalidStream("encoded PDF image masks are not supported yet")
  }
  let needed = width * height
  if data.length() < needed {
    raise InvalidStream("PDF image mask samples are truncated")
  }
  data[:needed].to_owned()
}

///|
fn pdf_load_soft_mask(
  file : PdfFile,
  object : PdfObject,
) -> PdfImageMask raise PdfStreamError {
  let (dict, raw) = pdf_mask_stream(file, object)
  match pdf_dict_get(dict, b"Matte") {
    Some(PdfNull) | None => ()
    Some(_) =>
      raise InvalidStream("PDF soft masks with Matte are not supported")
  }
  let width = pdf_image_dimension(file, dict, b"Width", "mask width")
  let height = pdf_image_dimension(file, dict, b"Height", "mask height")
  let bpc = match file.page_num(pdf_dict_get(dict, b"BitsPerComponent")) {
    Some(value) => value.to_int()
    None => 8
  }
  if bpc != 8 {
    raise InvalidStream("PDF soft masks with this bit depth are not supported")
  }
  match pdf_dict_get(dict, b"ColorSpace") {
    Some(value) =>
      match file.resolve_device_color(value, 0) {
        PdfGray => ()
        _ => raise InvalidStream("PDF soft mask colour space is not supported")
      }
    None => ()
  }
  {
    width,
    height,
    values: pdf_decode_mask_values(file, dict, raw, width, height),
    stencil: false,
  }
}

///|
fn pdf_stencil_values(
  width : Int32,
  height : Int32,
  invert : Bool,
  data : Bytes,
) -> Bytes raise PdfStreamError {
  let row_bytes = (width + 7) / 8
  if data.length() < row_bytes * height {
    raise InvalidStream("PDF stencil mask samples are truncated")
  }
  let out = @buffer.Buffer(size_hint=width * height)
  for y in 0..<height {
    for x in 0..<width {
      let bit = (data[y * row_bytes + x / 8].to_int() >> (7 - x % 8)) & 1
      out.write_byte(if (bit == 0) == !invert { 0xff } else { 0 })
    }
  }
  out.to_bytes()
}

///|
fn pdf_load_stencil_mask(
  file : PdfFile,
  object : PdfObject,
) -> PdfImageMask raise PdfStreamError {
  match object {
    PdfArray(_) =>
      raise InvalidStream("PDF colour key masks are not supported yet")
    _ => ()
  }
  let (dict, raw) = pdf_mask_stream(file, object)
  let is_mask = match file.page_deref(pdf_dict_get(dict, b"ImageMask")) {
    PdfBool(value) => value
    _ => false
  }
  if !is_mask {
    raise InvalidStream("PDF stencil masks require ImageMask")
  }
  let width = pdf_image_dimension(file, dict, b"Width", "mask width")
  let height = pdf_image_dimension(file, dict, b"Height", "mask height")
  let bpc = match file.page_num(pdf_dict_get(dict, b"BitsPerComponent")) {
    Some(value) => value.to_int()
    None => 1
  }
  if bpc != 1 {
    raise InvalidStream("PDF stencil masks must have one bit per pixel")
  }
  let decode : Array[Double] = match
    file.page_deref(pdf_dict_get(dict, b"Decode")) {
    PdfArray(values) =>
      values.map(fn(value) {
        match value {
          PdfInt(number) => number.to_double()
          PdfReal(number) => number
          _ => 0.0
        }
      })
    _ => []
  }
  let invert = !decode.is_empty() && decode[0] == 1.0
  let (data, codec) = pdf_decode_stream(
    raw,
    file.resolved_stream_filters(dict),
    1073741824L,
    false,
    1073741824L,
  )
  if codec is Some(_) {
    raise InvalidStream("encoded PDF image masks are not supported yet")
  }
  {
    width,
    height,
    values: pdf_stencil_values(width, height, invert, data),
    stencil: true,
  }
}

///|
fn pdf_image_rgba_from_rgb(
  width : Int32,
  height : Int32,
  rgb : Bytes,
) -> Bytes raise PdfStreamError {
  if rgb.length() != width * height * 3 {
    raise InvalidStream("invalid PDF image samples")
  }
  let out = @buffer.Buffer(size_hint=width * height * 4)
  let mut i = 0
  while i < width * height {
    out.write_byte(rgb[i * 3])
    out.write_byte(rgb[i * 3 + 1])
    out.write_byte(rgb[i * 3 + 2])
    out.write_byte(0xff)
    i += 1
  }
  out.to_bytes()
}

///|
fn pdf_apply_image_mask(
  rgba : Bytes,
  width : Int32,
  height : Int32,
  mask : PdfImageMask,
) -> Bytes raise PdfStreamError {
  if rgba.length() != width * height * 4 {
    raise InvalidStream("invalid PDF image samples")
  }
  if mask.width <= 0 || mask.height <= 0 {
    raise InvalidStream("invalid PDF image mask size")
  }
  let out = @buffer.Buffer(size_hint=rgba.length())
  for y in 0..<height {
    for x in 0..<width {
      let source = (y * width + x) * 4
      out.write_byte(rgba[source])
      out.write_byte(rgba[source + 1])
      out.write_byte(rgba[source + 2])
      let mask_x = x * mask.width / width
      let mask_y = y * mask.height / height
      let value = mask.values[mask_y * mask.width + mask_x].to_int()
      out.write_byte((if mask.stencil { 255 - value } else { value }).to_byte())
    }
  }
  out.to_bytes()
}

///|
fn pdf_color_key_alpha(
  width : Int32,
  height : Int32,
  space : PdfDeviceColorSpace,
  data : Bytes,
  key : Array[Double],
) -> Bytes raise PdfStreamError {
  let components = match space {
    PdfGray => 1
    PdfRGB => 3
    PdfCMYK => 4
    PdfPattern => raise InvalidStream("PDF image with a pattern colour space")
  }
  if key.length() != components * 2 {
    raise InvalidStream("PDF colour key mask has the wrong size")
  }
  let needed = width * height * components
  if data.length() < needed {
    raise InvalidStream("PDF image samples are truncated")
  }
  let alpha = @buffer.Buffer(size_hint=width * height)
  for pixel in 0..<(width * height) {
    let mut masked = true
    for component in 0..<components {
      let value = data[pixel * components + component].to_double()
      let low = key[component * 2] * 255.0
      let high = key[component * 2 + 1] * 255.0
      if value < low || value > high {
        masked = false
      }
    }
    alpha.write_byte(if masked { 0 } else { 0xff })
  }
  alpha.to_bytes()
}

///|
fn pdf_apply_image_alpha(
  rgba : Bytes,
  alpha : Bytes,
) -> Bytes raise PdfStreamError {
  let pixels = rgba.length() / 4
  if rgba.length() != pixels * 4 || alpha.length() != pixels {
    raise InvalidStream("invalid PDF image alpha")
  }
  let out = @buffer.Buffer(size_hint=rgba.length())
  for pixel in 0..<pixels {
    let source = pixel * 4
    out.write_byte(rgba[source])
    out.write_byte(rgba[source + 1])
    out.write_byte(rgba[source + 2])
    out.write_byte(alpha[pixel])
  }
  out.to_bytes()
}
