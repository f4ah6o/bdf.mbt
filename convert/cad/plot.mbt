///|
/// Drawings are plotted onto BDF pages: line widths are widths on paper,
/// whatever the scale of the drawing.
pub(all) struct Plotter {
  fonts : @canvas.Fonts
  thin : Double
}

///|
pub fn Plotter::new(fonts : @canvas.Fonts, thin~ : Double = 0.5) -> Plotter {
  { fonts, thin }
}

///|
pub fn Plotter::fonts(self : Plotter) -> @canvas.Fonts {
  self.fonts
}

///|
priv struct PlotState {
  mut fill : UInt32
  mut stroke : UInt32
  mut fill_set : Bool
  mut stroke_set : Bool
  mut width : Double
  mut miter : Double
  mut cap : Byte
  mut join : Byte
  mut line_set : Bool
  mut dash : Array[Double]?
  mut dash_offset : Double
  mut dash_set : Bool
  mut font : Int32
  mut size : Double
  mut font_set : Bool
}

///|
/// A copy of the state, for save: `PlotState` holds mutable fields, so
/// pushing `self.state` itself would let later changes rewrite the saved
/// state and leave the plotter's cache out of step with the canvas.
fn PlotState::copy(self : PlotState) -> PlotState {
  {
    fill: self.fill,
    stroke: self.stroke,
    fill_set: self.fill_set,
    stroke_set: self.stroke_set,
    width: self.width,
    miter: self.miter,
    cap: self.cap,
    join: self.join,
    line_set: self.line_set,
    dash: self.dash,
    dash_offset: self.dash_offset,
    dash_set: self.dash_set,
    font: self.font,
    size: self.size,
    font_set: self.font_set,
  }
}

///|
fn plot_state() -> PlotState {
  {
    fill: 0x000000ffU,
    stroke: 0x000000ffU,
    fill_set: false,
    stroke_set: false,
    width: 1.0,
    miter: 10.0,
    cap: CAP_BUTT,
    join: JOIN_MITER,
    line_set: false,
    dash: None,
    dash_offset: 0.0,
    dash_set: false,
    font: 0,
    size: 12.0,
    font_set: false,
  }
}

///|
priv struct PlotContext {
  plotter : Plotter
  canvas : @canvas.Canvas
  mut state : PlotState
  stack : Array[PlotState]
  view : Rect
}

///|
/// Draw `drawing` into `canvas`; `matrix` maps drawing coordinates into the
/// page (pt, y down). Items wholly outside `view` are left out.
pub fn Plotter::plot(
  self : Plotter,
  canvas : @canvas.Canvas,
  drawing : Drawing,
  matrix : @canvas.Matrix,
  view : Rect,
) -> Unit raise {
  let context : PlotContext = {
    plotter: self,
    canvas,
    state: plot_state(),
    stack: [],
    view,
  }
  for item in drawing.items {
    context.item(item, matrix)
  }
}

///|
fn PlotContext::save(self : PlotContext) -> Unit {
  self.canvas.save()
  self.stack.push(self.state.copy())
}

///|
fn PlotContext::restore(self : PlotContext) -> Unit {
  self.canvas.restore()
  if !self.stack.is_empty() {
    self.state = self.stack.pop().unwrap()
  }
}

///|
fn PlotContext::visible(self : PlotContext, bounds : Rect, matrix : @canvas.Matrix) -> Bool {
  if !self.view.is_valid() {
    return true
  }
  if !bounds.is_valid() {
    return false
  }
  let page = bounds.transform(matrix)
  let margin = 10.0
  page.max.x >= self.view.min.x - margin &&
  page.min.x <= self.view.max.x + margin &&
  page.max.y >= self.view.min.y - margin &&
  page.min.y <= self.view.max.y + margin
}

///|
fn PlotContext::item(self : PlotContext, item : Item, matrix : @canvas.Matrix) -> Unit raise {
  if !self.visible(item.bounds, matrix) {
    return
  }
  match item.kind {
    StrokeItem => self.stroke_item(item, matrix)
    FillItem => self.fill_item(item, matrix)
    TextItem =>
      match item.text {
        Some(text) => self.text(text, matrix)
        None => ()
      }
    StrokeTextItem =>
      match item.stroke_text {
        Some(text) => self.stroke_text(text, matrix)
        None => ()
      }
    ImageItem =>
      match item.image {
        Some(image) => self.image(image, matrix)
        None => ()
      }
    GroupItem => {
      self.save()
      match item.clip {
        Some(clip) => self.canvas.clip_path(to_path(clip, matrix), 1)
        None => ()
      }
      for child in item.items {
        self.item(child, matrix)
      }
      self.restore()
    }
  }
}

