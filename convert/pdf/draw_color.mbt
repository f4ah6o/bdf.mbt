///|
priv enum PdfColorBase {
  PdfBaseGray
  PdfBaseRGB
  PdfBaseCMYK
}

///|
priv enum PdfDeviceColorSpace {
  PdfGray
  PdfRGB
  PdfCMYK
  PdfPattern
  PdfIndexed(PdfColorBase, Int32, Bytes)
  PdfSeparation(PdfColorBase, PdfFunction)
  PdfDeviceN(PdfColorBase, PdfFunction)
  PdfLab
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
    b"Pattern" => PdfPattern
    _ => raise InvalidStream("unsupported PDF color space")
  }
}

///|
fn pdf_color_base_components(base : PdfColorBase) -> Int32 {
  match base {
    PdfBaseGray => 1
    PdfBaseRGB => 3
    PdfBaseCMYK => 4
  }
}

///|
fn pdf_color_base_space(base : PdfColorBase) -> PdfDeviceColorSpace {
  match base {
    PdfBaseGray => PdfGray
    PdfBaseRGB => PdfRGB
    PdfBaseCMYK => PdfCMYK
  }
}

///|
fn pdf_color_from_base(base : PdfColorBase, values : Array[Double]) -> UInt32 {
  pdf_device_color(pdf_color_base_space(base), values)
}

///|
fn pdf_lab_color(values : Array[Double]) -> UInt32 {
  let l = if values.length() > 0 {
    Double::min(100.0, Double::max(0.0, values[0]))
  } else {
    0.0
  }
  let a = if values.length() > 1 { values[1] } else { 0.0 }
  let b = if values.length() > 2 { values[2] } else { 0.0 }
  let fy = (l + 16.0) / 116.0
  let fx = fy + a / 500.0
  let fz = fy - b / 200.0
  let convert = fn(value : Double) -> Double {
    let cube = value * value * value
    if cube > 0.008856 {
      cube
    } else {
      (value - 16.0 / 116.0) / 7.787
    }
  }
  let x = convert(fx) * 0.9642
  let y = convert(fy)
  let z = convert(fz) * 0.8249
  let r = 3.1338561 * x - 1.6168667 * y - 0.4906146 * z
  let g = -0.9787684 * x + 1.9161415 * y + 0.0334540 * z
  let blue = 0.0719453 * x - 0.2289914 * y + 1.4052427 * z
  let gamma = fn(value : Double) -> Double {
    let v = Double::min(1.0, Double::max(0.0, value))
    if v <= 0.0031308 {
      12.92 * v
    } else {
      1.055 * Double::pow(v, 1.0 / 2.4) - 0.055
    }
  }
  pdf_color(gamma(r), gamma(g), gamma(blue))
}

///|
fn pdf_device_color(
  space : PdfDeviceColorSpace,
  values : Array[Double],
) -> UInt32 {
  match space {
    PdfGray => {
      let value = if values.length() > 0 { values[0] } else { 0.0 }
      pdf_color(value, value, value)
    }
    PdfRGB => {
      let r = if values.length() > 0 { values[0] } else { 0.0 }
      let g = if values.length() > 1 { values[1] } else { 0.0 }
      let b = if values.length() > 2 { values[2] } else { 0.0 }
      pdf_color(r, g, b)
    }
    PdfCMYK => {
      let c = if values.length() > 0 { values[0] } else { 0.0 }
      let m = if values.length() > 1 { values[1] } else { 0.0 }
      let y = if values.length() > 2 { values[2] } else { 0.0 }
      let k = if values.length() > 3 { values[3] } else { 1.0 }
      let c = Double::min(1.0, Double::max(0.0, c))
      let m = Double::min(1.0, Double::max(0.0, m))
      let y = Double::min(1.0, Double::max(0.0, y))
      let k = Double::min(1.0, Double::max(0.0, k))
      pdf_color((1.0 - c) * (1.0 - k), (1.0 - m) * (1.0 - k), (1.0 - y) * (1.0 - k))
    }
    PdfPattern => pdf_color(0.0, 0.0, 0.0)
    PdfIndexed(base, hival, lookup) => {
      let index = if values.length() > 0 {
        Double::min(hival.to_double(), Double::max(0.0, values[0])).to_int()
      } else {
        0
      }
      let count = pdf_color_base_components(base)
      let offset = index * count
      if offset + count > lookup.length() {
        pdf_color_from_base(base, [])
      } else {
        let components : Array[Double] = []
        for i in 0..<count {
          components.push(lookup[offset + i].to_double() / 255.0)
        }
        pdf_color_from_base(base, components)
      }
    }
    PdfSeparation(base, function) => {
      let tint = if values.length() > 0 {
        Double::min(1.0, Double::max(0.0, values[0]))
      } else {
        0.0
      }
      let converted = pdf_function_eval(function, tint)
      if converted.is_empty() {
        let fallback = match base {
          PdfBaseGray => [1.0 - tint]
          PdfBaseRGB => [1.0 - tint, 1.0 - tint, 1.0 - tint]
          PdfBaseCMYK => [0.0, 0.0, 0.0, 1.0 - tint]
        }
        pdf_color_from_base(base, fallback)
      } else {
        pdf_color_from_base(base, converted)
      }
    }
    PdfDeviceN(base, function) => {
      let tint = if values.length() > 0 {
        Double::min(1.0, Double::max(0.0, values[0]))
      } else {
        0.0
      }
      let converted = pdf_function_eval(function, tint)
      if !converted.is_empty() {
        pdf_color_from_base(base, converted)
      } else if values.length() >= pdf_color_base_components(base) {
        pdf_color_from_base(base, values)
      } else {
        pdf_color_from_base(base, [0.0, 0.0, 0.0, 1.0 - tint])
      }
    }
    PdfLab => pdf_lab_color(values)
  }
}

