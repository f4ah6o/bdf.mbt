///|
/// A KiCad conversion failure.
pub suberror KicadError {
  KicadInvalid(String)
}

///|
pub(all) struct KicadResult {
  bdf : Bytes
  pages : Int32
  summary : String
  warnings : Array[String]
}

///|
/// Detect a KiCad board or schematic.
pub fn detect(data : Bytes) -> Bool {
  let head = @utf8.decode_lossy(data[:Int::min(data.length(), 4096)].to_owned())
  head.contains("(kicad_pcb") || head.contains("(kicad_sch")
}

///|
priv enum SExpr {
  Atom(String)
  Text(String)
  List(Array[SExpr])
}

///|
fn sex_parse(text : String) -> SExpr? raise {
  let (value, _) = sex_value(text, 0)
  Some(value)
}

///|
fn sex_value(text : String, index : Int) -> (SExpr, Int) raise {
  let mut at = index
  while at < text.length() {
    let c = text[at].unsafe_to_char()
    if c == ' ' || c == '\t' || c == '\r' || c == '\n' {
      at += 1
    } else {
      break
    }
  }
  if at >= text.length() {
    raise Failure("kicad: unexpected end of s-expression")
  }
  let c = text[at].unsafe_to_char()
  if c == '(' {
    at += 1
    let values : Array[SExpr] = []
    while at < text.length() {
      let d = text[at].unsafe_to_char()
      if d == ')' {
        return (List(values), at + 1)
      }
      if d == ' ' || d == '\t' || d == '\r' || d == '\n' {
        at += 1
        continue
      }
      let (value, next) = sex_value(text, at)
      values.push(value)
      at = next
    }
    raise Failure("kicad: an s-expression is not closed")
  }
  if c == '"' {
    at += 1
    let output = StringBuilder()
    while at < text.length() {
      let d = text[at].unsafe_to_char()
      if d == '"' {
        return (Text(output.to_string()), at + 1)
      }
      if d == '\\' && at + 1 < text.length() {
        at += 1
        output.write_char(text[at].unsafe_to_char())
        at += 1
        continue
      }
      output.write_char(d)
      at += 1
    }
    raise Failure("kicad: a string is not closed")
  }
  let start = at
  while at < text.length() {
    let d = text[at].unsafe_to_char()
    if d == '(' || d == ')' || d == ' ' || d == '\t' || d == '\r' || d == '\n' {
      break
    }
    at += 1
  }
  (Atom(text[start:at].to_owned()), at)
}

///|
fn sex_head(value : SExpr) -> String {
  match value {
    List(values) =>
      if !values.is_empty() {
        sex_atom(values[0])
      } else {
        ""
      }
    _ => ""
  }
}

///|
fn sex_atom(value : SExpr) -> String {
  match value {
    Atom(text) => text
    Text(text) => text
    List(_) => ""
  }
}

///|
fn sex_child(value : SExpr, tag : String) -> SExpr? {
  match value {
    List(values) => {
      for item in values {
        if sex_head(item) == tag {
          return Some(item)
        }
      }
      None
    }
    _ => None
  }
}

///|
fn sex_children(value : SExpr, tag : String) -> Array[SExpr] {
  let output : Array[SExpr] = []
  match value {
    List(values) => {
      for item in values {
        if sex_head(item) == tag {
          output.push(item)
        }
      }
    }
    _ => ()
  }
  output
}

///|
fn sex_num(value : SExpr, tag : String, index : Int, default : Double) -> Double {
  match sex_child(value, tag) {
    Some(List(values)) =>
      if index + 1 < values.length() {
        @string.parse_double(sex_atom(values[index + 1])) catch { _ => default }
      } else {
        default
      }
    _ => default
  }
}

///|
fn sex_point(value : SExpr, tag : String) -> @cad.Point? {
  match sex_child(value, tag) {
    Some(List(values)) =>
      if values.length() >= 3 {
        let x = @string.parse_double(sex_atom(values[1])) catch { _ => 0.0 }
        let y = @string.parse_double(sex_atom(values[2])) catch { _ => 0.0 }
        Some({ x, y })
      } else {
        None
      }
    _ => None
  }
}

///|
fn sex_tag(value : SExpr, tag : String) -> String {
  match sex_child(value, tag) {
    Some(List(values)) =>
      if values.length() >= 2 {
        sex_atom(values[1])
      } else {
        ""
      }
    _ => ""
  }
}

