///|
/// A six-component Canvas 2D transformation matrix.
pub type Matrix = (Double, Double, Double, Double, Double, Double)

///|
/// One text run in extraction order. `separator` is 0 for none, 1 for a
/// space, and 2 for a line break, relative to the preceding run.
pub(all) struct TextRun {
  text : String
  x : Double
  y : Double
  advance : Double
  size : Double
  font : @core.Font?
  align : Int32
  matrix : Matrix
  separator : Int32
  ordinal : Int32
  alt_text : Bool
  lang : String
  node : Int32
}

///|
/// A LINK rectangle transformed into the extraction coordinate space.
pub(all) struct TextLink {
  x : Double
  y : Double
  width : Double
  height : Double
  url : String
  after : Int32
  node : Int32
}

///|
/// Extracted runs and links in instruction order.
pub(all) struct TextContent {
  runs : Array[TextRun]
  links : Array[TextLink]
  nodes : Array[TextNode]
}

///|
priv struct TextState {
  matrix : Matrix
  font : @core.Font?
  size : Double
  align : Int32
  clip : TextRect?
}

///|
/// Reuse one budget across the top-level objects of a view when building an index.
pub struct TextExtractionBudget {
  seen : Map[String, Bool]
  mut reused : Int32
  mut failure : String?
}

///|
pub fn TextExtractionBudget::new() -> TextExtractionBudget {
  { seen: {}, reused: 0, failure: None, }
}

///|
priv struct TextCollector {
  runs : Array[TextRun]
  links : Array[TextLink]
  nodes : Array[TextNode]
  open : Array[Int32]
  figures : Array[Int32]
  origins : Map[Int32, TextRect]
  mut leaf : Int32
  mut reserved : TextNode?
  budget : TextExtractionBudget
  mut pending : Int32
  mut has_mark : Bool
  mut alt : String?
  mut lang : String
}

///|
fn mul(a : Matrix, b : Matrix) -> Matrix {
  let (a0, a1, a2, a3, a4, a5) = a
  let (b0, b1, b2, b3, b4, b5) = b
  (
    a0 * b0 + a2 * b1,
    a1 * b0 + a3 * b1,
    a0 * b2 + a2 * b3,
    a1 * b2 + a3 * b3,
    a0 * b4 + a2 * b5 + a4,
    a1 * b4 + a3 * b5 + a5,
  )
}

///|
fn matrix_point(m : Matrix, x : Double, y : Double) -> (Double, Double) {
  let (a, b, c, d, e, f) = m
  (a * x + c * y + e, b * x + d * y + f)
}

///|
fn guess_separator(prev : TextRun, x : Double, y : Double) -> Int32 {
  let size = if prev.size > 0.0 { prev.size } else { 10.0 }
  if (y - prev.y).abs() > size * 0.5 ||
    prev.advance == 0.0 ||
    x - (prev.x + prev.advance) > 0.20000000298023224 * size {
    1
  } else {
    0
  }
}

///|
fn TextCollector::emit(
  self : TextCollector,
  text : String,
  x : Double,
  y : Double,
  advance : Double,
  st : TextState,
  alt : Bool,
) -> Unit raise {
  if self.runs.length() >= 4194304 {
    raise InvalidOperands("too many text runs")
  }
  let (px, py) = matrix_point(st.matrix, x, y)
  let sep = if self.has_mark {
    self.pending
  } else if self.runs.length() > 0 {
    guess_separator(self.runs[self.runs.length() - 1], px, py)
  } else {
    0
  }
  self.runs.push({
    text,
    x: px,
    y: py,
    advance,
    size: st.size,
    font: st.font,
    align: st.align,
    matrix: st.matrix,
    separator: sep,
    ordinal: self.runs.length(),
    alt_text: alt,
    lang: self.lang,
    node: self.leaf_node(),
  })
  if self.figures.length() > 0 {
    let width = if advance > 0.0 {
      advance
    } else {
      st.size * text.length().to_double() * 0.5
    }
    let anchor = if st.align == 1 {
      -width
    } else if st.align == 2 {
      -width / 2.0
    } else {
      0.0
    }
    self.grow(
      text_box(st.matrix, x + anchor, y - st.size * 0.8, width, st.size),
      st.clip,
    )
  }
  self.pending = 0
  self.has_mark = false
}

///|
fn TextCollector::flush_alt(self : TextCollector, st : TextState) -> Unit raise {
  if self.alt is Some(text) {
    self.alt = None
    self.emit(text, 0.0, 0.0, 0.0, st, true)
  }
}

