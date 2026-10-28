///|
/// A search highlight in page or sheet coordinates.
pub(all) struct HitRect {
  a : Int32
  b : Int32
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Eq, Debug)

///|
/// Whether the actual drawn width of a run can be measured.
pub fn text_has_extent(run : TextRun) -> Bool {
  run.font is Some(_) && (!run.alt_text || run.advance > 0.0)
}

///|
fn slice_end(index : Int32, length : Int32) -> Int32 {
  if index < 0 {
    (length.to_int64() + index.to_int64()).max(0L).to_int()
  } else {
    index.min(length)
  }
}

///|
/// Bound part of a run using a host font measurer. `start` and `end` are
/// UTF-16 code-unit offsets, as returned by `TextSearch::search`.
pub fn run_rect(
  run : TextRun,
  start : Int32,
  end : Int32,
  measure : (@core.Font, Double, String) -> Double,
) -> TextRect? {
  guard run.font is Some(font) else { return None }
  let full = measure(font, run.size, run.text)
  let width = if run.advance > 0.0 { run.advance } else { full }
  let scale = if run.advance > 0.0 && full > 0.0 {
    run.advance / full
  } else {
    1.0
  }
  let w1 = measure(
      font,
      run.size,
      run.text.unsafe_substring(
        start=0,
        end=slice_end(start, run.text.length()),
      ),
    ) *
    scale
  let w2 = measure(
      font,
      run.size,
      run.text.unsafe_substring(start=0, end=slice_end(end, run.text.length())),
    ) *
    scale
  let anchor = if run.align == 1 {
    -width
  } else if run.align == 2 {
    -width / 2.0
  } else {
    0.0
  }
  let (a, b, c, d, _, _) = run.matrix
  let xs = [anchor + w1, anchor + w2]
  let ys = [-run.size * 0.8, run.size * 0.2]
  let mut x0 = a * xs[0] + c * ys[0] + run.x
  let mut y0 = b * xs[0] + d * ys[0] + run.y
  let mut x1 = x0
  let mut y1 = y0
  for dx in xs {
    for dy in ys {
      let x = a * dx + c * dy + run.x
      let y = b * dx + d * dy + run.y
      x0 = x0.min(x)
      y0 = y0.min(y)
      x1 = x1.max(x)
      y1 = y1.max(y)
    }
  }
  Some({ x: x0, y: y0, width: x1 - x0, height: y1 - y0, })
}

///|
/// Locate the segments of a hit using runs supplied by the host. Set
/// `tile_size` for sheets to translate tile-local rectangles into sheet space.
pub fn locate_text_hit(
  hit : @core.SearchHit,
  run_at : (Int32, Int32, Int32) -> TextRun?,
  measure : (@core.Font, Double, String) -> Double,
  tile_size~ : Double = 0.0,
) -> Array[HitRect] {
  let out : Array[HitRect] = []
  for segment in hit.segments {
    if run_at(segment.a, segment.b, segment.ordinal) is Some(run) &&
      text_has_extent(run) {
      if run_rect(run, segment.start, segment.end, measure) is Some(rect) {
        out.push({
          a: segment.a,
          b: segment.b,
          x: rect.x + segment.a.to_double() * tile_size,
          y: rect.y + segment.b.to_double() * tile_size,
          width: rect.width,
          height: rect.height,
        })
      }
    }
  }
  out
}
