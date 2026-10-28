///|
/// A rectangle in the extraction coordinate space.
pub(all) struct TextRect {
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Eq, Debug)

///|
/// Document structure associated with extracted runs and links. A missing
/// optional field corresponds to an unspecified property in the BDF stream.
pub(all) struct TextNode {
  kind : String
  parent : Int32
  level : Int32?
  row : Int32?
  col : Int32?
  rows : Int32?
  cols : Int32?
  scope : String?
  alt : String?
  bounds : TextRect?
  data : String?
  code : Bool
  quote : Int32
  list : String?
}

///|
/// A parsed A1 cell reference or range.
pub(all) struct CellRef {
  row : Int32
  col : Int32
  rows : Int32
  cols : Int32
  scope : String?
} derive(Eq, Debug)

///|
fn node(kind : String) -> TextNode {
  {
    kind,
    parent: -1,
    level: None,
    row: None,
    col: None,
    rows: None,
    cols: None,
    scope: None,
    alt: None,
    bounds: None,
    data: None,
    code: false,
    quote: 0,
    list: None,
  }
}

///|
fn text_space(ch : Char) -> Bool {
  let c = ch.to_int()
  c == 9 ||
  c == 10 ||
  c == 11 ||
  c == 12 ||
  c == 13 ||
  c == 32 ||
  c == 160 ||
  c == 0x1680 ||
  (c >= 0x2000 && c <= 0x200a) ||
  c == 0x2028 ||
  c == 0x2029 ||
  c == 0x202f ||
  c == 0x205f ||
  c == 0x3000 ||
  c == 0xfeff
}

///|
fn words(text : String) -> Array[String] {
  let out : Array[String] = []
  let word = StringBuilder()
  for ch in text {
    if text_space(ch) {
      if !word.is_empty() {
        out.push(word.to_string())
        word.reset()
      }
    } else {
      word.write_char(ch)
    }
  }
  if !word.is_empty() {
    out.push(word.to_string())
  }
  out
}

///|
fn payload_node(kind : String, payload : String) -> TextNode {
  let mut result = node(kind)
  for word in words(payload) {
    match word {
      "code" => result = { ..result, code: true, }
      "quote" => result = { ..result, quote: result.quote + 1, }
      "bullet" | "ordered" => result = { ..result, list: Some(word), }
      _ => ()
    }
  }
  result
}

///|
fn scan_cell(chars : Array[Char], start : Int32) -> (Int32, Int32, Int32)? {
  let mut at = start
  let mut col = 0
  while at < chars.length() {
    let c = chars[at].to_int()
    let n = if c >= 65 && c <= 90 {
      c - 64
    } else if c >= 97 && c <= 122 {
      c - 96
    } else {
      0
    }
    if n == 0 {
      break
    }
    if col > (2147483647 - n) / 26 {
      return None
    }
    col = col * 26 + n
    at += 1
  }
  if at == start {
    return None
  }
  let digit_start = at
  let mut row = 0
  while at < chars.length() {
    let c = chars[at].to_int()
    if c < 48 || c > 57 {
      break
    }
    let n = c - 48
    if row > (2147483647 - n) / 10 {
      return None
    }
    row = row * 10 + n
    at += 1
  }
  if at == digit_start || row == 0 {
    None
  } else {
    Some((row - 1, col - 1, at))
  }
}

///|
/// Parse an A1 cell reference or range, optionally followed by col or row.
pub fn parse_cell_ref(payload : String) -> CellRef? {
  let chars = payload.iter().to_array()
  let mut at = 0
  while at < chars.length() && text_space(chars[at]) {
    at += 1
  }
  let (row, col, next) = match scan_cell(chars, at) {
    Some(value) => value
    None => return None
  }
  at = next
  let mut row2 = row
  let mut col2 = col
  if at < chars.length() && chars[at] == ':' {
    match scan_cell(chars, at + 1) {
      Some((r, c, n)) => {
        row2 = r
        col2 = c
        at = n
      }
      None => return None
    }
  }
  let space_start = at
  while at < chars.length() && text_space(chars[at]) {
    at += 1
  }
  let mut scope : String? = None
  if at < chars.length() {
    if at == space_start {
      return None
    }
    let rest = StringBuilder()
    while at < chars.length() && !text_space(chars[at]) {
      rest.write_char(chars[at])
      at += 1
    }
    let value = rest.to_string()
    if value != "col" && value != "row" {
      return None
    }
    scope = Some(value)
    while at < chars.length() && text_space(chars[at]) {
      at += 1
    }
  }
  if at != chars.length() {
    return None
  }
  Some({
    row,
    col,
    rows: (row2 - row + 1).max(1),
    cols: (col2 - col + 1).max(1),
    scope,
  })
}

