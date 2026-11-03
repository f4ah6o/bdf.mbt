///|
fn pdf_soft_mask_stream(
  file : PdfFile,
  object : PdfObject,
) -> (PdfObject, Bytes) raise PdfStreamError {
  match object {
    PdfRef(number, _) => {
      let loaded = file.load(number, 0)
      match loaded.stream {
        Some(raw) => (loaded.value, raw)
        None => raise InvalidStream("PDF soft mask form is not a stream")
      }
    }
    _ => raise InvalidStream("PDF soft mask form is not a stream")
  }
}

///|
fn pdf_soft_mask_number(file : PdfFile, value : PdfObject) -> Double? {
  match file.page_deref(Some(value)) {
    PdfInt(number) => Some(number.to_double())
    PdfReal(number) => Some(number)
    _ => None
  }
}

///|
fn pdf_soft_mask_backdrop(file : PdfFile, dict : PdfObject) -> UInt32 {
  match pdf_dict_get(dict, b"BC") {
    Some(value) => {
      let components : Array[Double] = match file.page_deref(Some(value)) {
        PdfArray(values) => {
          let out : Array[Double] = []
          for item in values {
            match pdf_soft_mask_number(file, item) {
              Some(number) => out.push(number)
              None => out.push(0.0)
            }
          }
          out
        }
        _ => []
      }
      match components.length() {
        1 => pdf_device_color(PdfGray, components)
        3 => pdf_device_color(PdfRGB, components)
        4 => pdf_device_color(PdfCMYK, components)
        _ => 0x000000ffU
      }
    }
    None => 0x000000ffU
  }
}

///|
fn pdf_soft_mask_transfer(file : PdfFile, dict : PdfObject) -> Bytes {
  match pdf_dict_get(dict, b"TR") {
    Some(PdfName(b"Identity")) | None => b""
    Some(value) => {
      let function = pdf_load_function(file, Some(value), 0) catch {
        _ => None
      }
      match function {
        Some(function) => {
          let transfer = @buffer.Buffer(size_hint=256)
          for i in 0..<256 {
            let values = pdf_function_eval(function, i.to_double() / 255.0)
            let value = if values.is_empty() {
              i
            } else {
              (Double::min(1.0, Double::max(0.0, values[0])) * 255.0)
              .round()
              .to_int()
            }
            transfer.write_byte(value.to_byte())
          }
          transfer.to_bytes()
        }
        None => b""
      }
    }
  }
}

///|
fn PdfGraphics::mask_group_bounds(
  self : PdfGraphics,
) -> (Double, Double, Double, Double) {
  let inverse = match pdf_matrix_inverse(self.state.matrix) {
    Some(value) => value
    None => return (0.0, 0.0, 1.0, 1.0)
  }
  let rect = pdf_transform_rect(
    inverse,
    (0.0, 0.0, self.page_width, self.page_height),
  )
  if rect.2 <= rect.0 || rect.3 <= rect.1 {
    (0.0, 0.0, 1.0, 1.0)
  } else {
    rect
  }
}

///|
fn PdfGraphics::ensure_mask_group(self : PdfGraphics) -> Unit {
  if self.mask_group_active || self.mask_rendering > 0 {
    return
  }
  match self.state.soft_mask {
    Some(_) => {
      let (x, y, width, height) = self.mask_group_bounds()
      self.object.group_begin(
        1.0F,
        0,
        Float::from_double(x),
        Float::from_double(y),
        Float::from_double(width),
        Float::from_double(height),
      )
      self.mask_group_active = true
      self.mask_group_level = self.stack.length()
    }
    None => ()
  }
}

///|
fn PdfGraphics::draw_soft_mask(
  self : PdfGraphics,
  object : PdfObject,
) -> Unit raise PdfStreamError {
  let file = match self.file {
    Some(value) => value
    None => raise InvalidStream("PDF soft mask resource missing")
  }
  if self.form_depth >= 16 {
    raise InvalidStream("PDF soft mask nesting limit")
  }
  let dict = file.page_deref(Some(object))
  let form_object = match pdf_dict_get(dict, b"G") {
    Some(value) => value
    None => raise InvalidStream("PDF soft mask form is missing")
  }
  let (form, raw) = pdf_soft_mask_stream(file, form_object)
  let matrix = match pdf_form_numbers(file, form, b"Matrix", 6) {
    Some(values) =>
      (values[0], values[1], values[2], values[3], values[4], values[5])
    None => (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)
  }
  let bbox = pdf_form_numbers(file, form, b"BBox", 4)
  let resources = match file.page_deref(pdf_dict_get(form, b"Resources")) {
    PdfDict(_) => Some(file.page_deref(pdf_dict_get(form, b"Resources")))
    _ => None
  }
  let (content, codec) = pdf_decode_stream(
    raw,
    file.resolved_stream_filters(form),
    268435456L,
    false,
    268435456L,
  )
  if codec is Some(_) {
    raise InvalidStream("PDF soft mask form is encoded as an image")
  }
  let kind = match file.page_deref(pdf_dict_get(dict, b"S")) {
    PdfName(b"Luminosity") => 1
    _ => 0
  }
  let backdrop = if kind == 1 {
    pdf_soft_mask_backdrop(file, dict)
  } else {
    0U
  }
  let transfer = pdf_soft_mask_transfer(file, dict)
  let depth = self.stack.length()
  self.form_depth += 1
  self.mask_rendering += 1
  self.save()
  self.object.mask_begin(kind.to_byte(), backdrop, transfer)
  self.transform(matrix)
  match bbox {
    Some(values) => {
      let width = values[2] - values[0]
      let height = values[3] - values[1]
      if width > 0.0 && height > 0.0 {
        self.object.clip_rect(
          Float::from_double(values[0]),
          Float::from_double(values[1]),
          Float::from_double(width),
          Float::from_double(height),
        )
      }
    }
    None => ()
  }
  let old_resources = self.resources
  match resources {
    Some(value) => self.resources = Some(value)
    None => ()
  }
  self.run_ops(content)
  self.finish_text()
  self.resources = old_resources
  while self.stack.length() > depth + 1 {
    self.restore()
  }
  self.object.mask_end()
  self.restore()
  self.mask_rendering -= 1
  self.form_depth -= 1
}

///|
fn PdfGraphics::close_mask_group(self : PdfGraphics) -> Unit raise PdfStreamError {
  if !self.mask_group_active || self.mask_rendering > 0 {
    return
  }
  match self.state.soft_mask {
    Some(value) => self.draw_soft_mask(value)
    None => ()
  }
  self.object.group_end()
  self.mask_group_active = false
}