///|
fn to_path(path : CadPath, matrix : @canvas.Matrix) -> @core.Path {
  let verbs : Array[Byte] = []
  let coordinates : Array[Double] = []
  let mut point_index = 0
  for verb in path.verbs {
    verbs.push(verb)
    let count = if verb == CUBIC_TO { 3 } else if verb == CLOSE_PATH { 0 } else { 1 }
    for offset in 0..<count {
      let point = apply(matrix, path.points[point_index + offset])
      coordinates.push(@canvas.f32(point.x).to_double())
      coordinates.push(@canvas.f32(point.y).to_double())
    }
    point_index += count
  }
  { verbs: Bytes::from_array(verbs), coordinates }
}

///|
fn PlotContext::stroke_item(
  self : PlotContext,
  item : Item,
  matrix : @canvas.Matrix,
) -> Unit raise {
  let pen = match item.pen {
    Some(value) => value
    None => return
  }
  let path = match item.path {
    Some(value) => value
    None => return
  }
  let scale = scale_of(matrix)
  let mut width = pen.width
  if pen.world_width > 0.0 {
    width = pen.world_width * scale
  }
  if width <= 0.0 {
    width = self.plotter.thin
  }
  let mut dash : Array[Double]? = None
  let mut offset = 0.0
  let mut cap = pen.cap
  match pen.dash {
    Some(values) if !values.is_empty() => {
      let scaled : Array[Double] = []
      let mut total = 0.0
      let mut dots = false
      for value in values {
        let length = value.abs() * scale
        scaled.push(length)
        total += length
        if length == 0.0 {
          dots = true
        }
      }
      if total < Double::max(width * 2.0, 0.2) || total > 1.0e6 {
        dash = None
      } else {
        dash = Some(scaled)
        offset = pen.dash_offset * scale
        if dots {
          // A dot is drawn as a round cap of zero length.
          cap = CAP_ROUND
        }
      }
    }
    _ => ()
  }
  self.set_stroke(pen.color)
  self.set_line(width, cap, pen.join, pen.miter)
  self.set_dash(dash, offset)
  let object = self.canvas.object()
  object.stroke_path(object.add_path(@core.Inline(to_path(path, matrix))))
  self.canvas.set_drawn()
}

///|
fn PlotContext::fill_item(
  self : PlotContext,
  item : Item,
  matrix : @canvas.Matrix,
) -> Unit raise {
  let fill = match item.fill {
    Some(value) => value
    None => return
  }
  let path = match item.path {
    Some(value) => value
    None => return
  }
  let rule : Byte = if item.even_odd { 1 } else { 0 }
  match fill.gradient {
    Some(gradient) if !gradient.stops.is_empty() => {
      let scale = scale_of(matrix)
      let p0 = apply(matrix, gradient.p0)
      let p1 = apply(matrix, gradient.p1)
      let mut coordinates : Array[Double] = []
      if gradient.radial {
        coordinates = [
          p0.x, p0.y, gradient.r0 * scale, p1.x, p1.y, gradient.r1 * scale,
        ]
      } else {
        coordinates = [p0.x, p0.y, p1.x, p1.y]
      }
      let paint = @core.Gradient(
        if gradient.radial { 1 } else { 0 },
        coordinates,
        gradient.stops,
      )
      let object = self.canvas.object()
      let index = object.add_paint(paint)
      object.fill_paint(index)
      self.state.fill_set = false
      object.fill_path(object.add_path(@core.Inline(to_path(path, matrix))), rule)
      self.canvas.set_drawn()
      return
    }
    _ => ()
  }
  match fill.pattern {
    Some(pattern) => {
      let object = self.canvas.object()
      let paint = @core.Pattern(
        self.canvas.image(pattern.image),
        1,
        matrix_to_array(matrix.mul(pattern.m)),
      )
      if !pattern.smooth {
        self.save()
        object.smoothing(false, 0)
      }
      let index = object.add_paint(paint)
      object.fill_paint(index)
      self.state.fill_set = false
      object.fill_path(object.add_path(@core.Inline(to_path(path, matrix))), rule)
      if !pattern.smooth {
        self.restore()
      }
      self.canvas.set_drawn()
      return
    }
    None => ()
  }
  self.set_fill(fill.color)
  let object = self.canvas.object()
  object.fill_path(object.add_path(@core.Inline(to_path(path, matrix))), rule)
  self.canvas.set_drawn()
}

