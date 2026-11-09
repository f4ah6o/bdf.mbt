///|
/// The text index of a DocuWorks page.
///
/// DocuWorks draws a page as one metafile, so the page's object stream already
/// holds every string in drawing order: body text and annotation text alike.
/// Reading the stream back is enough to index the text, and it is also what
/// makes covered text detectable — a run is hidden when a later opaque fill
/// covers its box completely.

///|
/// A text run found in a page's command stream: the box it occupies in page
/// points, and whether a later opaque fill covers it completely.
priv struct XdwTextRun {
  text : String
  x : Double
  y : Double
  w : Double
  h : Double
  /// Position in the command stream, so only later fills can cover the run.
  order : Int
  mut covered : Bool
}

///|
/// An opaque fill that may cover text drawn before it.
priv struct XdwCover {
  order : Int
  x : Double
  y : Double
  w : Double
  h : Double
}

///|
/// A 2×3 affine transform, composed the way the renderer composes it.
priv struct XdwMatrix {
  a : Double
  b : Double
  c : Double
  d : Double
  e : Double
  f : Double
}

///|
fn xdw_matrix_identity() -> XdwMatrix {
  { a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 0.0, f: 0.0 }
}

///|
/// `self` then `other`.
fn XdwMatrix::compose(self : XdwMatrix, other : XdwMatrix) -> XdwMatrix {
  {
    a: self.a * other.a + self.c * other.b,
    b: self.b * other.a + self.d * other.b,
    c: self.a * other.c + self.c * other.d,
    d: self.b * other.c + self.d * other.d,
    e: self.a * other.e + self.c * other.f + self.e,
    f: self.b * other.e + self.d * other.f + self.f,
  }
}

///|
fn XdwMatrix::point(self : XdwMatrix, x : Double, y : Double) -> (Double, Double) {
  (self.a * x + self.c * y + self.e, self.b * x + self.d * y + self.f)
}

///|
/// The axis-aligned box of a rectangle under `self`.
fn XdwMatrix::box(
  self : XdwMatrix,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> (Double, Double, Double, Double) {
  let (x0, y0) = self.point(x, y)
  let (x1, y1) = self.point(x + w, y)
  let (x2, y2) = self.point(x, y + h)
  let (x3, y3) = self.point(x + w, y + h)
  let minx = x0.min(x1).min(x2).min(x3)
  let maxx = x0.max(x1).max(x2).max(x3)
  let miny = y0.min(y1).min(y2).min(y3)
  let maxy = y0.max(y1).max(y2).max(y3)
  (minx, miny, maxx - minx, maxy - miny)
}

///|
/// Whether `inner` lies completely inside `outer`. A partial overlap leaves
/// the text visible, which is what the upstream reader does too.
fn xdw_box_contains(
  outer : (Double, Double, Double, Double),
  inner : (Double, Double, Double, Double),
) -> Bool {
  let (ox, oy, ow, oh) = outer
  let (ix, iy, iw, ih) = inner
  ix >= ox && iy >= oy && ix + iw <= ox + ow && iy + ih <= oy + oh
}

///|
/// The text runs of a page's object stream, in drawing order, with the runs a
/// later opaque fill covers completely marked.
fn xdw_page_text_runs(encoded : Bytes) -> Array[XdwTextRun] raise {
  let commands = @render.decode_commands(encoded)
  let runs : Array[XdwTextRun] = []
  let covers : Array[XdwCover] = []
  let stack : Array[(XdwMatrix, Double, Double, Double)] = []
  let mut matrix = xdw_matrix_identity()
  let mut size = 12.0
  let mut alpha = 1.0
  let mut fill_alpha = 1.0
  for order, command in commands {
    match command {
      Save => stack.push((matrix, size, alpha, fill_alpha))
      Restore =>
        match stack.pop() {
          Some((m, s, a, fa)) => {
            matrix = m
            size = s
            alpha = a
            fill_alpha = fa
          }
          None => ()
        }
      Transform(a, b, c, d, e, f) =>
        matrix = matrix.compose({ a, b, c, d, e, f })
      Translate(x, y) =>
        matrix = matrix.compose({ a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: x, f: y })
      Scale(x, y) =>
        matrix = matrix.compose({ a: x, b: 0.0, c: 0.0, d: y, e: 0.0, f: 0.0 })
      Font(_, s) => size = s
      Alpha(a) => alpha = a
      // The colour is 0xRRGGBBAA, so the low byte is the fill's own alpha.
      FillColor(c) => fill_alpha = (c & 0xff).to_double() / 255.0
      FillRect(x, y, w, h) =>
        if alpha * fill_alpha >= 0.999 {
          let (bx, by, bw, bh) = matrix.box(x, y, w, h)
          covers.push({ order, x: bx, y: by, w: bw, h: bh })
        }
      ClearRect(x, y, w, h) =>
        if alpha >= 0.999 {
          let (bx, by, bw, bh) = matrix.box(x, y, w, h)
          covers.push({ order, x: bx, y: by, w: bw, h: bh })
        }
      Image(_, x, y, w, h) =>
        if alpha >= 0.999 {
          let (bx, by, bw, bh) = matrix.box(x, y, w, h)
          covers.push({ order, x: bx, y: by, w: bw, h: bh })
        }
      FillText(text, x, y, advance) => {
        // `y` is the baseline; the run reaches 0.8 em above it, the same
        // offset the metafile writer uses for top-aligned text.
        let (bx, by, bw, bh) = matrix.box(x, y - size * 0.8, advance, size)
        runs.push({
          text,
          x: bx,
          y: by,
          w: bw,
          h: bh,
          order,
          covered: false,
        })
      }
      _ => ()
    }
  }
  for run in runs {
    for cover in covers {
      if cover.order > run.order &&
        xdw_box_contains((cover.x, cover.y, cover.w, cover.h), (run.x, run.y, run.w, run.h)) {
        run.covered = true
        break
      }
    }
  }
  runs
}

///|
/// The separator to put before `run`, given the run drawn before it: a new
/// line when the baseline moved, a space when the runs are apart on the same
/// line, nothing when they continue each other.
fn xdw_separator(prev : XdwTextRun, run : XdwTextRun) -> Int32 {
  let size = if prev.h > 0.0 { prev.h } else { 10.0 }
  if (run.y - prev.y).abs() > size * 0.5 {
    2
  } else if run.x - (prev.x + prev.w) > size * 0.2 {
    1
  } else {
    0
  }
}

///|
/// Turn a page's runs into index runs. Covered runs are dropped unless
/// `include_hidden` keeps them.
fn xdw_index_runs(
  runs : Array[XdwTextRun],
  page : Int,
  layer : Int,
  include_hidden : Bool,
) -> Array[@core.IndexRun] {
  let out : Array[@core.IndexRun] = []
  let mut prev : XdwTextRun? = None
  for run in runs {
    if run.text == "" {
      continue
    }
    if run.covered && !include_hidden {
      continue
    }
    let separator = match prev {
      Some(p) => xdw_separator(p, run)
      None => 2
    }
    out.push({
      a: page,
      b: layer,
      ordinal: out.length(),
      separator,
      text: run.text,
    })
    prev = Some(run)
  }
  out
}
