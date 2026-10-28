///|
/// Positions and total extent of the bodies in a continuous view.
pub(all) struct ContinuousLayout {
  offsets : Array[Double]
  width : Double
  height : Double
} derive(Debug)

///|
/// A page body placed in continuous-view coordinates.
pub(all) struct ContinuousBand {
  index : Int32
  offset : Double
  body : @core.PageRect
} derive(Debug, Eq)

///|
/// The body rectangle, or the full page when the document omits one.
pub fn continuous_body(page : @core.Page) -> @core.PageRect {
  match page.body {
    Some(body) => body
    None => { x: 0.0, y: 0.0, width: page.width, height: page.height, }
  }
}

///|
/// Match PageRenderer.continuousLayout, including negative gaps and scroll strips.
pub fn continuous_layout(view : @core.View) -> ContinuousLayout {
  let gap = if view.kind == "scroll" {
    0.0
  } else {
    view.continuous_gap.unwrap_or(0.0)
  }
  let offsets : Array[Double] = []
  let mut width = 0.0
  let mut y = 0.0
  for page in view.pages {
    let body = continuous_body(page)
    offsets.push(y)
    y += body.height + gap
    width = width.max(body.width)
  }
  { offsets, width, height: (y - gap).max(0.0), }
}

///|
/// Bodies intersecting a vertical viewport, in drawing order.
pub fn continuous_bands(
  view : @core.View,
  viewport : TextRect,
) -> Array[ContinuousBand] {
  let layout = continuous_layout(view)
  let bands : Array[ContinuousBand] = []
  for index, page in view.pages {
    let body = continuous_body(page)
    let top = layout.offsets[index]
    if top < viewport.y + viewport.height && top + body.height > viewport.y {
      bands.push({ index, offset: top, body, })
    }
  }
  bands
}
