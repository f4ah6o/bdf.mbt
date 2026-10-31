///|
priv struct PdfDrawState {
  mut matrix : (Double, Double, Double, Double, Double, Double)
  mut fill : UInt32
  mut fill_space : PdfDeviceColorSpace
  mut fill_pattern : Bytes?
  mut stroke : UInt32
  mut stroke_space : PdfDeviceColorSpace
  mut stroke_pattern : Bytes?
  mut width : Double
  mut cap : Byte
  mut join : Byte
  mut miter : Double
  mut dash : Array[Double]
  mut phase : Double
  mut fill_alpha : Double
  mut stroke_alpha : Double
  mut blend : Byte
  mut font : PdfSimpleFont?
  mut font_key : Int32
  mut font_size : Double
}

///|
priv struct PdfEmittedState {
  mut fill : UInt32?
  mut stroke : UInt32?
  mut line : (Double, Byte, Byte, Double)?
  mut dash_key : String
  mut alpha : Double
  mut blend : Byte
  mut font_key : Int32
  mut font_size : Double
  mut letter_spacing : Double
}

///|
priv struct PdfGraphics {
  object : @core.ObjectBuilder
  file : PdfFile?
  mut resources : PdfObject?
  mut form_depth : Int32
  optional_content : Map[Int64, Bool]
  mut hidden : Int32
  text : PdfLimitedText
  default_font : PdfSimpleFont
  child_writer : @core.DocumentWriter
  children : Array[Bytes]
  images : Array[Bytes]
  image_hashes : Map[String, Bool]
  font_parts : Array[Bytes]
  font_hashes : Map[String, Bool]
  fonts : Map[(Int64, Int64), (PdfSimpleFont, Int32)]
  font_refs : Map[Int32, Int32]
  mut next_font_key : Int32
  mut path : PdfDrawPath
  mut state : PdfDrawState
  mut emitted : PdfEmittedState
  stack : Array[
    (
      PdfDrawState,
      PdfEmittedState,
      (Double, Double, Double, Double, Double, Int32),
    ),
  ]
  mut unsaved : Int32
  mut clip : Int32
}

///|
fn PdfDrawState::copy(self : PdfDrawState) -> PdfDrawState {
  {
    matrix: self.matrix,
    fill: self.fill,
    fill_space: self.fill_space,
    fill_pattern: self.fill_pattern,
    stroke: self.stroke,
    stroke_space: self.stroke_space,
    stroke_pattern: self.stroke_pattern,
    width: self.width,
    cap: self.cap,
    join: self.join,
    miter: self.miter,
    dash: self.dash.copy(),
    phase: self.phase,
    fill_alpha: self.fill_alpha,
    stroke_alpha: self.stroke_alpha,
    blend: self.blend,
    font: self.font,
    font_key: self.font_key,
    font_size: self.font_size,
  }
}

///|
fn PdfEmittedState::copy(self : PdfEmittedState) -> PdfEmittedState {
  {
    fill: self.fill,
    stroke: self.stroke,
    line: self.line,
    dash_key: self.dash_key,
    alpha: self.alpha,
    blend: self.blend,
    font_key: self.font_key,
    font_size: self.font_size,
    letter_spacing: self.letter_spacing,
  }
}

///|
fn PdfGraphics::new(
  width : Double,
  height : Double,
  base : (Double, Double, Double, Double, Double, Double),
  file~ : PdfFile? = None,
  resources~ : PdfObject? = None,
  optional_content~ : Map[Int64, Bool] = {},
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
    file,
    resources,
    form_depth: 0,
    optional_content,
    hidden: 0,
    text: PdfLimitedText::new(),
    default_font: match file {
      Some(value) => value.default_simple_font()
      None => pdf_default_simple_font()
    },
    child_writer: @core.DocumentWriter::new(),
    children: [],
    images: [],
    image_hashes: {},
    font_parts: [],
    font_hashes: {},
    fonts: Map([]),
    font_refs: Map([]),
    next_font_key: 1,
    path: PdfDrawPath::new(),
    state: {
      matrix: base,
      fill: 0x000000ffU,
      fill_space: PdfGray,
      fill_pattern: None,
      stroke: 0x000000ffU,
      stroke_space: PdfGray,
      stroke_pattern: None,
      width: 1.0,
      cap: 0,
      join: 0,
      miter: 10.0,
      dash: [],
      phase: 0.0,
      fill_alpha: 1.0,
      stroke_alpha: 1.0,
      blend: 0,
      font: None,
      font_key: 0,
      font_size: 0.0,
    },
    emitted: {
      fill: None,
      stroke: None,
      line: None,
      dash_key: "",
      alpha: 1.0,
      blend: 0,
      font_key: -1,
      font_size: 0.0,
      letter_spacing: 0.0,
    },
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
  let text = self.text.state
  self.stack.push(
    (
      self.state.copy(),
      self.emitted.copy(),
      (
        text.char_spacing,
        text.word_spacing,
        text.horizontal_scale,
        text.leading,
        text.rise,
        text.rendering_mode,
      ),
    ),
  )
  self.object.save()
}

///|
fn PdfGraphics::restore(self : PdfGraphics) -> Unit {
  if self.unsaved > 0 {
    self.unsaved -= 1
    return
  }
  match self.stack.pop() {
    Some((state, emitted, (character, word, scale, leading, rise, mode))) => {
      let text = self.text.state
      text.char_spacing = character
      text.word_spacing = word
      text.horizontal_scale = scale
      text.leading = leading
      text.rise = rise
      text.rendering_mode = mode
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
fn PdfGraphics::sync_stroke_color(self : PdfGraphics) -> Unit {
  if self.emitted.stroke != Some(self.state.stroke) {
    self.object.stroke_color(self.state.stroke)
    self.emitted.stroke = Some(self.state.stroke)
  }
}

///|
fn PdfGraphics::sync_line_scaled(self : PdfGraphics, factor : Double) -> Unit {
  let mut width = self.state.width * factor
  if width <= 0.0 {
    width = 0.8 / Double::max(pdf_matrix_scale(self.state.matrix), 0.000001)
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
  let dash = if factor == 1.0 {
    self.state.dash
  } else {
    self.state.dash.map(fn(value) { value * factor })
  }
  let phase = self.state.phase * factor
  let key = pdf_dash_key(dash, phase)
  if key != self.emitted.dash_key {
    let mut positive = false
    let segments = dash.map(fn(value) {
      if value > 0.0 {
        positive = true
      }
      Float::from_double(value)
    })
    self.object.dash(
      if positive {
        segments
      } else {
        []
      },
      Float::from_double(phase),
    )
    self.emitted.dash_key = key
  }
}

///|
fn PdfGraphics::sync_stroke(self : PdfGraphics) -> Unit {
  self.sync_stroke_color()
  self.sync_line_scaled(1.0)
}

///|
fn PdfGraphics::sync_alpha(self : PdfGraphics, stroke : Bool) -> Unit {
  let alpha = if stroke {
    self.state.stroke_alpha
  } else {
    self.state.fill_alpha
  }
  if self.emitted.alpha != alpha {
    self.object.alpha(Float::from_double(alpha))
    self.emitted.alpha = alpha
  }
  if self.emitted.blend != self.state.blend {
    self.object.blend(self.state.blend)
    self.emitted.blend = self.state.blend
  }
}
