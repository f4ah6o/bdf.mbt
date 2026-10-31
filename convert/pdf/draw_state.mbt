///|
priv struct PdfDrawState {
  mut matrix : (Double, Double, Double, Double, Double, Double)
  mut fill : UInt32
  mut stroke : UInt32
  mut width : Double
  mut cap : Byte
  mut join : Byte
  mut miter : Double
}

///|
priv struct PdfEmittedState {
  mut fill : UInt32?
  mut stroke : UInt32?
  mut line : (Double, Byte, Byte, Double)?
}

///|
priv struct PdfGraphics {
  object : @core.ObjectBuilder
  mut path : PdfDrawPath
  mut state : PdfDrawState
  mut emitted : PdfEmittedState
  stack : Array[(PdfDrawState, PdfEmittedState)]
  mut unsaved : Int32
  mut clip : Int32
}

///|
fn PdfDrawState::copy(self : PdfDrawState) -> PdfDrawState {
  {
    matrix: self.matrix,
    fill: self.fill,
    stroke: self.stroke,
    width: self.width,
    cap: self.cap,
    join: self.join,
    miter: self.miter,
  }
}

///|
fn PdfEmittedState::copy(self : PdfEmittedState) -> PdfEmittedState {
  { fill: self.fill, stroke: self.stroke, line: self.line, }
}

///|
fn PdfGraphics::new(
  width : Double,
  height : Double,
  base : (Double, Double, Double, Double, Double, Double),
) -> PdfGraphics {
  let object = @core.ObjectBuilder::new()
  object.set_bbox(
    0.0F,
    0.0F,
    Float::from_double(width),
    Float::from_double(height),
  )
  let graphics : PdfGraphics = {
    object,
    path: PdfDrawPath::new(),
    state: {
      matrix: base,
      fill: 0x000000ffU,
      stroke: 0x000000ffU,
      width: 1.0,
      cap: 0,
      join: 0,
      miter: 10.0,
    },
    emitted: { fill: None, stroke: None, line: None, },
    stack: [],
    unsaved: 0,
    clip: -1,
  }
  graphics.transform(base)
  graphics
}

///|
fn PdfGraphics::transform(
  self : PdfGraphics,
  matrix : (Double, Double, Double, Double, Double, Double),
) -> Unit {
  self.state.matrix = pdf_matrix_mul(matrix, self.state.matrix)
  let (a, b, c, d, e, f) = matrix
  self.object.transform(
    Float::from_double(a),
    Float::from_double(b),
    Float::from_double(c),
    Float::from_double(d),
    Float::from_double(e),
    Float::from_double(f),
  )
}

///|
fn PdfGraphics::save(self : PdfGraphics) -> Unit {
  if self.stack.length() >= 1024 {
    self.unsaved += 1
    return
  }
  self.stack.push((self.state.copy(), self.emitted.copy()))
  self.object.save()
}

///|
fn PdfGraphics::restore(self : PdfGraphics) -> Unit {
  if self.unsaved > 0 {
    self.unsaved -= 1
    return
  }
  match self.stack.pop() {
    Some((state, emitted)) => {
      self.state = state
      self.emitted = emitted
      self.object.restore()
    }
    None => ()
  }
}

///|
fn PdfGraphics::sync_fill(self : PdfGraphics) -> Unit {
  if self.emitted.fill != Some(self.state.fill) {
    self.object.fill_color(self.state.fill)
    self.emitted.fill = Some(self.state.fill)
  }
}

///|
fn PdfGraphics::sync_stroke(self : PdfGraphics) -> Unit {
  if self.emitted.stroke != Some(self.state.stroke) {
    self.object.stroke_color(self.state.stroke)
    self.emitted.stroke = Some(self.state.stroke)
  }
  let mut width = self.state.width
  if width <= 0.0 {
    let (a, b, c, d, _, _) = self.state.matrix
    width = 0.8 / Double::max((a * d - b * c).abs().sqrt(), 0.000001)
  }
  let line = (width, self.state.cap, self.state.join, self.state.miter)
  if self.emitted.line != Some(line) {
    self.object.line(
      Float::from_double(width),
      self.state.cap,
      self.state.join,
      Float::from_double(self.state.miter),
    )
    self.emitted.line = Some(line)
  }
}
