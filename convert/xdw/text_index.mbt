///|
/// Which text of a DocuWorks page a later opaque fill hides.
///
/// DocuWorks draws a page as one metafile, so the page's object stream already
/// holds every string in drawing order: body text and annotation text alike.
/// The index itself is built from the renderer's own text runs, so its ordinals
/// and separators are exactly the ones the viewer draws with. This module only
/// answers which of those runs are hidden.
///
/// The walk is deliberately conservative: a run stays visible unless a fill
/// provably covers it. Hiding text that is still visible loses a search hit,
/// which is worse than indexing text that a reader cannot see.

///|
/// A text run found in a page's command stream: the box it occupies in page
/// points, and whether a later opaque fill covers it completely.
priv struct XdwTextRun {
  ordinal : Int32
  x : Double
  y : Double
  w : Double
  h : Double
  /// Position in the command stream, so only later fills can cover the run.
  order : Int
  /// Whether the box is trustworthy enough to test for coverage at all.
  provable : Bool
}

///|
/// A fill that may hide text drawn before it.
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
/// Whether `self` maps every axis-aligned rectangle to an axis-aligned
/// rectangle, so that `box` is the shape itself and not a larger hull.
///
/// A rotation by a multiple of 90° qualifies: it swaps the extents but keeps
/// the edges axis-aligned. Any other rotation or skew does not, and a fill
/// drawn under one cannot prove coverage from its box alone.
fn XdwMatrix::axis_aligned(self : XdwMatrix) -> Bool {
  let eps = 1.0e-9
  (self.b.abs() <= eps && self.c.abs() <= eps) ||
  (self.a.abs() <= eps && self.d.abs() <= eps)
}

///|
/// Whether `inner` lies completely inside `outer`. A partial overlap leaves
/// the text visible, which is what the upstream reader does too.
fn xdw_box_contains(
  outer : (Double, Double, Double, Double),
  inner : (Double, Double, Double, Double),
) -> Bool {
  let eps = 1.0e-9
  let (ox, oy, ow, oh) = outer
  let (ix, iy, iw, ih) = inner
  ix >= ox - eps &&
  iy >= oy - eps &&
  ix + iw <= ox + ow + eps &&
  iy + ih <= oy + oh + eps
}

///|
/// The drawing state that decides whether a fill can hide text.
priv struct XdwState {
  matrix : XdwMatrix
  size : Double
  /// Global alpha. `Alpha` sets it, as the PDF export does.
  alpha : Double
  /// The fill colour's own alpha, 0…1.
  fill_alpha : Double
  /// A `FillPaint` is active, so the fill's opacity is not provable.
  paint : Bool
  /// The clip in page space; `None` means the page is unclipped.
  clip : (Double, Double, Double, Double)?
  /// A `ClipPath` is active, so the clip's exact shape is not provable.
  clip_unknown : Bool
}

///|
fn xdw_state_initial() -> XdwState {
  {
    matrix: xdw_matrix_identity(),
    size: 10.0,
    alpha: 1.0,
    fill_alpha: 1.0,
    paint: false,
    clip: None,
    clip_unknown: false,
  }
}

