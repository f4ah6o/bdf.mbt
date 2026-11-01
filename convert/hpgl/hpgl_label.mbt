///|
priv struct HpglMetrics {
  mut cap_h : Double
  mut cell : Double
  mut em : Double
  mut lf : Double
  mut vadv : Double
  mut offset : Double
  fixed : Bool
  stick : Bool
  mut mirror_x : Bool
  mut mirror_y : Bool
  spec : @cad.FontSpec
}

///|
priv struct LabelChar {
  code : Int32
  ctrl : Bool
}

///|
priv struct LabelGlyph {
  code : Int32
  at : @cad.Point
  adv : Double
}

///|
priv struct LabelLine {
  start : @cad.Point
  glyphs : Array[LabelGlyph]
}

///|
fn label_font(font : HpglFontDef) -> @cad.FontSpec {
  let spec = @cad.FontSpec::new(
    bold=font.weight >= 3 && font.weight != 9999,
    italic=font.posture == 1 || font.posture == 2,
  )
  match font.typeface {
    0 | 3 | 6 | 4099 | 4102 | 48 | 49 => spec.family = "monospace"
    5 | 8 | 18 | 22 | 23 | 24 | 4101 | 4140 | 4197 | 4297 | 16901 =>
      spec.family = "serif"
    _ => ()
  }
  if font.spacing == 0 && spec.family == "" {
    spec.family = "monospace"
  }
  spec
}

///|
fn HpglGl::metrics(self : HpglGl, size_mode : Int) -> HpglMetrics {
  let label = self.label
  let font = label.font()
  let metrics : HpglMetrics = {
    cap_h: 0.0,
    cell: 0.0,
    em: 0.0,
    lf: 0.0,
    vadv: 0.0,
    offset: 0.0,
    fixed: font.spacing == 0,
    stick: font.stick(),
    mirror_x: false,
    mirror_y: false,
    spec: label_font(font),
  }
  let pt = 1016.0 / 72.0
  let mut width = 0.0
  let mut height = 0.0
  match size_mode {
    1 => {
      width = label.size_w * 400.0
      height = label.size_h * 400.0
    }
    2 => {
      width = label.size_w / 100.0 * (self.p2.x - self.p1.x)
      height = label.size_h / 100.0 * (self.p2.y - self.p1.y)
    }
    _ => ()
  }
  metrics.mirror_x = width < 0.0
  metrics.mirror_y = height < 0.0
  width = width.abs()
  height = height.abs()
  if metrics.stick {
    if size_mode == 0 {
      metrics.cell = 1016.0 / font.pitch
      width = metrics.cell / 1.5
      height = 0.67 * font.height * pt
    } else {
      metrics.cell = 1.5 * width
    }
    let size = height / 0.67
    metrics.cap_h = height
    metrics.lf = 2.0 * height
    metrics.em = 2.0 * width
    metrics.offset = size / 3.0
    metrics.vadv = 0.96 * size
  } else {
    let mut size = font.height * pt
    if metrics.fixed {
      size = 120.0 / font.pitch * pt
    }
    if size_mode == 0 {
      metrics.cap_h = 0.7 * size
      metrics.em = size
      metrics.cell = 0.6 * size
    } else {
      metrics.cap_h = height
      metrics.em = 2.0 * width
      metrics.cell = 1.2 * width
      size = height / 0.7
    }
    metrics.lf = 1.2 * size
    metrics.offset = size / 4.0
    metrics.vadv = 0.9 * size
  }
  if !metrics.fixed {
    metrics.cell = 0.0
  }
  metrics.lf *= 1.0 + label.extra_h
  metrics
}

///|
fn HpglGl::label_space(self : HpglGl, metrics : HpglMetrics) -> @canvas.Matrix {
  let label = self.label
  let mut run = label.run
  let mut rise = label.rise
  if label.rel_dir {
    run = run / 100.0 * (self.p2.x - self.p1.x)
    rise = rise / 100.0 * (self.p2.y - self.p1.y)
  }
  let length = @math.hypot(run, rise)
  if length == 0.0 || length.is_nan() {
    run = 1.0
    rise = 0.0
  }
  let c = if length == 0.0 { 1.0 } else { run / length }
  let s = if length == 0.0 { 0.0 } else { rise / length }
  let sx = if metrics.mirror_x { -1.0 } else { 1.0 }
  let sy = if metrics.mirror_y { -1.0 } else { 1.0 }
  let dev = self.dev
  let base : @canvas.Matrix = {
    a: dev.a,
    b: dev.b,
    c: dev.c,
    d: dev.d,
    e: 0.0,
    f: 0.0,
  }
  let turn : @canvas.Matrix = { a: c, b: s, c: -s, d: c, e: 0.0, f: 0.0 }
  base.mul(turn).mul(@canvas.Matrix::scale(sx, sy))
}