///|
fn cell_node(payload : String) -> TextNode {
  let base = node("cell")
  match parse_cell_ref(payload) {
    Some(cell) =>
      {
        ..base,
        row: Some(cell.row),
        col: Some(cell.col),
        rows: Some(cell.rows),
        cols: Some(cell.cols),
        scope: cell.scope,
      }
    None => base
  }
}

///|
fn TextCollector::top(self : TextCollector) -> Int32 {
  if self.open.length() == 0 {
    -1
  } else {
    self.open[self.open.length() - 1]
  }
}

///|
fn TextCollector::top_kind(self : TextCollector) -> String {
  let index = self.top()
  if index < 0 {
    ""
  } else {
    self.nodes[index].kind
  }
}

///|
fn TextCollector::add_node(self : TextCollector, n : TextNode) -> Int32 {
  let index = self.nodes.length()
  self.nodes.push({ ..n, parent: self.top(), })
  index
}

///|
fn TextCollector::open_node(
  self : TextCollector,
  n : TextNode,
  st : TextState?,
) -> Unit {
  let index = self.add_node(n)
  self.open.push(index)
  self.leaf = -1
  self.reserved = None
  if n.kind == "figure" {
    self.figures.push(index)
    let (_, _, _, _, x, y) = match st {
      Some(state) => state.matrix
      None => (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)
    }
    self.origins[index] = { x, y, width: 0.0, height: 0.0, }
  }
}

///|
fn TextCollector::close_top(self : TextCollector) -> Unit {
  self.leaf = -1
  self.reserved = None
  if self.open.pop() is Some(index) {
    if self.nodes[index].kind == "figure" {
      if self.figures.length() > 0 {
        ignore(self.figures.pop())
      }
      let current = self.nodes[index]
      if current.bounds is None {
        self.nodes[index] = { ..current, bounds: self.origins.get(index), }
      }
      self.origins.remove(index)
    }
  }
}

///|
fn TextCollector::leaf_node(self : TextCollector) -> Int32 {
  if self.leaf >= 0 && self.reserved is None {
    return self.leaf
  }
  let next = self.reserved.unwrap_or(node("paragraph"))
  self.reserved = None
  if self.top_kind() == "list" {
    self.open_node(node("item"), None)
  }
  let actual = if self.top_kind() == "table" { node("caption") } else { next }
  self.leaf = self.add_node(actual)
  self.leaf
}

///|
fn heading_level(token : String) -> Int32? {
  let chars = token.iter().to_array()
  if chars.length() >= 3 && chars[0] == '0' {
    let prefix = chars[1]
    let base = if prefix == 'x' || prefix == 'X' {
      16
    } else if prefix == 'b' || prefix == 'B' {
      2
    } else if prefix == 'o' || prefix == 'O' {
      8
    } else {
      0
    }
    if base > 0 {
      let mut value = 0
      for i in 2..<chars.length() {
        let c = chars[i].to_int()
        let n = if c >= 48 && c <= 57 {
          c - 48
        } else if c >= 65 && c <= 70 {
          c - 55
        } else if c >= 97 && c <= 102 {
          c - 87
        } else {
          -1
        }
        if n < 0 || n >= base {
          return None
        }
        value = value * base + n
        if value > 6 {
          return None
        }
      }
      return if value >= 1 { Some(value) } else { None }
    }
  }
  let value = @string.parse_double(token[:]) catch { _ => return None }
  if value >= 1.0 && value <= 6.0 && value.floor() == value {
    Some(value.to_int())
  } else {
    None
  }
}

///|
fn TextCollector::structure(
  self : TextCollector,
  kind : Int32,
  payload : String,
  st : TextState,
) -> Unit {
  match kind {
    0 | 3 => self.reserved = Some(payload_node("paragraph", payload))
    6 => {
      let tokens = words(payload)
      let level = if tokens.length() > 0 {
        heading_level(tokens[0])
      } else {
        None
      }
      self.reserved = Some({ ..node("heading"), level, })
    }
    7 => self.open_node(payload_node("list", payload), None)
    8 => {
      if self.top_kind() == "item" {
        self.close_top()
      }
      if self.top_kind() == "list" {
        self.open_node(node("item"), None)
      } else {
        self.reserved = Some(node("paragraph"))
      }
    }
    9 => self.open_node(node("table"), None)
    2 => {
      let n = cell_node(payload)
      if self.top_kind() == "cell" {
        self.close_top()
      }
      if self.top_kind() == "table" {
        self.open_node(n, None)
      } else {
        self.reserved = Some(n)
      }
    }
    10 => self.open_node({ ..node("figure"), alt: Some(payload), }, Some(st))
    11 => {
      if self.top_kind() == "item" || self.top_kind() == "cell" {
        self.close_top()
      }
      if self.open.length() > 0 {
        self.close_top()
      }
    }
    _ => ()
  }
}

