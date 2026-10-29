///|
/// Paints one strip of a font specimen scroll view.
pub struct SpecimenPagePainter {
  priv object : @core.ObjectBuilder
  priv glyphs : GlyphPainter
  priv ui : SpecimenUIPainter
  priv scroll : ScrollPlan
}

///|
/// Create a page painter with the upstream white background and fixed bounds.
/// All UI text must be measured before its font set is embedded.
pub fn SpecimenPagePainter::new(
  face : FileFace,
  programs : SpecimenFacePrograms,
  texter : SpecimenTexter,
  fonts : SpecimenUIFonts,
  scroll : ScrollPlan,
  height : Double,
  doc_language~ : String = "",
) -> SpecimenPagePainter raise {
  if programs.face_index != face.index {
    raise InvalidFontInput("font: specimen programs do not match the face")
  }
  let object = @core.ObjectBuilder::new()
  object.set_bbox(0.0F, 0.0F, 720.0F, specimen_f32(height))
  let glyphs = face.glyph_painter(
    object,
    embedded=programs.glyph_font,
    sample_font=programs.sample_font,
    doc_language~,
  )
  let ui = SpecimenUIPainter::new(glyphs, texter, fonts)
  glyphs.outlines.set_fill(0xffffffffU)
  object.fill_rect(0.0F, 0.0F, 720.0F, specimen_f32(height))
  { object, glyphs, ui, scroll, }
}

///|
/// Draw a filled rectangle, reusing the current fill when possible.
pub fn SpecimenPagePainter::rect(
  self : SpecimenPagePainter,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  color : UInt32,
) -> Unit {
  self.glyphs.outlines.set_fill(color)
  self.object.fill_rect(
    specimen_f32(x),
    specimen_f32(y),
    specimen_f32(width),
    specimen_f32(height),
  )
}

///|
/// Add a structural or accessibility mark.
pub fn SpecimenPagePainter::mark(
  self : SpecimenPagePainter,
  kind : Byte,
  value : String,
) -> Unit {
  self.object.mark(kind, value)
}

///|
/// Link a rectangle to a named position in this scroll view when it exists.
pub fn SpecimenPagePainter::link_to(
  self : SpecimenPagePainter,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  anchor : String,
) -> Unit {
  match self.scroll.anchor_page(anchor) {
    Some(page) =>
      self.object.link(
        specimen_f32(x),
        specimen_f32(y),
        specimen_f32(width),
        specimen_f32(height),
        "#page=" + page.to_string(),
      )
    None => ()
  }
}

///|
/// Draw a premeasured UI label aligned at x (0 left, 1 center, 2 right).
pub fn SpecimenPagePainter::label(
  self : SpecimenPagePainter,
  line : SpecimenTextLine,
  x : Double,
  y : Double,
  color : UInt32,
  align : Int32,
) -> Double raise {
  self.ui.label(line, x, y, color, align)
}

///|
/// Draw a sample in the specimen face with optional shaping and direction.
pub fn SpecimenPagePainter::sample(
  self : SpecimenPagePainter,
  text : String,
  x : Double,
  y : Double,
  size : Double,
  rtl : Bool,
  lang : String,
) -> Bool raise {
  self.glyphs.sample(text, x, y, size, rtl, lang)
}

///|
/// Draw positioned glyphs in the specimen face.
pub fn SpecimenPagePainter::glyph_run(
  self : SpecimenPagePainter,
  glyphs : Array[Int32],
  offsets : Array[Double],
  x : Double,
  y : Double,
  size : Double,
  alt : String,
) -> Bool raise {
  self.glyphs.draw(glyphs, offsets, x, y, size, alt)
}

///|
/// Encode the completed page's BDF object.
pub fn SpecimenPagePainter::encode(self : SpecimenPagePainter) -> Bytes raise {
  self.object.encode()
}

///|
/// Save the graphics state before clipping a specimen drawing.
pub fn SpecimenPagePainter::save(self : SpecimenPagePainter) -> Unit {
  self.object.save()
}

///|
/// Clip subsequent drawing to a rectangular page region.
pub fn SpecimenPagePainter::clip_rect(
  self : SpecimenPagePainter,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit {
  self.object.clip_rect(
    specimen_f32(x),
    specimen_f32(y),
    specimen_f32(width),
    specimen_f32(height),
  )
}

///|
/// Restore a saved graphics state and invalidate cached font and fill settings.
pub fn SpecimenPagePainter::restore(self : SpecimenPagePainter) -> Unit {
  self.object.restore()
  self.glyphs.reset_state()
}
