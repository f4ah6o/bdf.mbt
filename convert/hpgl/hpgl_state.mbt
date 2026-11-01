///|
/// The HP-GL/2 and HP-GL state of a plot.
pub const HPGL_PLU : Double = 72.0 / 1016.0

///|
pub const HPGL_DEFAULT_HARD_W : Double = 11880.0

///|
pub const HPGL_DEFAULT_HARD_H : Double = 8400.0

///|
pub const HPGL_PAGE_MARGIN : Double = 200.0

///|
pub const HPGL_MAX_PAGES : Int = 10000

///|
pub const HPGL_MAX_ITEMS : Int = 5000000

///|
fn hpgl_rgb(red : Int, green : Int, blue : Int) -> UInt32 {
  ((red & 255).reinterpret_as_uint() << 24) |
  ((green & 255).reinterpret_as_uint() << 16) |
  ((blue & 255).reinterpret_as_uint() << 8) |
  0xffU
}

///|
fn hpgl_default_color(index : Int) -> UInt32 {
  match index {
    0 => hpgl_rgb(255, 255, 255)
    1 => hpgl_rgb(0, 0, 0)
    2 => hpgl_rgb(255, 0, 0)
    3 => hpgl_rgb(0, 255, 0)
    4 => hpgl_rgb(255, 255, 0)
    5 => hpgl_rgb(0, 0, 255)
    6 => hpgl_rgb(255, 0, 255)
    7 => hpgl_rgb(0, 255, 255)
    _ => hpgl_rgb(0, 0, 0)
  }
}

///|
pub const HPGL_DEFAULT_WIDTH : Double = 0.35

///|
priv struct HpglPens {
  mut count : Int
  mut colors : Array[UInt32]
  mut widths : Array[Double]
  mut relative : Bool
  mut cr : Array[Double]
  mut selected : Int
  mut chosen : Bool
  mut cached : @cad.Pen?
}

///|
fn HpglPens::new() -> HpglPens {
  let pens : HpglPens = {
    count: 8,
    colors: [],
    widths: [],
    relative: false,
    cr: [0.0, 255.0, 0.0, 255.0, 0.0, 255.0],
    selected: 0,
    chosen: false,
    cached: None,
  }
  pens.defaults()
  pens
}

///|
fn HpglPens::defaults(self : HpglPens) -> Unit {
  self.count = 8
  self.colors = []
  self.widths = []
  for index in 0..<8 {
    self.colors.push(hpgl_default_color(index))
    self.widths.push(HPGL_DEFAULT_WIDTH)
  }
  self.relative = false
  self.default_color_range()
  self.cached = None
}

///|
fn HpglPens::default_color_range(self : HpglPens) -> Unit {
  self.cr = [0.0, 255.0, 0.0, 255.0, 0.0, 255.0]
}

///|
fn HpglPens::default_colors(self : HpglPens) -> Unit {
  self.resize(8)
  self.colors = []
  self.widths = []
  for index in 0..<8 {
    self.colors.push(hpgl_default_color(index))
    self.widths.push(HPGL_DEFAULT_WIDTH)
  }
  self.default_color_range()
  self.cached = None
}

///|
fn HpglPens::index(self : HpglPens, pen : Int) -> Int {
  if pen < 0 {
    return 0
  }
  if pen >= self.count {
    if self.count <= 1 {
      return 0
    }
    return (pen - 1) % (self.count - 1) + 1
  }
  pen
}

///|
fn HpglPens::current(self : HpglPens) -> Int {
  if !self.chosen && self.selected == 0 {
    return self.index(1)
  }
  self.index(self.selected)
}

///|
fn HpglPens::resize(self : HpglPens, count : Int) -> Unit {
  while self.colors.length() < count {
    self.colors.push(hpgl_default_color(self.colors.length()))
    self.widths.push(if self.relative { 0.1 } else { HPGL_DEFAULT_WIDTH })
  }
  self.count = count
  self.cached = None
}

///|
priv struct HpglLine {
  mut typ : Int
  mut set : Bool
  mut length : Double
  mut absolute : Bool
  user : Array[Array[Double]?]
  mut cap : Byte
  mut join : Byte
  mut miter : Double
}

///|
fn HpglLine::new() -> HpglLine {
  let user : Array[Array[Double]?] = []
  for _ in 0..<9 {
    user.push(None)
  }
  {
    typ: 0,
    set: false,
    length: 4.0,
    absolute: false,
    user,
    cap: @cad.CAP_BUTT,
    join: @cad.JOIN_MITER,
    miter: 5.0,
  }
}

///|
fn HpglLine::defaults(self : HpglLine) -> Unit {
  self.typ = 0
  self.set = false
  self.length = 4.0
  self.absolute = false
  for index in 0..<self.user.length() {
    self.user[index] = None
  }
  self.cap = @cad.CAP_BUTT
  self.join = @cad.JOIN_MITER
  self.miter = 5.0
}

