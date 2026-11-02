///|
/// A shape split into what is filled and what is stroked, so that boxes
/// with inner detail (cylinder tops, note folds, table lines, …) fill only
/// the body and stroke the outline and the detail.
priv struct DrawioShapePaint {
  fill : @cad.CadPath
  stroke : @cad.CadPath
  has_fill : Bool
  has_stroke : Bool
}

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
fn drawio_polygon_path(path : @cad.CadPath, points : Array[(Double, Double)]) -> Unit {
  if points.length() < 3 {
    return
  }
  let vertices : Array[@cad.Point] = []
  for point in points {
    vertices.push({ x: point.0, y: point.1 })
  }
  path.polyline(vertices, true)
}

///|
fn drawio_shape_paint(
  kind : DrawioShapeKind,
  style : String,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> DrawioShapePaint {
  let fill = @cad.CadPath::new()
  let stroke = @cad.CadPath::new()
  let w = Double::max(w, 0.0)
  let h = Double::max(h, 0.0)
  if kind == DkText {
    return { fill, stroke, has_fill: false, has_stroke: false }
  }
  if kind == DkPartialRect {
    fill.polyline([
      { x, y },
      { x: x + w, y },
      { x: x + w, y: y + h },
      { x, y: y + h },
    ], true)
    let top = drawio_style(style, "top", "1") != "0"
    let left = drawio_style(style, "left", "1") != "0"
    let bottom = drawio_style(style, "bottom", "1") != "0"
    let right = drawio_style(style, "right", "1") != "0"
    if top {
      stroke.move_to(x, y)
      stroke.line_to(x + w, y)
    }
    if right {
      stroke.move_to(x + w, y)
      stroke.line_to(x + w, y + h)
    }
    if bottom {
      stroke.move_to(x + w, y + h)
      stroke.line_to(x, y + h)
    }
    if left {
      stroke.move_to(x, y + h)
      stroke.line_to(x, y)
    }
    return { fill, stroke, has_fill: true, has_stroke: top || left || bottom || right }
  }
  if kind == DkLine {
    let mid = y + h / 2.0
    stroke.move_to(x, mid)
    stroke.line_to(x + w, mid)
    return { fill, stroke, has_fill: false, has_stroke: true }
  }
  let polygon = kind == DkRhombus || kind == DkTriangle || kind == DkHexagon ||
    kind == DkParallelogram || kind == DkTrapezoid || kind == DkStep ||
    kind == DkOctagon || kind == DkCross || kind == DkStar
  if polygon {
    let points = drawio_shape_vertices(kind, style, x, y, w, h)
    drawio_polygon_path(fill, points)
    drawio_polygon_path(stroke, points)
    return { fill, stroke, has_fill: true, has_stroke: true }
  }
  if kind == DkEllipse || kind == DkDoubleEllipse {
    fill.ellipse(
      { x: x + w / 2.0, y: y + h / 2.0 },
      { x: w / 2.0, y: 0.0 },
      if w == 0.0 { 1.0 } else { h / w },
    )
    stroke.ellipse(
      { x: x + w / 2.0, y: y + h / 2.0 },
      { x: w / 2.0, y: 0.0 },
      if w == 0.0 { 1.0 } else { h / w },
    )
    if kind == DkDoubleEllipse {
      let margin = Double::min(
        3.0 + drawio_num_from_style(style, "strokeWidth", 1.0),
        Double::min(w / 5.0, h / 5.0),
      )
      let iw = w - margin * 2.0
      let ih = h - margin * 2.0
      if iw > 0.0 && ih > 0.0 {
        stroke.ellipse(
          { x: x + w / 2.0, y: y + h / 2.0 },
          { x: iw / 2.0, y: 0.0 },
          if iw == 0.0 { 1.0 } else { ih / iw },
        )
      }
    }
    return { fill, stroke, has_fill: true, has_stroke: true }
  }
  if kind == DkRoundedRect || kind == DkStadium {
    let radius = if kind == DkStadium {
      Double::min(w, h) / 2.0
    } else {
      let percent = drawio_num_from_style(style, "arcSize", 15.0) * 0.01
      Double::min(w, h) * Double::min(percent, 0.5)
    }
    drawio_rounded_path(fill, x, y, w, h, radius)
    drawio_rounded_path(stroke, x, y, w, h, radius)
    return { fill, stroke, has_fill: true, has_stroke: true }
  }
  if kind == DkNote {
    let fold = Double::min(w * 0.2, 14.0)
    let points = drawio_shape_vertices(kind, style, x, y, w, h)
    drawio_polygon_path(fill, points)
    drawio_polygon_path(stroke, points)
    stroke.move_to(x + w - fold, y)
    stroke.line_to(x + w - fold, y + fold)
    stroke.line_to(x + w, y + fold)
    return { fill, stroke, has_fill: true, has_stroke: true }
  }
  if kind == DkDocument {
    fill.move_to(x, y)
    fill.line_to(x + w, y)
    fill.line_to(x + w, y + h * 0.85)
    fill.cubic_to(
      { x: x + w * 0.75, y: y + h * 1.05 },
      { x: x + w * 0.25, y: y + h * 0.65 },
      { x, y: y + h * 0.85 },
    )
    fill.close()
    stroke.move_to(x, y)
    stroke.line_to(x + w, y)
    stroke.line_to(x + w, y + h * 0.85)
    stroke.cubic_to(
      { x: x + w * 0.75, y: y + h * 1.05 },
      { x: x + w * 0.25, y: y + h * 0.65 },
      { x, y: y + h * 0.85 },
    )
    stroke.close()
    return { fill, stroke, has_fill: true, has_stroke: true }
  }
  if kind == DkCylinder {
    let top = Double::min(h * 0.12, 12.0)
    fill.move_to(x, y + top)
    fill.cubic_to(
      { x: x + w * 0.15, y },
      { x: x + w * 0.85, y },
      { x: x + w, y: y + top },
    )
    fill.line_to(x + w, y + h - top)
    fill.cubic_to(
      { x: x + w * 0.85, y: y + h },
      { x: x + w * 0.15, y: y + h },
      { x, y: y + h - top },
    )
    fill.close()
    stroke.move_to(x, y + top)
    stroke.cubic_to(
      { x: x + w * 0.15, y },
      { x: x + w * 0.85, y },
      { x: x + w, y: y + top },
    )
    stroke.line_to(x + w, y + h - top)
    stroke.cubic_to(
      { x: x + w * 0.85, y: y + h },
      { x: x + w * 0.15, y: y + h },
      { x, y: y + h - top },
    )
    stroke.close()
    stroke.move_to(x, y + top)
    stroke.cubic_to(
      { x: x + w * 0.15, y: y + top * 2.0 },
      { x: x + w * 0.85, y: y + top * 2.0 },
      { x: x + w, y: y + top },
    )
    return { fill, stroke, has_fill: true, has_stroke: true }
  }
  if kind == DkCube {
    let depth = Double::min(Double::min(w, h) * 0.18, 14.0)
    fill.polyline([
      { x, y: y + depth },
      { x: x + depth, y },
      { x: x + w, y },
      { x: x + w, y: y + h - depth },
      { x: x + w - depth, y: y + h },
      { x, y: y + h },
    ], true)
    drawio_polygon_path(stroke, [
      (x, y + depth),
      (x + depth, y),
      (x + w, y),
      (x + w, y + h - depth),
      (x + w - depth, y + h),
      (x, y + h),
    ])
    stroke.move_to(x, y + depth)
    stroke.line_to(x + depth, y + depth)
    stroke.line_to(x + depth, y)
    stroke.move_to(x + depth, y + depth)
    stroke.line_to(x + w, y + depth)
    stroke.move_to(x + depth, y + depth)
    stroke.line_to(x + depth, y + h)
    return { fill, stroke, has_fill: true, has_stroke: true }
  }
  if kind == DkCloud {
    fill.move_to(x + w * 0.2, y + h * 0.8)
    fill.cubic_to(
      { x: x - w * 0.05, y: y + h * 0.55 },
      { x: x + w * 0.1, y: y + h * 0.25 },
      { x: x + w * 0.28, y: y + h * 0.32 },
    )
    fill.cubic_to(
      { x: x + w * 0.35, y: y + h * 0.05 },
      { x: x + w * 0.65, y },
      { x: x + w * 0.72, y: y + h * 0.3 },
    )
    fill.cubic_to(
      { x: x + w * 0.95, y: y + h * 0.25 },
      { x: x + w * 1.08, y: y + h * 0.6 },
      { x: x + w * 0.8, y: y + h * 0.78 },
    )
    fill.cubic_to(
      { x: x + w * 0.7, y: y + h * 1.02 },
      { x: x + w * 0.3, y: y + h * 1.02 },
      { x: x + w * 0.2, y: y + h * 0.8 },
    )
    fill.close()
    stroke.append(fill)
    return { fill, stroke, has_fill: true, has_stroke: true }
  }
  if kind == DkActor || kind == DkUmlActor {
    let head = Double::min(w, h * 0.25) / 2.0
    let cx = x + w / 2.0
    fill.circle({ x: cx, y: y + head }, head)
    stroke.circle({ x: cx, y: y + head }, head)
    let body_top = y + head * 2.0
    stroke.move_to(cx, body_top)
    stroke.line_to(cx, y + h * 0.7)
    stroke.move_to(x + w * 0.2, y + h * 0.38)
    stroke.line_to(x + w * 0.8, y + h * 0.38)
    stroke.move_to(cx, y + h * 0.7)
    stroke.line_to(x + w * 0.2, y + h)
    stroke.move_to(cx, y + h * 0.7)
    stroke.line_to(x + w * 0.8, y + h)
    return { fill, stroke, has_fill: true, has_stroke: true }
  }
  if kind == DkCallout {
    let size = Double::min(
      Double::max(drawio_num_from_style(style, "size", 30.0), 4.0),
      Double::min(w * 0.5, h * 0.5),
    )
    let position = drawio_num_from_style(style, "position", 0.5)
    let body = Double::max(h - size, 0.0)
    let px = x + Double::min(Double::max(position, 0.0), 1.0) * w
    let points = [
      (x, y),
      (x + w, y),
      (x + w, y + body),
      (px + size / 2.0, y + body),
      (px, y + body + size),
      (px - size / 2.0, y + body),
      (x, y + body),
    ]
    drawio_polygon_path(fill, points)
    drawio_polygon_path(stroke, points)
    return { fill, stroke, has_fill: true, has_stroke: true }
  }
  if kind == DkProcess {
    fill.polyline([
      { x, y },
      { x: x + w, y },
      { x: x + w, y: y + h },
      { x, y: y + h },
    ], true)
    drawio_polygon_path(stroke, [(x, y), (x + w, y), (x + w, y + h), (x, y + h)])
    let inset = Double::min(w * 0.125, 12.0)
    stroke.move_to(x + inset, y)
    stroke.line_to(x + inset, y + h)
    stroke.move_to(x + w - inset, y)
    stroke.line_to(x + w - inset, y + h)
    return { fill, stroke, has_fill: true, has_stroke: true }
  }
  if kind == DkSwimlane {
    fill.polyline([
      { x, y },
      { x: x + w, y },
      { x: x + w, y: y + h },
      { x, y: y + h },
    ], true)
    drawio_polygon_path(stroke, [(x, y), (x + w, y), (x + w, y + h), (x, y + h)])
    let start = Double::min(
      Double::max(drawio_num_from_style(style, "startSize", 40.0), 0.0),
      if drawio_shape_vertical(style) { w } else { h },
    )
    if start > 0.0 {
      if drawio_shape_vertical(style) {
        stroke.move_to(x + start, y)
        stroke.line_to(x + start, y + h)
      } else {
        stroke.move_to(x, y + start)
        stroke.line_to(x + w, y + start)
      }
    }
    return { fill, stroke, has_fill: true, has_stroke: true }
  }
  if kind == DkTable || kind == DkTableRow {
    fill.polyline([
      { x, y },
      { x: x + w, y },
      { x: x + w, y: y + h },
      { x, y: y + h },
    ], true)
    drawio_polygon_path(stroke, [(x, y), (x + w, y), (x + w, y + h), (x, y + h)])
    return { fill, stroke, has_fill: true, has_stroke: true }
  }
  if kind == DkUmlBoundary {
    fill.ellipse(
      { x: x + w / 2.0 + 2.0, y: y + h / 2.0 },
      { x: Double::max(w / 2.0 - 2.0, 0.0), y: 0.0 },
      if w == 0.0 { 1.0 } else { h / Double::max(w - 4.0, 1.0) },
    )
    stroke.ellipse(
      { x: x + w / 2.0 + 2.0, y: y + h / 2.0 },
      { x: Double::max(w / 2.0 - 2.0, 0.0), y: 0.0 },
      if w == 0.0 { 1.0 } else { h / Double::max(w - 4.0, 1.0) },
    )
    stroke.move_to(x, y + 2.0)
    stroke.line_to(x, y + h - 2.0)
    stroke.move_to(x, y + h / 2.0)
    stroke.line_to(x + w * 0.25, y + h / 2.0)
    return { fill, stroke, has_fill: true, has_stroke: true }
  }
  if kind == DkUmlEntity {
    fill.circle({ x: x + w / 2.0, y: y + h / 2.0 }, Double::min(w, h) / 2.0)
    stroke.circle({ x: x + w / 2.0, y: y + h / 2.0 }, Double::min(w, h) / 2.0)
    stroke.move_to(x + w * 0.1, y + h)
    stroke.line_to(x + w * 0.9, y + h)
    return { fill, stroke, has_fill: true, has_stroke: true }
  }
  if kind == DkUmlControl {
    let radius = Double::min(w, h) / 2.0
    fill.circle({ x: x + w / 2.0, y: y + h / 2.0 }, radius)
    stroke.circle({ x: x + w / 2.0, y: y + h / 2.0 }, radius)
    stroke.move_to(x + w * 0.1, y + h * 0.1)
    stroke.line_to(x + w * 0.35, y + h * 0.35)
    stroke.move_to(x + w * 0.35, y + h * 0.35)
    stroke.line_to(x + w * 0.2, y + h * 0.35)
    stroke.move_to(x + w * 0.35, y + h * 0.35)
    stroke.line_to(x + w * 0.35, y + h * 0.2)
    return { fill, stroke, has_fill: true, has_stroke: true }
  }
  if kind == DkUmlDestroy {
    stroke.move_to(x, y)
    stroke.line_to(x + w, y + h)
    stroke.move_to(x + w, y)
    stroke.line_to(x, y + h)
    return { fill, stroke, has_fill: false, has_stroke: true }
  }
  if kind == DkUmlLifeline {
    fill.polyline([
      { x, y },
      { x: x + w, y },
      { x: x + w, y: y + h },
      { x, y: y + h },
    ], true)
    drawio_polygon_path(stroke, [(x, y), (x + w, y), (x + w, y + h), (x, y + h)])
    return { fill, stroke, has_fill: true, has_stroke: true }
  }
  if kind == DkUmlFrame {
    fill.polyline([
      { x, y },
      { x: x + w, y },
      { x: x + w, y: y + h },
      { x, y: y + h },
    ], true)
    drawio_polygon_path(stroke, [(x, y), (x + w, y), (x + w, y + h), (x, y + h)])
    let tab = Double::min(Double::min(w * 0.5, h * 0.5), 40.0)
    if tab > 4.0 {
      stroke.move_to(x, y + tab)
      stroke.line_to(x + tab * 0.65, y + tab)
      stroke.line_to(x + tab, y + tab * 0.65)
      stroke.line_to(x + tab, y)
    }
    return { fill, stroke, has_fill: true, has_stroke: true }
  }
  if kind == DkUmlState {
    let radius = Double::min(w, h) * 0.15
    drawio_rounded_path(fill, x, y, w, h, radius)
    drawio_rounded_path(stroke, x, y, w, h, radius)
    return { fill, stroke, has_fill: true, has_stroke: true }
  }
  if kind == DkComponent {
    let tab = Double::min(Double::min(w, h) * 0.12, 10.0)
    fill.polyline([
      { x, y },
      { x: x + w, y },
      { x: x + w, y: y + h },
      { x, y: y + h },
    ], true)
    drawio_polygon_path(stroke, [(x, y), (x + w, y), (x + w, y + h), (x, y + h)])
    if tab > 2.0 {
      for index in 0..<2 {
        let ty = y + h * (0.2 + 0.4 * index.to_double())
        stroke.move_to(x, ty)
        stroke.line_to(x - tab, ty)
        stroke.line_to(x - tab, ty + tab)
        stroke.line_to(x, ty + tab)
      }
    }
    return { fill, stroke, has_fill: true, has_stroke: true }
  }
  if kind == DkModule {
    let tab = Double::min(Double::min(w, h) * 0.25, 14.0)
    fill.polyline([
      { x, y },
      { x: x + w, y },
      { x: x + w, y: y + h },
      { x, y: y + h },
    ], true)
    drawio_polygon_path(stroke, [(x, y), (x + w, y), (x + w, y + h), (x, y + h)])
    stroke.move_to(x, y + tab)
    stroke.line_to(x + tab, y + tab)
    stroke.line_to(x + tab, y)
    return { fill, stroke, has_fill: true, has_stroke: true }
  }
  if kind == DkLollipop {
    let radius = Double::min(w, h * 0.3) / 2.0
    let cx = x + w / 2.0
    let cy = y + radius
    fill.circle({ x: cx, y: cy }, radius)
    stroke.circle({ x: cx, y: cy }, radius)
    stroke.move_to(cx, cy + radius)
    stroke.line_to(cx, y + h)
    return { fill, stroke, has_fill: true, has_stroke: true }
  }
  // DkRect and every kind without a distinct outline.
  fill.polyline([
    { x, y },
    { x: x + w, y },
    { x: x + w, y: y + h },
    { x, y: y + h },
  ], true)
  drawio_polygon_path(stroke, [(x, y), (x + w, y), (x + w, y + h), (x, y + h)])
  { fill, stroke, has_fill: true, has_stroke: true }
}

///|
/// Whether an edge is painted as a block arrow instead of a line
/// (`shape=flexArrow` and the other mxArrowConnector variants).
fn drawio_edge_is_block_arrow(style : String) -> Bool {
  let shape = drawio_style(style, "shape", "")
  shape == "flexArrow" || shape == "arrowConnector" || shape == "link" ||
    shape == "arrow"
}

///|
/// Paint an edge as a block arrow between its first and last points. This
/// is the practical subset of mxArrowConnector: the shaft and the head are
/// taken from `width`, `endWidth` and `endSize`, and bend points are
/// ignored.
fn drawio_paint_block_arrow(
  drawing : @cad.Drawing,
  from : (Double, Double),
  to : (Double, Double),
  style : String,
  stroke : UInt32,
) -> Unit {
  let dx = to.0 - from.0
  let dy = to.1 - from.1
  let distance = (dx * dx + dy * dy).sqrt()
  if distance <= 1.0 {
    return
  }
  let ux = dx / distance
  let uy = dy / distance
  let px = -uy
  let py = ux
  let shaft = Double::max(drawio_num_from_style(style, "width", 10.0), 1.0) / 2.0
  let head_width = Double::max(drawio_num_from_style(style, "endWidth", 20.0), shaft * 2.0) / 2.0
  let head = Double::min(
    Double::max(drawio_num_from_style(style, "endSize", 20.0), 1.0),
    distance,
  )
  let base_x = to.0 - ux * head
  let base_y = to.1 - uy * head
  let path = @cad.CadPath::new()
  path.polyline([
    { x: from.0 + px * shaft, y: from.1 + py * shaft },
    { x: base_x + px * shaft, y: base_y + py * shaft },
    { x: base_x + px * head_width, y: base_y + py * head_width },
    { x: to.0, y: to.1 },
    { x: base_x - px * head_width, y: base_y - py * head_width },
    { x: base_x - px * shaft, y: base_y - py * shaft },
    { x: from.0 - px * shaft, y: from.1 - py * shaft },
  ], true)
  let fill_color = drawio_color(drawio_style(style, "fillColor", ""), stroke)
  if drawio_style(style, "fillColor", "") != "none" {
    drawing.fill(path, @cad.Fill::solid(fill_color), false)
  }
  if drawio_style(style, "strokeColor", "") != "none" {
    drawing.stroke(path, @cad.Pen::new(color=stroke, width=1.0, cap=@cad.CAP_ROUND, join=@cad.JOIN_ROUND))
  }
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
