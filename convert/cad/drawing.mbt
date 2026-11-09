///|
/// Line caps and joins, in BDF values.
pub const CAP_BUTT : Byte = 0

///|
pub const CAP_ROUND : Byte = 1

///|
pub const CAP_SQUARE : Byte = 2

///|
pub const JOIN_MITER : Byte = 0

///|
pub const JOIN_ROUND : Byte = 1

///|
pub const JOIN_BEVEL : Byte = 2

///|
/// How a path is stroked.
pub(all) struct Pen {
  color : UInt32
  /// The width of the line on paper in pt; 0 is the thinnest line.
  width : Double
  /// The width in drawing units instead, when positive.
  mut world_width : Double
  /// Dash and gap lengths in drawing units, or None for a continuous line.
  mut dash : Array[Double]?
  mut dash_offset : Double
  mut cap : Byte
  mut join : Byte
  mut miter : Double
}

///|
pub fn Pen::new(
  color~ : UInt32 = 0x000000ffU,
  width~ : Double = 0.0,
  world_width~ : Double = 0.0,
  dash~ : Array[Double]? = None,
  dash_offset~ : Double = 0.0,
  cap~ : Byte = CAP_BUTT,
  join~ : Byte = JOIN_MITER,
  miter~ : Double = 0.0,
) -> Pen {
  { color, width, world_width, dash, dash_offset, cap, join, miter }
}

///|
/// An image repeated in both directions.
pub(all) struct CadPattern {
  image : String
  m : @canvas.Matrix
  smooth : Bool
}

///|
/// A raster image drawn into a parallelogram.
pub(all) struct CadImage {
  image : String
  width : Int
  height : Int
  m : @canvas.Matrix
  smooth : Bool
}

///|
/// A gradient in drawing coordinates.
pub(all) struct CadGradient {
  radial : Bool
  p0 : Point
  p1 : Point
  r0 : Double
  r1 : Double
  stops : Array[@core.ColorStop]
}

///|
/// A solid color, a gradient or a pattern.
pub(all) struct Fill {
  color : UInt32
  mut gradient : CadGradient?
  mut pattern : CadPattern?
}

///|
pub fn Fill::solid(color : UInt32) -> Fill {
  { color, gradient: None, pattern: None }
}

///|
pub fn Fill::gradient(gradient : CadGradient) -> Fill {
  { color: 0x000000ffU, gradient: Some(gradient), pattern: None }
}

///|
pub fn Fill::pattern(pattern : CadPattern) -> Fill {
  { color: 0x000000ffU, gradient: None, pattern: Some(pattern) }
}

///|
priv enum ItemKind {
  StrokeItem
  FillItem
  TextItem
  GroupItem
  ImageItem
  StrokeTextItem
}

///|
priv struct Item {
  kind : ItemKind
  path : CadPath?
  pen : Pen?
  fill : Fill?
  even_odd : Bool
  text : CadText?
  stroke_text : CadStrokeText?
  image : CadImage?
  clip : CadPath?
  items : Array[Item]
  bounds : Rect
}

///|
/// The string of a text item.
fn item_text(item : Item) -> String {
  match item.kind {
    TextItem =>
      match item.text {
        Some(text) => text.s
        None => ""
      }
    StrokeTextItem =>
      match item.stroke_text {
        Some(text) => text.s
        None => ""
      }
    _ => ""
  }
}

///|
priv struct GroupFrame {
  clip : CadPath?
  items : Array[Item]
}

///|
/// A display list in drawing coordinates.
pub struct Drawing {
  priv items : Array[Item]
  priv open : Array[GroupFrame]
  mut points : Int
}

///|
pub fn Drawing::new() -> Drawing {
  { items: [], open: [], points: 0 }
}

///|
/// The number of points of the paths drawn so far, group clips included.
pub fn Drawing::points(self : Drawing) -> Int {
  self.points
}

///|
fn Drawing::add(self : Drawing, item : Item) -> Unit {
  match item.path {
    Some(path) => {
      self.points += path.size()
    }
    None => ()
  }
  if self.open.is_empty() {
    self.items.push(item)
  } else {
    self.open[self.open.length() - 1].items.push(item)
  }
}

