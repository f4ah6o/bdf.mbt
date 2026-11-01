///|
/// A Gerber conversion failure.
pub suberror GerberError {
  GerberInvalid(String)
}

///|
pub(all) struct GerberResult {
  bdf : Bytes
  pages : Int32
  summary : String
  warnings : Array[String]
}

///|
/// Detect a Gerber or Excellon file.
pub fn detect(data : Bytes) -> Bool {
  let head = @utf8.decode_lossy(data[:Int::min(data.length(), 8192)].to_owned())
  head.contains("%FS") || head.contains("%MO") || head.contains("G04") ||
    head.contains("M48") || head.contains("T01C")
}

///|
priv struct GerberAperture {
  kind : String
  params : Array[Double]
  macro : String
}

///|
priv struct GerberState {
  mut xi : Int
  mut xd : Int
  mut yi : Int
  mut yd : Int
  mut trailing : Bool
  mut unit : Double
  apertures : Map[Int, GerberAperture]
  macros : Map[String, Bool]
  mut current_aperture : Int
  mut point : @cad.Point
  mut interpolate : Int
  mut multi_quadrant : Bool
  mut last_op : Int
  mut region : Bool
  mut region_path : @cad.CadPath
  mut region_start : @cad.Point
}

///|
fn gerber_state() -> GerberState {
  {
    xi: 2,
    xd: 4,
    yi: 2,
    yd: 4,
    trailing: false,
    unit: 25.4,
    apertures: Map([]),
    macros: Map([]),
    current_aperture: 0,
    point: { x: 0.0, y: 0.0 },
    interpolate: 1,
    multi_quadrant: false,
    last_op: 2,
    region: false,
    region_path: @cad.CadPath::new(),
    region_start: { x: 0.0, y: 0.0 },
  }
}

///|
fn gerber_number(text : String, integer_digits : Int, decimal_digits : Int, unit : Double, trailing : Bool) -> Double {
  let mut value = sfc_gerber_trim(text)
  if value == "" {
    return 0.0
  }
  let negative = value.has_prefix("-")
  if negative || value.has_prefix("+") {
    value = value[1:].to_owned()
  }
  if value.contains(".") {
    let number = @string.parse_double(value) catch { _ => 0.0 }
    return (if negative { -number } else { number }) * unit
  }
  let digits = integer_digits + decimal_digits
  let mut raw = value
  if !trailing {
    while raw.length() < digits {
      raw = "0" + raw
    }
  }
  let number = @string.parse_double(raw) catch { _ => 0.0 }
  let divisor = @math.pow(10.0, decimal_digits.to_double())
  if negative { -number / divisor * unit } else { number / divisor * unit }
}

///|
fn sfc_gerber_trim(value : StringView) -> String {
  let mut start = 0
  let mut end = value.length()
  while start < end && (value[start] == ' ' || value[start] == '\t' || value[start] == '\r' || value[start] == '\n') {
    start += 1
  }
  while end > start && (value[end - 1] == ' ' || value[end - 1] == '\t' || value[end - 1] == '\r' || value[end - 1] == '\n') {
    end -= 1
  }
  value[start:end].to_owned()
}

///|
fn gerber_parse_params(text : String) -> Array[Double] {
  let output : Array[Double] = []
  for part in text.split("X") {
    let item = sfc_gerber_trim(part)
    if item != "" {
      output.push(@string.parse_double(item) catch { _ => 0.0 })
    }
  }
  output
}

///|
fn gerber_define_aperture(state : GerberState, body : String) -> Unit {
  let rest = sfc_gerber_trim(body)
  let mut index = 0
  if index < rest.length() && (rest[index].unsafe_to_char() == 'D' || rest[index].unsafe_to_char() == 'd') {
    index += 1
  }
  let start = index
  while index < rest.length() && rest[index].to_int() >= '0'.to_int() && rest[index].to_int() <= '9'.to_int() {
    index += 1
  }
  if index == start { return }
  if index == 0 { return }
  let code = @string.parse_int(rest[start:index]) catch { _ => return }
  let spec = rest[index:]
  let comma = spec.find(",")
  let kind = match comma {
    Some(value) => spec[:value].to_owned()
    None => spec.to_owned()
  }
  let params = match comma {
    Some(value) => gerber_parse_params(spec[value + 1:].to_owned())
    None => []
  }
  state.apertures[code] = { kind, params, macro: "" }
}

