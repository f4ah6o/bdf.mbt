///|
fn pdf_oc_refs(file : PdfFile, object : PdfObject?) -> Array[Int64] {
  match object {
    Some(PdfRef(number, _)) => [number]
    Some(value) =>
      match file.page_deref(Some(value)) {
        PdfArray(values) => {
          let out : Array[Int64] = []
          for value in values {
            match value {
              PdfRef(number, _) => out.push(number)
              _ => ()
            }
          }
          out
        }
        _ => []
      }
    None => []
  }
}

///|
// Default optional-content visibility from /OCProperties. A missing default
// configuration leaves every layer visible.
fn pdf_optional_content(file : PdfFile) -> Map[Int64, Bool] {
  let result : Map[Int64, Bool] = {}
  let catalog = file.page_deref(file.trailer_entry(b"Root"))
  let properties = file.page_deref(pdf_dict_get(catalog, b"OCProperties"))
  let config = match file.page_deref(pdf_dict_get(properties, b"D")) {
    PdfDict(_) => Some(file.page_deref(pdf_dict_get(properties, b"D")))
    _ => None
  }
  let base = match config {
    Some(dict) =>
      match file.page_deref(pdf_dict_get(dict, b"BaseState")) {
        PdfName(b"OFF") => false
        _ => true
      }
    None => true
  }
  for number in pdf_oc_refs(file, pdf_dict_get(properties, b"OCGs")) {
    result[number] = base
  }
  match config {
    Some(dict) => {
      for number in pdf_oc_refs(file, pdf_dict_get(dict, b"OFF")) {
        result[number] = false
      }
      for number in pdf_oc_refs(file, pdf_dict_get(dict, b"ON")) {
        result[number] = true
      }
    }
    None => ()
  }
  result
}

///|
fn pdf_oc_visible(
  file : PdfFile,
  visibility : Map[Int64, Bool],
  object : PdfObject,
) -> Bool {
  match object {
    PdfRef(number, _) => visibility.get(number).unwrap_or(true)
    PdfArray(values) => {
      for value in values {
        if !pdf_oc_visible(file, visibility, value) {
          return false
        }
      }
      true
    }
    _ =>
      match file.page_deref(Some(object)) {
        PdfArray(values) => {
          for value in values {
            if !pdf_oc_visible(file, visibility, value) {
              return false
            }
          }
          true
        }
        _ => true
      }
  }
}

///|
fn PdfGraphics::property_visible(
  self : PdfGraphics,
  value : ContentValue,
) -> Bool {
  let file = match self.file {
    Some(value) => value
    None => return true
  }
  let resources = match self.resources {
    Some(value) => value
    None => return true
  }
  let raw = match value {
    Name(name) => {
      let table = file.page_deref(pdf_dict_get(resources, b"Properties"))
      match pdf_dict_get(table, name) {
        Some(object) => object
        None => return true
      }
    }
    _ => return true
  }
  let property = file.page_deref(Some(raw))
  let oc = match pdf_dict_get(property, b"OC") {
    Some(value) => value
    None =>
      match pdf_dict_get(property, b"Type") {
        Some(PdfName(b"OCG")) => raw
        _ => return true
      }
  }
  pdf_oc_visible(file, self.optional_content, oc)
}
