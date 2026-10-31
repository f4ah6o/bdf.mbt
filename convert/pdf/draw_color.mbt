///|
priv enum PdfDeviceColorSpace {
  PdfGray
  PdfRGB
  PdfCMYK
}

///|
fn pdf_device_color_space(
  value : ContentValue,
) -> PdfDeviceColorSpace raise PdfStreamError {
  let name = match value {
    Name(value) => value
    ArrayValue(values) if !values.is_empty() =>
      match values[0] {
        Name(value) => value
        _ => b""
      }
    _ => b""
  }
  match name {
    b"DeviceGray" | b"G" | b"CalGray" => PdfGray
    b"DeviceRGB" | b"RGB" | b"CalRGB" => PdfRGB
    b"DeviceCMYK" | b"CMYK" => PdfCMYK
    _ => raise InvalidStream("unsupported PDF color space")
  }
}

///|
fn pdf_device_color(
  space : PdfDeviceColorSpace,
  values : Array[Double],
) -> UInt32 {
  let defaults = match space {
    PdfGray => [0.0]
    PdfRGB => [0.0, 0.0, 0.0]
    PdfCMYK => [0.0, 0.0, 0.0, 1.0]
  }
  let count = if values.length() < defaults.length() {
    values.length()
  } else {
    defaults.length()
  }
  for i in 0..<count {
    defaults[i] = values[i]
  }
  match space {
    PdfGray => pdf_color(defaults[0], defaults[0], defaults[0])
    PdfRGB => pdf_color(defaults[0], defaults[1], defaults[2])
    PdfCMYK => {
      let c = Double::min(1.0, Double::max(0.0, defaults[0]))
      let m = Double::min(1.0, Double::max(0.0, defaults[1]))
      let y = Double::min(1.0, Double::max(0.0, defaults[2]))
      let k = Double::min(1.0, Double::max(0.0, defaults[3]))
      pdf_color(
        (1.0 - c) * (1.0 - k),
        (1.0 - m) * (1.0 - k),
        (1.0 - y) * (1.0 - k),
      )
    }
  }
}
