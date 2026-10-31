///|
fn pdf_blend_mode(name : Bytes) -> Byte {
  match name {
    b"Multiply" => 1
    b"Screen" => 2
    b"Overlay" => 3
    b"Darken" => 4
    b"Lighten" => 5
    b"ColorDodge" => 6
    b"ColorBurn" => 7
    b"HardLight" => 8
    b"SoftLight" => 9
    b"Difference" => 10
    b"Exclusion" => 11
    b"Hue" => 12
    b"Saturation" => 13
    b"Color" => 14
    b"Luminosity" => 15
    _ => 0
  }
}

///|
fn PdfGraphics::apply_ext_state(
  self : PdfGraphics,
  name : Bytes,
) -> Unit raise PdfStreamError {
  let file = match self.file {
    Some(value) => value
    None => return
  }
  let resources = match self.resources {
    Some(value) => value
    None => return
  }
  let entries = file.page_deref(pdf_dict_get(resources, b"ExtGState"))
  let state = file.page_deref(pdf_dict_get(entries, name))
  if !(state is PdfDict(_)) {
    return
  }
  match pdf_dict_get(state, b"SMask") {
    Some(value) =>
      match file.page_deref(Some(value)) {
        PdfNull | PdfName(b"None") => ()
        _ => raise InvalidStream("unsupported PDF soft mask")
      }
    None => ()
  }
  match pdf_dict_get(state, b"LW") {
    Some(value) =>
      match file.page_num(Some(value)) {
        Some(n) => self.state.width = n
        None => ()
      }
    None => ()
  }
  match pdf_dict_get(state, b"LC") {
    Some(value) =>
      self.state.cap = (match file.page_num(Some(value)) {
        Some(n) => n.to_int()
        None => 0
      }).to_byte()
    None => ()
  }
  match pdf_dict_get(state, b"LJ") {
    Some(value) =>
      self.state.join = (match file.page_num(Some(value)) {
        Some(n) => n.to_int()
        None => 0
      }).to_byte()
    None => ()
  }
  match pdf_dict_get(state, b"ML") {
    Some(value) =>
      self.state.miter = match file.page_num(Some(value)) {
        Some(n) => n
        None => 10.0
      }
    None => ()
  }
  match pdf_dict_get(state, b"CA") {
    Some(value) =>
      self.state.stroke_alpha = Double::min(
        1.0,
        Double::max(
          0.0,
          match file.page_num(Some(value)) {
            Some(n) => n
            None => 1.0
          },
        ),
      )
    None => ()
  }
  match pdf_dict_get(state, b"ca") {
    Some(value) =>
      self.state.fill_alpha = Double::min(
        1.0,
        Double::max(
          0.0,
          match file.page_num(Some(value)) {
            Some(n) => n
            None => 1.0
          },
        ),
      )
    None => ()
  }
  match pdf_dict_get(state, b"BM") {
    Some(value) => {
      let value = file.page_deref(Some(value))
      let value = match value {
        PdfArray(values) if !values.is_empty() =>
          file.page_deref(Some(values[0]))
        _ => value
      }
      self.state.blend = match value {
        PdfName(name) => pdf_blend_mode(name)
        _ => 0
      }
    }
    None => ()
  }
  match pdf_dict_get(state, b"D") {
    Some(value) =>
      match file.page_deref(Some(value)) {
        PdfArray(values) if values.length() == 2 => {
          self.state.dash = match file.page_deref(Some(values[0])) {
            PdfArray(segments) =>
              segments.map(fn(value) {
                match file.page_num(Some(value)) {
                  Some(n) => n
                  None => 0.0
                }
              })
            _ => []
          }
          self.state.phase = match file.page_num(Some(values[1])) {
            Some(n) => n
            None => 0.0
          }
        }
        _ => ()
      }
    None => ()
  }
}
