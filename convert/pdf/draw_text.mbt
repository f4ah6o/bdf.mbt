///|
// Text block and accumulated simple-font run.
priv struct PdfLimitedText {
  state : PdfTextState
  mut draw : StringBuilder
  mut actual : StringBuilder
  mut advance : Double
  mut run_start : Double
  mut open : Bool
  mut open_base : (Double, Double, Double, Double, Double, Double)
  mut open_scale : Double
  mut open_rise : Double
  mut saved_matrix : (Double, Double, Double, Double, Double, Double)
  mut saved_emitted : PdfEmittedState?
  mut has_run : Bool
  mut alt : Bool
}

///|
fn PdfLimitedText::new() -> PdfLimitedText {
  {
    state: PdfTextState::new(),
    draw: StringBuilder(),
    actual: StringBuilder(),
    advance: 0.0,
    run_start: 0.0,
    open: false,
    open_base: (0.0, 0.0, 0.0, 0.0, 0.0, 0.0),
    open_scale: 1.0,
    open_rise: 0.0,
    saved_matrix: (0.0, 0.0, 0.0, 0.0, 0.0, 0.0),
    saved_emitted: None,
    has_run: false,
    alt: false,
  }
}

///|
fn pdf_default_simple_font() -> PdfSimpleFont {
  {
    encoding: { base: pdf_standard_encoding, differences: Map([]), },
    to_unicode: None,
    first: 0,
    widths: [],
    missing_width: 0.0,
    family: "sans-serif",
    weight: 400,
    style: 0,
    used_nul: false,
  }
}

///|
fn PdfFile::default_simple_font(self : PdfFile) -> PdfSimpleFont {
  match self.default_font {
    Some(font) => font
    None => {
      let font = pdf_default_simple_font()
      self.default_font = Some(font)
      font
    }
  }
}

///|
fn PdfGraphics::select_simple_font(
  self : PdfGraphics,
  name : Bytes,
  size : Double,
) -> Unit raise PdfStreamError {
  let (font, key) = match self.file {
    Some(file) => {
      let resources = file.page_deref(self.resources)
      let fonts = file.page_deref(pdf_dict_get(resources, b"Font"))
      match pdf_dict_get(fonts, name) {
        Some(PdfRef(number, generation)) =>
          match self.fonts.get((number, generation)) {
            Some(cached) => cached
            None => {
              let font = file.simple_font(PdfRef(number, generation))
              let key = self.next_font_key
              self.next_font_key += 1
              self.fonts[(number, generation)] = (font, key)
              (font, key)
            }
          }
        Some(object) => {
          let font = file.simple_font(object)
          let key = self.next_font_key
          self.next_font_key += 1
          (font, key)
        }
        None => (self.default_font, 0)
      }
    }
    None => (self.default_font, 0)
  }
  self.state.font = Some(font)
  self.state.font_key = key
  self.state.font_size = size
}

///|
fn PdfGraphics::close_text_block(self : PdfGraphics) -> Unit {
  let text = self.text
  if text.open {
    self.object.restore()
    self.state.matrix = text.saved_matrix
    match text.saved_emitted {
      Some(emitted) => self.emitted = emitted
      None => ()
    }
    text.open = false
    text.saved_emitted = None
  }
}

///|
fn PdfGraphics::open_text_block(self : PdfGraphics) -> Unit {
  let text = self.text
  if text.open &&
    text.open_base == text.state.base &&
    text.open_scale == text.state.horizontal_scale &&
    text.open_rise == text.state.rise {
    return
  }
  self.close_text_block()
  text.saved_matrix = self.state.matrix
  text.saved_emitted = Some(self.emitted.copy())
  self.object.save()
  if text.state.base != (1.0, 0.0, 0.0, 1.0, 0.0, 0.0) {
    self.transform(text.state.base)
  }
  if text.state.horizontal_scale != 1.0 || text.state.rise != 0.0 {
    self.transform(
      (text.state.horizontal_scale, 0.0, 0.0, 1.0, 0.0, text.state.rise),
    )
  }
  self.transform((1.0, 0.0, 0.0, -1.0, 0.0, 0.0))
  text.open = true
  text.open_base = text.state.base
  text.open_scale = text.state.horizontal_scale
  text.open_rise = text.state.rise
}

