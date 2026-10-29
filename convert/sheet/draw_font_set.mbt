///|
fn DrawTile::database_text_run(
  self : DrawTile,
  text : String,
  x : Double,
  y : Double,
  width : Double,
  color : UInt32,
  fonts : GridFontSet,
  choice : @fontdb.Choice,
  hashes : Map[Int32, String],
) -> Unit raise {
  let id = choice.resolved.face.unwrap_or(-1)
  let hash = hashes.get(id)
  let generic = choice.resolved.generic
  let family = if hash is Some(_) {
    generic
  } else {
    let names : Array[String] = []
    if choice.requested != "" {
      names.push(css_quote(choice.requested))
    }
    match fonts.db.face(id) {
      Some(face) if face.font.info.family != "" &&
        face.font.info.family != choice.requested =>
        names.push(css_quote(face.font.info.family))
      _ => ()
    }
    names.push(generic)
    names.join(", ")
  }
  let weight = if hash is Some(_) {
    if choice.resolved.synth_bold {
      700
    } else {
      400
    }
  } else if choice.bold {
    700
  } else {
    400
  }
  let style = if hash is Some(_) {
    if choice.resolved.synth_italic {
      1
    } else {
      0
    }
  } else if choice.italic {
    1
  } else {
    0
  }
  let key = "db:\{id}:\{weight}:\{style}:\{family}"
  let index = match self.fonts.get(key) {
    Some(index) => index
    None => {
      let index = self.object.add_font({ hash, family, weight, style, })
      self.fonts[key] = index
      index
    }
  }
  if !self.has_font || self.current_font != index {
    self.object.font(index, 11.0F)
    self.current_font = index
    self.has_font = true
  }
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
fn DrawTile::emit_database_line(
  self : DrawTile,
  line : DrawLine,
  bold : Bool,
  color : UInt32,
  advance : (Char, Bool) -> Double,
  fonts : GridFontSet,
  hashes : Map[Int32, String],
) -> Unit raise {
  let mut chars = StringBuilder()
  let mut previous : @fontdb.Choice? = None
  let mut cjk = false
  let mut run_x = line.x
  let mut run_width = 0.0
  for character in line.text {
    let choice = fonts.choice(character, bold)
    let next_cjk = is_cjk(character.to_int())
    match previous {
      Some(old) if old != choice || cjk != next_cjk => {
        self.database_text_run(
          chars.to_string(),
          run_x,
          line.baseline,
          run_width,
          color,
          fonts,
          old,
          hashes,
        )
        run_x += run_width
        chars = StringBuilder()
        run_width = 0.0
      }
      _ => ()
    }
    previous = Some(choice)
    cjk = next_cjk
    chars.write_char(character)
    run_width += advance(character, bold)
  }
  match previous {
    Some(choice) =>
      self.database_text_run(
        chars.to_string(),
        run_x,
        line.baseline,
        run_width,
        color,
        fonts,
        choice,
        hashes,
      )
    None => ()
  }
}
