///|
fn DrawTile::set_language(self : DrawTile, raw : String) -> Unit {
  let candidate = raw.trim().to_string()
  let lower = candidate.to_lower()
  let doc = self.document_language.to_lower()
  let lang = if lower == "x-none" ||
    lower == doc ||
    (lower != "" && !lower.contains("-") && doc.has_prefix(lower + "-")) {
    ""
  } else {
    candidate
  }
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
  face : @sfnt.Font?,
  hash : String?,
  size~ : Double = 11.0,
  italic~ : Bool = false,
) -> Unit raise {
  let weight = if bold &&
    (hash is None || (face is Some(f) && f.info.weight < 600)) {
    700
  } else {
    400
  }
  let generic = if family.contains("serif") && !family.contains("sans-serif") {
    "serif"
  } else {
    "sans-serif"
  }
  let family = if hash is Some(_) {
    generic
  } else {
    match face {
      Some(font) => {
        let separator = family.length() - generic.length()
        let prefix = family.unsafe_substring(start=0, end=separator)
        let name = font.info.family
        if name == "" || prefix == css_quote(name) + ", " {
          family
        } else {
          prefix + css_quote(name) + ", " + generic
        }
      }
      None => family
    }
  }
  let request_key = (if bold { "single:700:" } else { "single:400:" }) +
    (if italic { "italic:" } else { "normal:" }) +
    family
  let index = match self.fonts.get(request_key) {
    Some(index) => index
    None => {
      let index = self.object.add_font({
        hash,
        family,
        weight,
        style: if italic {
          1
        } else {
          0
        },
      })
      self.fonts[request_key] = index
      index
    }
  }
  if !self.has_font || self.current_font != index || self.current_size != size {
    self.object.font(index, Float::from_double(size))
    self.current_font = index
    self.current_size = size
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
  face : @sfnt.Font?,
  hash : String?,
  size~ : Double = 11.0,
  italic~ : Bool = false,
  underline~ : String = "",
  strike~ : Bool = false,
) -> Unit raise {
  self.set_font(family, bold, face, hash, size~, italic~)
  self.fill_color(color)
  self.object.fill_text(
    text,
    Float::from_double(x - self.x.to_double() * 2048.0),
    Float::from_double(y - self.y.to_double() * 2048.0),
    Float::from_double(width),
  )
  let lx = x - self.x.to_double() * 2048.0
  let ly = y - self.y.to_double() * 2048.0
  let thickness = Double::max(0.05 * size, 0.75)
  if underline != "" {
    self.object.fill_rect(
      Float::from_double(lx),
      grid_fused_float(0.1, size, ly),
      Float::from_double(width),
      Float::from_double(thickness),
    )
    if underline.has_prefix("double") {
      let uy = @core.fused_multiply_add(0.1, size, ly)
      self.object.fill_rect(
        Float::from_double(lx),
        Float::from_double(uy + 2.0 * thickness),
        Float::from_double(width),
        Float::from_double(thickness),
      )
    }
  }
  if strike {
    self.object.fill_rect(
      Float::from_double(lx),
      grid_fused_float(-0.3, size, ly),
      Float::from_double(width),
      Float::from_double(thickness),
    )
  }
  self.drawn = true
}

///|
// Most results round identically to Float without an exact multiply-add. Use
// the exact operation near a Float rounding boundary or cancellation.
fn grid_fused_float(a : Double, b : Double, c : Double) -> Float {
  let product = a * b
  let sum = product + c
  let rounded = Float::from_double(sum)
  let value = rounded.to_double()
  let margin = value.abs() / 33554432.0 - (sum - value).abs()
  let error = (product.abs() + c.abs()) * 1.0e-15
  if margin > error {
    rounded
  } else {
    Float::from_double(@core.fused_multiply_add(a, b, c))
  }
}

///|
fn DrawTile::emit_line(
  self : DrawTile,
  line : DrawLine,
  family : String,
  bold : Bool,
  color : UInt32,
  advance : (Char, Bool) -> Double,
  face : @sfnt.Font?,
  hash : String?,
  size~ : Double = 11.0,
  east_asian~ : String = "",
  italic~ : Bool = false,
  underline~ : String = "",
  strike~ : Bool = false,
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
        if cjk && east_asian != "" {
          east_asian
        } else {
          family
        },
        bold,
        color,
        face,
        hash,
        size~,
        italic~,
        underline~,
        strike~,
      )
      run_x += run_width
      chars = StringBuilder()
      run_width = 0.0
    }
    has_chars = true
    cjk = next_cjk
    chars.write_char(character)
    run_width += advance(character, bold)
  }
  if has_chars {
    self.text_run(
      chars.to_string(),
      run_x,
      line.baseline,
      run_width,
      if cjk && east_asian != "" {
        east_asian
      } else {
        family
      },
      bold,
      color,
      face,
      hash,
      size~,
      italic~,
      underline~,
      strike~,
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
  advance : (Char, Bool) -> Double,
  face : @sfnt.Font?,
  hash : String?,
  fontset : GridFontSet?,
  hashes : Map[Int32, String],
  size~ : Double = 11.0,
  east_asian~ : String = "",
  italic~ : Bool = false,
  underline~ : String = "",
  strike~ : Bool = false,
  rich_lines~ : Array[Array[GridRichColorRun]] = [],
  rich_scale~ : Double = 1.0,
) -> Unit raise {
  self.object.mark(2, ref)
  if layout.lang_known {
    self.set_language(layout.lang)
  } else if grid_script(self.lang) == 0 {
    self.set_language("")
  }
  let was_has_font = self.has_font
  let was_font = self.current_font
  let was_size = self.current_size
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
    if !rich_lines.is_empty() {
      let rich_runs = rich_lines[i]
      let mut offset = 0.0
      for run in rich_runs {
        let run_family = if run.family_override {
          rich_family(run.family)
        } else {
          family
        }
        let run_east_asian = if run.family_override {
          if run.east_asian == "" {
            ""
          } else {
            rich_family(run.east_asian)
          }
        } else {
          east_asian
        }
        let run_size = if run.size > 0.0 { run.size * rich_scale } else { size }
        let mut chars = StringBuilder()
        let mut has_chars = false
        let mut cjk = false
        let mut width = 0.0
        let mut start = offset
        for character in run.text {
          let next_cjk = is_cjk(character.to_int())
          if has_chars && next_cjk != cjk {
            self.text_run(
              chars.to_string(),
              line.x + start,
              line.baseline,
              width,
              if cjk && run_east_asian != "" {
                run_east_asian
              } else {
                run_family
              },
              run.bold,
              run.color,
              face,
              hash,
              size=run_size,
              italic=run.italic,
              underline=run.underline,
              strike=run.strike,
            )
            chars = StringBuilder()
            width = 0.0
            start = offset
          }
          has_chars = true
          cjk = next_cjk
          chars.write_char(character)
          let step = if run.size > 0.0 {
            sized_fallback_advance(character, run.bold, run.size) * rich_scale
          } else {
            advance(character, run.bold)
          }
          width += step
          offset += step
        }
        if has_chars {
          self.text_run(
            chars.to_string(),
            line.x + start,
            line.baseline,
            width,
            if cjk && run_east_asian != "" {
              run_east_asian
            } else {
              run_family
            },
            run.bold,
            run.color,
            face,
            hash,
            size=run_size,
            italic=run.italic,
            underline=run.underline,
            strike=run.strike,
          )
        }
      }
    } else {
      match fontset {
        Some(fonts) =>
          self.emit_database_line(line, bold, color, advance, fonts, hashes)
        None =>
          self.emit_line(
            line,
            family,
            bold,
            color,
            advance,
            face,
            hash,
            size~,
            east_asian~,
            italic~,
            underline~,
            strike~,
          )
      }
    }
  }
  if layout.clip {
    self.object.restore()
    self.has_font = was_has_font
    self.current_font = was_font
    self.current_size = was_size
    self.has_color = was_has_color
    self.current_color = was_color
  }
}

///|
fn css_quote(value : String) -> String {
  let result = StringBuilder()
  result.write_char('"')
  for character in value {
    if character == '"' || character == '\\' {
      result.write_char('\\')
    }
    result.write_char(character)
  }
  result.write_char('"')
  result.to_string()
}

///|
fn rich_family(name : String) -> String {
  let generic = @fontdb.classify(name)
  match name {
    "sans-serif"
    | "serif"
    | "monospace"
    | "cursive"
    | "fantasy"
    | "system-ui"
    | "ui-sans-serif"
    | "ui-serif"
    | "ui-monospace" => generic
    _ => css_quote(name) + ", " + generic
  }
}