///|
/// The page-space box a fill of `(x, y, w, h)` in user space covers, or `None`
/// when that cannot be proven.
///
/// The fill is clipped, so the box is intersected with the active clip. A
/// `ClipPath` makes the clip's shape unknown, and a rotated or skewed fill has
/// a box larger than the shape, so neither can prove coverage.
fn XdwState::cover_box(
  self : XdwState,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> (Double, Double, Double, Double)? {
  if self.clip_unknown || !self.matrix.axis_aligned() {
    return None
  }
  let (bx, by, bw, bh) = self.matrix.box(x, y, w, h)
  match self.clip {
    None => Some((bx, by, bw, bh))
    Some((cx, cy, cw, ch)) => {
      let left = bx.max(cx)
      let top = by.max(cy)
      let right = (bx + bw).min(cx + cw)
      let bottom = (by + bh).min(cy + ch)
      if right <= left || bottom <= top {
        None
      } else {
        Some((left, top, right - left, bottom - top))
      }
    }
  }
}

///|
/// The rectangle a path draws, when the path is exactly one axis-aligned
/// rectangle.
///
/// A curve, a rotated rectangle, or a path with several subpaths returns
/// `None`: its box would not prove that the fill hides what is under it. Real
/// EMF and WMF rectangles reach the object stream as a single rect verb, so
/// this is the shape that matters in practice.
fn xdw_rect_path(
  paths : Array[@core.PathEntry],
  index : Int32,
) -> (Double, Double, Double, Double)? {
  if index < 0 || index >= paths.length() {
    return None
  }
  let path = match paths[index] {
    @core.Inline(path) => path
    @core.External(_, _) => return None
  }
  if path.verbs.length() != 1 || path.verbs[0].to_int() != 5 {
    return None
  }
  let coordinates = path.coordinates
  if coordinates.length() < 4 {
    return None
  }
  if coordinates[2] <= 0.0 || coordinates[3] <= 0.0 {
    return None
  }
  Some((coordinates[0], coordinates[1], coordinates[2], coordinates[3]))
}

///|
/// A DocuWorks page object is self-contained: it never references another
/// object, so text extraction never has to resolve one.
fn xdw_no_external_object(_ : String) -> @core.ObjectResources? raise {
  None
}

///|
/// The text runs and opaque fills of one object stream, in drawing order.
priv struct XdwCoverScan {
  runs : Array[XdwTextRun]
  covers : Array[XdwCover]
}

///|
/// The text runs and opaque fills of one object stream.
///
/// Images are never covers: a decoded image can carry transparent pixels, so
/// its box does not prove opacity. A `FillPaint` is never a cover, because a
/// gradient or a pattern can be translucent. A fill under an unknown clip is
/// never a cover, because the clip may cut it away from the run.
fn xdw_scan_covers(
  encoded : Bytes,
  resources : @core.ObjectResources,
) -> XdwCoverScan raise {
  let commands = @render.decode_commands(encoded)
  let runs : Array[XdwTextRun] = []
  let covers : Array[XdwCover] = []
  let stack : Array[XdwState] = []
  let mut state = xdw_state_initial()
  let mut ordinal = 0
  for order, command in commands {
    match command {
      Save => stack.push(state)
      Restore =>
        match stack.pop() {
          Some(previous) => state = previous
          None => ()
        }
      Transform(a, b, c, d, e, f) =>
        state = { ..state, matrix: state.matrix.compose({ a, b, c, d, e, f }) }
      Translate(x, y) =>
        state = {
          ..state,
          matrix: state.matrix.compose({
            a: 1.0,
            b: 0.0,
            c: 0.0,
            d: 1.0,
            e: x,
            f: y,
          }),
        }
      Scale(x, y) =>
        state = {
          ..state,
          matrix: state.matrix.compose({
            a: x,
            b: 0.0,
            c: 0.0,
            d: y,
            e: 0.0,
            f: 0.0,
          }),
        }
      Font(_, size) => state = { ..state, size, }
      Alpha(value) => state = { ..state, alpha: value, }
      // The colour is 0xRRGGBBAA, so the low byte is the fill's own alpha.
      FillColor(colour) =>
        state = {
          ..state,
          fill_alpha: (colour & 0xff).to_double() / 255.0,
          paint: false,
        }
      FillPaint(_) => state = { ..state, paint: true, }
      ClipRect(x, y, w, h) => {
        let (bx, by, bw, bh) = state.matrix.box(x, y, w, h)
        let clipped = match state.clip {
          None => Some((bx, by, bw, bh))
          Some((cx, cy, cw, ch)) => {
            let left = bx.max(cx)
            let top = by.max(cy)
            let right = (bx + bw).min(cx + cw)
            let bottom = (by + bh).min(cy + ch)
            if right <= left || bottom <= top {
              Some((left, top, 0.0, 0.0))
            } else {
              Some((left, top, right - left, bottom - top))
            }
          }
        }
        state = { ..state, clip: clipped, }
      }
      ClipPath(_, _) => state = { ..state, clip_unknown: true, }
      FillRect(x, y, w, h) =>
        if state.alpha * state.fill_alpha >= 0.999 && !state.paint {
          match state.cover_box(x, y, w, h) {
            Some((bx, by, bw, bh)) =>
              covers.push({ order, x: bx, y: by, w: bw, h: bh })
            None => ()
          }
        }
      // `ClearRect` erases what is under it, so the text is gone either way.
      ClearRect(x, y, w, h) =>
        match state.cover_box(x, y, w, h) {
          Some((bx, by, bw, bh)) =>
            covers.push({ order, x: bx, y: by, w: bw, h: bh })
          None => ()
        }
      FillPath(index, _) =>
        if state.alpha * state.fill_alpha >= 0.999 && !state.paint {
          match xdw_rect_path(resources.paths, index) {
            Some((x, y, w, h)) =>
              match state.cover_box(x, y, w, h) {
                Some((bx, by, bw, bh)) =>
                  covers.push({ order, x: bx, y: by, w: bw, h: bh })
                None => ()
              }
            None => ()
          }
        }
      FillText(_, x, y, advance) => {
        // `y` is the baseline; the run reaches 0.8 em above it, the same
        // offset the metafile writer uses for top-aligned text. A run with no
        // advance or no size has no trustworthy box, so it is never covered.
        let (bx, by, bw, bh) = state.matrix.box(
          x,
          y - state.size * 0.8,
          advance,
          state.size,
        )
        runs.push({
          ordinal,
          x: bx,
          y: by,
          w: bw,
          h: bh,
          order,
          provable: advance > 0.0 && state.size > 0.0,
        })
        ordinal += 1
      }
      // The renderer indexes stroke text too, so it takes an ordinal, but a
      // stroke does not fill its box, so it is never treated as covered.
      StrokeText(_, _, _, _) => ordinal += 1
      _ => ()
    }
  }
  { runs, covers, }
}

///|
/// The page-space boxes of the opaque fills in a scan.
fn xdw_cover_boxes(scan : XdwCoverScan) -> Array[(Double, Double, Double, Double)] {
  scan.covers.map(fn(cover) { (cover.x, cover.y, cover.w, cover.h) })
}

///|
/// The ordinals of the text runs a later opaque fill hides completely.
///
/// `extra_covers` are fills from a layer drawn above this one. The viewer
/// draws that layer later, so its fills hide this layer's text exactly as a
/// fill in the same stream would. The body layer passes the annotation layer,
/// so the default index matches the default view, where annotations are
/// visible. A viewer that hides the annotation layer reveals body text that
/// this static index leaves out; the index cannot represent both views.
fn xdw_covered_ordinals(
  scan : XdwCoverScan,
  extra_covers : Array[(Double, Double, Double, Double)],
) -> Array[Int32] {
  let covered : Array[Int32] = []
  for run in scan.runs {
    if !run.provable {
      continue
    }
    let box = (run.x, run.y, run.w, run.h)
    let mut hidden = false
    for cover in scan.covers {
      if cover.order > run.order &&
        xdw_box_contains((cover.x, cover.y, cover.w, cover.h), box) {
        hidden = true
        break
      }
    }
    if !hidden {
      for cover in extra_covers {
        if xdw_box_contains(cover, box) {
          hidden = true
          break
        }
      }
    }
    if hidden {
      covered.push(run.ordinal)
    }
  }
  covered
}

///|
/// The index runs of one page layer, and how many runs the layer drew.
///
/// The runs come from the renderer, so their ordinals and separators are the
/// ones the viewer draws with — a run keeps its ordinal even when an earlier
/// run is left out, because the viewer locates a hit by that ordinal. Only the
/// runs a later opaque fill hides are dropped, and only when the caller did not
/// ask for them. The drawn count includes the hidden runs, so a run added
/// later can take an ordinal past every drawn one.
///
/// `covers_from` is a layer drawn above this one: its opaque fills hide this
/// layer's text, because the viewer draws it later. The body layer passes the
/// annotation layer, so a fill on an annotation still hides the body text it
/// covers, exactly as it did when both were one stream.
fn xdw_page_index_runs(
  encoded : Bytes,
  page : Int,
  layer : Int,
  include_hidden : Bool,
  covers_from : Bytes?,
) -> (Array[@core.IndexRun], Int32) raise {
  let resources = @core.decode_object_resources(encoded)
  let scan = xdw_scan_covers(encoded, resources)
  let extra_covers = match covers_from {
    Some(above) => {
      let above_resources = @core.decode_object_resources(above)
      xdw_cover_boxes(xdw_scan_covers(above, above_resources))
    }
    None => []
  }
  let covered = xdw_covered_ordinals(scan, extra_covers)
  let content = @render.extract_text(resources, xdw_no_external_object)
  let out : Array[@core.IndexRun] = []
  for run_index, run in content.runs {
    if !include_hidden && covered.contains(run.ordinal) {
      continue
    }
    out.push({
      a: page,
      b: layer,
      ordinal: run.ordinal,
      separator: if run_index == 0 { 2 } else { run.separator },
      text: run.text,
    })
  }
  (out, content.runs.length())
}

///|
/// Whether the document needs an `idx` part.
///
/// An index that is present but empty is not the same as a missing one: the
/// reader rebuilds a missing index from the object stream, which would bring
/// back exactly the text the index leaves out. So the part is written whenever
/// a page drew text, even when every run was filtered away. A page whose text
/// could not be read back is the one case that falls back, because a partial
/// index would silently drop that page's text.
fn xdw_index_part_needed(saw_text : Bool, index_failed : Bool) -> Bool {
  saw_text && !index_failed
}
