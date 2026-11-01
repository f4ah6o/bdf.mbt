///|
/// The current bytes of the plot.
fn HpglConverter::data(self : HpglConverter) -> Bytes {
  self.data
}

///|
fn HpglConverter::skip_blank(self : HpglConverter) -> Unit {
  let data = self.data
  while self.offset < data.length() {
    let byte = data[self.offset]
    if byte == 0 ||
      byte == 32 ||
      byte == 9 ||
      byte == 13 ||
      byte == 10 ||
      byte == 59 ||
      byte == 3 {
      self.offset += 1
    } else if byte == 0x1b &&
      self.offset + 1 < data.length() &&
      data[self.offset + 1] == 46 {
      self.offset = hpgl_device(data, self.offset)
    } else {
      return
    }
  }
}

///|
fn HpglConverter::handle_escape(self : HpglConverter) -> Unit {
  let data = self.data
  if self.offset + 1 >= data.length() {
    self.offset = data.length()
    return
  }
  match data[self.offset + 1] {
    46 => self.offset = hpgl_device(data, self.offset)
    37 => {
      // ESC % # A/B: PCL or HP RTL, or HP-GL/2 entered again
      self.warn_once(
        "pcl",
        "PCL and HP RTL escape sequences are not supported; HP-GL/2 is read where it starts",
      )
      self.offset += 2
      while self.offset < data.length() &&
        data[self.offset] >= 48 &&
        data[self.offset] <= 57 {
        self.offset += 1
      }
      if self.offset < data.length() {
        self.offset += 1
      }
    }
    69 => {
      self.offset += 2
      self.gl.reset_page()
    }
    _ => self.offset += 2
  }
}

///|
fn HpglConverter::run(self : HpglConverter) -> Unit {
  let data = self.data
  self.skip_blank()
  // PJL headers: enter HP-GL/2 where the job says so.
  if (self.offset < data.length() && data[self.offset] == 0x1b) ||
    data.has_prefix(b"@PJL") {
    while self.offset < data.length() {
      self.skip_blank()
      if self.offset >= data.length() {
        break
      }
      if data[self.offset] == 0x1b {
        self.handle_escape()
        continue
      }
      if data[self.offset] == 64 && bytes_at(data, self.offset, b"@PJL") {
        self.skip_pjl_line()
        continue
      }
      break
    }
  }
  while self.offset < data.length() && !self.stopped {
    self.skip_blank()
    if self.offset >= data.length() {
      break
    }
    let byte = data[self.offset]
    if byte == 0x1b {
      self.handle_escape()
      continue
    }
    if byte == 33 {
      // Device-specific instructions of cutting plotters.
      self.offset += 1
      while self.offset < data.length() && is_letter(data[self.offset]) {
        self.offset += 1
      }
      ignore(self.params())
      self.warn_once("!", "device-specific instructions (!...) are ignored")
      continue
    }
    if !is_letter(byte) {
      self.offset += 1
      continue
    }
    if self.offset + 1 >= data.length() ||
      !is_letter(data[self.offset + 1]) {
      self.offset += 1
      continue
    }
    let first = ascii_upper(data[self.offset])
    let second = ascii_upper(data[self.offset + 1])
    let name = first.to_int().unsafe_to_char().to_string() +
      second.to_int().unsafe_to_char().to_string()
    self.offset += 2
    if hpgl_known(name) {
      self.instructions += 1
    }
    self.instruction(name)
  }
  self.end_page()
}

///|
fn HpglConverter::skip_pjl_line(self : HpglConverter) -> Unit {
  let data = self.data
  while self.offset < data.length() {
    let byte = data[self.offset]
    self.offset += 1
    if byte == 10 || byte == 13 {
      break
    }
  }
}

///|
fn ascii_upper(byte : Byte) -> Byte {
  if byte >= 97 && byte <= 122 {
    byte - 32
  } else {
    byte
  }
}