///|
fn matrix_to_array(matrix : @canvas.Matrix) -> Array[Double] {
  [matrix.a, matrix.b, matrix.c, matrix.d, matrix.e, matrix.f]
}

///|
fn PlotContext::image(
  self : PlotContext,
  image : CadImage,
  matrix : @canvas.Matrix,
) -> Unit raise {
  self.save()
  self.canvas.transform(matrix.mul(image.m))
  if !image.smooth {
    self.canvas.object().smoothing(false, 0)
  }
  self.canvas.object().image(
    self.canvas.image(image.image),
    0.0F,
    0.0F,
    Float::from_double(image.width.to_double()),
    Float::from_double(image.height.to_double()),
  )
  self.restore()
  self.canvas.set_drawn()
}

///|
fn PlotContext::set_fill(self : PlotContext, color : UInt32) -> Unit {
  if !self.state.fill_set || self.state.fill != color {
    self.canvas.object().fill_color(color)
    self.state.fill = color
    self.state.fill_set = true
  }
}

///|
fn PlotContext::set_stroke(self : PlotContext, color : UInt32) -> Unit {
  if !self.state.stroke_set || self.state.stroke != color {
    self.canvas.object().stroke_color(color)
    self.state.stroke = color
    self.state.stroke_set = true
  }
}

///|
fn PlotContext::set_line(
  self : PlotContext,
  width : Double,
  cap : Byte,
  join : Byte,
  miter : Double,
) -> Unit {
  let miter = if miter <= 0.0 { 10.0 } else { miter }
  if !self.state.line_set ||
    self.state.width != width ||
    self.state.cap != cap ||
    self.state.join != join ||
    self.state.miter != miter {
    self.canvas.object().line(
      @canvas.f32(width),
      cap,
      join,
      @canvas.f32(miter),
    )
    self.state.width = width
    self.state.cap = cap
    self.state.join = join
    self.state.miter = miter
    self.state.line_set = true
  }
}

///|
fn dash_equal(left : Array[Double]?, right : Array[Double]?) -> Bool {
  match (left, right) {
    (None, None) => true
    (Some(a), Some(b)) => {
      if a.length() != b.length() {
        return false
      }
      for index, value in a {
        if value != b[index] {
          return false
        }
      }
      true
    }
    _ => false
  }
}

///|
fn PlotContext::set_dash(
  self : PlotContext,
  dash : Array[Double]?,
  offset : Double,
) -> Unit {
  if self.state.dash_set && dash_equal(self.state.dash, dash) &&
    self.state.dash_offset == offset {
    return
  }
  if !self.state.dash_set && dash is None {
    return
  }
  let segments : Array[Float] = []
  match dash {
    Some(values) => {
      for value in values {
        segments.push(@canvas.f32(value))
      }
    }
    None => ()
  }
  self.canvas.object().dash(segments, @canvas.f32(offset))
  self.state.dash = dash
  self.state.dash_offset = offset
  self.state.dash_set = true
}

///|
fn PlotContext::set_font(self : PlotContext, index : Int32, size : Double) -> Unit raise {
  if !self.state.font_set || self.state.font != index || self.state.size != size {
    self.canvas.object().font(index, @canvas.f32(size))
    self.state.font = index
    self.state.size = size
    self.state.font_set = true
  }
}

///|
priv struct TextRun {
  choice : @fontdb.Choice
  chars : Array[Int32]
  text : StringBuilder
  x : Double
  mut w : Double
}