///|
fn pdf_color_components(space : PdfDeviceColorSpace) -> Int32 {
  match space {
    PdfGray => 1
    PdfRGB => 3
    PdfCMYK => 4
    PdfPattern => 0
    PdfIndexed(_, _, _) => 1
    PdfSeparation(_, _) => 1
    PdfDeviceN(_, _) => 1
    PdfLab => 3
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
fn pdf_color_base_of(space : PdfDeviceColorSpace) -> PdfColorBase {
  match space {
    PdfGray => PdfBaseGray
    PdfCMYK => PdfBaseCMYK
    _ => PdfBaseRGB
  }
}

///|
fn pdf_default_function() -> PdfFunction {
  {
    kind: 2,
    domain: [0.0, 1.0],
    c0: [1.0, 1.0, 1.0, 0.0],
    c1: [0.0, 0.0, 0.0, 1.0],
    exponent: 1.0,
    bounds: [],
    encode: [],
    functions: [],
  }
}

///|
fn PdfFile::indexed_lookup(
  self : PdfFile,
  object : PdfObject,
) -> Bytes raise PdfStreamError {
  match object {
    PdfRef(number, _) => {
      let loaded = self.load(number, 0)
      match loaded.stream {
        Some(raw) => {
          let (data, codec) = pdf_decode_stream(
            raw,
            self.resolved_stream_filters(loaded.value),
            67108864L,
            false,
            67108864L,
          )
          if codec is Some(_) {
            raise InvalidStream("encoded PDF indexed color lookup is not supported")
          }
          data
        }
        None =>
          match self.page_deref(Some(object)) {
            PdfString(data) | PdfHex(data) => data
            _ => b""
          }
      }
    }
    _ =>
      match self.page_deref(Some(object)) {
        PdfString(data) | PdfHex(data) => data
        _ => b""
      }
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
        b"Pattern" => PdfPattern
        _ => raise InvalidStream("unsupported PDF color space")
      }
    PdfArray(values) if !values.is_empty() => {
      let family = self.page_deref(Some(values[0]))
      let family_name = match family {
        PdfName(name) => name
        _ => b""
      }
      if family_name == b"ICCBased" {
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
      } else if family_name == b"Indexed" {
        let base = if values.length() > 1 {
          pdf_color_base_of(self.resolve_device_color(values[1], depth + 1))
        } else {
          PdfBaseRGB
        }
        let hival = Int32::max(
          0,
          if values.length() > 2 {
            match self.page_num(Some(values[2])) {
              Some(value) => value.to_int()
              None => 0
            }
          } else {
            0
          },
        )
        let lookup = if values.length() > 3 {
          self.indexed_lookup(values[3]) catch { _ => b"" }
        } else {
          b""
        }
        PdfIndexed(base, hival, lookup)
      } else if family_name == b"Separation" {
        let base = if values.length() > 2 {
          pdf_color_base_of(self.resolve_device_color(values[2], depth + 1))
        } else {
          PdfBaseGray
        }
        let function = if values.length() > 3 {
          match pdf_load_function(self, Some(values[3]), depth + 1) {
            Some(value) => value
            None => pdf_default_function()
          }
        } else {
          pdf_default_function()
        }
        PdfSeparation(base, function)
      } else if family_name == b"DeviceN" {
        let base = if values.length() > 2 {
          pdf_color_base_of(self.resolve_device_color(values[2], depth + 1))
        } else {
          PdfBaseCMYK
        }
        let function = if values.length() > 3 {
          match pdf_load_function(self, Some(values[3]), depth + 1) {
            Some(value) => value
            None => pdf_default_function()
          }
        } else {
          pdf_default_function()
        }
        PdfDeviceN(base, function)
      } else if family_name == b"Lab" {
        PdfLab
      } else {
        self.resolve_device_color(family, depth + 1)
      }
    }
    _ => raise InvalidStream("unsupported PDF color space")
  }
}
