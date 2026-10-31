///|
// A single simple-font run. Other text modes fail closed until supported.
priv struct PdfLimitedText {
  state : PdfTextState
  mut draw : StringBuilder
  mut actual : StringBuilder
  mut advance : Double
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
fn PdfGraphics::finish_text(self : PdfGraphics) -> Unit raise PdfStreamError {
  let text = self.text
  if text.has_run {
    let font = match self.state.font {
      Some(font) => font
      None => self.default_font
    }
    let old_matrix = self.state.matrix
    let old_emitted = self.emitted.copy()
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
      self.object.text_style(
        0,
        0,
        0,
        Float::from_double(text.state.char_spacing),
      )
      self.emitted.letter_spacing = text.state.char_spacing
    }
    if text.alt {
      self.object.mark(4, text.actual.to_string())
    }
    self.sync_fill()
    self.sync_alpha(false)
    self.object.fill_text(
      text.draw.to_string(),
      0.0F,
      0.0F,
      Float::from_double(text.advance),
    )
    self.object.restore()
    self.state.matrix = old_matrix
    self.emitted = old_emitted
  }
  text.draw = StringBuilder()
  text.actual = StringBuilder()
  text.advance = 0.0
  text.has_run = false
  text.alt = false
  text.state.in_text = false
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
    if text.state.word_spacing != 0.0 ||
      text.state.rendering_mode != 0 ||
      self.state.font_size <= 0.0 {
      raise InvalidStream("unsupported PDF text state")
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
        text.advance += advance
        text.has_run = true
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
              if !text.has_run || number.abs() > 150.0 {
                raise InvalidStream("PDF text adjustment requires a new run")
              }
              let scale = if text.state.horizontal_scale == 0.0 {
                1.0
              } else {
                text.state.horizontal_scale
              }
              let shift = -number / 1000.0 * self.state.font_size * scale
              text.advance += shift / scale
            }
            _ => raise InvalidStream("unsupported PDF text array value")
          }
        }
      _ => raise InvalidStream("invalid PDF text array")
    }
    return true
  }
  if operator == b"Tf" {
    if text.has_run {
      raise InvalidStream(
        "PDF font change within a text run is not supported yet",
      )
    }
    if n >= 2 {
      match args[n - 2] {
        Name(name) =>
          self.select_simple_font(name, pdf_draw_number(args, n - 1))
        _ => ()
      }
    }
    return true
  }
  match operator {
    b"Tc"
    | b"Tw"
    | b"Tz"
    | b"TL"
    | b"Ts"
    | b"Tr"
    | b"Td"
    | b"TD"
    | b"Tm"
    | b"T*" => {
      if text.has_run {
        raise InvalidStream(
          "PDF text positioning within a run is not supported yet",
        )
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