///|
fn gerber_macro_aperture(state : GerberState, body : String) -> Unit {
  let rest = sfc_gerber_trim(body)
  let mut index = 0
  if index < rest.length() && (rest[index].unsafe_to_char() == 'D' || rest[index].unsafe_to_char() == 'd') {
    index += 1
  }
  let start = index
  while index < rest.length() && rest[index].to_int() >= '0'.to_int() && rest[index].to_int() <= '9'.to_int() {
    index += 1
  }
  if index == start { return }
  if index == 0 { return }
  let code = @string.parse_int(rest[:index]) catch { _ => return }
  let name = rest[index:].to_owned()
  state.apertures[code] = { kind: "M", params: [], macro: name }
}

///|
fn gerber_apply_extended(state : GerberState, body : String) -> GerberState {
  let command = sfc_gerber_trim(body)
  if command.has_prefix("FS") {
    let spec = command[2:]
    state.trailing = spec.contains("T")
    let x = spec.find("X")
    let y = spec.find("Y")
    match (x, y) {
      (Some(x_at), Some(y_at)) => {
        let xs = spec[x_at + 1:y_at]
        let ys = spec[y_at + 1:]
        if xs.length() >= 2 {
          state.xi = xs[0].to_int() - 48
          state.xd = xs[1].to_int() - 48
        }
        if ys.length() >= 2 {
          state.yi = ys[0].to_int() - 48
          state.yd = ys[1].to_int() - 48
        }
      }
      _ => ()
    }
  } else if command.has_prefix("MO") {
    if command.contains("MM") { state.unit = 1.0 }
    if command.contains("IN") { state.unit = 25.4 }
  } else if command.has_prefix("AD") {
    gerber_define_aperture(state, command[2:].to_owned())
  } else if command.has_prefix("AM") {
    let rest = command[2:]
    let star = rest.find("*")
    let name = match star {
      Some(value) => rest[:value].to_owned()
      None => rest.to_owned()
    }
    state.macros[name] = true
  }
  state
}

///|
fn gerber_flash(
  drawing : @cad.Drawing,
  state : GerberState,
  point : @cad.Point,
) -> Unit {
  let aperture = match state.apertures.get(state.current_aperture) {
    Some(value) => value
    None => return
  }
  let path = @cad.CadPath::new()
  if aperture.kind == "C" {
    let diameter = if aperture.params.is_empty() { 0.0 } else { aperture.params[0].abs() }
    if diameter <= 0.0 { return }
    path.circle(point, diameter / 2.0)
  } else if aperture.kind == "R" {
    let width = if aperture.params.length() > 0 { aperture.params[0].abs() } else { 0.0 }
    let height = if aperture.params.length() > 1 { aperture.params[1].abs() } else { width }
    if width <= 0.0 || height <= 0.0 { return }
    path.polyline([
      { x: point.x - width / 2.0, y: point.y - height / 2.0 },
      { x: point.x + width / 2.0, y: point.y - height / 2.0 },
      { x: point.x + width / 2.0, y: point.y + height / 2.0 },
      { x: point.x - width / 2.0, y: point.y + height / 2.0 },
    ], true)
  } else if aperture.kind == "O" {
    let width = if aperture.params.length() > 0 { aperture.params[0].abs() } else { 0.0 }
    let height = if aperture.params.length() > 1 { aperture.params[1].abs() } else { width }
    if width <= 0.0 || height <= 0.0 { return }
    path.ellipse(point, { x: Double::max(width, height) / 2.0, y: 0.0 }, Double::min(width, height) / Double::max(width, height))
  } else if aperture.kind == "P" {
    let diameter = if aperture.params.is_empty() { 0.0 } else { aperture.params[0].abs() }
    let sides = if aperture.params.length() > 1 { Int::max(aperture.params[1].to_int(), 3) } else { 6 }
    if diameter <= 0.0 { return }
    let points : Array[@cad.Point] = []
    for index in 0..<sides {
      let angle = index.to_double() * 2.0 * 3.141592653589793 / sides.to_double()
      points.push({
        x: point.x + diameter / 2.0 * @math.cos(angle),
        y: point.y + diameter / 2.0 * @math.sin(angle),
      })
    }
    path.polyline(points, true)
  } else {
    path.circle(point, 0.5)
  }
  drawing.fill(path, @cad.Fill::solid(0xffcc33ffU), false)
  let outline = @cad.CadPath::new()
  outline.append(path)
  drawing.stroke(outline, @cad.Pen::new(color=0x000000ffU, width=0.05, cap=@cad.CAP_ROUND, join=@cad.JOIN_ROUND))
}