///|
fn TextCollector::take_alt(
  self : TextCollector,
  x : Double,
  y : Double,
  advance : Double,
  st : TextState,
) -> Bool raise {
  if self.alt is Some(text) {
    self.alt = None
    self.emit(text, x, y, advance, st, true)
    true
  } else {
    false
  }
}

///|
fn TextCollector::mark(self : TextCollector, sep : Int32) -> Unit {
  if !self.has_mark || sep > self.pending {
    self.pending = sep
  }
  self.has_mark = true
}

///|
fn TextCollector::link(
  self : TextCollector,
  st : TextState,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  url : String,
) -> Unit {
  let (x0, y0) = matrix_point(st.matrix, x, y)
  let (x1, y1) = matrix_point(st.matrix, x + w, y)
  let (x2, y2) = matrix_point(st.matrix, x, y + h)
  let (x3, y3) = matrix_point(st.matrix, x + w, y + h)
  let left = x0.min(x1).min(x2).min(x3)
  let top = y0.min(y1).min(y2).min(y3)
  let right = x0.max(x1).max(x2).max(x3)
  let bottom = y0.max(y1).max(y2).max(y3)
  self.links.push({
    x: left,
    y: top,
    width: right - left,
    height: bottom - top,
    url,
    after: self.runs.length() - 1,
    node: if self.leaf >= 0 {
      self.leaf
    } else {
      self.top()
    },
  })
}

///|
fn collect_object(
  collector : TextCollector,
  object : @core.ObjectResources,
  resolve : (String) -> @core.ObjectResources? raise,
  matrix : Matrix,
  depth : Int32,
  repeated : Bool,
  clip : TextRect?,
) -> Unit raise {
  let mut st : TextState = { matrix, font: None, size: 10.0, align: 0, clip, }
  let stack : Array[TextState] = []
  let mut masking = 0
  for command in compile_object(object.object) {
    if repeated {
      if collector.budget.reused >= 134217728 {
        raise InvalidOperands("objects are drawn too many times")
      }
      collector.budget.reused += 1
    }
    match command {
      Save => stack.push(st)
      Restore => if stack.pop() is Some(saved) { st = saved }
      Transform(a, b, c, d, e, f) =>
        st = { ..st, matrix: mul(st.matrix, (a, b, c, d, e, f)), }
      Translate(x, y) =>
        st = { ..st, matrix: mul(st.matrix, (1.0, 0.0, 0.0, 1.0, x, y)), }
      Scale(x, y) =>
        st = { ..st, matrix: mul(st.matrix, (x, 0.0, 0.0, y, 0.0, 0.0)), }
      Font(index, size) =>
        st = {
          ..st,
          font: if index >= 0 && index < object.fonts.length() {
            Some(object.fonts[index])
          } else {
            None
          },
          size,
        }
      TextStyle(align, _, _, _) => st = { ..st, align, }
      ClipRect(x, y, w, h) => {
        let clipped = intersect_box(text_box(st.matrix, x, y, w, h), st.clip)
        st = {
          ..st,
          clip: Some(
            clipped.unwrap_or({ x: 0.0, y: 0.0, width: 0.0, height: 0.0, }),
          ),
        }
      }
      ClipPath(index, _) =>
        if path_box(object.paths, index) is Some(b) {
          let clipped = intersect_box(
            text_box(st.matrix, b.x, b.y, b.width, b.height),
            st.clip,
          )
          st = {
            ..st,
            clip: Some(
              clipped.unwrap_or({ x: 0.0, y: 0.0, width: 0.0, height: 0.0, }),
            ),
          }
        }
      FillRect(x, y, w, h) | StrokeRect(x, y, w, h) | Image(_, x, y, w, h) if masking ==
        0 =>
        if collector.figures.length() > 0 {
          collector.grow(text_box(st.matrix, x, y, w, h), st.clip)
        }
      ImageSub(_, _, _, _, _, x, y, w, h) if masking == 0 =>
        if collector.figures.length() > 0 {
          collector.grow(text_box(st.matrix, x, y, w, h), st.clip)
        }
      FillPath(index, _) | StrokePath(index) if masking == 0 =>
        collector.grow_path(object.paths, index, 0.0, 0.0, st)
      MaskBegin(_, _, _) => {
        stack.push(st)
        masking += 1
      }
      MaskEnd =>
        if masking > 0 {
          masking -= 1
          if stack.pop() is Some(saved) {
            st = saved
          }
        }
      Mark(kind, payload) if masking == 0 =>
        match kind {
          1 => {
            collector.flush_alt(st)
            collector.mark(1)
          }
          0 | 2 | 3 | 6 | 7 | 8 | 9 | 10 | 11 => {
            collector.flush_alt(st)
            collector.mark(2)
            collector.structure(kind, payload, st)
          }
          4 => {
            collector.flush_alt(st)
            collector.alt = Some(payload)
          }
          5 => {
            collector.flush_alt(st)
            collector.mark(0)
          }
          12 => collector.lang = payload
          14 => collector.set_data(payload)
          _ => ()
        }
      Link(x, y, w, h, url) if masking == 0 =>
        collector.link(st, x, y, w, h, url)
      FillText(text, x, y, advance) | StrokeText(text, x, y, advance) if masking ==
        0 =>
        if !collector.take_alt(x, y, advance, st) {
          collector.emit(text, x, y, advance, st, false)
        }
      FillPathAt(index, _, x, y) if masking == 0 => {
        collector.grow_path(object.paths, index, x, y, st)
        ignore(collector.take_alt(x, y, 0.0, st))
      }
      FillPathRun(_, glyphs) if masking == 0 => {
        for glyph in glyphs {
          collector.grow_path(object.paths, glyph.path, glyph.x, glyph.y, st)
        }
        let (x, y) = if glyphs.length() > 0 {
          (glyphs[0].x, glyphs[0].y)
        } else {
          (0.0, 0.0)
        }
        ignore(collector.take_alt(x, y, 0.0, st))
      }
      Use(hash) | UseAt(hash, _, _) if masking == 0 => {
        let (x, y) = match command {
          UseAt(_, dx, dy) => (dx, dy)
          _ => (0.0, 0.0)
        }
        let child = resolve(hash)
        let again = child is Some(_) && collector.budget.seen.contains(hash)
        if child is Some(_) {
          collector.budget.seen[hash] = true
        }
        if collector.alt is Some(_) {
          let (bx, _, bw, _) = match child {
            Some(c) => c.object.bbox
            None => (0.0, 0.0, 0.0, 0.0)
          }
          if child is Some(c) && collector.figures.length() > 0 {
            let (cx, cy, cw, ch) = c.object.bbox
            collector.grow(text_box(st.matrix, cx + x, cy + y, cw, ch), st.clip)
          }
          ignore(collector.take_alt(x + bx, y, bw, st))
        } else if child is Some(c) {
          if depth >= 64 {
            raise InvalidOperands("objects draw objects too deep")
          }
          collect_object(
            collector,
            c,
            resolve,
            mul(st.matrix, (1.0, 0.0, 0.0, 1.0, x, y)),
            depth + 1,
            repeated || again,
            st.clip,
          )
        }
      }
      _ => ()
    }
  }
}

