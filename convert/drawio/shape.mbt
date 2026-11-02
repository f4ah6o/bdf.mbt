///|
fn drawio_rounded_path(
  path : @cad.CadPath,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  radius : Double,
) -> Unit {
  let r = Double::min(Double::max(radius, 0.0), Double::min(w, h) / 2.0)
  if r <= 0.0 {
    path.polyline([
      { x, y },
      { x: x + w, y },
      { x: x + w, y: y + h },
      { x, y: y + h },
    ], true)
    return
  }
  let k = r * 0.5522847498
  path.move_to(x + r, y)
  path.line_to(x + w - r, y)
  path.cubic_to({ x: x + w - r + k, y }, { x: x + w, y: y + r - k }, { x: x + w, y: y + r })
  path.line_to(x + w, y + h - r)
  path.cubic_to({ x: x + w, y: y + h - r + k }, { x: x + w - r + k, y: y + h }, { x: x + w - r, y: y + h })
  path.line_to(x + r, y + h)
  path.cubic_to({ x: x + r - k, y: y + h }, { x, y: y + h - r + k }, { x, y: y + h - r })
  path.line_to(x, y + r)
  path.cubic_to({ x, y: y + r - k }, { x: x + r - k, y }, { x: x + r, y })
  path.close()
}

///|
fn drawio_shape(style : String, x : Double, y : Double, want_w : Double, want_h : Double) -> @cad.CadPath {
  let path = @cad.CadPath::new()
  let w = Double::max(want_w, 0.0)
  let h = Double::max(want_h, 0.0)
  let shape = drawio_style(style, "shape", "")
  let rounded = drawio_style(style, "rounded", "") == "1" || shape == "rounded"
  if shape == "ellipse" || drawio_style(style, "ellipse", "") == "1" {
    path.ellipse({ x: x + w / 2.0, y: y + h / 2.0 }, { x: w / 2.0, y: 0.0 }, if w == 0.0 { 1.0 } else { h / w })
  } else if shape == "rhombus" || shape == "decision" {
    path.polyline([
      { x: x + w / 2.0, y },
      { x: x + w, y: y + h / 2.0 },
      { x: x + w / 2.0, y: y + h },
      { x, y: y + h / 2.0 },
    ], true)
  } else if shape == "triangle" {
    path.polyline([
      { x: x + w / 2.0, y },
      { x: x + w, y: y + h },
      { x, y: y + h },
    ], true)
  } else if shape == "hexagon" {
    let inset = Double::min(w * 0.2, h / 2.0)
    path.polyline([
      { x: x + inset, y },
      { x: x + w - inset, y },
      { x: x + w, y: y + h / 2.0 },
      { x: x + w - inset, y: y + h },
      { x: x + inset, y: y + h },
      { x, y: y + h / 2.0 },
    ], true)
  } else if shape == "parallelogram" {
    let inset = Double::min(w * 0.2, w / 2.0)
    path.polyline([
      { x: x + inset, y },
      { x: x + w, y },
      { x: x + w - inset, y: y + h },
      { x, y: y + h },
    ], true)
  } else if shape == "trapezoid" {
    let inset = Double::min(w * 0.2, w / 2.0)
    path.polyline([
      { x: x + inset, y },
      { x: x + w - inset, y },
      { x: x + w, y: y + h },
      { x, y: y + h },
    ], true)
  } else if shape == "step" {
    let inset = Double::min(w * 0.2, w / 2.0)
    path.polyline([
      { x, y },
      { x: x + w - inset, y },
      { x: x + w, y: y + h / 2.0 },
      { x: x + w - inset, y: y + h },
      { x, y: y + h },
      { x: x + inset, y: y + h / 2.0 },
    ], true)
  } else if shape == "note" {
    let fold = Double::min(w * 0.2, 14.0)
    path.polyline([
      { x, y },
      { x: x + w - fold, y },
      { x: x + w, y: y + fold },
      { x: x + w, y: y + h },
      { x, y: y + h },
    ], true)
    path.move_to(x + w - fold, y)
    path.line_to(x + w - fold, y + fold)
    path.line_to(x + w, y + fold)
  } else if shape == "document" {
    path.move_to(x, y)
    path.line_to(x + w, y)
    path.line_to(x + w, y + h * 0.85)
    path.cubic_to(
      { x: x + w * 0.75, y: y + h * 1.05 },
      { x: x + w * 0.25, y: y + h * 0.65 },
      { x, y: y + h * 0.85 },
    )
    path.close()
  } else if shape == "cylinder" || shape == "cylinder3" || shape == "database" ||
    shape == "mxgraph.flowchart.database" {
    let top = Double::min(h * 0.12, 12.0)
    path.move_to(x, y + top)
    path.cubic_to(
      { x: x + w * 0.15, y },
      { x: x + w * 0.85, y },
      { x: x + w, y: y + top },
    )
    path.line_to(x + w, y + h - top)
    path.cubic_to(
      { x: x + w * 0.85, y: y + h },
      { x: x + w * 0.15, y: y + h },
      { x, y: y + h - top },
    )
    path.line_to(x, y + top)
    path.close()
    path.move_to(x, y + top)
    path.cubic_to(
      { x: x + w * 0.15, y: y + top * 2.0 },
      { x: x + w * 0.85, y: y + top * 2.0 },
      { x: x + w, y: y + top },
    )
  } else if shape == "cube" {
    let depth = Double::min(Double::min(w, h) * 0.18, 14.0)
    path.polyline([
      { x, y: y + depth },
      { x: x + depth, y },
      { x: x + w, y },
      { x: x + w, y: y + h - depth },
      { x: x + w - depth, y: y + h },
      { x, y: y + h },
    ], true)
    path.move_to(x, y + depth)
    path.line_to(x + depth, y + depth)
    path.line_to(x + depth, y)
    path.move_to(x + depth, y + depth)
    path.line_to(x + w, y + depth)
    path.move_to(x + depth, y + depth)
    path.line_to(x + depth, y + h)
  } else if shape == "cloud" {
    path.move_to(x + w * 0.2, y + h * 0.8)
    path.cubic_to(
      { x: x - w * 0.05, y: y + h * 0.55 },
      { x: x + w * 0.1, y: y + h * 0.25 },
      { x: x + w * 0.28, y: y + h * 0.32 },
    )
    path.cubic_to(
      { x: x + w * 0.35, y: y + h * 0.05 },
      { x: x + w * 0.65, y: y },
      { x: x + w * 0.72, y: y + h * 0.3 },
    )
    path.cubic_to(
      { x: x + w * 0.95, y: y + h * 0.25 },
      { x: x + w * 1.08, y: y + h * 0.6 },
      { x: x + w * 0.8, y: y + h * 0.78 },
    )
    path.cubic_to(
      { x: x + w * 0.7, y: y + h * 1.02 },
      { x: x + w * 0.3, y: y + h * 1.02 },
      { x: x + w * 0.2, y: y + h * 0.8 },
    )
    path.close()
  } else if shape == "actor" || shape == "umlActor" {
    let head = Double::min(w, h * 0.25) / 2.0
    let cx = x + w / 2.0
    path.circle({ x: cx, y: y + head }, head)
    let body_top = y + head * 2.0
    path.move_to(cx, body_top)
    path.line_to(cx, y + h * 0.7)
    path.move_to(x + w * 0.2, y + h * 0.38)
    path.line_to(x + w * 0.8, y + h * 0.38)
    path.move_to(cx, y + h * 0.7)
    path.line_to(x + w * 0.2, y + h)
    path.move_to(cx, y + h * 0.7)
    path.line_to(x + w * 0.8, y + h)
  } else if shape == "mxgraph.flowchart.start_1" || shape == "start" {
    drawio_rounded_path(path, x, y, w, h, Double::min(w, h) / 2.0)
  } else if rounded {
    let radius = drawio_num_from_style(style, "arcSize", 15.0) * 0.01
    drawio_rounded_path(path, x, y, w, h, Double::min(w, h) * Double::min(radius, 0.5))
  } else {
    path.polyline([
      { x, y },
      { x: x + w, y },
      { x: x + w, y: y + h },
      { x, y: y + h },
    ], true)
  }
  path
}

///|
fn drawio_num_from_style(style : String, key : String, default : Double) -> Double {
  let text = drawio_style(style, key, "")
  if text == "" {
    return default
  }
  @string.parse_double(text) catch {
    _ => default
  }
}