///|
fn gerber_draw(
  drawing : @cad.Drawing,
  state : GerberState,
  from : @cad.Point,
  to : @cad.Point,
  center : @cad.Point?,
) -> Unit {
  let aperture = match state.apertures.get(state.current_aperture) {
    Some(value) => value
    None => return
  }
  let width = if aperture.params.is_empty() {
    0.2
  } else {
    aperture.params[0].abs()
  }
  let pen = @cad.Pen::new(
    color=0x000000ffU,
    width=Double::max(width, 0.05),
    cap=@cad.CAP_ROUND,
    join=@cad.JOIN_ROUND,
  )
  let path = @cad.CadPath::new()
  path.move_to(from.x, from.y)
  if state.interpolate == 2 || state.interpolate == 3 {
    match center {
      Some(center) => {
        let radius = from.sub(center).length()
        let start = @math.atan2(from.y - center.y, from.x - center.x)
        let mut end = @math.atan2(to.y - center.y, to.x - center.x)
        if state.interpolate == 2 {
          if end >= start { end -= 2.0 * 3.141592653589793 }
        } else if end <= start {
          end += 2.0 * 3.141592653589793
        }
        path.arc(center, radius, start, end)
      }
      None => path.line_to(to.x, to.y)
    }
  } else {
    path.line_to(to.x, to.y)
  }
  drawing.stroke(path, pen)
}

///|
fn gerber_run(data : Bytes) -> (@cad.Drawing, Array[String]) raise {
  let text = @utf8.decode_lossy(data)
  let drawing = @cad.Drawing::new()
  let mut state = gerber_state()
  let warnings : Array[String] = []
  let mut index = 0
  while index < text.length() {
    let c = text[index].unsafe_to_char()
    if c == '%' {
      let close = text[index + 1:].find("%")
      match close {
        None => break
        Some(offset) => {
          let body = text[index + 1:index + 1 + offset].to_owned()
          for part in body.split("*") {
            let command = sfc_gerber_trim(part)
            if command != "" {
              state = gerber_apply_extended(state, command)
            }
          }
          index += offset + 2
        }
      }
    } else if c == ' ' || c == '\t' || c == '\r' || c == '\n' {
      index += 1
    } else {
      let close = text[index:].find("*")
      match close {
        None => break
        Some(offset) => {
          let word = sfc_gerber_trim(text[index:index + offset])
          state = gerber_word(drawing, state, word, warnings)
          index += offset + 1
        }
      }
    }
  }
  (drawing, warnings)
}