///|
fn PlotContext::text(self : PlotContext, text : CadText, matrix : @canvas.Matrix) -> Unit raise {
  // Canvas text space (y down) to the page.
  let tm = matrix.mul(text.m).mul(@canvas.Matrix::scale(1.0, -1.0))
  let ex = @math.hypot(tm.a, tm.b)
  let det = tm.a * tm.d - tm.b * tm.c
  if ex < 1.0e-9 {
    return
  }
  let size = det.abs() / ex
  if size < 1.0e-3 || size > 1.0e5 || size.is_nan() {
    return
  }
  let hx = ex / size
  let norm : @canvas.Matrix = {
    a: tm.a / ex,
    b: tm.b / ex,
    c: tm.c / size,
    d: tm.d / size,
    e: tm.e,
    f: tm.f,
  }
  let fonts = self.plotter.fonts
  let runs : Array[TextRun] = []
  let mut x = 0.0
  let mut index = 0
  for character in text.s {
    let code = character.to_int()
    let choice = fonts.face(
      text.font.family,
      text.font.east_asian,
      code,
      bold=text.font.bold,
      italic=text.font.italic,
    )
    let mut advance = fonts.advance(choice, code)
    match text.cells {
      Some(cells) => {
        advance = if index < cells.length() { cells[index] } else { 0.0 }
      }
      None => ()
    }
    advance += text.spacing
    let key = @canvas.choice_key(choice)
    let mut found = false
    if !runs.is_empty() {
      let last = runs[runs.length() - 1]
      if @canvas.choice_key(last.choice) == key {
        last.chars.push(code)
        last.text.write_char(character)
        last.w += advance
        found = true
      }
    }
    if !found {
      let run : TextRun = {
        choice,
        chars: [code],
        text: StringBuilder(),
        x,
        w: advance,
      }
      run.text.write_char(character)
      runs.push(run)
    }
    x += advance
    index += 1
  }
  self.save()
  self.canvas.transform(norm)
  if text.vertical {
    self.vertical(text, runs, size, hx, x)
    self.restore()
    return
  }
  match text.line_break {
    BreakBox => self.canvas.object().mark(3, "")
    BreakParagraph => self.canvas.object().mark(0, "")
    BreakLine => self.canvas.object().mark(1, "")
    BreakWrap => self.canvas.object().mark(5, "")
    BreakNone => ()
  }
  let k = size * hx
  if text.spacing != 0.0 {
    self.canvas.object().text_style(0, 0, 0, @canvas.f32(text.spacing * k))
  }
  for run in runs {
    let value = run.text.to_string()
    if is_blank(value) {
      continue
    }
    self.set_lang(run.chars)
    let font_index = self.canvas.font(run.choice, run.chars)
    self.set_font(font_index, size)
    self.set_fill(text.color)
    self.canvas.object().fill_text(
      value,
      @canvas.f32(run.x * k),
      0.0F,
      @canvas.f32(run.w * k),
    )
    self.canvas.set_drawn()
  }
  if text.underline || text.overline || text.strike {
    let (ul_pos, ul_thick) = underline_metrics(fonts, text.font)
    let thickness = Double::max(ul_thick, 0.04) * size
    let width = x * k
    self.set_fill(text.color)
    if text.underline {
      self.canvas.object().fill_rect(
        0.0F,
        @canvas.f32(-ul_pos * size),
        @canvas.f32(width),
        @canvas.f32(thickness),
      )
    }
    if text.overline {
      self.canvas.object().fill_rect(
        0.0F,
        @canvas.f32(-(text.cap + 0.15) * size - thickness),
        @canvas.f32(width),
        @canvas.f32(thickness),
      )
    }
    if text.strike {
      self.canvas.object().fill_rect(
        0.0F,
        @canvas.f32(-text.cap * 0.5 * size),
        @canvas.f32(width),
        @canvas.f32(thickness),
      )
    }
  }
  self.restore()
}

///|
fn is_blank(value : String) -> Bool {
  for character in value {
    if !character.is_whitespace() {
      return false
    }
  }
  true
}

///|
fn PlotContext::set_lang(self : PlotContext, chars : Array[Int32]) -> Unit {
  let mut cjk = false
  for code in chars {
    if @fontdb.is_cjk(code) {
      cjk = true
      break
    }
  }
  if cjk {
    let mut language = ""
    for code in chars {
      language = rune_lang(code)
      if language != "" {
        break
      }
    }
    if language == "" && script_of(self.canvas.lang()) != "" {
      return
    }
    self.canvas.set_lang(language)
  } else {
    self.canvas.set_lang("")
  }
}