///|
fn PdfGraphics::flush_text(self : PdfGraphics) -> Unit raise PdfStreamError {
  let text = self.text
  if !text.has_run {
    return
  }
  let font = match self.state.font {
    Some(font) => font
    None => self.default_font
  }
  self.open_text_block()
  let reference = match self.font_refs.get(self.state.font_key) {
    Some(value) => value
    None => {
      let value = self.object.add_font({
        hash: None,
        family: font.family,
        weight: font.weight,
        style: font.style,
      })
      self.font_refs[self.state.font_key] = value
      value
    }
  }
  if self.emitted.font_key != self.state.font_key ||
    self.emitted.font_size != self.state.font_size {
    self.object.font(reference, Float::from_double(self.state.font_size)) catch {
      _ => raise InvalidStream("PDF font output failed")
    }
    self.emitted.font_key = self.state.font_key
    self.emitted.font_size = self.state.font_size
  }
  if self.emitted.letter_spacing != text.state.char_spacing {
    self.object.text_style(0, 0, 0, Float::from_double(text.state.char_spacing))
    self.emitted.letter_spacing = text.state.char_spacing
  }
  if text.alt {
    self.object.mark(4, text.actual.to_string())
  }
  let mode = if self.state.font_size == 0.0 || text.state.rendering_mode == 7 {
    3
  } else {
    text.state.rendering_mode
  }
  let draw = text.draw.to_string()
  let x = Float::from_double(text.run_start)
  let advance = Float::from_double(text.advance)
  if mode == 0 || mode == 4 || mode == 2 || mode == 6 {
    self.sync_fill()
    self.sync_alpha(false)
    self.object.fill_text(draw, x, 0.0F, advance)
  }
  if mode == 1 || mode == 5 || mode == 2 || mode == 6 {
    self.sync_stroke_color()
    let mut scale = pdf_matrix_scale(text.state.base) *
      text.state.horizontal_scale.abs().sqrt()
    if scale < 0.000000001 {
      scale = 1.0
    }
    self.sync_line_scaled(1.0 / scale)
    self.sync_alpha(true)
    self.object.stroke_text(draw, x, 0.0F, advance)
  }
  if mode != 0 && mode != 1 && mode != 2 && mode != 4 && mode != 5 && mode != 6 {
    if self.emitted.fill != Some(0U) {
      self.object.fill_color(0U)
      self.emitted.fill = Some(0U)
    }
    self.object.fill_text(draw, x, 0.0F, advance)
  }
  text.draw = StringBuilder()
  text.actual = StringBuilder()
  text.advance = 0.0
  text.has_run = false
  text.alt = false
}

///|
fn PdfGraphics::finish_text(self : PdfGraphics) -> Unit raise PdfStreamError {
  self.flush_text()
  self.close_text_block()
  self.text.state.in_text = false
}