///|
fn TextCollector::set_data(self : TextCollector, id : String) -> Unit {
  if self.figures.length() > 0 {
    let index = self.figures[self.figures.length() - 1]
    self.nodes[index] = { ..self.nodes[index], data: Some(id), }
  }
}

///|
fn text_box(
  m : Matrix,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> TextRect {
  let (x0, y0) = matrix_point(m, x, y)
  let (x1, y1) = matrix_point(m, x + w, y)
  let (x2, y2) = matrix_point(m, x, y + h)
  let (x3, y3) = matrix_point(m, x + w, y + h)
  let left = x0.min(x1).min(x2).min(x3)
  let top = y0.min(y1).min(y2).min(y3)
  {
    x: left,
    y: top,
    width: x0.max(x1).max(x2).max(x3) - left,
    height: y0.max(y1).max(y2).max(y3) - top,
  }
}

///|
fn intersect_box(a : TextRect, clip : TextRect?) -> TextRect? {
  match clip {
    None => Some(a)
    Some(b) => {
      let x = a.x.max(b.x)
      let y = a.y.max(b.y)
      let right = (a.x + a.width).min(b.x + b.width)
      let bottom = (a.y + a.height).min(b.y + b.height)
      if right >= x && bottom >= y {
        Some({ x, y, width: right - x, height: bottom - y, })
      } else {
        None
      }
    }
  }
}

///|
fn TextCollector::grow(
  self : TextCollector,
  box : TextRect,
  clip : TextRect?,
) -> Unit {
  if intersect_box(box, clip) is Some(b) {
    for index in self.figures {
      let n = self.nodes[index]
      let bounds = match n.bounds {
        None => b
        Some(old) => {
          let x = old.x.min(b.x)
          let y = old.y.min(b.y)
          {
            x,
            y,
            width: (old.x + old.width).max(b.x + b.width) - x,
            height: (old.y + old.height).max(b.y + b.height) - y,
          }
        }
      }
      self.nodes[index] = { ..n, bounds: Some(bounds), }
    }
  }
}

///|
priv struct BoundsAccumulator {
  mut x0 : Double
  mut y0 : Double
  mut x1 : Double
  mut y1 : Double
  mut has : Bool
}

///|
fn BoundsAccumulator::add(
  self : BoundsAccumulator,
  x : Double,
  y : Double,
) -> Unit {
  if self.has {
    self.x0 = self.x0.min(x)
    self.y0 = self.y0.min(y)
    self.x1 = self.x1.max(x)
    self.y1 = self.y1.max(y)
  } else {
    self.x0 = x
    self.y0 = y
    self.x1 = x
    self.y1 = y
    self.has = true
  }
}

///|
fn path_box(entries : Array[@core.PathEntry], index : Int32) -> TextRect? {
  if index < 0 || index >= entries.length() {
    return None
  }
  let path = match entries[index] {
    @core.Inline(p) => p
    @core.External(_, _) => return None
  }
  let b : BoundsAccumulator = {
    x0: 0.0,
    y0: 0.0,
    x1: 0.0,
    y1: 0.0,
    has: false,
  }
  let a = path.coordinates
  let mut i = 0
  for verb in path.verbs {
    match verb.to_int() {
      0 | 1 => {
        b.add(a[i], a[i + 1])
        i += 2
      }
      2 => {
        b.add(a[i], a[i + 1])
        b.add(a[i + 2], a[i + 3])
        i += 4
      }
      3 => {
        b.add(a[i], a[i + 1])
        b.add(a[i + 2], a[i + 3])
        b.add(a[i + 4], a[i + 5])
        i += 6
      }
      4 => ()
      5 => {
        b.add(a[i], a[i + 1])
        b.add(a[i] + a[i + 2], a[i + 1] + a[i + 3])
        i += 4
      }
      6 => {
        let radius = a[i + 2].abs().max(a[i + 3].abs())
        b.add(a[i] - radius, a[i + 1] - radius)
        b.add(a[i] + radius, a[i + 1] + radius)
        i += 8
      }
      7 => {
        b.add(a[i], a[i + 1])
        b.add(a[i + 2], a[i + 3])
        i += 5
      }
      8 => {
        b.add(a[i], a[i + 1])
        b.add(a[i] + a[i + 2], a[i + 1] + a[i + 3])
        i += 5
      }
      _ => return None
    }
  }
  if b.has {
    Some({ x: b.x0, y: b.y0, width: b.x1 - b.x0, height: b.y1 - b.y0, })
  } else {
    None
  }
}

///|
fn TextCollector::grow_path(
  self : TextCollector,
  entries : Array[@core.PathEntry],
  index : Int32,
  dx : Double,
  dy : Double,
  st : TextState,
) -> Unit {
  if self.figures.length() > 0 {
    if path_box(entries, index) is Some(b) {
      self.grow(
        text_box(st.matrix, b.x + dx, b.y + dy, b.width, b.height),
        st.clip,
      )
    }
  }
}
