///|
fn DrawTile::set_language(self : DrawTile, lang : String) -> Unit {
  if self.lang != lang {
    self.object.mark(12, lang)
    self.lang = lang
  }
}

///|
fn DrawTile::set_font(
  self : DrawTile,
  family : String,
  bold : Bool,
) -> Unit raise {
  let weight = if bold { 700 } else { 400 }
  let index = match self.fonts.get(weight) {
    Some(index) => index
    None => {
      let index = self.object.add_font({ hash: None, family, weight, style: 0, })
      self.fonts[weight] = index
      index
    }
  }
  if !self.has_font || self.current_font != index {
    self.object.font(index, 11.0F)
    self.current_font = index
    self.has_font = true
  }
}

///|
fn DrawTile::fill_color(self : DrawTile, color : UInt32) -> Unit {
  if !self.has_color || self.current_color != color {
    self.object.fill_color(color)
    self.current_color = color
    self.has_color = true
  }
}

///|
fn DrawTile::text_run(
  self : DrawTile,
  text : String,
  x : Double,
  y : Double,
  width : Double,
  family : String,
  bold : Bool,
  color : UInt32,
) -> Unit raise {
  self.set_font(family, bold)
  self.fill_color(color)
  self.object.fill_text(
    text,
    Float::from_double(x - self.x.to_double() * 2048.0),
    Float::from_double(y - self.y.to_double() * 2048.0),
    Float::from_double(width),
  )
  self.drawn = true
}

///|
fn DrawTile::emit_line(
  self : DrawTile,
  line : DrawLine,
  family : String,
  bold : Bool,
  color : UInt32,
) -> Unit raise {
  let mut chars = StringBuilder()
  let mut has_chars = false
  let mut cjk = false
  let mut run_x = line.x
  let mut run_width = 0.0
  for character in line.text {
    let next_cjk = is_cjk(character.to_int())
    if has_chars && next_cjk != cjk {
      self.text_run(
        chars.to_string(),
        run_x,
        line.baseline,
        run_width,
        family,
        bold,
        color,
      )
      run_x += run_width
      chars = StringBuilder()
      run_width = 0.0
    }
    has_chars = true
    cjk = next_cjk
    chars.write_char(character)
    run_width += fallback_advance(character, bold)
  }
  if has_chars {
    self.text_run(
      chars.to_string(),
      run_x,
      line.baseline,
      run_width,
      family,
      bold,
      color,
    )
  }
}

///|
fn DrawTile::emit_cell(
  self : DrawTile,
  layout : DrawCell,
  ref : String,
  family : String,
  bold : Bool,
  color : UInt32,
) -> Unit raise {
  self.object.mark(2, ref)
  if layout.lang_known {
    self.set_language(layout.lang)
  } else if grid_script(self.lang) == 0 {
    self.set_language("")
  }
  let was_has_font = self.has_font
  let was_font = self.current_font
  let was_has_color = self.has_color
  let was_color = self.current_color
  if layout.clip {
    self.object.save()
    self.object.clip_rect(
      Float::from_double(layout.x0 - self.x.to_double() * 2048.0),
      Float::from_double(layout.y0 - self.y.to_double() * 2048.0),
      Float::from_double(layout.x1 - layout.x0),
      Float::from_double(layout.y1 - layout.y0),
    )
  }
  for i, line in layout.lines {
    if i > 0 {
      self.object.mark(if line.cjk_wrap { 5 } else { 1 }, "")
    }
    self.emit_line(line, family, bold, color)
  }
  if layout.clip {
    self.object.restore()
    self.has_font = was_has_font
    self.current_font = was_font
    self.has_color = was_has_color
    self.current_color = was_color
  }
}
