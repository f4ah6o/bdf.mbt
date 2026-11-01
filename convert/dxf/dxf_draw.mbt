///|
priv struct DxfCtx {
  drawing : @cad.Drawing
  matrix : @canvas.Matrix
  dark : Bool
  plot : Bool
  frozen : Map[String, Bool]
  ins_layer : String
  by_block : UInt32
  fonts : @canvas.Fonts
  depth : Int
}

///|
fn dxf_aci(index : Int, dark : Bool) -> UInt32 {
  let mut value = index
  if value < 0 { value = -value }
  if value < 1 || value > 255 { value = 7 }
  let base : Array[UInt32] = [
    0x000000ffU, 0xff0000ffU, 0xffff00ffU, 0x00ff00ffU,
    0x00ffffffU, 0x0000ffffU, 0xff00ffffU, 0xffffffffU,
    0x808080ffU, 0xc0c0c0ffU,
  ]
  if value <= 9 {
    if value == 7 && !dark {
      return 0x000000ffU
    }
    return base[value]
  }
  let hue = ((value - 10) / 10).to_double() / 24.0
  let light = if (value - 10) % 10 < 5 { 0.55 } else { 0.85 }
  dxf_hsv(hue, 0.7, light)
}

///|
fn dxf_hsv(h : Double, s : Double, v : Double) -> UInt32 {
  let hh = (h - h.floor()) * 6.0
  let i = hh.to_int()
  let f = hh - i.to_double()
  let p = v * (1.0 - s)
  let q = v * (1.0 - s * f)
  let t = v * (1.0 - s * (1.0 - f))
  let (r, g, b) = match i {
    0 => (v, t, p)
    1 => (q, v, p)
    2 => (p, v, t)
    3 => (p, q, v)
    4 => (t, p, v)
    _ => (v, p, q)
  }
  ((((r * 255.0).round().to_int() << 24) |
  ((g * 255.0).round().to_int() << 16) |
  ((b * 255.0).round().to_int() << 8) |
  255).to_uint())
}

///|
fn DxfCtx::layer(self : DxfCtx, drawing : DxfDrawing, name : String) -> DxfLayer {
  let key = if name == "" { "0" } else { name.to_upper() }
  match drawing.layers.get(key) {
    Some(value) => value
    None => {
      name: if name == "" { "0" } else { name },
      color: 7,
      ltype: "CONTINUOUS",
      lineweight: -3,
      no_plot: false,
      frozen: false,
      off: false,
    }
  }
}

///|
fn DxfCtx::visible(self : DxfCtx, drawing : DxfDrawing, entity : DxfEntity) -> Bool {
  if entity.int(60, 0) == 1 {
    return false
  }
  let name = entity.str(8)
  let layer = self.layer(drawing, name)
  if layer.frozen || layer.off || self.frozen.contains(name.to_upper()) {
    return false
  }
  if name.to_upper() == "DEFPOINTS" || (self.plot && layer.no_plot) {
    return false
  }
  true
}

///|
fn DxfCtx::color(self : DxfCtx, drawing : DxfDrawing, entity : DxfEntity) -> UInt32 {
  let aci = entity.int(62, 256)
  if entity.has(420) && (!entity.has(62) || (aci != 0 && aci != 256)) {
    let value = entity.int(420, 0)
    return (((value & 0xff) << 24) | (((value >> 8) & 0xff) << 16) | (((value >> 16) & 0xff) << 8) | 255).to_uint()
  }
  if aci == 0 {
    return self.by_block
  }
  let layer = self.layer(drawing, entity.str(8))
  if aci == 256 || aci == 257 {
    dxf_aci(layer.color, self.dark)
  } else {
    dxf_aci(aci, self.dark)
  }
}