///|
fn kicad_transform(point : @cad.Point, origin : @cad.Point, rotation : Double) -> @cad.Point {
  let angle = rotation * 3.141592653589793 / 180.0
  let x = point.x * @math.cos(angle) - point.y * @math.sin(angle)
  let y = point.x * @math.sin(angle) + point.y * @math.cos(angle)
  { x: x + origin.x, y: y + origin.y }
}

///|
fn kicad_layer_color(layer : String) -> UInt32 {
  if layer == "F.Cu" {
    0xd04040ffU
  } else if layer == "B.Cu" {
    0x4060d0ffU
  } else if layer == "Edge.Cuts" {
    0xf0e080ffU
  } else if layer == "F.SilkS" || layer == "B.SilkS" {
    0xf0f0f0ffU
  } else if layer == "F.Mask" || layer == "B.Mask" {
    0xa060c0ffU
  } else {
    0x909090ffU
  }
}

///|
fn kicad_draw_graphic(
  drawing : @cad.Drawing,
  node : SExpr,
  origin : @cad.Point,
  rotation : Double,
) -> Unit {
  let layer = sex_tag(node, "layer")
  let color = kicad_layer_color(layer)
  let width = sex_num(node, "stroke", 0, 0.1)
  let pen = @cad.Pen::new(color=color, width=Double::max(width, 0.05), cap=@cad.CAP_ROUND, join=@cad.JOIN_ROUND)
  let tag = sex_head(node)
  if tag == "segment" {
    match (sex_point(node, "start"), sex_point(node, "end")) {
      (Some(a), Some(b)) => {
        let path = @cad.CadPath::new()
        path.move_to(a.x, a.y)
        path.line_to(b.x, b.y)
        let w = sex_num(node, "width", 0, 0.2)
        drawing.stroke(path, @cad.Pen::new(color=color, width=Double::max(w, 0.05), cap=@cad.CAP_ROUND, join=@cad.JOIN_ROUND))
      }
      _ => ()
    }
  } else if tag == "via" {
    let at = sex_point(node, "at") catch { _ => None }
    match at {
      Some(point) => {
        let size = sex_num(node, "size", 0, 0.6)
        let path = @cad.CadPath::new()
        path.circle(point, size / 2.0)
        drawing.fill(path, @cad.Fill::solid(color), false)
      }
      None => ()
    }
  } else if tag == "gr_line" || tag == "fp_line" {
    match (sex_point(node, "start"), sex_point(node, "end")) {
      (Some(a), Some(b)) => {
        let path = @cad.CadPath::new()
        let ta = if tag == "fp_line" { kicad_transform(a, origin, rotation) } else { a }
        let tb = if tag == "fp_line" { kicad_transform(b, origin, rotation) } else { b }
        path.move_to(ta.x, ta.y)
        path.line_to(tb.x, tb.y)
        drawing.stroke(path, pen)
      }
      _ => ()
    }
  } else if tag == "gr_rect" || tag == "fp_rect" {
    match (sex_point(node, "start"), sex_point(node, "end")) {
      (Some(a), Some(b)) => {
        let ta = if tag == "fp_rect" { kicad_transform(a, origin, rotation) } else { a }
        let tb = if tag == "fp_rect" { kicad_transform(b, origin, rotation) } else { b }
        let path = @cad.CadPath::new()
        path.polyline([
          ta,
          { x: tb.x, y: ta.y },
          tb,
          { x: ta.x, y: tb.y },
        ], true)
        drawing.stroke(path, pen)
      }
      _ => ()
    }
  } else if tag == "gr_circle" || tag == "fp_circle" {
    match (sex_point(node, "center"), sex_point(node, "end")) {
      (Some(center), Some(end)) => {
        let c = if tag == "fp_circle" { kicad_transform(center, origin, rotation) } else { center }
        let e = if tag == "fp_circle" { kicad_transform(end, origin, rotation) } else { end }
        let path = @cad.CadPath::new()
        path.circle(c, c.sub(e).length())
        drawing.stroke(path, pen)
      }
      _ => ()
    }
  } else if tag == "gr_arc" {
    match (sex_point(node, "start"), sex_point(node, "mid"), sex_point(node, "end")) {
      (Some(a), Some(m), Some(b)) => {
        let path = @cad.CadPath::new()
        path.move_to(a.x, a.y)
        path.cubic_to(a, m, b)
        drawing.stroke(path, pen)
      }
      _ => ()
    }
  } else if tag == "gr_poly" || tag == "fp_poly" {
    match sex_child(node, "pts") {
      Some(pts) => {
        let points : Array[@cad.Point] = []
        for item in sex_children(pts, "xy") {
          match item {
            List(values) =>
              if values.length() >= 3 {
                let p : @cad.Point = {
                  x: @string.parse_double(sex_atom(values[1])) catch { _ => 0.0 },
                  y: @string.parse_double(sex_atom(values[2])) catch { _ => 0.0 },
                }
                points.push(if tag == "fp_poly" { kicad_transform(p, origin, rotation) } else { p })
              }
            _ => ()
          }
        }
        if points.length() >= 2 {
          let path = @cad.CadPath::new()
          path.polyline(points, true)
          drawing.stroke(path, pen)
        }
      }
      None => ()
    }
  }
}