///|
pub fn Drawing::stroke(self : Drawing, path : CadPath, pen : Pen) -> Unit {
  if path.is_empty() {
    return
  }
  self.add({
    kind: StrokeItem,
    path: Some(path),
    pen: Some(pen),
    fill: None,
    even_odd: false,
    text: None,
    stroke_text: None,
    image: None,
    clip: None,
    items: [],
    bounds: path.bounds(),
  })
}

///|
pub fn Drawing::fill(
  self : Drawing,
  path : CadPath,
  fill : Fill,
  even_odd : Bool,
) -> Unit {
  if path.is_empty() {
    return
  }
  self.add({
    kind: FillItem,
    path: Some(path),
    pen: None,
    fill: Some(fill),
    even_odd,
    text: None,
    stroke_text: None,
    image: None,
    clip: None,
    items: [],
    bounds: path.bounds(),
  })
}

///|
pub fn Drawing::text(self : Drawing, text : CadText) -> Unit {
  if text.s == "" {
    return
  }
  self.add({
    kind: TextItem,
    path: None,
    pen: None,
    fill: None,
    even_odd: false,
    text: Some(text),
    stroke_text: None,
    image: None,
    clip: None,
    items: [],
    bounds: text.bounds(),
  })
}

///|
pub fn Drawing::stroke_text(self : Drawing, text : CadStrokeText) -> Unit {
  if text.s == "" && text.strokes.is_empty() && text.parts.is_empty() {
    return
  }
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
  self.add({
    kind: StrokeTextItem,
    path: None,
    pen: None,
    fill: None,
    even_odd: false,
    text: None,
    stroke_text: Some(text),
    image: None,
    clip: None,
    items: [],
    bounds: bounds.transform(text.m),
  })
}

///|
pub fn Drawing::image(self : Drawing, image : CadImage) -> Unit {
  if image.width <= 0 || image.height <= 0 {
    return
  }
  let rect : Rect = {
    min: { x: 0.0, y: 0.0 },
    max: { x: image.width.to_double(), y: image.height.to_double() },
    ok: true,
  }
  self.add({
    kind: ImageItem,
    path: None,
    pen: None,
    fill: None,
    even_odd: false,
    text: None,
    stroke_text: None,
    image: Some(image),
    clip: None,
    items: [],
    bounds: rect.transform(image.m),
  })
}

///|
pub fn Drawing::begin(self : Drawing, clip : CadPath?) -> Unit {
  match clip {
    Some(path) => {
      self.points += path.size()
    }
    None => ()
  }
  self.open.push({ clip, items: [], })
}

///|
pub fn Drawing::end(self : Drawing) -> Unit {
  if self.open.is_empty() {
    return
  }
  let frame = self.open.pop()
  if frame is Some(group) {
    if group.items.is_empty() {
      return
    }
    let mut bounds = Rect::empty()
    for item in group.items {
      bounds = bounds.union(item.bounds)
    }
    match group.clip {
      Some(clip) => {
        bounds = bounds.intersect(clip.bounds())
      }
      None => ()
    }
    self.add({
      kind: GroupItem,
      path: None,
      pen: None,
      fill: None,
      even_odd: false,
      text: None,
      stroke_text: None,
      image: None,
      clip: group.clip,
      items: group.items,
      bounds,
    })
  }
}

///|
pub fn Drawing::bounds(self : Drawing) -> Rect {
  let mut bounds = Rect::empty()
  for item in self.items {
    bounds = bounds.union(item.bounds)
  }
  bounds
}

///|
pub fn Drawing::is_empty(self : Drawing) -> Bool {
  self.items.is_empty()
}

///|
pub fn Drawing::item_count(self : Drawing) -> Int {
  self.items.length()
}

