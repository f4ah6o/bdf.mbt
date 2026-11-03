///|
fn pdf_jpx_u32(data : Bytes, offset : Int32) -> Int32 {
  (data[offset].to_int() << 24) |
  (data[offset + 1].to_int() << 16) |
  (data[offset + 2].to_int() << 8) |
  data[offset + 3].to_int()
}

///|
fn pdf_jpx_codestream(data : Bytes) -> Bytes raise PdfStreamError {
  if data.length() >= 4 &&
    data[0] == b'\xff' &&
    data[1] == b'\x4f' &&
    data[2] == b'\xff' &&
    data[3] == b'\x51' {
    return data
  }
  if data.length() >= 12 &&
    data[4] == b'j' &&
    data[5] == b'P' &&
    data[6] == b' ' &&
    data[7] == b' ' {
    let mut offset = 0
    while offset + 8 <= data.length() {
      let length = pdf_jpx_u32(data, offset)
      let box_length : Int64 = if length == 0 {
        (data.length() - offset).to_int64()
      } else if length == 1 {
        if offset + 16 > data.length() {
          raise InvalidStream("invalid PDF JPX box")
        }
        let high = pdf_jpx_u32(data, offset + 8).to_int64() & 0xffffffffL
        let low = pdf_jpx_u32(data, offset + 12).to_int64() & 0xffffffffL
        (high << 32) | low
      } else {
        length.to_int64()
      }
      if box_length < 8L || offset.to_int64() + box_length > data.length().to_int64() {
        raise InvalidStream("invalid PDF JPX box")
      }
      let kind = data[offset + 4:offset + 8]
      let header = if length == 1 { 16 } else { 8 }
      if kind == b"jp2c" {
        return data[offset + header:offset + box_length.to_int()].to_owned()
      }
      offset += box_length.to_int()
    }
  }
  raise InvalidStream("unsupported PDF JPX image")
}

///|
fn pdf_jpx_sample(
  image : @jpx.ImageData,
  component : Int32,
  pixel : Int32,
  bytes_per : Int32,
  interleaved : Bool,
) -> Int32 {
  let offset = if interleaved {
    (pixel * image.num_components + component) * bytes_per
  } else {
    (component * image.width * image.height + pixel) * bytes_per
  }
  if bytes_per == 1 {
    image.data[offset].to_int()
  } else {
    image.data[offset].to_int() | (image.data[offset + 1].to_int() << 8)
  }
}

///|
fn pdf_jpx_value(
  sample : Int32,
  bits : Int32,
  signed : Bool,
  invert : Bool,
) -> Int32 {
  let mut value = sample
  if signed {
    let sign = 1 << (bits - 1)
    if (value & sign) != 0 {
      value -= 1 << bits
    }
    value += sign
  }
  let scaled = if bits >= 8 {
    (value >> (bits - 8)) & 0xff
  } else if bits > 0 {
    value * 255 / ((1 << bits) - 1)
  } else {
    value
  }
  if invert {
    255 - scaled
  } else {
    scaled
  }
}

///|
fn pdf_jpx_rgb(
  data : Bytes,
  space : PdfDeviceColorSpace?,
  invert : Bool,
) -> (Int32, Int32, Bytes) raise PdfStreamError {
  let codestream = pdf_jpx_codestream(data)
  let (image, layout) = @jpx.decode_all_components(codestream) catch {
    _ => raise InvalidStream("invalid PDF JPX image")
  }
  if image.width <= 0 || image.height <= 0 || image.num_components <= 0 {
    raise InvalidStream("invalid PDF JPX image size")
  }
  let pixels = image.width * image.height
  if pixels <= 0 {
    raise InvalidStream("invalid PDF JPX image size")
  }
  let bits = if image.bits_per_component <= 0 {
    8
  } else {
    image.bits_per_component
  }
  let bytes_per = if bits > 8 { 2 } else { 1 }
  let plane = pixels * bytes_per
  if image.data.length() < plane * image.num_components {
    raise InvalidStream("PDF JPX image samples are truncated")
  }
  let interleaved = image.num_components > 1 &&
    layout.contains("raster") &&
    !layout.contains("planar") &&
    image.data.length() >= plane * image.num_components
  let space = match space {
    Some(PdfGray) => PdfGray
    Some(PdfRGB) => PdfRGB
    Some(PdfCMYK) => PdfCMYK
    Some(PdfPattern) => raise InvalidStream("PDF JPX image with a pattern colour space")
    Some(PdfIndexed(_, _, _) | PdfSeparation(_, _) | PdfDeviceN(_, _) | PdfLab) =>
      raise InvalidStream("unsupported PDF JPX image colour space")
    None =>
      if image.num_components == 1 {
        PdfGray
      } else if image.num_components == 3 {
        PdfRGB
      } else if image.num_components == 4 {
        PdfCMYK
      } else {
        raise InvalidStream("unsupported PDF JPX component count")
      }
  }
  if (match space {
      PdfRGB => image.num_components < 3
      PdfCMYK => image.num_components < 4
      _ => false
    }) {
    raise InvalidStream("PDF JPX component count does not match its colour space")
  }
  let rgb = @buffer.Buffer(size_hint=pixels * 3)
  for pixel in 0..<pixels {
    let first = pdf_jpx_value(
      pdf_jpx_sample(image, 0, pixel, bytes_per, interleaved),
      bits,
      image.is_signed,
      invert,
    )
    if (match space {
      PdfGray => true
      _ => false
    }) {
      rgb.write_byte(first.to_byte())
      rgb.write_byte(first.to_byte())
      rgb.write_byte(first.to_byte())
    } else {
      let second = pdf_jpx_value(
        pdf_jpx_sample(image, 1, pixel, bytes_per, interleaved),
        bits,
        image.is_signed,
        invert,
      )
      let third = pdf_jpx_value(
        pdf_jpx_sample(image, 2, pixel, bytes_per, interleaved),
        bits,
        image.is_signed,
        invert,
      )
      if (match space {
        PdfRGB => true
        _ => false
      }) {
        rgb.write_byte(first.to_byte())
        rgb.write_byte(second.to_byte())
        rgb.write_byte(third.to_byte())
      } else {
        let fourth = pdf_jpx_value(
          pdf_jpx_sample(image, 3, pixel, bytes_per, interleaved),
          bits,
          image.is_signed,
          invert,
        )
        let c = first.to_double() / 255.0
        let m = second.to_double() / 255.0
        let y = third.to_double() / 255.0
        let k = fourth.to_double() / 255.0
        rgb.write_byte(((1.0 - c) * (1.0 - k) * 255.0).round().to_int().to_byte())
        rgb.write_byte(((1.0 - m) * (1.0 - k) * 255.0).round().to_int().to_byte())
        rgb.write_byte(((1.0 - y) * (1.0 - k) * 255.0).round().to_int().to_byte())
      }
    }
  }
  (image.width, image.height, rgb.to_bytes())
}