///|
fn PdfGraphics::text_operator(
  self : PdfGraphics,
  operator : Bytes,
  args : Array[ContentValue],
) -> Bool raise PdfStreamError {
  let text = self.text
  let n = args.length()
  if operator == b"BT" {
    self.finish_text()
    ignore(text.state.execute(operator, args))
    return true
  }
  if operator == b"ET" {
    self.finish_text()
    return true
  }
  if operator == b"Tj" {
    if !text.state.in_text {
      ignore(text.state.execute(b"BT", []))
    }
    let font = match self.state.font {
      Some(font) => font
      None => {
        let fallback = self.default_font
        self.state.font = Some(fallback)
        fallback
      }
    }
    if n > 0 {
      let bytes = match args[n - 1] {
        Literal(value) => value
        Hex(value) => pdf_text_hex(value)
        _ => b""
      }
      for byte in bytes {
        let word_space = byte == b' ' && text.state.word_spacing != 0.0
        if word_space {
          self.flush_text()
        }
        if !text.has_run {
          let scale = if text.state.horizontal_scale == 0.0 {
            1.0
          } else {
            text.state.horizontal_scale
          }
          text.run_start = text.state.x / scale
        }
        let code = byte.to_int()
        let actual = font.unicode(code)
        if actual == "" {
          if code != 0 || !font.used_nul {
            pdf_text_char(text.draw, code)
            text.alt = true
          }
          if code == 0 {
            font.used_nul = true
          }
        } else {
          text.draw.write_string(actual)
        }
        text.actual.write_string(actual)
        let width = font.width(code)
        let advance = if text.state.char_spacing == 0.0 {
          width * self.state.font_size + text.state.char_spacing
        } else {
          pdf_matrix_fma(width, self.state.font_size, text.state.char_spacing)
        }
        let advance = if word_space {
          advance + text.state.word_spacing
        } else {
          advance
        }
        text.advance += advance
        let scale = if text.state.horizontal_scale == 0.0 {
          1.0
        } else {
          text.state.horizontal_scale
        }
        text.state.x = pdf_matrix_fma(advance, scale, text.state.x)
        text.has_run = true
        if word_space {
          self.flush_text()
        }
      }
    }
    return true
  }
  if operator == b"TJ" {
    if n < 1 {
      return true
    }
    match args[n - 1] {
      ArrayValue(values) =>
        for value in values {
          match value {
            Literal(_) | Hex(_) => ignore(self.text_operator(b"Tj", [value]))
            Integer(_) | Real(_) => {
              let number = pdf_draw_number([value], 0)
              let scale = if text.state.horizontal_scale == 0.0 {
                1.0
              } else {
                text.state.horizontal_scale
              }
              let shift = -number / 1000.0 * self.state.font_size * scale
              if text.has_run && number.abs() <= 150.0 {
                text.advance += shift / scale
              } else {
                self.flush_text()
              }
              text.state.x += shift
            }
            _ => raise InvalidStream("unsupported PDF text array value")
          }
        }
      _ => raise InvalidStream("invalid PDF text array")
    }
    return true
  }
  if operator == b"Td" ||
    operator == b"TD" ||
    operator == b"Tm" ||
    operator == b"T*" {
    if (operator == b"Td" || operator == b"TD") && n < 2 {
      return true
    }
    if operator == b"Tm" && n < 6 {
      return true
    }
    if !text.has_run {
      ignore(text.state.execute(operator, args))
      return true
    }
    let next = PdfTextState::new()
    next.line_matrix = text.state.line_matrix
    next.leading = text.state.leading
    ignore(next.execute(operator, args))
    let (a, b, c, d, e, f) = text.state.base
    let (na, nb, nc, nd, ne, nf) = next.base
    let mut merged = false
    if a == na && b == nb && c == nc && d == nd {
      let dxv = ne - e
      let dyv = nf - f
      let length = pdf_matrix_fma(a, a, b * b)
      if length > 0.0 {
        let dx = pdf_matrix_fma(dxv, a, dyv * b) / length
        let rx = pdf_matrix_fma(-dx, a, dxv)
        let ry = pdf_matrix_fma(-dx, b, dyv)
        let size = if self.state.font_size <= 0.0 {
          1.0
        } else {
          self.state.font_size
        }
        if pdf_matrix_fma(rx, rx, ry * ry) < 0.000001 * size * size &&
          (dx - text.state.x).abs() <= 0.25 * size {
          let scale = if text.state.horizontal_scale == 0.0 {
            1.0
          } else {
            text.state.horizontal_scale
          }
          text.advance += (dx - text.state.x) / scale
          text.state.x = dx
          text.state.matrix = next.base
          text.state.line_matrix = next.base
          text.state.leading = next.leading
          merged = true
        }
      }
    }
    if !merged {
      self.flush_text()
      text.state.leading = next.leading
      text.state.set_line(next.base)
    }
    return true
  }
  if operator == b"Tf" {
    self.flush_text()
    if n >= 2 {
      match args[n - 2] {
        Name(name) =>
          self.select_simple_font(name, pdf_draw_number(args, n - 1))
        _ => self.select_simple_font(b"", pdf_draw_number(args, n - 1))
      }
    }
    return true
  }
  match operator {
    b"Tc" | b"Tw" | b"Tz" | b"TL" | b"Ts" | b"Tr" => {
      if operator != b"TL" {
        self.flush_text()
      }
      ignore(text.state.execute(operator, args))
      true
    }
    _ => false
  }
}

///|
fn pdf_text_hex(value : Bytes) -> Bytes raise PdfStreamError {
  let out : Array[Byte] = []
  let mut high = -1
  for byte in value {
    let digit = content_hex_digit(byte)
    if digit < 0 {
      raise InvalidStream("invalid PDF hexadecimal string")
    }
    if high < 0 {
      high = digit
    } else {
      out.push((high * 16 + digit).to_byte())
      high = -1
    }
  }
  if high >= 0 {
    out.push((high * 16).to_byte())
  }
  Bytes::from_array(out)
}