///|
fn DxfCtx::pen(self : DxfCtx, drawing : DxfDrawing, entity : DxfEntity, matrix : @canvas.Matrix) -> @cad.Pen {
  let layer = self.layer(drawing, entity.str(8))
  let mut lineweight = entity.int(370, -1)
  if lineweight == -1 {
    lineweight = layer.lineweight
  }
  if lineweight < 0 {
    lineweight = 25
  }
  let pen = @cad.Pen::new(
    color=self.color(drawing, entity),
    width=lineweight.to_double() / 100.0 * 72.0 / 25.4,
    cap=@cad.CAP_ROUND,
    join=@cad.JOIN_ROUND,
  )
  let mut ltype = entity.str(6).to_upper()
  if ltype == "" || ltype == "BYLAYER" {
    ltype = layer.ltype.to_upper()
  }
  match drawing.ltypes.get(ltype) {
    Some(elements) =>
      if !elements.is_empty() {
        let scale = entity.num(48, 1.0) * @cad.scale_of(matrix)
        let scaled : Array[Double] = []
        for value in elements {
          scaled.push(value * scale)
        }
        let (dash, offset) = @cad.dash_pattern(Some(scaled))
        pen.dash = dash
        pen.dash_offset = offset
      }
    None => ()
  }
  pen
}

///|
fn dxf_ocs(entity : DxfEntity, elevation : Double) -> @canvas.Matrix {
  let n = entity.vec3(210)
  let (x, y, z) = n
  let length = (x * x + y * y + z * z).sqrt()
  if length == 0.0 || (x == 0.0 && y == 0.0 && z > 0.0) {
    return @canvas.Matrix::identity()
  }
  let nx = x / length
  let ny = y / length
  let nz = z / length
  let (ax, ay, az) = if nx.abs() < 1.0 / 64.0 && ny.abs() < 1.0 / 64.0 {
    (ny, -nx, 0.0)
  } else {
    (ny, -nx, 0.0)
  }
  let alen = (ax * ax + ay * ay + az * az).sqrt()
  let (ux, uy, uz) = if alen == 0.0 {
    (1.0, 0.0, 0.0)
  } else {
    (ax / alen, ay / alen, az / alen)
  }
  let vx = ny * uz - nz * uy
  let vy = nz * ux - nx * uz
  let vz = nx * uy - ny * ux
  {
    a: ux,
    b: uy,
    c: vx,
    d: vy,
    e: nx * elevation,
    f: ny * elevation,
  }
}

///|
fn DxfCtx::draw_entities(self : DxfCtx, drawing : DxfDrawing, entities : Array[DxfEntity]) -> Unit {
  for entity in entities {
    self.entity(drawing, entity)
  }
}

///|
fn DxfCtx::entity(self : DxfCtx, drawing : DxfDrawing, entity : DxfEntity) -> Unit {
  if !self.visible(drawing, entity) {
    return
  }
  if entity.num(230, 1.0) < 0.0 || entity.num(220, 0.0) != 0.0 || entity.num(210, 0.0) != 0.0 {
    return
  }
  match entity.typ {
    "LINE" => {
      let path = @cad.CadPath::new()
      path.move_to(entity.num(10, 0.0), entity.num(20, 0.0))
      path.line_to(entity.num(11, 0.0), entity.num(21, 0.0))
      self.stroke(drawing, entity, path)
    }
    "LWPOLYLINE" => self.lwpolyline(drawing, entity)
    "POLYLINE" => self.polyline(drawing, entity)
    "CIRCLE" => {
      let path = @cad.CadPath::new()
      path.circle(entity.point(10), entity.num(40, 0.0))
      self.stroke(drawing, entity, path)
    }
    "ARC" => {
      let center = entity.point(10)
      let radius = entity.num(40, 0.0)
      let start = entity.num(50, 0.0) * 3.141592653589793 / 180.0
      let end = entity.num(51, 0.0) * 3.141592653589793 / 180.0
      let mut span = end - start
      while span <= 0.0 { span += 2.0 * 3.141592653589793 }
      let path = @cad.CadPath::new()
      path.arc(center, radius, start, start + span)
      self.stroke(drawing, entity, path)
    }
    "ELLIPSE" => {
      let path = @cad.CadPath::new()
      let major = entity.point(11)
      let start = entity.num(41, 0.0)
      let end = entity.num(42, 2.0 * 3.141592653589793)
      path.ellipse_arc(entity.point(10), major, entity.num(40, 1.0), start, end)
      self.stroke(drawing, entity, path)
    }
    "POINT" => {
      let point = entity.point(10)
      let path = @cad.CadPath::new()
      path.circle(point, 0.5)
      self.drawing.fill(path.transform(self.matrix), @cad.Fill::solid(self.color(drawing, entity)), false)
    }
    "SOLID" | "3DFACE" => {
      let path = @cad.CadPath::new()
      path.polyline([
        entity.point(10),
        entity.point(11),
        entity.point(13),
        entity.point(12),
      ], true)
      self.drawing.fill(path.transform(self.matrix), @cad.Fill::solid(self.color(drawing, entity)), false)
    }
    "TEXT" => self.text(drawing, entity)
    "MTEXT" => self.mtext(drawing, entity)
    "INSERT" => self.insert(drawing, entity)
    "SPLINE" => self.spline(drawing, entity)
    "HATCH" => ()
    _ => ()
  }
}

