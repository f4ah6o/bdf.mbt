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
    match file.page_deref(pdf_dict_get(dict, b"Subtype")) {
      PdfName(b"Link") => ()
      _ => continue
    }
    let flags = match file.page_num(pdf_dict_get(dict, b"F")) {
      Some(number) => number.to_int()
      None => 0
    }
    if (flags & 2) != 0 || (flags & 32) != 0 {
      continue
    }
    let url = self.link_target(file, dict)
    if url == "" {
      continue
    }
    match pdf_annotation_rect(file, dict) {
      Some((x, y, width, height)) =>
        self.object.link(
          Float::from_double(x),
          Float::from_double(y),
          Float::from_double(width),
          Float::from_double(height),
          url,
        )
      None => ()
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
