///|
/// A row laid out at a distance from the top of its scroll view.
pub(all) struct ScrollBand {
  y : Double
  height : Double
  keep : Bool
}

///|
/// A page cut from a scroll view, with the indices and local y-coordinates of its rows.
pub(all) struct ScrollStrip {
  start : Double
  height : Double
  bands : Array[(Int32, Double)]
}

///|
/// Completed scroll-page cuts and anchor positions.
pub struct ScrollPlan {
  strips : Array[ScrollStrip]
  priv anchors : Map[String, Double]
}

///|
/// Stacked specimen rows and anchors before the scroll view is split into pages.
pub struct ScrollLayout {
  priv mut y : Double
  priv bands : Array[ScrollBand]
  priv anchors : Map[String, Double]
}

///|
pub fn ScrollLayout::new() -> ScrollLayout {
  { y: 36.0, bands: [], anchors: Map([]), }
}

///|
/// Add a row, optionally keeping it on the same strip as the following row.
pub fn ScrollLayout::add(
  self : ScrollLayout,
  height : Double,
  keep~ : Bool = false,
) -> Unit {
  self.bands.push({ y: self.y, height, keep, })
  self.y += height
}

///|
pub fn ScrollLayout::space(self : ScrollLayout, height : Double) -> Unit {
  self.y += height
}

///|
/// Anchor the position where the next row starts; later anchors replace earlier ones.
pub fn ScrollLayout::anchor(self : ScrollLayout, name : String) -> Unit {
  self.anchors[name] = self.y
}

///|
/// Cut at row boundaries near 1024 pt while keeping headings and avoiding a short trailing strip.
pub fn ScrollLayout::finish(self : ScrollLayout) -> ScrollPlan {
  let total = self.y + 36.0
  let cuts : Array[Double] = [0.0]
  let mut start = 0.0
  for i, band in self.bands {
    if i == 0 || band.y - start < 1024.0 || self.bands[i - 1].keep {
      continue
    }
    if total - band.y < 256.0 {
      break
    }
    cuts.push(band.y)
    start = band.y
  }
  cuts.push(total)
  let strips : Array[ScrollStrip] = []
  let mut k = 0
  for i in 0..<(cuts.length() - 1) {
    let a = cuts[i]
    let b = cuts[i + 1]
    let rows : Array[(Int32, Double)] = []
    while k < self.bands.length() && self.bands[k].y < b {
      rows.push((k, self.bands[k].y - a))
      k += 1
    }
    strips.push({ start: a, height: b - a, bands: rows, })
  }
  { strips, anchors: self.anchors.copy(), }
}

///|
/// Resolve an anchor to its one-based scroll-page number.
pub fn ScrollPlan::anchor_page(self : ScrollPlan, name : String) -> Int32? {
  guard self.anchors.get(name) is Some(y) else { return None }
  let strips = self.strips
  for i in 1..<strips.length() {
    if y < strips[i].start {
      return Some(i)
    }
  }
  Some(strips.length())
}
