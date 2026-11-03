///|
fn PdfFile::type3_glyph_stream(
  self : PdfFile,
  font : PdfSimpleFont,
  code : Int32,
) -> (PdfObject, Bytes)? raise PdfStreamError {
  let name = font.encoding.name(code)
  if name == "" {
    return None
  }
  let char_procs = self.page_deref(Some(font.char_procs))
  let glyph = match pdf_dict_get(char_procs, @utf8.encode(name)) {
    Some(value) => value
    None => return None
  }
  let loaded = match glyph {
    PdfRef(number, _) => self.load(number, 0)
    _ => return None
  }
  let raw = match loaded.stream {
    Some(value) => value
    None => return None
  }
  match pdf_decode_stream(
    raw,
    self.resolved_stream_filters(loaded.value),
    268435456L,
    false,
    268435456L,
  ) {
    (data, None) => Some((loaded.value, data))
    _ => None
  }
}

///|
fn PdfGraphics::type3_glyph_form(
  self : PdfGraphics,
  font : PdfSimpleFont,
  matrix : (Double, Double, Double, Double, Double, Double),
) -> PdfObject {
  let (x0, y0, x1, y1) = font.font_bbox
  let entries : Array[(Bytes, PdfObject)] = [
    (b"Type", PdfName(b"XObject")),
    (b"Subtype", PdfName(b"Form")),
    (
      b"BBox",
      PdfArray([
        PdfReal(x0),
        PdfReal(y0),
        PdfReal(x1),
        PdfReal(y1),
      ]),
    ),
    (
      b"Matrix",
      PdfArray([
        PdfReal(matrix.0),
        PdfReal(matrix.1),
        PdfReal(matrix.2),
        PdfReal(matrix.3),
        PdfReal(matrix.4),
        PdfReal(matrix.5),
      ]),
    ),
  ]
  match font.font_resources {
    PdfDict(_) => entries.push((b"Resources", font.font_resources))
    _ => ()
  }
  PdfDict(entries)
}

///|
fn PdfGraphics::show_type3(
  self : PdfGraphics,
  font : PdfSimpleFont,
  bytes : Bytes,
) -> Unit raise PdfStreamError {
  let file = match self.file {
    Some(value) => value
    None => raise InvalidStream("PDF Type3 glyph file is missing")
  }
  self.flush_text()
  let text = self.text
  let scale = if text.state.horizontal_scale == 0.0 {
    1.0
  } else {
    text.state.horizontal_scale
  }
  for glyph in font.decode(bytes) {
    let code = glyph.code.to_int()
    let mode = text.state.rendering_mode
    if mode != 3 && mode != 7 {
      match file.type3_glyph_stream(font, code) {
        Some((_, raw)) => {
          let text_size = (
            self.state.font_size * scale,
            0.0,
            0.0,
            self.state.font_size,
            0.0,
            text.state.rise,
          )
          let translate = (1.0, 0.0, 0.0, 1.0, text.state.x, text.state.y)
          let matrix = pdf_matrix_mul(
            font.font_matrix,
            pdf_matrix_mul(
              text_size,
              pdf_matrix_mul(translate, text.state.matrix),
            ),
          )
          let saved_in_text = text.state.in_text
          let saved_matrix = text.state.matrix
          let saved_line_matrix = text.state.line_matrix
          let saved_base = text.state.base
          let saved_x = text.state.x
          let saved_y = text.state.y
          let saved_char_spacing = text.state.char_spacing
          let saved_word_spacing = text.state.word_spacing
          let saved_horizontal_scale = text.state.horizontal_scale
          let saved_leading = text.state.leading
          let saved_rise = text.state.rise
          let saved_rendering_mode = text.state.rendering_mode
          let form = self.type3_glyph_form(font, matrix)
          text.state.in_text = false
          self.draw_form_xobject(file, form, raw)
          text.state.in_text = saved_in_text
          text.state.matrix = saved_matrix
          text.state.line_matrix = saved_line_matrix
          text.state.base = saved_base
          text.state.x = saved_x
          text.state.y = saved_y
          text.state.char_spacing = saved_char_spacing
          text.state.word_spacing = saved_word_spacing
          text.state.horizontal_scale = saved_horizontal_scale
          text.state.leading = saved_leading
          text.state.rise = saved_rise
          text.state.rendering_mode = saved_rendering_mode
        }
        None => ()
      }
    }
    let width = font.glyph_width(glyph)
    let mut advance = if text.state.char_spacing == 0.0 {
      width * self.state.font_size + text.state.char_spacing
    } else {
      pdf_matrix_fma(width, self.state.font_size, text.state.char_spacing)
    }
    if glyph.size == 1 && glyph.code == 32L && text.state.word_spacing != 0.0 {
      advance += text.state.word_spacing
    }
    text.state.x = pdf_matrix_fma(advance, scale, text.state.x)
  }
}