///|
fn HpglLabel::text_path(self : HpglLabel) -> (@cad.Point, @cad.Point) {
  let path : @cad.Point = match self.path {
    1 => { x: 0.0, y: -1.0 }
    2 => { x: -1.0, y: 0.0 }
    3 => { x: 0.0, y: 1.0 }
    _ => { x: 1.0, y: 0.0 }
  }
  let mut line_feed : @cad.Point = { x: path.y, y: -path.x }
  if self.reverse_lf {
    line_feed = line_feed.mul(-1.0)
  }
  (path, line_feed)
}

///|
fn HpglConverter::define_terminator(self : HpglConverter) -> Unit {
  let data = self.data
  if self.offset >= data.length() {
    return
  }
  let term = data[self.offset]
  if term == 59 {
    self.offset += 1
    self.gl.label.term = 0x03
    self.gl.label.term_print = false
    return
  }
  self.offset += 1
  let values = self.params()
  if term == 0 || term == 5 || term == 0x1b {
    return
  }
  self.gl.label.term = term
  self.gl.label.term_print = !values.is_empty() && values[0] == 0.0
}

///|
fn HpglConverter::symbol_mode(self : HpglConverter) -> Unit {
  self.gl.symbol = None
  let data = self.data
  if self.offset >= data.length() {
    return
  }
  let count = if self.gl.label.mode16 { 2 } else { 1 }
  if data[self.offset] == 59 {
    self.offset += 1
    return
  }
  if data[self.offset] < 0x20 && !self.gl.label.mode16 {
    return
  }
  let end = Int::min(data.length(), self.offset + count)
  self.gl.symbol = Some(data[self.offset:end].to_owned())
  self.offset = end
}

///|
fn HpglConverter::character_instruction(
  self : HpglConverter,
  name : String,
  values : Array[Double],
) -> Unit {
  if !hpgl_valid(values) {
    return
  }
  let label = self.gl.label
  match name {
    "SI" | "SR" => {
      if values.is_empty() && name == "SI" {
        self.gl.label.size_mode = 0
      } else if values.is_empty() {
        self.gl.label.size_mode = 2
        self.gl.label.size_w = 0.75
        self.gl.label.size_h = 1.5
      } else if values.length() >= 2 && values[0] != 0.0 && values[1] != 0.0 {
        self.gl.label.size_w = values[0]
        self.gl.label.size_h = values[1]
        self.gl.label.size_mode = if name == "SR" { 2 } else { 1 }
      }
    }
    "SD" | "AD" => {
      if values.is_empty() {
        let defaults = hpgl_default_font()
        if name == "AD" {
          self.gl.label.alt = defaults
        } else {
          self.gl.label.std = defaults
        }
        return
      }
      let font = if name == "AD" { label.alt } else { label.std }
      let mut index = 0
      while index + 1 < values.length() {
        let key = values[index].to_int()
        let value = values[index + 1]
        match key {
          1 => font.symbol_set = value.to_int()
          2 => font.spacing = value.to_int()
          3 => if value > 0.0 { font.pitch = value }
          4 => if value > 0.0 { font.height = value }
          5 => font.posture = value.to_int()
          6 => font.weight = value.to_int()
          7 => font.typeface = value.to_int()
          _ => ()
        }
        index += 2
      }
      if name == "AD" {
        self.gl.label.alt = font
      } else {
        self.gl.label.std = font
      }
    }
    "SS" => self.gl.label.use_alt = false
    "SA" => self.gl.label.use_alt = true
    "CS" | "CA" => {
      if name == "CA" {
        self.gl.label.alt.symbol_set = 277
      } else {
        self.gl.label.std.symbol_set = 277
      }
    }
    "DI" | "DR" => {
      self.gl.label.rel_dir = name == "DR"
      self.gl.label.run = 1.0
      self.gl.label.rise = 0.0
      if values.length() >= 2 && (values[0] != 0.0 || values[1] != 0.0) {
        self.gl.label.run = values[0]
        self.gl.label.rise = values[1]
      }
    }
    "DV" => {
      self.gl.label.path = 0
      self.gl.label.reverse_lf = false
      if !values.is_empty() && values[0] >= 0.0 && values[0] <= 3.0 {
        self.gl.label.path = values[0].to_int()
      }
      if values.length() > 1 {
        self.gl.label.reverse_lf = values[1] == 1.0
      }
    }
    "LO" => {
      let origin = if values.is_empty() { 1 } else { values[0].to_int() }
      if (origin >= 1 && origin <= 9) ||
        (origin >= 11 && origin <= 19) ||
        origin == 21 {
        self.gl.label.origin = origin
      }
    }
    "ES" => {
      self.gl.label.extra_w = 0.0
      self.gl.label.extra_h = 0.0
      if !values.is_empty() {
        self.gl.label.extra_w = values[0]
      }
      if values.length() > 1 {
        self.gl.label.extra_h = values[1]
      }
    }
    "SL" => {
      self.gl.label.slant = 0.0
      if !values.is_empty() {
        self.gl.label.slant = Double::max(-100.0, Double::min(100.0, values[0]))
      }
    }
    "TD" => self.gl.label.td = !values.is_empty() && values[0] == 1.0
    "LM" => {
      self.gl.label.mode16 = !values.is_empty() && values[0] == 1.0
      self.gl.label.row = 0
      if values.length() > 1 && values[1] >= 0.0 && values[1] <= 255.0 {
        self.gl.label.row = values[1].to_int()
      }
      self.gl.symbol = None
    }
    "CP" => {
      self.character_plot(values)
    }
    _ => ()
  }
}