///|
fn kicad_draw_footprint(drawing : @cad.Drawing, footprint : SExpr) -> Unit {
  let at = sex_point(footprint, "at")
  let (origin, rotation) = match at {
    Some(point) => (point, sex_num(footprint, "at", 2, 0.0))
    None => ({ x: 0.0, y: 0.0 }, 0.0)
  }
  for item in sex_children(footprint, "fp_line") {
    kicad_draw_graphic(drawing, item, origin, rotation)
  }
  for item in sex_children(footprint, "fp_rect") {
    kicad_draw_graphic(drawing, item, origin, rotation)
  }
  for item in sex_children(footprint, "fp_circle") {
    kicad_draw_graphic(drawing, item, origin, rotation)
  }
  for item in sex_children(footprint, "fp_poly") {
    kicad_draw_graphic(drawing, item, origin, rotation)
  }
  for pad in sex_children(footprint, "pad") {
    let at = sex_point(pad, "at")
    match at {
      Some(point) => {
        let center = kicad_transform(point, origin, rotation)
        let size = sex_child(pad, "size")
        let (w, h) = match size {
          Some(List(values)) =>
            if values.length() >= 3 {
              (
                @string.parse_double(sex_atom(values[1])) catch { _ => 0.0 },
                @string.parse_double(sex_atom(values[2])) catch { _ => 0.0 },
              )
            } else {
              (0.0, 0.0)
            }
          None => (0.0, 0.0)
          _ => (0.0, 0.0)
        }
        if w > 0.0 && h > 0.0 {
          let path = @cad.CadPath::new()
          let shape = sex_atom(
            match pad {
              List(values) => if values.length() > 2 { values[2] } else { Atom("") }
              _ => Atom("")
            },
          )
          if shape == "circle" {
            path.circle(center, w / 2.0)
          } else if shape == "oval" {
            path.ellipse(center, { x: Double::max(w, h) / 2.0, y: 0.0 }, Double::min(w, h) / Double::max(w, h))
          } else {
            path.polyline([
              { x: center.x - w / 2.0, y: center.y - h / 2.0 },
              { x: center.x + w / 2.0, y: center.y - h / 2.0 },
              { x: center.x + w / 2.0, y: center.y + h / 2.0 },
              { x: center.x - w / 2.0, y: center.y + h / 2.0 },
            ], true)
          }
          drawing.fill(path, @cad.Fill::solid(0xc08040ffU), false)
        }
      }
      None => ()
    }
  }
  for property in sex_children(footprint, "property") {
    let (name, text) = match property {
      List(values) =>
        if values.length() >= 3 {
          (sex_atom(values[1]), sex_atom(values[2]))
        } else {
          ("", "")
        }
      _ => ("", "")
    }
    if name == "Reference" || name == "Value" {
      if text != "" {
        let point = sex_point(property, "at")
        match point {
          Some(relative) => {
            let p = kicad_transform(relative, origin, rotation)
            let size = sex_num(property, "size", 0, 1.0)
            let matrix = @canvas.Matrix::translate(p.x, p.y).mul(@canvas.Matrix::scale(size, size))
            let spec = @cad.FontSpec::new()
            let choice = @canvas.Fonts::new(None).face(spec.family, spec.east_asian, text[0].to_int())
            let metrics = @canvas.Fonts::new(None).metrics(choice)
            drawing.text(@cad.CadText::new(
              text,
              matrix,
              font=spec,
              color=0xf0f0f0ffU,
              advance=text.length().to_double() * 0.55,
              asc=metrics.asc,
              desc=metrics.desc,
              cap=metrics.cap,
            ))
          }
          None => ()
        }
      }
    }
  }
}

