///|
/// Draw specimen glyphs using a glyph font when available, with an outline fallback.
pub struct GlyphPainter {
  priv face : FileFace
  priv object : @core.ObjectBuilder
  priv outlines : OutlinePainter
  priv embedded : @core.Font?
  priv sample_font : @core.Font?
  priv doc_language : String
  priv mut language : String
  priv mut font_ref : Int32?
  priv mut sample_ref : Int32?
  priv mut active_ref : Int32?
  priv mut font_size : Float?
}

///|
/// Prepare a painter for a font face and object. Pass a glyph-mapped embedded
/// font record when embedding is permitted; None draws all glyphs as paths.
pub fn FileFace::glyph_painter(
  self : FileFace,
  object : @core.ObjectBuilder,
  embedded~ : @core.Font? = None,
  sample_font~ : @core.Font? = None,
  doc_language~ : String = "",
) -> GlyphPainter {
  {
    face: self,
    object,
    outlines: self.outline_painter(object),
    embedded,
    sample_font,
    doc_language,
    language: "",
    font_ref: None,
    sample_ref: None,
    active_ref: None,
    font_size: None,
  }
}

///|
/// Invalidate cached drawing state after external object state changes.
pub fn GlyphPainter::reset_state(self : GlyphPainter) -> Unit {
  self.outlines.reset_fill()
  self.font_size = None
  self.active_ref = None
}

///|
fn GlyphPainter::text_run(
  self : GlyphPainter,
  glyphs : Array[Int32],
  x : Double,
  y : Double,
  size : Double,
  alt : String,
  advance : Double,
) -> Unit raise {
  let text = StringBuilder()
  for glyph in glyphs {
    let code = if glyph < 65534 {
      0xf0000 + glyph
    } else {
      0x100000 + glyph - 65534
    }
    text.write_char(code.unsafe_to_char())
  }
  self.object.mark(4, alt)
  let ref = match self.font_ref {
    Some(ref) => ref
    None => {
      let font = self.embedded.unwrap()
      let ref = match (self.sample_font, self.sample_ref) {
        (Some(sample), Some(existing)) if specimen_fonts_equal(sample, font) =>
          existing
        _ => self.object.add_font(font)
      }
      self.font_ref = Some(ref)
      ref
    }
  }
  self.set_font(ref, size)
  self.object.fill_text(
    text.to_string(),
    specimen_f32(x),
    specimen_f32(y),
    specimen_f32(advance * size),
  )
}

///|
fn GlyphPainter::set_font(
  self : GlyphPainter,
  ref : Int32,
  size : Double,
) -> Unit raise {
  let value = specimen_f32(size)
  if self.active_ref != Some(ref) || self.font_size != Some(value) {
    self.object.font(ref, value)
    self.active_ref = Some(ref)
    self.font_size = Some(value)
  }
}

///|
fn specimen_fonts_equal(a : @core.Font, b : @core.Font) -> Bool {
  a.hash == b.hash &&
  a.family == b.family &&
  a.weight == b.weight &&
  a.style == b.style
}

///|
fn GlyphPainter::sample_font_ref(self : GlyphPainter) -> Int32 {
  match self.sample_ref {
    Some(ref) => ref
    None => {
      let font = self.sample_font.unwrap()
      let ref = match (self.embedded, self.font_ref) {
        (Some(glyph_font), Some(existing)) if specimen_fonts_equal(
            glyph_font, font,
          ) => existing
        _ => self.object.add_font(font)
      }
      self.sample_ref = Some(ref)
      ref
    }
  }
}

///|
fn GlyphPainter::set_language(self : GlyphPainter, value : String) -> Unit {
  let mut lang = font_trim(value)
  if specimen_equal_fold(lang, "x-none") {
    lang = ""
  }
  let doc = @utf8.encode(self.doc_language)
  let n = @utf8.encode(lang).length()
  if specimen_equal_fold(lang, self.doc_language) ||
    (
      n > 0 &&
      !lang.contains("-") &&
      doc.length() > n &&
      doc[n] == b'-' &&
      specimen_equal_fold(lang, @utf8.decode_lossy(doc[:n]))
    ) {
    lang = ""
  }

  if lang != self.language {
    self.object.mark(12, lang)
    self.language = lang
  }
}

///|
/// Draw browser-shaped sample text when a sample font is available; otherwise
/// lay out the mapped glyphs individually, including right-to-left positioning.
pub fn GlyphPainter::sample(
  self : GlyphPainter,
  text : String,
  x : Double,
  y : Double,
  size : Double,
  rtl : Bool,
  lang : String,
) -> Bool raise {
  self.set_language(lang)
  let result = match self.sample_font {
    Some(_) => {
      self.outlines.ensure_fill()
      self.set_font(self.sample_font_ref(), size)
      if rtl {
        self.object.text_style(1, 0, 2, 0.0F)
      }
      self.object.fill_text(text, specimen_f32(x), specimen_f32(y), 0.0F)
      if rtl {
        self.object.text_style(0, 0, 0, 0.0F)
      }
      true
    }
    None => {
      let glyphs : Array[Int32] = []
      let offsets : Array[Double] = []
      let mut width = 0.0
      for c in text {
        let glyph = match self.face.font.glyph(c.to_int()) {
          Some(g) if g < self.face.font.metrics.glyph_count => g
          _ => 0
        }
        glyphs.push(glyph)
        offsets.push(width)
        width += self.face.font.advance(glyph)
      }
      if rtl {
        for i, glyph in glyphs {
          offsets[i] = width - offsets[i] - self.face.font.advance(glyph)
        }
      }
      self.draw(
        glyphs,
        offsets,
        if rtl {
          x - width * size
        } else {
          x
        },
        y,
        size,
        text,
      )
    }
  }
  self.set_language("")
  result
}

///|
/// Draw glyphs at their em offsets. Contiguous advances use a single embedded
/// text run; other positions use separate glyphs. A run containing glyph zero
/// is drawn as outlines, as in the upstream specimen converter.
pub fn GlyphPainter::draw(
  self : GlyphPainter,
  glyphs : Array[Int32],
  offsets : Array[Double],
  x : Double,
  y : Double,
  size : Double,
  alt : String,
) -> Bool raise {
  if glyphs.length() != offsets.length() {
    raise InvalidFontInput("font: glyph and offset counts differ")
  }
  if glyphs.length() == 0 {
    return false
  }
  let mut outline = self.embedded is None
  for glyph in glyphs {
    if glyph == 0 {
      outline = true
    }
  }
  if outline {
    return self.outlines.draw(glyphs, offsets, x, y, size, alt)
  }
  for glyph in glyphs {
    if glyph < 0 || glyph >= self.face.font.metrics.glyph_count || glyph > 65535 {
      raise InvalidFontInput("font: glyph index out of range")
    }
  }
  self.outlines.ensure_fill()
  let mut advance = 0.0
  let mut consecutive = true
  for i, glyph in glyphs {
    if (offsets[i] - advance).abs() > 0.000001 {
      consecutive = false
    }
    advance += self.face.font.advance(glyph)
  }
  if consecutive {
    self.text_run(glyphs, x, y, size, alt, advance)
    return true
  }
  let mut first = true
  for i, glyph in glyphs {
    self.text_run(
      [glyph],
      x + offsets[i] * size,
      y,
      size,
      if first {
        alt
      } else {
        ""
      },
      self.face.font.advance(glyph),
    )
    first = false
  }
  true
}