///|
fn DxfCtx::stroke(self : DxfCtx, drawing : DxfDrawing, entity : DxfEntity, path : @cad.CadPath) -> Unit {
  self.drawing.stroke(
    path.transform(self.matrix.mul(dxf_ocs(entity, entity.num(38, 0.0)))),
    self.pen(drawing, entity, self.matrix),
  )
}

///|
fn DxfCtx::lwpolyline(self : DxfCtx, drawing : DxfDrawing, entity : DxfEntity) -> Unit {
  let points : Array[@cad.Point] = []
  let bulges : Array[Double] = []
  let mut index = 0
  while index < entity.tags.length() {
    if entity.tags[index].code == 10 {
      let x = entity.tags[index].f
      let mut y = 0.0
      let mut bulge = 0.0
      let mut at = index + 1
      while at < entity.tags.length() && entity.tags[at].code != 10 {
        if entity.tags[at].code == 20 { y = entity.tags[at].f }
        if entity.tags[at].code == 42 { bulge = entity.tags[at].f }
        at += 1
      }
      points.push({ x, y })
      bulges.push(bulge)
      index = at
    } else {
      index += 1
    }
  }
  if points.is_empty() { return }
  let path = @cad.CadPath::new()
  path.move_to(points[0].x, points[0].y)
  for at in 0..<points.length() {
    let next = (at + 1) % points.length()
    if at + 1 < points.length() || (entity.int(70, 0) & 1) != 0 {
      path.bulge_to(points[next], bulges[at])
    }
  }
  if (entity.int(70, 0) & 1) != 0 { path.close() }
  self.stroke(drawing, entity, path)
}

///|
fn DxfCtx::polyline(self : DxfCtx, drawing : DxfDrawing, entity : DxfEntity) -> Unit {
  let path = @cad.CadPath::new()
  let mut first = true
  for child in entity.kids {
    let point = child.point(10)
    if first {
      path.move_to(point.x, point.y)
      first = false
    } else {
      path.bulge_to(point, child.num(42, 0.0))
    }
  }
  if (entity.int(70, 0) & 1) != 0 { path.close() }
  self.stroke(drawing, entity, path)
}

///|
fn DxfCtx::spline(self : DxfCtx, drawing : DxfDrawing, entity : DxfEntity) -> Unit {
  let points : Array[@cad.Point] = []
  let mut index = 0
  while index < entity.tags.length() {
    if entity.tags[index].code == 10 {
      let mut y = 0.0
      let mut at = index + 1
      while at < entity.tags.length() && entity.tags[at].code != 10 {
        if entity.tags[at].code == 20 { y = entity.tags[at].f }
        at += 1
      }
      points.push({ x: entity.tags[index].f, y })
      index = at
    } else {
      index += 1
    }
  }
  if points.length() < 2 { return }
  let path = @cad.CadPath::new()
  path.polyline(points, false)
  self.stroke(drawing, entity, path)
}

///|
fn dxf_face(fonts : @canvas.Fonts, spec : @cad.FontSpec, text : String) -> @fontdb.Choice {
  let code = if text == "" { 0 } else { text[0].to_int() }
  fonts.face(spec.family, spec.east_asian, code, bold=spec.bold, italic=spec.italic)
}

///|
fn dxf_text_height(entity : DxfEntity) -> Double {
  let height = entity.num(40, 0.0)
  if height > 0.0 { height } else { 2.5 }
}