///|
/// Convert a KiCad board into a fixed-view BDF document (front view).
pub fn convert(
  data : Bytes,
  title~ : String = "",
  db~ : @fontdb.Database? = None,
) -> KicadResult raise KicadError {
  if data.length() > 268435456 {
    raise KicadInvalid("kicad: the file is larger than 268435456 bytes")
  }
  let text = @utf8.decode_lossy(data)
  let root = sex_parse(text) catch {
    _ => raise KicadInvalid("kicad: not a KiCad s-expression")
  }
  let root = match root {
    Some(value) => value
    None => raise KicadInvalid("kicad: not a KiCad s-expression")
  }
  if sex_head(root) != "kicad_pcb" {
    raise KicadInvalid("kicad: only .kicad_pcb files are supported yet")
  }
  let drawing = @cad.Drawing::new()
  let graphic_tags = ["gr_line", "gr_rect", "gr_circle", "gr_arc", "gr_poly"]
  for tag in graphic_tags {
    for item in sex_children(root, tag) {
      kicad_draw_graphic(drawing, item, { x: 0.0, y: 0.0 }, 0.0)
    }
  }
  for item in sex_children(root, "segment") {
    kicad_draw_graphic(drawing, item, { x: 0.0, y: 0.0 }, 0.0)
  }
  for item in sex_children(root, "via") {
    kicad_draw_graphic(drawing, item, { x: 0.0, y: 0.0 }, 0.0)
  }
  for footprint in sex_children(root, "footprint") {
    kicad_draw_footprint(drawing, footprint)
  }
  let warnings : Array[String] = []
  let bounds = drawing.bounds()
  if !bounds.is_valid() {
    raise KicadInvalid("kicad: the board draws nothing")
  }
  let margin = 2.0
  let area = bounds.add({
    x: bounds.min.x - margin,
    y: bounds.min.y - margin,
  }).add({
    x: bounds.max.x + margin,
    y: bounds.max.y + margin,
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
  let meta = @cad.document_meta("kicad", title=title)
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
  let canvas = @canvas.Canvas::new()
  canvas.object().set_bbox(0.0F, 0.0F, @canvas.f32(width), @canvas.f32(height))
  canvas.object().fill_color(0x101418ffU)
  canvas.object().fill_rect(0.0F, 0.0F, @canvas.f32(width), @canvas.f32(height))
  canvas.set_drawn()
  let plotter = @cad.Plotter::new(fonts, thin=0.1 * mm)
  plotter.plot(canvas, drawing, matrix, {
    min: { x: 0.0, y: 0.0 },
    max: { x: width, y: height },
    ok: true,
  }) catch {
    error => raise KicadInvalid("kicad: " + error.to_string())
  }
  let hash = canvas.encode(writer, fonts, warnings) catch {
    error => raise KicadInvalid("kicad: " + error.to_string())
  }
  let page = @cad.page(width, height, [@cad.layer("body", hash)])
  let view_json = @cad.fixed_view([page], title=title)
  let view_map = match view_json {
    Json::Object(value) => value
    _ => Map([])
  }
  let runs : Array[@core.IndexRun] = []
  for (text, _) in drawing.texts() {
    if text != "" {
      runs.push({
        a: 0,
        b: 0,
        ordinal: runs.length(),
        separator: 2,
        text,
      })
    }
  }
  if !runs.is_empty() {
    let index_hash = writer.add_part("idx", @core.encode_text_index(runs)) catch {
      error => raise KicadInvalid("kicad: " + error.to_string())
    }
    view_map["textIndex"] = Json::string(index_hash)
  }
  writer.add_view(Json::object(view_map))
  let bdf = writer.write_single() catch {
    error => raise KicadInvalid("kicad: " + error.to_string())
  }
  {
    bdf,
    pages: 1,
    summary: "1 page (\{area.w().round().to_int()} × \{area.h().round().to_int()} mm)",
    warnings,
  }
}
