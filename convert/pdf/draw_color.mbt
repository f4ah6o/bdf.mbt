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

///|
// Resolve a named page color space through its resource dictionary. The
// recursive form is bounded and accepts the device and ICC-based families.
fn PdfGraphics::resolve_color_space(
  self : PdfGraphics,
  value : ContentValue,
) -> PdfDeviceColorSpace raise PdfStreamError {
  let simple = Some(pdf_device_color_space(value)) catch { _ => None }
  match simple {
    Some(space) => return space
    None => ()
  }
  let name = match value {
    Name(name) => name
    _ => raise InvalidStream("unsupported PDF color space")
  }
  let file = match self.file {
    Some(value) => value
    None => raise InvalidStream("PDF color space resource missing")
  }
  let resources = match self.resources {
    Some(value) => value
    None => raise InvalidStream("PDF color space resource missing")
  }
  let table = file.page_deref(pdf_dict_get(resources, b"ColorSpace"))
  match pdf_dict_get(table, name) {
    Some(value) => file.resolve_device_color(value, 0)
    None => raise InvalidStream("PDF color space resource missing")
  }
}

///|
fn PdfFile::resolve_device_color(
  self : PdfFile,
  object : PdfObject,
  depth : Int32,
) -> PdfDeviceColorSpace raise PdfStreamError {
  if depth > 16 {
    raise InvalidStream("PDF color space nesting limit")
  }
  let value = self.page_deref(Some(object))
  match value {
    PdfName(name) =>
      match name {
        b"DeviceGray" | b"G" | b"CalGray" => PdfGray
        b"DeviceRGB" | b"RGB" | b"CalRGB" => PdfRGB
        b"DeviceCMYK" | b"CMYK" => PdfCMYK
        _ => raise InvalidStream("unsupported PDF color space")
      }
    PdfArray(values) if !values.is_empty() => {
      let family = self.page_deref(Some(values[0]))
      if family == PdfName(b"ICCBased") {
        if values.length() < 2 {
          return PdfRGB
        }
        let profile = match values[1] {
          PdfRef(number, _) => self.load(number, 0) catch { _ => return PdfRGB }
          _ => return PdfRGB
        }
        if profile.stream is None {
          return PdfRGB
        }
        let n = match self.page_num(pdf_dict_get(profile.value, b"N")) {
          Some(value) => value.to_int()
          None => 0
        }
        match n {
          1 => PdfGray
          4 => PdfCMYK
          0 =>
            match pdf_dict_get(profile.value, b"Alternate") {
              Some(alternate) => self.resolve_device_color(alternate, depth + 1)
              None => PdfRGB
            }
          _ => PdfRGB
        }
      } else {
        self.resolve_device_color(family, depth + 1)
      }
    }
    _ => raise InvalidStream("unsupported PDF color space")
  }
}
