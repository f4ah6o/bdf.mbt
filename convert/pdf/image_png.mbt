///|
fn pdf_png_write_u32(out : @buffer.Buffer, value : UInt32) -> Unit {
  out.write_byte(((value >> 24) & 0xffU).to_int().to_byte())
  out.write_byte(((value >> 16) & 0xffU).to_int().to_byte())
  out.write_byte(((value >> 8) & 0xffU).to_int().to_byte())
  out.write_byte((value & 0xffU).to_int().to_byte())
}

///|
fn pdf_png_crc32(data : Bytes) -> UInt32 {
  let mut crc = 0xffffffffU
  for byte in data {
    crc = crc ^ byte.to_uint()
    for _ in 0..<8 {
      if (crc & 1U) != 0U {
        crc = (crc >> 1) ^ 0xedb88320U
      } else {
        crc = crc >> 1
      }
    }
  }
  crc ^ 0xffffffffU
}

///|
fn pdf_png_chunk(out : @buffer.Buffer, kind : Bytes, data : Bytes) -> Unit {
  pdf_png_write_u32(out, data.length().to_uint())
  out.write_bytesview(kind[:])
  out.write_bytesview(data[:])
  let checked = @buffer.Buffer(size_hint=kind.length() + data.length())
  checked.write_bytesview(kind[:])
  checked.write_bytesview(data[:])
  pdf_png_write_u32(out, pdf_png_crc32(checked.to_bytes()))
}

///|
// Encode RGB samples as a non-interlaced 8-bit PNG. PDF sample images are
// converted to RGB before they reach this encoder.
fn pdf_png_encode_rgb(
  width : Int32,
  height : Int32,
  rgb : Bytes,
) -> Bytes raise PdfStreamError {
  if width <= 0 || height <= 0 {
    raise InvalidStream("invalid PDF image size")
  }
  let row_size = width * 3
  if rgb.length() != row_size * height {
    raise InvalidStream("invalid PDF image samples")
  }
  let scanlines = @buffer.Buffer(size_hint=(row_size + 1) * height)
  for y in 0..<height {
    scanlines.write_byte(0)
    scanlines.write_bytesview(rgb[y * row_size:y * row_size + row_size])
  }
  let header = @buffer.Buffer(size_hint=13)
  pdf_png_write_u32(header, width.to_uint())
  pdf_png_write_u32(header, height.to_uint())
  header.write_byte(8)
  header.write_byte(2)
  header.write_byte(0)
  header.write_byte(0)
  header.write_byte(0)
  let out = @buffer.Buffer()
  out.write_bytesview(b"\x89PNG\r\n\x1a\n"[:])
  pdf_png_chunk(out, b"IHDR", header.to_bytes())
  pdf_png_chunk(out, b"IDAT", @zlib.compress(scanlines.to_bytes()[:]))
  pdf_png_chunk(out, b"IEND", b"")
  out.to_bytes()
}

///|
// Convert unencoded 8-bit PDF samples to RGB. Masks, Decode arrays and other
// bit depths are rejected until their decoders are ported.
fn pdf_image_rgb_samples(
  file : PdfFile,
  dict : PdfObject,
  data : Bytes,
) -> (Int32, Int32, Bytes) raise PdfStreamError {
  let width = match file.page_num(pdf_dict_get(dict, b"Width")) {
    Some(value) if value > 0.0 && value <= 65535.0 => value.to_int()
    _ => raise InvalidStream("PDF image width is missing")
  }
  let height = match file.page_num(pdf_dict_get(dict, b"Height")) {
    Some(value) if value > 0.0 && value <= 65535.0 => value.to_int()
    _ => raise InvalidStream("PDF image height is missing")
  }
  let bpc = match file.page_num(pdf_dict_get(dict, b"BitsPerComponent")) {
    Some(value) => value.to_int()
    None => 8
  }
  if bpc != 8 {
    raise InvalidStream(
      "PDF image bit depths other than 8 are not supported yet",
    )
  }
  match pdf_dict_get(dict, b"Decode") {
    Some(PdfArray(values)) if !values.is_empty() =>
      raise InvalidStream("PDF image Decode arrays are not supported yet")
    _ => ()
  }
  let space = match pdf_dict_get(dict, b"ColorSpace") {
    Some(value) => file.resolve_device_color(value, 0)
    None => raise InvalidStream("PDF image color space is missing")
  }
  let components = match space {
    PdfGray => 1
    PdfRGB => 3
    PdfCMYK => 4
  }
  let needed = width * height * components
  if data.length() < needed {
    raise InvalidStream("PDF image samples are truncated")
  }
  let rgb = @buffer.Buffer(size_hint=width * height * 3)
  let mut i = 0
  while i < needed {
    match space {
      PdfGray => {
        let value = data[i]
        rgb.write_byte(value)
        rgb.write_byte(value)
        rgb.write_byte(value)
      }
      PdfRGB => {
        rgb.write_byte(data[i])
        rgb.write_byte(data[i + 1])
        rgb.write_byte(data[i + 2])
      }
      PdfCMYK => {
        let c = data[i].to_int()
        let m = data[i + 1].to_int()
        let y = data[i + 2].to_int()
        let k = data[i + 3].to_int()
        rgb.write_byte(((255 - c) * (255 - k) / 255).to_byte())
        rgb.write_byte(((255 - m) * (255 - k) / 255).to_byte())
        rgb.write_byte(((255 - y) * (255 - k) / 255).to_byte())
      }
    }
    i += components
  }
  (width, height, rgb.to_bytes())
}
