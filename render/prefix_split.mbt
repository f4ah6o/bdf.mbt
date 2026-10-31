///|
priv struct PrefixSplit {
  prefix : @core.ObjectBuilder
  rest : @core.ObjectBuilder
  prefix_fonts : Array[Int32]
  rest_fonts : Array[Int32]
  prefix_children : Array[Int32]
  rest_children : Array[Int32]
}

///|
priv struct PrefixState {
  mut matrix : (Float, Float, Float, Float, Float, Float)
  mut has_matrix : Bool
  mut fill : InstructionSpan?
  mut stroke : InstructionSpan?
  mut line : InstructionSpan?
  mut dash : InstructionSpan?
  mut alpha : InstructionSpan?
  mut blend : InstructionSpan?
  mut font : InstructionSpan?
  mut text_style : InstructionSpan?
  mut smoothing : InstructionSpan?
}

///|
fn PrefixState::new() -> PrefixState {
  {
    matrix: (1.0F, 0.0F, 0.0F, 1.0F, 0.0F, 0.0F),
    has_matrix: false,
    fill: None,
    stroke: None,
    line: None,
    dash: None,
    alpha: None,
    blend: None,
    font: None,
    text_style: None,
    smoothing: None,
  }
}

///|
// Upstream calculates the matrix in float32; Go on arm64 fuses the first
// multiply-add, while the other product is rounded first.
fn prefix_mul_add(a : Float, b : Float, c : Float, d : Float) -> Float {
  let other = Float::from_double(c.to_double() * d.to_double())
  Float::from_double(
    @core.fused_multiply_add(a.to_double(), b.to_double(), other.to_double()),
  )
}

///|
fn PrefixState::multiply(
  self : PrefixState,
  rhs : (Float, Float, Float, Float, Float, Float),
) -> Unit {
  let (a, b, c, d, e, f) = self.matrix
  let (g, h, i, j, k, l) = rhs
  self.matrix = (
    prefix_mul_add(a, g, c, h),
    prefix_mul_add(b, g, d, h),
    prefix_mul_add(a, i, c, j),
    prefix_mul_add(b, i, d, j),
    Float::from_double((prefix_mul_add(a, k, c, l) + e).to_double()),
    Float::from_double((prefix_mul_add(b, k, d, l) + f).to_double()),
  )
  self.has_matrix = true
}

///|
fn PrefixState::apply(
  self : PrefixState,
  span : InstructionSpan,
  depth : Int32,
) -> Unit {
  if depth != 0 {
    return
  }
  let f = fn(value : Double) { Float::from_double(value) }
  match span.command {
    Transform(a, b, c, d, e, g) =>
      self.multiply((f(a), f(b), f(c), f(d), f(e), f(g)))
    Translate(x, y) => self.multiply((1.0F, 0.0F, 0.0F, 1.0F, f(x), f(y)))
    Scale(x, y) => self.multiply((f(x), 0.0F, 0.0F, f(y), 0.0F, 0.0F))
    FillColor(_) | FillPaint(_) => self.fill = Some(span)
    StrokeColor(_) | StrokePaint(_) => self.stroke = Some(span)
    Line(_, _, _, _) => self.line = Some(span)
    Dash(_, _) => self.dash = Some(span)
    Alpha(_) => self.alpha = Some(span)
    Blend(_) => self.blend = Some(span)
    Font(_, _) => self.font = Some(span)
    TextStyle(_, _, _, _) => self.text_style = Some(span)
    Smoothing(_, _) => self.smoothing = Some(span)
    _ => ()
  }
}

///|
fn PrefixState::emit(self : PrefixState, replay : PrefixReplay) -> Unit raise {
  if self.has_matrix && self.matrix != (1.0F, 0.0F, 0.0F, 1.0F, 0.0F, 0.0F) {
    let (a, b, c, d, e, f) = self.matrix
    replay.target.transform(a, b, c, d, e, f)
  }
  for
    span in [
      self.fill,
      self.stroke,
      self.line,
      self.dash,
      self.alpha,
      self.blend,
      self.font,
      self.text_style,
      self.smoothing,
    ] {
    if span is Some(value) {
      replay.emit(value)
    }
  }
}

///|
fn split_prefix(
  source : @core.ObjectResources,
  child_boxes : Array[(Float, Float, Float, Float)],
  cut : PrefixCut,
) -> PrefixSplit raise {
  let spans = instruction_spans(source.object)
  if !prefix_cut_points(spans).any(fn(point) {
      point.instruction == cut.instruction && point.offset == cut.offset
    }) {
    raise InvalidOperands("invalid prefix cut")
  }
  let prefix = PrefixReplay::new(source, child_boxes)
  let state = PrefixState::new()
  let mut depth = 0
  for i in 0..<cut.instruction {
    let span = spans[i]
    state.apply(span, depth)
    match span.command {
      Save | GroupBegin(_, _, _, _, _, _) | MaskBegin(_, _, _) => depth += 1
      Restore | GroupEnd | MaskEnd => depth -= 1
      _ => ()
    }
    prefix.emit(span)
  }
  let rest = PrefixReplay::new(source, child_boxes)
  let (x, y, w, h) = source.object.bbox
  ignore(
    rest.target.add_object(
      "00000000000000000000000000000000",
      (
        Float::from_double(x),
        Float::from_double(y),
        Float::from_double(w),
        Float::from_double(h),
      ),
    ),
  )
  rest.child_refs.push(-1)
  rest.target.use_object(0)
  state.emit(rest)
  for i in cut.instruction..<spans.length() {
    rest.emit(spans[i])
  }
  {
    prefix: prefix.target,
    rest: rest.target,
    prefix_fonts: prefix.font_refs,
    rest_fonts: rest.font_refs,
    prefix_children: prefix.child_refs,
    rest_children: rest.child_refs,
  }
}