///|
fn PlotContext::vertical(
  self : PlotContext,
  text : CadText,
  runs : Array[TextRun],
  size : Double,
  hx : Double,
  total : Double,
) -> Unit raise {
  let k = size * hx
  let bbox : (Float, Float, Float, Float) = (
    0.0F,
    @canvas.f32(-size / 2.0),
    @canvas.f32(total * k),
    @canvas.f32(size),
  )
  let (child, reference) = self.canvas.child(bbox)
  child.object().set_bbox(
    0.0F,
    @canvas.f32(-size),
    @canvas.f32(total * k),
    @canvas.f32(2.0 * size),
  )
  let sub : PlotContext = {
    plotter: self.plotter,
    canvas: child,
    state: plot_state(),
    stack: [],
    view: Rect::empty(),
  }
  let fonts = self.plotter.fonts
  let mut x = 0.0
  for run in runs {
    let mut natural = 0.0
    for code in run.chars {
      natural += fonts.advance(run.choice, code) + text.spacing
    }
    for code in run.chars {
      let mut cell = fonts.advance(run.choice, code) + text.spacing
      if natural > 0.0 {
        cell *= run.w / natural
      }
      let advance = fonts.advance(run.choice, code)
      if !code_is_space(code) {
        sub.save()
        child.transform(
          @canvas.Matrix::translate((x + cell / 2.0) * k, 0.0).mul(
            @canvas.Matrix::rotate(-90.0),
          ),
        )
        sub.set_lang([code])
        let font_index = child.font(run.choice, [code])
        sub.set_font(font_index, size)
        sub.set_fill(text.color)
        child.object().fill_text(
          code.unsafe_to_char().to_string(),
          @canvas.f32(-advance * size / 2.0),
          @canvas.f32(0.38 * size),
          @canvas.f32(advance * size),
        )
        child.set_drawn()
        sub.restore()
      }
      x += cell
    }
  }
  match text.line_break {
    BreakBox => self.canvas.object().mark(3, "")
    BreakParagraph => self.canvas.object().mark(0, "")
    BreakLine => self.canvas.object().mark(1, "")
    BreakWrap => self.canvas.object().mark(5, "")
    BreakNone => ()
  }
  if !runs.is_empty() {
    self.set_lang(runs[0].chars)
    let font_index = self.canvas.font(runs[0].choice, runs[0].chars)
    self.set_font(font_index, size)
  }
  self.canvas.object().mark(4, text.s)
  self.canvas.object().use_object_at(reference, 0.0F, 0.0F)
  self.canvas.used(child)
  self.canvas.set_drawn()
}

///|
fn code_is_space(code : Int32) -> Bool {
  code == 32 || code == 9 || code == 10 || code == 13
}

///|
fn PlotContext::stroke_text(
  self : PlotContext,
  text : CadStrokeText,
  matrix : @canvas.Matrix,
) -> Unit raise {
  let pm = matrix.mul(text.m)
  let linear : @canvas.Matrix = {
    a: pm.a,
    b: pm.b,
    c: pm.c,
    d: pm.d,
    e: 0.0,
    f: 0.0,
  }
  let bounds = text_bounds(text).transform(linear)
  if !bounds.is_valid() {
    return
  }
  let bbox : (Float, Float, Float, Float) = (
    @canvas.f32(bounds.min.x),
    @canvas.f32(bounds.min.y),
    @canvas.f32(bounds.w()),
    @canvas.f32(bounds.h()),
  )
  let (child, reference) = self.canvas.child(bbox)
  child.object().set_bbox(bbox.0, bbox.1, bbox.2, bbox.3)
  let sub : PlotContext = {
    plotter: self.plotter,
    canvas: child,
    state: plot_state(),
    stack: [],
    view: Rect::empty(),
  }
  if !text.strokes.is_empty() {
    let item : Item = {
      kind: StrokeItem,
      path: Some(text.strokes),
      pen: Some(text.pen),
      fill: None,
      even_odd: false,
      text: None,
      stroke_text: None,
      image: None,
      clip: None,
      items: [],
      bounds: text.strokes.bounds(),
    }
    sub.stroke_item(item, linear)
  }
  for part in text.parts {
    sub.text(part, linear)
  }
  match text.line_break {
    BreakBox => self.canvas.object().mark(3, "")
    BreakParagraph => self.canvas.object().mark(0, "")
    BreakLine => self.canvas.object().mark(1, "")
    BreakWrap => self.canvas.object().mark(5, "")
    BreakNone => ()
  }
  self.canvas.object().mark(4, text.s)
  self.canvas.object().use_object_at(reference, @canvas.f32(pm.e), @canvas.f32(pm.f))
  self.canvas.used(child)
  self.canvas.set_drawn()
}

///|
fn text_bounds(text : CadStrokeText) -> Rect {
  let mut bounds = Rect::empty()
  if !text.strokes.is_empty() {
    bounds = text.strokes.bounds()
    let half = text.pen.world_width / 2.0
    bounds = bounds
      .add({ x: bounds.min.x - half, y: bounds.min.y - half })
      .add({ x: bounds.max.x + half, y: bounds.max.y + half })
  }
  for part in text.parts {
    bounds = bounds.union(part.bounds())
  }
  bounds
}
