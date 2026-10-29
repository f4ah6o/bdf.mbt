///|
/// Draw specimen glyphs using a glyph font when available, with an outline fallback.
pub struct GlyphPainter {
  priv face : FileFace
  priv object : @core.ObjectBuilder
  priv outlines : OutlinePainter
  priv embedded : @core.Font?
  priv mut font_ref : Int32?
  priv mut font_size : Float?
}

///|
/// Prepare a painter for a font face and object. Pass a glyph-mapped embedded
/// font record when embedding is permitted; None draws all glyphs as paths.
pub fn FileFace::glyph_painter(
  self : FileFace,
  object : @core.ObjectBuilder,
  embedded~ : @core.Font? = None,
) -> GlyphPainter {
  {
    face: self,
    object,
    outlines: self.outline_painter(object),
    embedded,
    font_ref: None,
    font_size: None,
  }
}

///|
/// Invalidate cached drawing state after external object state changes.
pub fn GlyphPainter::reset_state(self : GlyphPainter) -> Unit {
  self.outlines.reset_fill()
  self.font_size = None
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
      let ref = self.object.add_font(self.embedded.unwrap())
      self.font_ref = Some(ref)
      ref
    }
  }
  let font_size = Float::from_double(size)
  if self.font_size != Some(font_size) {
    self.object.font(ref, font_size)
    self.font_size = Some(font_size)
  }
  self.object.fill_text(
    text.to_string(),
    Float::from_double(x),
    Float::from_double(y),
    Float::from_double(advance * size),
  )
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