///|
fn DxfCtx::text(self : DxfCtx, drawing : DxfDrawing, entity : DxfEntity) -> Unit {
  let text = entity.str(1)
  if text == "" { return }
  let height = dxf_text_height(entity)
  let angle = entity.num(50, 0.0) * 3.141592653589793 / 180.0
  let point = entity.point(10)
  let spec = @cad.FontSpec::new(family=entity.str(7))
  let matrix = self.matrix.mul(@canvas.Matrix::translate(point.x, point.y)).mul(
    @canvas.Matrix::rotate(angle * 180.0 / 3.141592653589793),
  ).mul(@canvas.Matrix::scale(height, height))
  let choice = dxf_face(self.fonts, spec, text)
  let metrics = self.fonts.metrics(choice)
  let cad_text = @cad.CadText::new(
    text,
    matrix,
    font=spec,
    color=self.color(drawing, entity),
    advance=text.length().to_double() * 0.55,
    asc=metrics.asc,
    desc=metrics.desc,
    cap=metrics.cap,
  )
  self.drawing.text(cad_text)
}

///|
fn DxfCtx::mtext(self : DxfCtx, drawing : DxfDrawing, entity : DxfEntity) -> Unit {
  let mut text = ""
  for tag in entity.tags {
    if tag.code == 3 { text += tag.s }
    if tag.code == 1 { text += tag.s }
  }
  if text == "" { return }
  let cleaned = dxf_clean_mtext(text)
  let height = dxf_text_height(entity)
  let angle = entity.num(50, 0.0) * 3.141592653589793 / 180.0
  let point = entity.point(10)
  let spec = @cad.FontSpec::new(family=entity.str(7))
  let matrix = self.matrix.mul(@canvas.Matrix::translate(point.x, point.y)).mul(
    @canvas.Matrix::rotate(angle * 180.0 / 3.141592653589793),
  ).mul(@canvas.Matrix::scale(height, height))
  let choice = dxf_face(self.fonts, spec, cleaned)
  let metrics = self.fonts.metrics(choice)
  let cad_text = @cad.CadText::new(
    cleaned,
    matrix,
    font=spec,
    color=self.color(drawing, entity),
    advance=cleaned.length().to_double() * 0.55,
    asc=metrics.asc,
    desc=metrics.desc,
    cap=metrics.cap,
  )
  self.drawing.text(cad_text)
}

///|
fn dxf_clean_mtext(text : String) -> String {
  let output = StringBuilder()
  let mut index = 0
  while index < text.length() {
    let c = text[index].unsafe_to_char()
    if c == '\\' && index + 1 < text.length() {
      let next = text[index + 1].unsafe_to_char()
      if next == 'P' {
        output.write_char('\n')
        index += 2
        continue
      }
      if next == '\\' || next == '{' || next == '}' {
        output.write_char(next)
        index += 2
        continue
      }
      if next == 'f' || next == 'F' || next == 'H' || next == 'W' || next == 'Q' ||
        next == 'T' || next == 'A' || next == 'C' || next == 'c' || next == 'p' {
        while index < text.length() && text[index] != ';' {
          index += 1
        }
        index += 1
        continue
      }
    }
    output.write_char(c)
    index += 1
  }
  output.to_string()
}

///|
fn DxfCtx::insert(self : DxfCtx, drawing : DxfDrawing, entity : DxfEntity) -> Unit {
  let name = entity.str(2).to_upper()
  match drawing.blocks.get(name) {
    None => ()
    Some(block) => {
      if self.depth > 24 { return }
      let position = entity.point(10)
      let sx = if entity.num(41, 1.0) == 0.0 { 1.0 } else { entity.num(41, 1.0) }
      let sy = if entity.num(42, 1.0) == 0.0 { 1.0 } else { entity.num(42, 1.0) }
      let rotation = entity.num(50, 0.0)
      let matrix = self.matrix.mul(
        @canvas.Matrix::translate(position.x, position.y),
      ).mul(@canvas.Matrix::rotate(rotation)).mul(
        @canvas.Matrix::translate(-block.base.x, -block.base.y),
      ).mul(@canvas.Matrix::scale(sx, sy))
      let child : DxfCtx = {
        drawing: self.drawing,
        matrix,
        dark: self.dark,
        plot: self.plot,
        frozen: self.frozen,
        ins_layer: if entity.str(8) == "" { "0" } else { entity.str(8) },
        by_block: self.color(drawing, entity),
        fonts: self.fonts,
        depth: self.depth + 1,
      }
      child.draw_entities(drawing, block.entities)
    }
  }
}
