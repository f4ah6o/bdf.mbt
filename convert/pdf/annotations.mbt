///|
fn pdf_annotation_rect(
  file : PdfFile,
  dict : PdfObject,
) -> (Double, Double, Double, Double)? raise PdfStreamError {
  let values = match file.page_deref(pdf_dict_get(dict, b"Rect")) {
    PdfArray(values) if values.length() == 4 => values
    _ => return None
  }
  let numbers : Array[Double] = []
  for value in values {
    match file.page_num(Some(value)) {
      Some(number) => numbers.push(number)
      None => return None
    }
  }
  let x0 = Double::min(numbers[0], numbers[2])
  let y0 = Double::min(numbers[1], numbers[3])
  let x1 = Double::max(numbers[0], numbers[2])
  let y1 = Double::max(numbers[1], numbers[3])
  if x1 <= x0 || y1 <= y0 {
    return None
  }
  Some((x0, y0, x1 - x0, y1 - y0))
}

///|
fn PdfGraphics::link_target(
  self : PdfGraphics,
  file : PdfFile,
  dict : PdfObject,
) -> String {
  match file.page_deref(pdf_dict_get(dict, b"A")) {
    PdfDict(_) => {
      let action = file.page_deref(pdf_dict_get(dict, b"A"))
      match file.page_deref(pdf_dict_get(action, b"S")) {
        PdfName(b"URI") => file.metadata_text(pdf_dict_get(action, b"URI"))
        _ => ""
      }
    }
    _ => ""
  }
}

///|
fn PdfGraphics::emit_annotations(
  self : PdfGraphics,
  file : PdfFile,
  values : Array[PdfObject],
) -> Unit raise PdfStreamError {
  for value in values {
    let dict = file.page_deref(Some(value))
    let subtype = file.page_deref(pdf_dict_get(dict, b"Subtype"))
    match subtype {
      PdfName(b"Popup") => continue
      _ => ()
    }
    let flags = match file.page_num(pdf_dict_get(dict, b"F")) {
      Some(number) => number.to_int()
      None => 0
    }
    if (flags & 2) != 0 || (flags & 32) != 0 {
      continue
    }
    let rect = match pdf_annotation_rect(file, dict) {
      Some(value) => value
      None => continue
    }
    match subtype {
      PdfName(b"Link") => {
        let url = self.link_target(file, dict)
        if url == "" {
          continue
        }
        let (x, y, width, height) = rect
        self.object.link(
          Float::from_double(x),
          Float::from_double(y),
          Float::from_double(width),
          Float::from_double(height),
          url,
        )
      }
      _ =>
        match pdf_annotation_appearance(file, dict) {
          Some((appearance, raw)) =>
            self.draw_annotation_appearance(file, appearance, raw, rect)
          None => ()
        }
    }
  }
}

///|
// Link annotations are in default user space. Undo an unbalanced content
// transform before emitting them, as the upstream converter does.
fn PdfGraphics::draw_annotations(
  self : PdfGraphics,
  page_dict : PdfObject,
  base : (Double, Double, Double, Double, Double, Double),
) -> Unit raise PdfStreamError {
  let file = match self.file {
    Some(value) => value
    None => return
  }
  let values = match file.page_deref(pdf_dict_get(page_dict, b"Annots")) {
    PdfArray(values) => values
    _ => return
  }
  if values.is_empty() {
    return
  }
  if self.state.matrix == base {
    self.emit_annotations(file, values)
  } else {
    let inverse = match pdf_matrix_inverse(self.state.matrix) {
      Some(value) => value
      None => return
    }
    self.save()
    self.transform(pdf_matrix_mul(base, inverse))
    self.emit_annotations(file, values)
    self.restore()
  }
}

///|
fn pdf_load_appearance_stream(
  file : PdfFile,
  object : PdfObject,
) -> (PdfObject, Bytes)? raise PdfStreamError {
  match object {
    PdfRef(number, _) => {
      let loaded = file.load(number, 0)
      let raw = match loaded.stream {
        Some(value) => value
        None => return None
      }
      Some((loaded.value, raw))
    }
    _ => None
  }
}

///|
fn pdf_annotation_appearance(
  file : PdfFile,
  dict : PdfObject,
) -> (PdfObject, Bytes)? raise PdfStreamError {
  let appearance = file.page_deref(pdf_dict_get(dict, b"AP"))
  let normal_object = match pdf_dict_get(appearance, b"N") {
    Some(value) => value
    None => return None
  }
  let normal = file.page_deref(Some(normal_object))
  match normal {
    PdfDict(_) if pdf_dict_get(normal, b"Subtype") is Some(PdfName(b"Form")) =>
      pdf_load_appearance_stream(file, normal_object)
    PdfDict(entries) => {
      let state = match file.page_deref(pdf_dict_get(dict, b"AS")) {
        PdfName(name) => Some(name)
        _ => None
      }
      let mut selected : PdfObject? = None
      match state {
        Some(name) =>
          match pdf_dict_get(normal, name) {
            Some(value) => selected = Some(value)
            None => ()
          }
        None => ()
      }
      if selected is None && !entries.is_empty() {
        selected = Some(entries[0].1)
      }
      match selected {
        Some(value) => pdf_load_appearance_stream(file, value)
        None => None
      }
    }
    _ => pdf_load_appearance_stream(file, normal_object)
  }
}

///|
fn PdfGraphics::draw_annotation_appearance(
  self : PdfGraphics,
  file : PdfFile,
  dict : PdfObject,
  raw : Bytes,
  rect : (Double, Double, Double, Double),
) -> Unit raise PdfStreamError {
  let bbox = match pdf_form_numbers(file, dict, b"BBox", 4) {
    Some(values) => (values[0], values[1], values[2], values[3])
    None => return
  }
  let matrix = match pdf_form_numbers(file, dict, b"Matrix", 6) {
    Some(values) =>
      (values[0], values[1], values[2], values[3], values[4], values[5])
    None => (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)
  }
  let transformed = pdf_transform_rect(matrix, bbox)
  let width = transformed.2 - transformed.0
  let height = transformed.3 - transformed.1
  if width <= 0.0 || height <= 0.0 {
    return
  }
  let (rect_x, rect_y, rect_width, rect_height) = rect
  let scale_x = rect_width / width
  let scale_y = rect_height / height
  let mapping = (
    scale_x,
    0.0,
    0.0,
    scale_y,
    rect_x - transformed.0 * scale_x,
    rect_y - transformed.1 * scale_y,
  )
  let combined = pdf_matrix_mul(mapping, matrix)
  let old_resources = self.resources
  match pdf_dict_get(dict, b"Resources") {
    Some(value) => self.resources = Some(file.page_deref(Some(value)))
    None => ()
  }
  defer {
    self.resources = old_resources
  }
  let depth = self.stack.length()
  self.save()
  self.object.clip_rect(
    Float::from_double(rect_x),
    Float::from_double(rect_y),
    Float::from_double(rect_width),
    Float::from_double(rect_height),
  )
  self.transform(combined)
  self.run_ops(raw)
  self.finish_text()
  while self.stack.length() > depth + 1 {
    self.restore()
  }
  self.restore()
}