///|
fn bytes_at(data : Bytes, offset : Int, prefix : Bytes) -> Bool {
  if offset + prefix.length() > data.length() {
    return false
  }
  for index, value in prefix {
    if data[offset + index] != value {
      return false
    }
  }
  true
}

///|
fn hpgl_known(name : String) -> Bool {
  hpgl_mnemonics.contains(" " + name + " ")
}

///|
fn is_letter(byte : Byte) -> Bool {
  (byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122)
}

///|
fn HpglConverter::params(self : HpglConverter) -> Array[Double] {
  let data = self.data
  let values : Array[Double] = []
  while self.offset < data.length() {
    let byte = data[self.offset]
    if byte == 32 || byte == 44 || byte == 9 || byte == 13 || byte == 10 || byte == 0 {
      self.offset += 1
    } else if (byte >= 48 && byte <= 57) ||
      byte == 46 ||
      byte == 43 ||
      byte == 45 {
      let (value, consumed) = parse_number(data, self.offset)
      self.offset += if consumed > 0 { consumed } else { 1 }
      if consumed > 0 {
        values.push(value)
      }
    } else if byte == 59 {
      self.offset += 1
      return values
    } else {
      return values
    }
  }
  values
}

///|
fn parse_number(data : Bytes, start : Int) -> (Double, Int) {
  let mut index = start
  let mut sign = 1.0
  if index < data.length() && (data[index] == 43 || data[index] == 45) {
    if data[index] == 45 {
      sign = -1.0
    }
    index += 1
  }
  let mut value = 0.0
  let mut digits = 0
  while index < data.length() && data[index] >= 48 && data[index] <= 57 {
    value = value * 10.0 + (data[index] - 48).to_double()
    digits += 1
    index += 1
  }
  if index < data.length() && data[index] == 46 {
    index += 1
    let mut scale = 0.1
    while index < data.length() && data[index] >= 48 && data[index] <= 57 {
      value += (data[index] - 48).to_double() * scale
      scale /= 10.0
      digits += 1
      index += 1
    }
  }
  if digits == 0 {
    (0.0, index - start)
  } else {
    (value * sign, index - start)
  }
}

///|
fn HpglConverter::quoted(self : HpglConverter) -> String {
  let data = self.data
  while self.offset < data.length() &&
    (data[self.offset] == 32 || data[self.offset] == 9 || data[self.offset] == 44) {
    self.offset += 1
  }
  if self.offset >= data.length() || data[self.offset] != 34 {
    let start = self.offset
    while self.offset < data.length() && data[self.offset] != 59 {
      self.offset += 1
    }
    return ""
  }
  self.offset += 1
  let output = StringBuilder()
  while self.offset < data.length() {
    let byte = data[self.offset]
    self.offset += 1
    if byte == 34 {
      if self.offset < data.length() && data[self.offset] == 34 {
        output.write_char('"')
        self.offset += 1
        continue
      }
      break
    }
    output.write_char(byte.to_int().unsafe_to_char())
  }
  output.to_string()
}

///|
fn HpglConverter::label_text(self : HpglConverter) -> Bytes {
  let data = self.data
  let term = self.gl.label.term
  let start = self.offset
  if self.gl.label.mode16 {
    while self.offset + 1 < data.length() {
      if data[self.offset] == 0 && data[self.offset + 1] == term {
        let end = if self.gl.label.term_print {
          self.offset + 2
        } else {
          self.offset
        }
        let text = data[start:end].to_owned()
        self.offset += 2
        return text
      }
      self.offset += 2
    }
  } else {
    while self.offset < data.length() {
      if data[self.offset] == term && term != 0 {
        let end = if self.gl.label.term_print {
          self.offset + 1
        } else {
          self.offset
        }
        let text = data[start:end].to_owned()
        self.offset += 1
        return text
      }
      self.offset += 1
    }
  }
  self.warn_once(
    "unterminated",
    "a label has no terminator; its text ends with the file",
  )
  data[start:].to_owned()
}