///|
/// Add the items of another drawing transformed by `matrix`, clipped by
/// `clip` in this drawing's coordinates.
pub fn Drawing::append(
  self : Drawing,
  source : Drawing,
  matrix : @canvas.Matrix,
  clip : CadPath?,
) -> Unit {
  self.begin(clip)
  let scale = scale_of(matrix)
  for item in source.items {
    let transformed = transform_item(item, matrix, scale)
    self.add(transformed)
  }
  self.end()
}

///|
/// A copy of `item` with `matrix` applied. The source is left untouched:
/// callers reuse drawings (the stencil cache), so mutating in place would
/// apply the transform again on the next append.
fn transform_item(item : Item, matrix : @canvas.Matrix, scale : Double) -> Item {
  let path = match item.path {
    Some(value) => Some(value.transform(matrix))
    None => None
  }
  let clip = match item.clip {
    Some(value) => Some(value.transform(matrix))
    None => None
  }
  let pen = match item.pen {
    Some(pen) => {
      let dash = match pen.dash {
        Some(values) => {
          let scaled : Array[Double] = []
          for value in values {
            scaled.push(value * scale)
          }
          Some(scaled)
        }
        None => None
      }
      Some({
        color: pen.color,
        width: pen.width,
        world_width: pen.world_width * scale,
        dash,
        dash_offset: pen.dash_offset * scale,
        cap: pen.cap,
        join: pen.join,
        miter: pen.miter,
      })
    }
    None => None
  }
  let fill = match item.fill {
    Some(fill) => {
      let gradient = match fill.gradient {
        Some(gradient) => {
          Some({
            radial: gradient.radial,
            p0: apply(matrix, gradient.p0),
            p1: apply(matrix, gradient.p1),
            r0: gradient.r0 * scale,
            r1: gradient.r1 * scale,
            stops: gradient.stops,
          })
        }
        None => None
      }
      let pattern = match fill.pattern {
        Some(pattern) => {
          Some({
            image: pattern.image,
            m: matrix.mul(pattern.m),
            smooth: pattern.smooth,
          })
        }
        None => None
      }
      Some({ color: fill.color, gradient, pattern })
    }
    None => None
  }
  let text = match item.text {
    Some(text) => {
      Some({
        s: text.s,
        font: text.font,
        color: text.color,
        m: matrix.mul(text.m),
        advance: text.advance,
        cells: text.cells,
        spacing: text.spacing,
        asc: text.asc,
        desc: text.desc,
        cap: text.cap,
        underline: text.underline,
        overline: text.overline,
        strike: text.strike,
        line_break: text.line_break,
        vertical: text.vertical,
      })
    }
    None => None
  }
  let stroke_text = match item.stroke_text {
    Some(text) => {
      Some({
        s: text.s,
        m: matrix.mul(text.m),
        strokes: text.strokes,
        pen: text.pen,
        parts: text.parts,
        line_break: text.line_break,
      })
    }
    None => None
  }
  let image = match item.image {
    Some(image) => {
      Some({
        image: image.image,
        width: image.width,
        height: image.height,
        m: matrix.mul(image.m),
        smooth: image.smooth,
      })
    }
    None => None
  }
  let children : Array[Item] = []
  match item.kind {
    GroupItem =>
      for child in item.items {
        children.push(transform_item(child, matrix, scale))
      }
    _ => ()
  }
  {
    kind: item.kind,
    path,
    pen,
    fill,
    even_odd: item.even_odd,
    text,
    stroke_text,
    image,
    clip,
    items: children,
    bounds: item.bounds.transform(matrix),
  }
}

///|
/// The text items of the drawing with their bounds, groups included.
pub fn Drawing::texts(self : Drawing) -> Array[(String, Rect)] {
  let output : Array[(String, Rect)] = []
  texts_in(self.items, output)
  output
}

///|
fn texts_in(items : Array[Item], output : Array[(String, Rect)]) -> Unit {
  for item in items {
    match item.kind {
      TextItem =>
        match item.text {
          Some(text) => output.push((text.s, item.bounds))
          None => ()
        }
      StrokeTextItem =>
        match item.stroke_text {
          Some(text) => output.push((text.s, item.bounds))
          None => ()
        }
      GroupItem => texts_in(item.items, output)
      _ => ()
    }
  }
}