///|
fn HpglConverter::character_plot(self : HpglConverter, values : Array[Double]) -> Unit {
  let metrics = self.gl.metrics(self.gl.label.size_mode)
  let space = self.gl.label_space(metrics)
  let (path, line_feed) = self.gl.label.text_path()
  if values.length() < 2 {
    let delta = hpgl_linear(space, line_feed.mul(metrics.lf))
    self.gl.cr_point = self.gl.cr_point.add(delta)
    self.gl.pos = self.gl.cr_point
    return
  }
  let spaces = values[0]
  let lines = values[1]
  let advance = if metrics.cell != 0.0 {
    metrics.cell * (1.0 + self.gl.label.extra_w)
  } else {
    metrics.em / 4.0
  }
  let along = if self.gl.label.path % 2 == 1 { metrics.vadv } else { advance }
  self.gl.pos = self.gl.pos.add(hpgl_linear(space, path.mul(spaces * along)))
  let down = hpgl_linear(space, line_feed.mul(-lines * metrics.lf))
  self.gl.pos = self.gl.pos.add(down)
  self.gl.cr_point = self.gl.cr_point.add(down)
}

///|
fn HpglConverter::decode_label(self : HpglConverter, text : Bytes) -> Array[LabelChar] {
  let output : Array[LabelChar] = []
  let label = self.gl.label
  if label.mode16 {
    let mut index = 0
    while index + 1 < text.length() {
      let first = text[index]
      let second = text[index + 1]
      index += 2
      if first == 0 {
        if second < 0x20 && !label.td {
          output.push({ code: second.to_int(), ctrl: true })
        } else {
          output.push({ code: second.to_int(), ctrl: false })
        }
        continue
      }
      let euc = [
        (first.to_int() | 0x80).to_byte(),
        (second.to_int() | 0x80).to_byte(),
      ]
      match @encoding.decode(Bytes::from_array(euc), "EUC-JP") {
        Ok(value) => {
          for character in value {
            output.push({ code: character.to_int(), ctrl: false })
          }
        }
        Err(_) => output.push({ code: 32, ctrl: false })
      }
    }
    return output
  }
  let mut index = 0
  while index < text.length() {
    let byte = text[index]
    if (byte < 0x20 || byte == 0x7f) && !label.td {
      output.push({ code: byte.to_int(), ctrl: true })
      index += 1
      continue
    }
    let start = index
    while index < text.length() {
      let value = text[index]
      if (value < 0x20 || value == 0x7f) && !label.td {
        break
      }
      index += 1
    }
    let run = text[start:index].to_owned()
    let decoded = try_decode_text(run)
    for character in decoded {
      output.push({ code: character.to_int(), ctrl: false })
    }
  }
  output
}

///|
fn try_decode_text(data : Bytes) -> String {
  let mut high = false
  for byte in data {
    if byte >= 0x80 {
      high = true
      break
    }
  }
  if high {
    match @encoding.decode(data, "shift_jis") {
      Ok(value) => return value
      Err(_) => ()
    }
  }
  @utf8.decode_lossy(data)
}