///|
/// Extract runs and links, traversing child objects with a host resolver.
/// Returns semantic nodes, their runs, and links.
pub fn extract_text(
  object : @core.ObjectResources,
  resolve : (String) -> @core.ObjectResources? raise,
  matrix~ : Matrix = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0),
) -> TextContent raise {
  extract_text_with_budget(
    object,
    resolve,
    TextExtractionBudget::new(),
    matrix~,
  )
}

///|
/// Extract an object while sharing child-use limits with other top-level objects.
pub fn extract_text_with_budget(
  object : @core.ObjectResources,
  resolve : (String) -> @core.ObjectResources? raise,
  budget : TextExtractionBudget,
  matrix~ : Matrix = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0),
) -> TextContent raise {
  if budget.failure is Some(message) {
    raise InvalidOperands(message)
  }
  let collector : TextCollector = {
    runs: [],
    links: [],
    nodes: [],
    open: [],
    figures: [],
    origins: {},
    leaf: -1,
    reserved: None,
    budget,
    pending: 0,
    has_mark: false,
    alt: None,
    lang: "",
  }
  try {
    collect_object(collector, object, resolve, matrix, 0, false, None)
    collector.flush_alt({
      matrix,
      font: None,
      size: 10.0,
      align: 0,
      clip: None,
    })
  } catch {
    InvalidOperands(message) => {
      if [
          "too many text runs", "objects are drawn too many times", "objects draw objects too deep",
        ].contains(message) {
        budget.failure = Some(message)
      }
      raise InvalidOperands(message)
    }
    error => raise error
  }
  while collector.open.length() > 0 {
    collector.close_top()
  }
  { runs: collector.runs, links: collector.links, nodes: collector.nodes, }
}

///|
/// Join runs with their recorded spaces and line breaks.
pub fn join_text(runs : Array[TextRun]) -> String {
  let text = StringBuilder()
  for i, run in runs {
    if i > 0 {
      if run.separator == 2 {
        text.write_string("\n")
      } else if run.separator == 1 {
        text.write_string(" ")
      }
    }
    text.write_string(run.text)
  }
  text.to_string()
}