///|
fn gerber_word(
  drawing : @cad.Drawing,
  state : GerberState,
  word : String,
  warnings : Array[String],
) -> GerberState {
  if word == "" || word == "M02" || word == "M00" || word == "M01" { return state }
  let mut index = 0
  let mut x = state.point.x
  let mut y = state.point.y
  let mut i_value = 0.0
  let mut j_value = 0.0
  let mut has_xy = false
  let mut op = 0
  while index < word.length() {
    let c = word[index].unsafe_to_char()
    if c == 'G' || c == 'D' || c == 'X' || c == 'Y' || c == 'I' || c == 'J' {
      let start = index + 1
      let mut end = start
      while end < word.length() {
        let d = word[end].unsafe_to_char()
        if (d >= '0' && d <= '9') || d == '-' || d == '+' || d == '.' {
          end += 1
        } else {
          break
        }
      }
      let value = word[start:end]
      if c == 'G' {
        let number = @string.parse_int(value) catch { _ => 0 }
        if number == 1 { state.interpolate = 1 }
        if number == 2 { state.interpolate = 2 }
        if number == 3 { state.interpolate = 3 }
        if number == 36 {
          state.region = true
          state.region_path = @cad.CadPath::new()
        }
        if number == 37 {
          if state.region {
            drawing.fill(state.region_path, @cad.Fill::solid(0x000000ffU), !state.region_path.is_empty())
            state.region = false
          }
        }
        if number == 75 { state.multi_quadrant = true }
      } else if c == 'D' {
        let number = @string.parse_int(value) catch { _ => 0 }
        if number >= 10 {
          state.current_aperture = number
        } else if number >= 1 && number <= 3 {
          op = number
        }
      } else if c == 'X' {
        x = gerber_number(value.to_owned(), state.xi, state.xd, state.unit, state.trailing)
        has_xy = true
      } else if c == 'Y' {
        y = gerber_number(value.to_owned(), state.yi, state.yd, state.unit, state.trailing)
        has_xy = true
      } else if c == 'I' {
        i_value = gerber_number(value.to_owned(), state.xi, state.xd, state.unit, state.trailing)
      } else if c == 'J' {
        j_value = gerber_number(value.to_owned(), state.yi, state.yd, state.unit, state.trailing)
      }
      index = end
    } else {
      index += 1
    }
  }
  if op == 0 {
    op = if has_xy { state.last_op } else { 0 }
  }
  if op == 0 { return state }
  state.last_op = op
  let target : @cad.Point = { x, y }
  if state.region {
    if op == 2 {
      state.region_path.move_to(target.x, target.y)
      state.region_start = target
    } else if op == 1 {
      if state.region_path.is_empty() {
        state.region_path.move_to(state.point.x, state.point.y)
        state.region_start = state.point
      }
      state.region_path.line_to(target.x, target.y)
    } else if op == 3 {
      state.region_path.move_to(target.x, target.y)
      state.region_start = target
    }
    state.point = target
    return state
  }
  if op == 2 {
    state.point = target
  } else if op == 3 {
    gerber_flash(drawing, state, target)
    state.point = target
  } else if op == 1 {
    let center : @cad.Point? = if state.interpolate == 2 || state.interpolate == 3 {
      Some({ x: state.point.x + i_value, y: state.point.y + j_value })
    } else {
      None
    }
    gerber_draw(drawing, state, state.point, target, center)
    state.point = target
  }
  let _ = warnings
  state
}

///|
/// Convert a single Gerber file into a fixed-view BDF document.
pub fn convert(
  data : Bytes,
  title~ : String = "",
  db~ : @fontdb.Database? = None,
) -> GerberResult raise GerberError {
  if data.length() > 1073741824 {
    raise GerberInvalid("gerber: the file is larger than 1073741824 bytes")
  }
  let (drawing, warnings) = gerber_run(data) catch {
    Failure(message) => raise GerberInvalid(message)
    _ => raise GerberInvalid("gerber: not a Gerber file")
  }
  let bounds = drawing.bounds()
  if !bounds.is_valid() {
    raise GerberInvalid("gerber: the file draws nothing")
  }
  let grow = Double::max(1.0, 0.03 * Double::max(bounds.w(), bounds.h()))
  let area = bounds.add({
    x: bounds.min.x - grow,
    y: bounds.min.y - grow,
  }).add({
    x: bounds.max.x + grow,
    y: bounds.max.y + grow,
  })
  let mm = 72.0 / 25.4
  let width = area.w() * mm
  let height = area.h() * mm
  let matrix : @canvas.Matrix = {
    a: mm,
    b: 0.0,
    c: 0.0,
    d: -mm,
    e: -area.min.x * mm,
    f: area.max.y * mm,
  }
  let fonts = @canvas.Fonts::new(db)
  let meta = @cad.document_meta("gerber", title=title)
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
  let canvas = @canvas.Canvas::new()
  canvas.object().set_bbox(0.0F, 0.0F, @canvas.f32(width), @canvas.f32(height))
  canvas.object().fill_color(0x202830ffU)
  canvas.object().fill_rect(0.0F, 0.0F, @canvas.f32(width), @canvas.f32(height))
  canvas.set_drawn()
  let plotter = @cad.Plotter::new(fonts, thin=0.1 * mm)
  plotter.plot(canvas, drawing, matrix, {
    min: { x: 0.0, y: 0.0 },
    max: { x: width, y: height },
    ok: true,
  }) catch {
    error => raise GerberInvalid("gerber: " + error.to_string())
  }
  let hash = canvas.encode(writer, fonts, warnings) catch {
    error => raise GerberInvalid("gerber: " + error.to_string())
  }
  let page = @cad.page(width, height, [@cad.layer("body", hash)])
  writer.add_view(@cad.fixed_view([page], title=title))
  let bdf = writer.write_single() catch {
    error => raise GerberInvalid("gerber: " + error.to_string())
  }
  {
    bdf,
    pages: 1,
    summary: "1 page (\{area.w().round().to_int()} × \{area.h().round().to_int()} mm)",
    warnings,
  }
}