///|
fn measure(fonts : @canvas.Fonts, spec : @cad.FontSpec, code : Int32) -> Double {
  let choice = fonts.face(
    spec.family,
    spec.east_asian,
    code,
    bold=spec.bold,
    italic=spec.italic,
  )
  fonts.advance(choice, code)
}

///|
fn HpglConverter::draw_label(self : HpglConverter, text : Bytes) -> Unit {
  if self.gl.in_poly {
    return
  }
  self.gl.flush()
  let chars = self.decode_label(text)
  if chars.is_empty() {
    return
  }
  let mut metrics = self.gl.metrics(self.gl.label.size_mode)
  let mut space = self.gl.label_space(metrics)
  let (path, line_feed) = self.gl.label.text_path()
  let start = self.gl.pos
  let mut pen = self.gl.pos
  let lines : Array[LabelLine] = []
  let mut line : LabelLine = { start: pen, glyphs: [] }
  let mut last_advance = 0.0
  let mut have_last = false
  for item in chars {
    if item.ctrl {
      match item.code {
        0x0d => {
          if !line.glyphs.is_empty() {
            lines.push(line)
          }
          pen = self.gl.cr_point
          line = { start: pen, glyphs: [] }
        }
        0x0a => {
          if !line.glyphs.is_empty() {
            lines.push(line)
          }
          let delta = hpgl_linear(space, line_feed.mul(metrics.lf))
          pen = pen.add(delta)
          self.gl.cr_point = self.gl.cr_point.add(delta)
          line = { start: pen, glyphs: [] }
        }
        0x08 => {
          if have_last {
            pen = pen.sub(hpgl_linear(space, path.mul(last_advance)))
            if !line.glyphs.is_empty() {
              ignore(line.glyphs.pop())
            }
            have_last = false
          }
        }
        0x0e | 0x0f => {
          self.gl.label.use_alt = item.code == 0x0e
          metrics = self.gl.metrics(0)
          space = self.gl.label_space(metrics)
        }
        _ => ()
      }
      continue
    }
    let mut advance = metrics.cell
    if self.gl.label.path % 2 == 1 {
      advance = metrics.vadv
    } else if advance == 0.0 {
      advance = measure(self.fonts, metrics.spec, item.code) * metrics.em
    }
    advance *= 1.0 + self.gl.label.extra_w
    line.glyphs.push({ code: item.code, at: pen, adv: advance, })
    pen = pen.add(hpgl_linear(space, path.mul(advance)))
    last_advance = advance
    have_last = true
  }
  if !line.glyphs.is_empty() {
    lines.push(line)
  }
  for index, value in lines {
    self.draw_label_line(value, index > 0, metrics, space)
  }
  if concatenates(self.gl.label.path, self.gl.label.origin) {
    self.gl.pos = pen
  } else {
    self.gl.pos = start
  }
}

