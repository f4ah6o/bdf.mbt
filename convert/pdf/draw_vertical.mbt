///|
fn PdfGraphics::show_vertical(
  self : PdfGraphics,
  font : PdfSimpleFont,
  bytes : Bytes,
) -> Unit raise PdfStreamError {
  let text = self.text
  if text.has_run {
    self.flush_text()
  }
  let size = self.state.font_size
  for glyph in font.decode(bytes) {
    let w0 = font.glyph_width(glyph)
    let (w1, vx, vy) = font.glyph_vertical_metrics(glyph)
    let actual = font.glyph_unicode(glyph)
    if text.vertical_glyphs.is_empty() && text.vertical_text.to_string() == "" {
      text.vertical_x = text.state.x
      text.vertical_y = text.state.y
      text.vertical_size = size
    }
    let mut draw = actual
    let mut turn = false
    if draw != "" {
      match pdf_cjk_vertical_form(font.collection, glyph.cid) {
        Some(code) => {
          let out = StringBuilder()
          pdf_text_char(out, code.to_int())
          draw = out.to_string()
        }
        None =>
          match pdf_cjk_unicode(font.collection, glyph.cid) {
            Some((code, true)) => {
              let out = StringBuilder()
              pdf_text_char(out, code.to_int())
              let value = out.to_string()
              if "ー－―‐〜～…‥‖｜＝＿￣（）「」『』【】〔〕［］｛｝〈〉《》".contains(
                  value,
                ) {
                draw = value
                turn = true
              }
            }
            _ => ()
          }
      }
      text.vertical_glyphs.push({
        draw,
        offset: text.vertical_y - text.state.y,
        x: -vx * size,
        y: vy * size,
        advance: w0 * size,
        along: (w1 * size).abs(),
        turn,
      })
    }
    text.vertical_text.write_string(actual)
    let advance = pdf_matrix_fma(w1, size, text.state.char_spacing)
    text.state.y += if glyph.size == 1 && glyph.code == 32L {
      advance + text.state.word_spacing
    } else {
      advance
    }
  }
}

///|
fn PdfGraphics::flush_vertical(self : PdfGraphics) -> Unit raise PdfStreamError {
  let text = self.text
  let actual = text.vertical_text.to_string()
  if text.vertical_glyphs.is_empty() && actual == "" {
    return
  }
  let font = match self.state.font {
    Some(value) => value
    None => self.default_font
  }
  let size = text.vertical_size
  let mode = if size == 0.0 || text.state.rendering_mode == 7 {
    3
  } else {
    text.state.rendering_mode
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
    self.emitted.font_size != size {
    self.object.font(reference, Float::from_double(size)) catch {
      _ => raise InvalidStream("PDF vertical font output failed")
    }
    self.emitted.font_key = self.state.font_key
    self.emitted.font_size = size
  }
  if self.emitted.letter_spacing != 0.0 {
    self.object.text_style(0, 0, 0, 0.0F)
    self.emitted.letter_spacing = 0.0
  }
  if mode == 0 || mode == 4 {
    self.sync_fill()
    self.sync_alpha(false)
  } else if mode == 1 || mode == 5 {
    self.sync_stroke_color()
    self.sync_vertical_line()
    self.sync_alpha(true)
  } else if mode == 2 || mode == 6 {
    self.sync_fill()
    self.sync_stroke_color()
    self.sync_vertical_line()
    self.sync_alpha(false)
  } else if self.emitted.fill != Some(0U) {
    self.object.fill_color(0U)
    self.emitted.fill = Some(0U)
  }
  let baseline = 0.38 * size
  let mut length = 0.0
  for glyph in text.vertical_glyphs {
    length = Double::max(length, glyph.offset + glyph.along)
  }
  let bbox = (
    0.0F,
    Float::from_double(-baseline - size),
    Float::from_double(length),
    Float::from_double(2.0 * size),
  )
  let child = @core.ObjectBuilder::new()
  child.set_bbox(bbox.0, bbox.1, bbox.2, bbox.3)
  let child_font = child.add_font({
    hash: None,
    family: font.family,
    weight: font.weight,
    style: font.style,
  })
  child.font(child_font, Float::from_double(size)) catch {
    _ => raise InvalidStream("PDF vertical child font output failed")
  }
  for glyph in text.vertical_glyphs {
    child.save()
    if glyph.turn {
      child.translate(Float::from_double(glyph.offset), 0.0F)
      pdf_vertical_text(
        child,
        mode,
        glyph.draw,
        0.0F,
        0.0F,
        Float::from_double(glyph.along),
      )
    } else {
      child.transform(
        0.0F,
        -1.0F,
        1.0F,
        0.0F,
        Float::from_double(glyph.offset),
        Float::from_double(-baseline),
      )
      pdf_vertical_text(
        child,
        mode,
        glyph.draw,
        Float::from_double(glyph.x),
        Float::from_double(glyph.y),
        Float::from_double(glyph.advance),
      )
    }
    child.restore()
  }
  let encoded = child.encode() catch {
    _ => raise InvalidStream("PDF vertical child encoding failed")
  }
  let hash = self.child_writer.add_part("obj", encoded) catch {
    _ => raise InvalidStream("PDF vertical child hash failed")
  }
  self.children.push(encoded)
  let index = self.object.add_object(hash, bbox)
  self.object.save()
  self.object.transform(
    0.0F,
    1.0F,
    -1.0F,
    0.0F,
    Float::from_double(text.vertical_x),
    Float::from_double(-text.vertical_y),
  )
  self.object.mark(4, actual)
  self.object.use_object_at(index, 0.0F, Float::from_double(baseline)) catch {
    _ => raise InvalidStream("PDF vertical child placement failed")
  }
  self.object.restore()
  text.vertical_glyphs.clear()
  text.vertical_text = StringBuilder()
}

///|
fn PdfGraphics::sync_vertical_line(self : PdfGraphics) -> Unit {
  let text = self.text
  let mut scale = pdf_matrix_scale(text.state.base) *
    text.state.horizontal_scale.abs().sqrt()
  if scale < 0.000000001 {
    scale = 1.0
  }
  self.sync_line_scaled(1.0 / scale)
}

///|
fn pdf_vertical_text(
  child : @core.ObjectBuilder,
  mode : Int32,
  text : String,
  x : Float,
  y : Float,
  advance : Float,
) -> Unit {
  match mode {
    1 | 5 => child.stroke_text(text, x, y, advance)
    2 | 6 => {
      child.fill_text(text, x, y, advance)
      child.stroke_text(text, x, y, advance)
    }
    _ => child.fill_text(text, x, y, advance)
  }
}