///|
fn HpglLine::pattern(self : HpglLine, typ : Int) -> Array[Double]? {
  let kind = if typ < 0 { -typ } else { typ }
  if kind < 1 || kind > 8 {
    return None
  }
  match self.user[kind] {
    Some(value) => Some(value)
    None =>
      match kind {
        1 => Some([0.0, 100.0])
        2 => Some([50.0, 50.0])
        3 => Some([70.0, 30.0])
        4 => Some([80.0, 10.0, 0.0, 10.0])
        5 => Some([70.0, 10.0, 10.0, 10.0])
        6 => Some([50.0, 10.0, 10.0, 10.0, 10.0, 10.0])
        7 => Some([70.0, 10.0, 0.0, 10.0, 0.0, 10.0])
        8 => Some([50.0, 10.0, 0.0, 10.0, 10.0, 10.0, 0.0, 10.0])
        _ => None
      }
  }
}

///|
priv struct HpglFill {
  mut typ : Int
  mut spacing : Array[Double]
  mut angle : Array[Double]
  mut shade : Double
  mut transparent : Bool
  mut sv : Int
  mut sv_shade : Double
}

///|
fn HpglFill::new() -> HpglFill {
  {
    typ: 1,
    spacing: [0.0, 0.0, 0.0, 0.0, 0.0],
    angle: [0.0, 0.0, 0.0, 0.0, 0.0],
    shade: 50.0,
    transparent: true,
    sv: 0,
    sv_shade: 50.0,
  }
}

///|
fn HpglFill::defaults(self : HpglFill) -> Unit {
  self.typ = 1
  self.spacing = [0.0, 0.0, 0.0, 0.0, 0.0]
  self.angle = [0.0, 0.0, 0.0, 0.0, 0.0]
  self.shade = 50.0
  self.transparent = true
  self.sv = 0
  self.sv_shade = 50.0
}

///|
priv struct HpglFontDef {
  mut symbol_set : Int
  mut spacing : Int
  mut pitch : Double
  mut height : Double
  mut posture : Int
  mut weight : Int
  mut typeface : Int
}

///|
fn hpgl_default_font() -> HpglFontDef {
  {
    symbol_set: 277,
    spacing: 0,
    pitch: 9.0,
    height: 11.5,
    posture: 0,
    weight: 0,
    typeface: 48,
  }
}

///|
fn HpglFontDef::stick(self : HpglFontDef) -> Bool {
  self.typeface >= 48 && self.typeface <= 50
}

///|
priv struct HpglLabel {
  mut std : HpglFontDef
  mut alt : HpglFontDef
  mut use_alt : Bool
  mut size_mode : Int
  mut size_w : Double
  mut size_h : Double
  mut rel_dir : Bool
  mut run : Double
  mut rise : Double
  mut path : Int
  mut reverse_lf : Bool
  mut origin : Int
  mut extra_w : Double
  mut extra_h : Double
  mut slant : Double
  mut term : Byte
  mut term_print : Bool
  mut td : Bool
  mut mode16 : Bool
  mut row : Int
}

///|
fn HpglLabel::new() -> HpglLabel {
  {
    std: hpgl_default_font(),
    alt: hpgl_default_font(),
    use_alt: false,
    size_mode: 0,
    size_w: 0.0,
    size_h: 0.0,
    rel_dir: false,
    run: 1.0,
    rise: 0.0,
    path: 0,
    reverse_lf: false,
    origin: 1,
    extra_w: 0.0,
    extra_h: 0.0,
    slant: 0.0,
    term: 0x03,
    term_print: false,
    td: false,
    mode16: false,
    row: 0,
  }
}

///|
fn HpglLabel::defaults(self : HpglLabel) -> Unit {
  self.std = hpgl_default_font()
  self.alt = hpgl_default_font()
  self.use_alt = false
  self.size_mode = 0
  self.size_w = 0.0
  self.size_h = 0.0
  self.rel_dir = false
  self.run = 1.0
  self.rise = 0.0
  self.path = 0
  self.reverse_lf = false
  self.origin = 1
  self.extra_w = 0.0
  self.extra_h = 0.0
  self.slant = 0.0
  self.term = 0x03
  self.term_print = false
  self.td = false
  self.mode16 = false
  self.row = 0
}

///|
fn HpglLabel::font(self : HpglLabel) -> HpglFontDef {
  if self.use_alt {
    self.alt
  } else {
    self.std
  }
}

///|
priv struct HpglPolygon {
  mut fill : @cad.CadPath?
  mut sub : @cad.CadPath?
  mut edges : @cad.CadPath?
  saved_pos : @cad.Point
  saved_down : Bool
}

///|
fn HpglPolygon::new() -> HpglPolygon {
  {
    fill: None,
    sub: None,
    edges: None,
    saved_pos: { x: 0.0, y: 0.0 },
    saved_down: false,
  }
}