///|
fn HpglConverter::draw_label_line(
  self : HpglConverter,
  line : LabelLine,
  continuation : Bool,
  metrics : HpglMetrics,
  space : @canvas.Matrix,
) -> Unit {
  if line.glyphs.is_empty() {
    return
  }
  let inverse = hpgl_invert(space)
  let mut box = @cad.Rect::empty()
  for glyph in line.glyphs {
    let relative = hpgl_linear(inverse, glyph.at.sub(line.start))
    let mut width = glyph.adv
    if self.gl.label.path % 2 == 1 {
      width = if metrics.cell != 0.0 { metrics.cell } else { metrics.em / 2.0 }
    }
    box = box.add(relative)
    box = box.add({ x: relative.x + width, y: relative.y + metrics.cap_h })
  }
  let origin = self.gl.label.origin
  let base = if origin == 21 {
    1
  } else if origin > 10 {
    origin - 10
  } else {
    origin
  }
  let shift_x = match (base - 1) / 3 {
    1 => -(box.min.x + box.max.x) / 2.0
    2 => -box.max.x
    _ => -box.min.x
  }
  let shift_y = match (base - 1) % 3 {
    1 => -(box.min.y + box.max.y) / 2.0
    2 => -box.max.y
    _ => -box.min.y
  }
  let mut shift_x = shift_x
  let mut shift_y = shift_y
  if origin > 10 {
    if (base - 1) / 3 == 0 {
      shift_x += metrics.offset
    } else if (base - 1) / 3 == 2 {
      shift_x -= metrics.offset
    }
    if (base - 1) % 3 == 0 {
      shift_y += metrics.offset
    } else if (base - 1) % 3 == 2 {
      shift_y -= metrics.offset
    }
  }
  let shift : @cad.Point = { x: shift_x, y: shift_y }
  let color = self.gl.pen_color_of(self.gl.pens.current())
  let line_break = if continuation { @cad.BreakLine } else { @cad.BreakBox }
  let first = line.glyphs[0]
  let text = StringBuilder()
  let cells : Array[Double] = []
  for glyph in line.glyphs {
    text.write_char(glyph.code.unsafe_to_char())
    cells.push(glyph.adv / metrics.em)
  }
  let value = text.to_string()
  if is_blank_string(value) {
    return
  }
  let anchor = first.at.add(hpgl_linear(space, shift))
  let base_matrix : @canvas.Matrix = {
    a: space.a,
    b: space.b,
    c: space.c,
    d: space.d,
    e: anchor.x,
    f: anchor.y,
  }
  let slant : @canvas.Matrix = {
    a: 1.0,
    b: 0.0,
    c: self.gl.label.slant,
    d: 1.0,
    e: 0.0,
    f: 0.0,
  }
  let mut matrix = base_matrix.mul(slant)
  if self.gl.label.path == 1 {
    matrix = matrix.mul(@canvas.Matrix::rotate(-90.0))
  } else if self.gl.label.path == 2 {
    matrix = matrix.mul(@canvas.Matrix::rotate(180.0))
  } else if self.gl.label.path == 3 {
    matrix = matrix.mul(@canvas.Matrix::rotate(90.0))
  }
  let matrix = matrix.mul(@canvas.Matrix::scale(metrics.em, metrics.em))
  let choice = self.fonts.face(
    metrics.spec.family,
    metrics.spec.east_asian,
    first.code,
    bold=metrics.spec.bold,
    italic=metrics.spec.italic,
  )
  let font_metrics = self.fonts.metrics(choice)
  let text_item = @cad.CadText::new(
    value,
    matrix,
    font=metrics.spec,
    color=color,
    advance=cells_sum(cells),
    cells=Some(cells),
    asc=font_metrics.asc,
    desc=font_metrics.desc,
    cap=font_metrics.cap,
    line_break=line_break,
    vertical=self.gl.label.path == 1,
  )
  if !self.gl.budget() {
    return
  }
  self.gl.drawing.text(text_item)
  self.has_text = true
}

///|
fn cells_sum(cells : Array[Double]) -> Double {
  let mut total = 0.0
  for value in cells {
    total += value
  }
  total
}

///|
fn is_blank_string(value : String) -> Bool {
  for character in value {
    if !character.is_whitespace() {
      return false
    }
  }
  true
}

///|
fn concatenates(path : Int, origin : Int) -> Bool {
  let value = if origin > 10 && origin < 20 { origin - 10 } else { origin }
  match path {
    0 => value == 1 || value == 2 || value == 3 || origin == 21
    1 => value == 3 || value == 6 || value == 9
    2 => value == 7 || value == 8 || value == 9
    _ => value == 1 || value == 4 || value == 7 || origin == 21
  }
}

///|
fn HpglConverter::draw_symbol_mode(self : HpglConverter) -> Unit {
  match self.gl.symbol {
    Some(entry) => {
      let chars = try_decode_text(entry)
      if chars.length() == 0 {
        return
      }
      let metrics = self.gl.metrics(self.gl.label.size_mode)
      let space = self.gl.label_space(metrics)
      let code = chars[0].to_int()
      let mut advance = metrics.cell
      if advance == 0.0 {
        advance = measure(self.fonts, metrics.spec, code) * metrics.em
      }
      let width = if metrics.stick { advance / 1.5 } else { advance }
      let anchor = self.gl.pos
      let base_matrix : @canvas.Matrix = {
        a: space.a,
        b: space.b,
        c: space.c,
        d: space.d,
        e: anchor.x,
        f: anchor.y,
      }
      let slant : @canvas.Matrix = {
        a: 1.0,
        b: 0.0,
        c: self.gl.label.slant,
        d: 1.0,
        e: 0.0,
        f: 0.0,
      }
      let matrix = base_matrix.mul(slant).mul(
        @canvas.Matrix::scale(metrics.em, metrics.em),
      )
      let text_item = @cad.CadText::new(
        chars,
        matrix,
        font=metrics.spec,
        color=self.gl.pen_color_of(self.gl.pens.current()),
        advance=width / metrics.em,
        cells=Some([width / metrics.em]),
        asc=metrics.cap_h / metrics.em,
        cap=metrics.cap_h / metrics.em,
      )
      self.gl.drawing.text(text_item)
    }
    None => ()
  }
}