///|
fn HpglConverter::instruction(self : HpglConverter, name : String) -> Unit {
  match name {
    "LB" => {
      let text = self.label_text()
      self.draw_label(text)
    }
    "WD" | "BL" => {
      ignore(self.label_text())
    }
    "DT" => self.define_terminator()
    "SM" => self.symbol_mode()
    "CO" | "MG" => {
      ignore(self.quoted())
    }
    "BP" => self.begin_plot()
    "PE" => self.polyline_encoded()
    "PB" => {
      ignore(self.params())
    }
    _ => {
      let values = self.params()
      self.instruction_values(name, values)
    }
  }
}

///|
fn HpglConverter::instruction_values(
  self : HpglConverter,
  name : String,
  values : Array[Double],
) -> Unit {
  let gl = self.gl
  match name {
    "IN" => gl.initialize()
    "DF" => gl.defaults()
    "IP" => self.input_p1_p2(values, false)
    "IR" => self.input_p1_p2(values, true)
    "IW" => gl.input_window(values)
    "SC" => self.scale_instruction(values)
    "RO" => self.rotate(values)
    "PS" => self.plot_size(values)
    "PG" | "AF" | "AH" | "FR" => self.end_page()
    "PA" => {
      gl.relative = false
      self.plot(values)
    }
    "PR" => {
      gl.relative = true
      self.plot(values)
    }
    "PU" => {
      gl.pen_up()
      self.plot(values)
    }
    "PD" => {
      gl.pen_down()
      self.plot(values)
    }
    "AA" => self.arc_instruction(values, false)
    "AR" => self.arc_instruction(values, true)
    "AT" => self.arc_three(values, false)
    "RT" => self.arc_three(values, true)
    "CI" => self.circle(values)
    "BZ" => self.bezier(values, false)
    "BR" => self.bezier(values, true)
    "CT" => {
      if values.is_empty() || values[0] == 0.0 || values[0] == 1.0 {
        gl.chord = if values.is_empty() { 0 } else { values[0].to_int() }
      }
    }
    "PM" => self.polygon_mode(values)
    "EP" => self.edge_polygon()
    "FP" => self.fill_polygon(values)
    "EA" => self.rectangle(values, false, false)
    "ER" => self.rectangle(values, true, false)
    "RA" => self.rectangle(values, false, true)
    "RR" => self.rectangle(values, true, true)
    "EW" => self.wedge(values, false)
    "WG" => self.wedge(values, true)
    "SP" => self.select_pen(values)
    "PW" => self.pen_width(values)
    "WU" => self.width_unit(values)
    "NP" => self.number_of_pens(values)
    "PC" => self.pen_color(values)
    "CR" => self.color_range(values)
    "LT" => self.line_type(values)
    "UL" => self.user_line_type(values)
    "LA" => self.line_attributes(values)
    "FT" => self.fill_type(values)
    "RF" => self.raster_fill(values)
    "AC" => self.anchor_corner(values)
    "SV" => self.screened_vectors(values)
    "TR" => {
      gl.flush()
      gl.fill.transparent = values.is_empty() || values[0] != 0.0
    }
    "MC" => {
      gl.merge = !values.is_empty() && values[0] != 0.0
      if gl.merge && (values.length() < 2 || values[1] != 252.0) {
        self.warn_once(
          "MC",
          "merge control (MC) is not applied: later marks replace earlier ones",
        )
      }
    }
    "SI" | "SR" | "SD" | "AD" | "SS" | "SA" | "CS" | "CA" | "DI" | "DR" |
    "DV" | "LO" | "ES" | "SL" | "CP" | "TD" | "LM" | "CF" | "SB" => self.character_instruction(name, values)
    "XT" => self.tick(values, true)
    "YT" => self.tick(values, false)
    "TL" => self.tick_length(values)
    _ => {
      self.warn_once(
        "unknown " + name,
        "the instruction \{name} is not supported",
      )
    }
  }
}