///|
priv struct HpglWindow {
  path : @cad.CadPath
  mut open : Bool
}

///|
priv struct HpglStroke {
  mut path : @cad.CadPath?
  mut pen : @cad.Pen?
  mut pending_dot : Bool
}

///|
fn HpglStroke::new() -> HpglStroke {
  { path: None, pen: None, pending_dot: false }
}

///|
priv struct HpglPage {
  drawing : @cad.Drawing
  hard : @cad.Rect
  view : @canvas.Matrix
  marked : Bool
}

///|
fn HpglPage::new() -> HpglPage {
  {
    drawing: @cad.Drawing::new(),
    hard: @cad.Rect::empty(),
    view: @canvas.Matrix::identity(),
    marked: false,
  }
}

///|
priv struct HpglGl {
  mut hard_w : Double
  mut hard_h : Double
  mut ps_set : Bool
  mut rot : Int
  mut p1 : @cad.Point
  mut p2 : @cad.Point
  mut scale_typ : Int
  mut scale_values : Array[Double]
  mut scale_set : Bool
  mut dev : @canvas.Matrix
  mut um : @canvas.Matrix
  mut inv : @canvas.Matrix
  mut pos : @cad.Point
  mut down : Bool
  mut relative : Bool
  mut cr_point : @cad.Point
  pens : HpglPens
  line : HpglLine
  fill : HpglFill
  mut window : HpglWindow?
  mut in_poly : Bool
  mut polygon : HpglPolygon
  label : HpglLabel
  mut anchor : @cad.Point
  mut anchored : Bool
  mut chord : Int
  mut symbol : Bytes?
  mut merge : Bool
  mut ticks : (Double, Double)
  mut stroke : HpglStroke
  mut drawing : @cad.Drawing
  mut items : Int
  warnings : Array[String]
  warned : Map[String, Bool]
  mut mono : Bool
}

///|
fn HpglGl::new() -> HpglGl {
  let gl : HpglGl = {
    hard_w: HPGL_DEFAULT_HARD_W,
    hard_h: HPGL_DEFAULT_HARD_H,
    ps_set: false,
    rot: 0,
    p1: { x: 0.0, y: 0.0 },
    p2: { x: 0.0, y: 0.0 },
    scale_typ: 0,
    scale_values: [],
    scale_set: false,
    dev: @canvas.Matrix::identity(),
    um: @canvas.Matrix::identity(),
    inv: @canvas.Matrix::identity(),
    pos: { x: 0.0, y: 0.0 },
    down: false,
    relative: false,
    cr_point: { x: 0.0, y: 0.0 },
    pens: HpglPens::new(),
    line: HpglLine::new(),
    fill: HpglFill::new(),
    window: None,
    in_poly: false,
    polygon: HpglPolygon::new(),
    label: HpglLabel::new(),
    anchor: { x: 0.0, y: 0.0 },
    anchored: false,
    chord: 0,
    symbol: None,
    merge: false,
    ticks: (0.5, 0.5),
    stroke: HpglStroke::new(),
    drawing: @cad.Drawing::new(),
    items: 0,
    warnings: [],
    warned: Map([]),
    mono: false,
  }
  gl.initialize()
  gl
}

///|
priv struct HpglConverter {
  pages : Array[HpglPage]
  gl : HpglGl
  mut title : String
  job_name : String
  mut has_text : Bool
  mut instructions : Int
  mut stopped : Bool
  fonts : @canvas.Fonts
  data : Bytes
  mut offset : Int
}

///|
fn HpglConverter::new(
  data : Bytes,
  mono : Bool,
) -> HpglConverter {
  let converter : HpglConverter = {
    pages: [],
    gl: HpglGl::new(),
    title: "",
    job_name: "",
    has_text: false,
    instructions: 0,
    stopped: false,
    fonts: @canvas.Fonts::new(None),
    data,
    offset: 0,
  }
  converter.gl.mono = mono
  converter
}

///|
fn HpglGl::warn(self : HpglGl, message : String) -> Unit {
  self.warnings.push(message)
}

///|
fn HpglGl::warn_once(self : HpglGl, key : String, message : String) -> Unit {
  if !self.warned.contains(key) {
    self.warned[key] = true
    self.warn(message)
  }
}

///|
fn HpglGl::budget(self : HpglGl) -> Bool {
  self.items += 1
  if self.items > HPGL_MAX_ITEMS {
    self.warn_once(
      "budget",
      "only the first \{HPGL_MAX_ITEMS} items are drawn",
    )
    false
  } else {
    true
  }
}

///|
fn HpglGl::take_drawing(self : HpglGl) -> @cad.Drawing {
  let drawing = self.drawing
  self.drawing = @cad.Drawing::new()
  drawing
}
