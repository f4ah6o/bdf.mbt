///|
priv struct PdfFunction {
  kind : Int32
  domain : Array[Double]
  c0 : Array[Double]
  c1 : Array[Double]
  exponent : Double
  bounds : Array[Double]
  encode : Array[Double]
  functions : Array[PdfFunction]
}

///|
fn pdf_function_numbers(
  file : PdfFile,
  dict : PdfObject,
  key : Bytes,
  default : Array[Double],
) -> Array[Double] raise PdfStreamError {
  match file.page_deref(pdf_dict_get(dict, key)) {
    PdfArray(values) => {
      let out : Array[Double] = []
      for value in values {
        match file.page_num(Some(value)) {
          Some(number) => out.push(number)
          None => raise InvalidStream("invalid PDF function array")
        }
      }
      out
    }
    PdfNull => default
    _ => raise InvalidStream("invalid PDF function array")
  }
}

///|
fn pdf_load_function(
  file : PdfFile,
  object : PdfObject?,
  depth : Int32,
) -> PdfFunction? raise PdfStreamError {
  if depth > 8 {
    raise InvalidStream("PDF function nesting limit")
  }
  let dict = match object {
    Some(value) => file.page_deref(Some(value))
    None => PdfNull
  }
  if dict is PdfNull {
    return None
  }
  let kind = match file.page_num(pdf_dict_get(dict, b"FunctionType")) {
    Some(value) => value.to_int()
    None => return None
  }
  let domain = pdf_function_numbers(
    file,
    dict,
    b"Domain",
    if kind == 1 {
      [0.0, 1.0, 0.0, 1.0]
    } else {
      [0.0, 1.0]
    },
  )
  let c0 = match kind {
    2 => pdf_function_numbers(file, dict, b"C0", [0.0])
    _ => []
  }
  let c1 = match kind {
    2 => pdf_function_numbers(file, dict, b"C1", [1.0])
    _ => []
  }
  let exponent = match kind {
    2 =>
      match file.page_num(pdf_dict_get(dict, b"N")) {
        Some(value) => value
        None => 1.0
      }
    _ => 1.0
  }
  let bounds = match kind {
    3 => pdf_function_numbers(file, dict, b"Bounds", [])
    _ => []
  }
  let encode = match kind {
    3 => pdf_function_numbers(file, dict, b"Encode", [])
    _ => []
  }
  let functions : Array[PdfFunction] = []
  if kind == 3 {
    match file.page_deref(pdf_dict_get(dict, b"Functions")) {
      PdfArray(values) =>
        for value in values {
          match pdf_load_function(file, Some(value), depth + 1) {
            Some(function) => functions.push(function)
            None => raise InvalidStream("PDF stitching function is missing")
          }
        }
      _ => raise InvalidStream("PDF stitching function is missing")
    }
  }
  Some({ kind, domain, c0, c1, exponent, bounds, encode, functions, })
}

///|
fn pdf_function_eval(function : PdfFunction, input : Double) -> Array[Double] {
  match function.kind {
    2 => {
      let low = function.domain[0]
      let high = if function.domain.length() > 1 {
        function.domain[1]
      } else {
        1.0
      }
      let t = if high > low {
        Double::min(1.0, Double::max(0.0, (input - low) / (high - low)))
      } else {
        0.0
      }
      let value = Double::pow(t, function.exponent)
      let count = if function.c0.length() > function.c1.length() {
        function.c0.length()
      } else {
        function.c1.length()
      }
      let out : Array[Double] = []
      for i in 0..<count {
        let start = if i < function.c0.length() { function.c0[i] } else { 0.0 }
        let end = if i < function.c1.length() { function.c1[i] } else { 1.0 }
        out.push(start + value * (end - start))
      }
      out
    }
    3 => {
      let low = function.domain[0]
      let high = if function.domain.length() > 1 {
        function.domain[1]
      } else {
        1.0
      }
      let t = if high > low {
        Double::min(1.0, Double::max(0.0, (input - low) / (high - low)))
      } else {
        0.0
      }
      let mut index = 0
      while index < function.bounds.length() && t >= function.bounds[index] {
        index += 1
      }
      if index >= function.functions.length() {
        return []
      }
      let begin = if index == 0 { 0.0 } else { function.bounds[index - 1] }
      let end = if index < function.bounds.length() {
        function.bounds[index]
      } else {
        1.0
      }
      let local = if end > begin { (t - begin) / (end - begin) } else { 0.0 }
      let encode_low = if 2 * index < function.encode.length() {
        function.encode[2 * index]
      } else {
        0.0
      }
      let encode_high = if 2 * index + 1 < function.encode.length() {
        function.encode[2 * index + 1]
      } else {
        1.0
      }
      pdf_function_eval(
        function.functions[index],
        encode_low + local * (encode_high - encode_low),
      )
    }
    _ => []
  }
}