///|
fn HpglConverter::warn(self : HpglConverter, message : String) -> Unit {
  self.gl.warn(message)
}

///|
fn HpglConverter::warn_once(self : HpglConverter, key : String, message : String) -> Unit {
  self.gl.warn_once(key, message)
}

///|
fn HpglConverter::budget(self : HpglConverter) -> Bool {
  self.gl.budget()
}

///|
fn HpglGl::reset_page(self : HpglGl) -> Unit {
  self.flush()
  self.close_window()
  self.polygon = HpglPolygon::new()
  self.in_poly = false
}

///|
fn HpglGl::pen_up(self : HpglGl) -> Unit {
  if self.down && self.stroke.pending_dot && !self.in_poly {
    self.dot(self.pos)
  }
  self.down = false
  self.stroke.pending_dot = false
}

///|
fn HpglGl::pen_down(self : HpglGl) -> Unit {
  if !self.down {
    self.stroke.pending_dot = true
  }
  self.down = true
}

///|
fn HpglConverter::input_p1_p2(
  self : HpglConverter,
  values : Array[Double],
  relative : Bool,
) -> Unit {
  let gl = self.gl
  gl.flush()
  if values.is_empty() {
    gl.default_p1_p2()
    gl.update()
    return
  }
  if (values.length() != 2 && values.length() < 4) || !hpgl_valid(values) {
    return
  }
  let (width, height) = gl.size()
  let at = fn(x : Double, y : Double) -> @cad.Point {
    if relative {
      { x: x / 100.0 * width, y: y / 100.0 * height }
    } else {
      { x: x.round(), y: y.round() }
    }
  }
  let p1 = at(values[0], values[1])
  let mut p2 = p1.add(gl.p2.sub(gl.p1))
  if values.length() >= 4 {
    p2 = at(values[2], values[3])
  }
  if p1.x == p2.x {
    p2 = { x: p2.x + 1.0, y: p2.y }
  }
  if p1.y == p2.y {
    p2 = { x: p2.x, y: p2.y + 1.0 }
  }
  gl.p1 = p1
  gl.p2 = p2
  gl.update()
}

///|
fn HpglConverter::scale_instruction(self : HpglConverter, values : Array[Double]) -> Unit {
  let gl = self.gl
  gl.flush()
  if values.is_empty() {
    gl.scale_set = false
    gl.scale_values = []
    gl.update()
    return
  }
  if values.length() < 4 || !hpgl_valid(values) {
    return
  }
  let typ = if values.length() >= 5 { values[4].to_int() } else { 0 }
  match typ {
    0 => {
      if values[0] == values[1] || values[2] == values[3] {
        return
      }
    }
    1 => {
      if values[0] == values[1] || values[2] == values[3] {
        return
      }
    }
    2 => {
      if values[1] == 0.0 || values[3] == 0.0 {
        return
      }
    }
    _ => return
  }
  gl.scale_typ = typ
  if typ == 1 {
    gl.scale_values = [
      values[0],
      values[1],
      values[2],
      values[3],
      if values.length() >= 7 {
        Double::max(0.0, Double::min(100.0, values[5]))
      } else {
        50.0
      },
      if values.length() >= 7 {
        Double::max(0.0, Double::min(100.0, values[6]))
      } else {
        50.0
      },
    ]
  } else {
    gl.scale_values = [values[0], values[1], values[2], values[3]]
  }
  gl.scale_set = true
  gl.update()
}

///|
fn HpglConverter::rotate(self : HpglConverter, values : Array[Double]) -> Unit {
  let gl = self.gl
  let mut rotation = 0
  if !values.is_empty() {
    rotation = values[0].round().to_int()
  }
  if rotation != 0 && rotation != 90 && rotation != 180 && rotation != 270 {
    return
  }
  gl.flush()
  let old = gl.dev
  gl.rot = rotation
  gl.update()
  gl.cr_point = gl.pos
  let turn = gl.dev.mul(hpgl_invert(old))
  gl.polygon_transform(turn)
  match gl.window {
    Some(window) => {
      let open = window.open
      gl.close_window()
      gl.window = Some({ path: window.path.transform(turn), open: false })
      if open {
        gl.open_window()
      }
    }
    None => ()
  }
}