///|
fn pdf_shading_color(
  space : PdfDeviceColorSpace,
  values : Array[Double],
) -> Int32 {
  pdf_device_color(space, values).reinterpret_as_int()
}

///|
fn pdf_shading_stops(
  space : PdfDeviceColorSpace,
  function : PdfFunction?,
  start : Double,
  end : Double,
) -> Array[@core.ColorStop] {
  let stops : Array[@core.ColorStop] = []
  let add = fn(offset : Double) {
    let t = start + offset * (end - start)
    let values = match function {
      Some(value) => pdf_function_eval(value, t)
      None => []
    }
    let color = if values.is_empty() {
      0x808080ffU.reinterpret_as_int()
    } else {
      pdf_shading_color(space, values)
    }
    stops.push({ offset, color, })
  }
  match function {
    Some(value) if value.kind == 2 && value.exponent == 1.0 => {
      add(0.0)
      add(1.0)
    }
    _ =>
      for i in 0..<33 {
        add(i.to_double() / 32.0)
      }
  }
  stops
}

///|
fn pdf_matrix_inverse(
  matrix : (Double, Double, Double, Double, Double, Double),
) -> (Double, Double, Double, Double, Double, Double)? {
  let (a, b, c, d, e, f) = matrix
  let determinant = a * d - b * c
  if Double::abs(determinant) < 1.0e-12 {
    None
  } else {
    let inverse = 1.0 / determinant
    Some(
      (
        d * inverse,
        -b * inverse,
        -c * inverse,
        a * inverse,
        (c * f - d * e) * inverse,
        (b * e - a * f) * inverse,
      ),
    )
  }
}

///|
fn pdf_transform_point(
  matrix : (Double, Double, Double, Double, Double, Double),
  x : Double,
  y : Double,
) -> (Double, Double) {
  let (a, b, c, d, e, f) = matrix
  (a * x + c * y + e, b * x + d * y + f)
}

///|
fn PdfGraphics::shading_area(
  self : PdfGraphics,
) -> (Double, Double, Double, Double) {
  let (x, y, width, height) = self.object.bbox()
  if width <= 0.0F || height <= 0.0F {
    return (0.0, 0.0, 0.0, 0.0)
  }
  let inverse = match pdf_matrix_inverse(self.state.matrix) {
    Some(value) => value
    None => return (0.0, 0.0, 0.0, 0.0)
  }
  let (x0, y0) = pdf_transform_point(inverse, x.to_double(), y.to_double())
  let (x1, y1) = pdf_transform_point(
    inverse,
    x.to_double() + width.to_double(),
    y.to_double(),
  )
  let (x2, y2) = pdf_transform_point(
    inverse,
    x.to_double(),
    y.to_double() + height.to_double(),
  )
  let (x3, y3) = pdf_transform_point(
    inverse,
    x.to_double() + width.to_double(),
    y.to_double() + height.to_double(),
  )
  (
    Double::min(Double::min(x0, x1), Double::min(x2, x3)),
    Double::min(Double::min(y0, y1), Double::min(y2, y3)),
    Double::max(Double::max(x0, x1), Double::max(x2, x3)),
    Double::max(Double::max(y0, y1), Double::max(y2, y3)),
  )
}

///|
fn PdfGraphics::draw_shading(
  self : PdfGraphics,
  file : PdfFile,
  dict : PdfObject,
) -> Unit raise PdfStreamError {
  let kind = match file.page_num(pdf_dict_get(dict, b"ShadingType")) {
    Some(value) => value.to_int()
    None => 0
  }
  let space = match pdf_dict_get(dict, b"ColorSpace") {
    Some(value) => file.resolve_device_color(value, 0)
    None => raise InvalidStream("PDF shading color space is missing")
  }
  let function = pdf_load_function(file, pdf_dict_get(dict, b"Function"), 0)
  let domain = pdf_function_numbers(file, dict, b"Domain", [0.0, 1.0])
  let start = if domain.length() > 0 { domain[0] } else { 0.0 }
  let end = if domain.length() > 1 { domain[1] } else { 1.0 }
  let coords = pdf_function_numbers(file, dict, b"Coords", [])
  let area = self.shading_area()
  if area.2 <= area.0 || area.3 <= area.1 {
    return
  }
  let bbox = match pdf_dict_get(dict, b"BBox") {
    Some(_) => {
      let values = pdf_function_numbers(file, dict, b"BBox", [])
      if values.length() == 4 {
        Some(values)
      } else {
        None
      }
    }
    None => None
  }
  let (area_x0, area_y0, area_x1, area_y1) = area
  let mut x0 = area_x0
  let mut y0 = area_y0
  let mut x1 = area_x1
  let mut y1 = area_y1
  match bbox {
    Some(values) => {
      x0 = Double::max(x0, values[0])
      y0 = Double::max(y0, values[1])
      x1 = Double::min(x1, values[2])
      y1 = Double::min(y1, values[3])
    }
    None => ()
  }
  if x1 <= x0 || y1 <= y0 {
    return
  }
  let paint = match kind {
    2 if coords.length() >= 4 =>
      Some(
        @core.Gradient(
          0,
          [coords[0], coords[1], coords[2], coords[3]],
          pdf_shading_stops(space, function, start, end),
        ),
      )
    3 if coords.length() >= 6 =>
      Some(
        @core.Gradient(
          1,
          [coords[0], coords[1], coords[2], coords[3], coords[4], coords[5]],
          pdf_shading_stops(space, function, start, end),
        ),
      )
    _ => None
  }
  self.sync_alpha(false)
  self.emitted.fill = None
  match paint {
    Some(value) => {
      let index = self.object.add_paint(value)
      self.object.fill_paint(index) catch {
        _ => raise InvalidStream("PDF shading output failed")
      }
    }
    None => {
      let values = match function {
        Some(value) => pdf_function_eval(value, (start + end) / 2.0)
        None => []
      }
      let color = if values.is_empty() {
        0x808080ffU
      } else {
        pdf_shading_color(space, values).reinterpret_as_uint()
      }
      self.object.fill_color(color)
      self.state.fill = color
    }
  }
  self.object.fill_rect(
    Float::from_double(x0),
    Float::from_double(y0),
    Float::from_double(x1 - x0),
    Float::from_double(y1 - y0),
  )
}

///|
fn PdfGraphics::paint_shading(
  self : PdfGraphics,
  name : Bytes,
) -> Unit raise PdfStreamError {
  let file = match self.file {
    Some(value) => value
    None => raise InvalidStream("PDF shading resource missing")
  }
  let resources = match self.resources {
    Some(value) => value
    None => raise InvalidStream("PDF shading resource missing")
  }
  let table = file.page_deref(pdf_dict_get(resources, b"Shading"))
  let object = match pdf_dict_get(table, name) {
    Some(value) => value
    None => raise InvalidStream("PDF shading is missing")
  }
  let dict = file.page_deref(Some(object))
  self.draw_shading(file, dict)
}