///|
fn HpglConverter::plot_size(self : HpglConverter, values : Array[Double]) -> Unit {
  let gl = self.gl
  let mut width = HPGL_DEFAULT_HARD_W
  let mut height = HPGL_DEFAULT_HARD_H
  if !values.is_empty() {
    let length = values[0]
    let mut across = if values.length() >= 2 { values[1] } else { 0.0 }
    if length <= 0.0 || !hpgl_valid([length, across]) {
      return
    }
    if across <= 0.0 {
      across = length / 1.5
    }
    width = Double::max(length, across)
    height = Double::min(length, across)
  }
  gl.flush()
  gl.close_window()
  gl.hard_w = width
  gl.hard_h = height
  gl.ps_set = true
  gl.default_p1_p2()
  gl.window = None
  gl.anchored = false
  gl.polygon = HpglPolygon::new()
  gl.in_poly = false
  gl.update()
  gl.pos = hpgl_apply(gl.dev, { x: 0.0, y: 0.0 })
  gl.cr_point = gl.pos
}

///|
fn HpglConverter::begin_plot(self : HpglConverter) -> Unit {
  let data = self.data
  while self.offset < data.length() {
    let byte = data[self.offset]
    if byte == 59 ||
      byte == 32 ||
      byte == 44 ||
      byte == 9 ||
      byte == 13 ||
      byte == 10 {
      self.offset += 1
      continue
    }
    if (byte >= 48 && byte <= 57) || byte == 43 || byte == 45 || byte == 46 {
      let (value, consumed) = parse_number(data, self.offset)
      self.offset += if consumed > 0 { consumed } else { 1 }
      if value.to_int() == 1 {
        while self.offset < data.length() &&
          (data[self.offset] == 32 || data[self.offset] == 44) {
          self.offset += 1
        }
        if self.offset < data.length() && data[self.offset] == 34 {
          let title = self.quoted()
          if title != "" && self.title == "" {
            self.title = title
          }
        }
      }
      continue
    }
    if byte == 34 {
      ignore(self.quoted())
      continue
    }
    break
  }
  self.gl.flush()
  if !self.gl.drawing.is_empty() {
    self.end_page()
  }
  self.gl.initialize()
}

///|
fn HpglConverter::plot(self : HpglConverter, values : Array[Double]) -> Unit {
  let mut index = 0
  while index + 1 < values.length() {
    self.gl.plot([values[index], values[index + 1]])
    self.draw_symbol_mode()
    index += 2
  }
}

///|
fn HpglConverter::end_page(self : HpglConverter) -> Unit {
  let gl = self.gl
  gl.flush()
  gl.close_window()
  if gl.drawing.is_empty() {
    gl.drawing = @cad.Drawing::new()
    return
  }
  if self.pages.length() >= HPGL_MAX_PAGES {
    self.warn_once(
      "pages",
      "only the first \{HPGL_MAX_PAGES} pages are converted",
    )
    self.stopped = true
    return
  }
  let hard = if gl.ps_set { gl.hard_rect() } else { @cad.Rect::empty() }
  let view = hpgl_invert(gl.rotation())
  let drawing = gl.take_drawing()
  self.pages.push({
    drawing,
    hard,
    view,
    marked: false,
  })
  gl.page_advanced()
  gl.open_window()
}

///|
fn HpglGl::open_window(self : HpglGl) -> Unit {
  match self.window {
    Some(window) =>
      if !window.open {
        self.drawing.begin(Some(window.path))
        window.open = true
      }
    None => ()
  }
}
