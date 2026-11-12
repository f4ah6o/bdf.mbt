///|
priv enum DrawioRenderItem {
  Shape(DrawioCell, DrawioShapeKind, Double, Double, Double, Double)
  Edge(DrawioCell, Array[(Double, Double)])
}

///|
fn drawio_double_opt(text : String) -> Double? {
  if text == "" {
    return None
  }
  let value = @string.parse_double(text) catch { _ => return None }
  Some(value)
}

///|
fn drawio_point(geo : DrawioNode, name : String) -> (Double, Double)? {
  let mut result : (Double, Double)? = None
  for child in geo.children {
    if child.name == "mxPoint" && drawio_attr(child, "as", "") == name {
      result = Some((drawio_num(child, "x", 0.0), drawio_num(child, "y", 0.0)))
    }
  }
  result
}

///|
fn drawio_offset(geo : DrawioNode) -> (Double, Double) {
  match drawio_point(geo, "offset") {
    Some(value) => value
    None => (0.0, 0.0)
  }
}

///|
fn drawio_waypoints(geo : DrawioNode) -> Array[(Double, Double)] {
  let output : Array[(Double, Double)] = []
  for child in geo.children {
    if child.name == "Array" && drawio_attr(child, "as", "") == "points" {
      for point in child.children {
        if point.name == "mxPoint" {
          output.push((drawio_num(point, "x", 0.0), drawio_num(point, "y", 0.0)))
        }
      }
    }
  }
  output
}

///|
/// A terminal of an edge: its shape kind, style and absolute bounds.
priv struct DrawioTerminal {
  kind : DrawioShapeKind
  style : String
  x : Double
  y : Double
  w : Double
  h : Double
  center : (Double, Double)
}

///|
fn drawio_terminal(model : DrawioModel, cell : DrawioCell, warn : DrawioWarn) -> DrawioTerminal {
  let (x, y, w, h) = model.absolute(cell)
  {
    kind: drawio_shape_kind(cell.style, warn),
    style: cell.style,
    x,
    y,
    w,
    h,
    center: (x + w / 2.0, y + h / 2.0),
  }
}

///|
/// The connection point a terminal's exitX/exitY (entryX/entryY) asks
/// for, projected onto the shape's perimeter unless exitPerimeter is 0.
fn drawio_connection_point(
  terminal : DrawioTerminal,
  edge_style : String,
  source : Bool,
) -> (Double, Double)? {
  let key_x = if source { "exitX" } else { "entryX" }
  let key_y = if source { "exitY" } else { "entryY" }
  let key_perimeter = if source { "exitPerimeter" } else { "entryPerimeter" }
  let key_dx = if source { "exitDx" } else { "entryDx" }
  let key_dy = if source { "exitDy" } else { "entryDy" }
  let fraction_x = match drawio_double_opt(drawio_style(edge_style, key_x, "")) {
    Some(value) => value
    None => return None
  }
  let fraction_y = match drawio_double_opt(drawio_style(edge_style, key_y, "")) {
    Some(value) => value
    None => return None
  }
  let px = terminal.x + fraction_x * terminal.w +
    drawio_num_from_style(edge_style, key_dx, 0.0)
  let py = terminal.y + fraction_y * terminal.h +
    drawio_num_from_style(edge_style, key_dy, 0.0)
  let perimeter = drawio_style(edge_style, key_perimeter, "1") != "0"
  if perimeter {
    Some(drawio_shape_perimeter(
      terminal.kind,
      terminal.style,
      terminal.x,
      terminal.y,
      terminal.w,
      terminal.h,
      px,
      py,
    ))
  } else {
    Some((px, py))
  }
}

///|
/// Whether the edge style asks for an orthogonal or elbow route.
fn drawio_edge_is_orthogonal(style : String) -> Bool {
  let edge_style = drawio_style(style, "edgeStyle", "")
  edge_style == "orthogonalEdgeStyle" || edge_style == "elbowEdgeStyle" ||
    edge_style == "orthogonalLoop"
}

///|
/// Turn a straight/waypoint route into an orthogonal route. Each segment
/// gets one corner; the first segment follows the exit side and the last
/// one the entry side, and other segments alternate. Zero-length segments
/// are removed.
fn drawio_orthogonal_route(
  points : Array[(Double, Double)],
  style : String,
) -> Array[(Double, Double)] {
  if points.length() < 2 {
    return points
  }
  let exit_x = drawio_style(style, "exitX", "")
  let exit_y = drawio_style(style, "exitY", "")
  let entry_x = drawio_style(style, "entryX", "")
  let entry_y = drawio_style(style, "entryY", "")
  let first_horizontal = if exit_x != "" {
    true
  } else if exit_y != "" {
    false
  } else {
    (points[1].0 - points[0].0).abs() >= (points[1].1 - points[0].1).abs()
  }
  let output : Array[(Double, Double)] = []
  let add = fn(point : (Double, Double)) {
    if output.is_empty() || output[output.length() - 1] != point {
      output.push(point)
    }
  }
  add(points[0])
  for index in 0..<(points.length() - 1) {
    let from = points[index]
    let to = points[index + 1]
    let horizontal = if index == 0 {
      first_horizontal
    } else if index == points.length() - 2 && entry_y != "" {
      false
    } else if index == points.length() - 2 && entry_x != "" {
      true
    } else {
      index % 2 == 0
    }
    if horizontal {
      add((to.0, from.1))
    } else {
      add((from.0, to.1))
    }
    add(to)
  }
  output
}

///|
/// The guaranteed facing-rectangle orthogonal route, taken before the
/// general perimeter projection. When an `edgeStyle=orthogonalEdgeStyle`
/// edge has floating ends on both terminals (no waypoint, fixed
/// exit/entry, rotation, port constraint, explicit perimeter or non-default
/// jetty in the way) and both terminals must connect at the box bounds --
/// rectangles, or AWS stencils whose `outlineConnect=0` opts out of their
/// outlines -- and the terminals face each other flat side to flat side
/// (horizontally separated, Y ranges overlapping, at least the default
/// jetties of 10 + 10 apart), the edge leaves one terminal at its facing
/// side's centre height, turns once midway in the gap, and enters the
/// other at its facing side's centre height. That is the side choice of
/// upstream orthConnector exactly when preferredVertDist <= 0 and
/// preferredHorizDist > 0 (shibukawa/bdf converter/drawio/edgestyle.go at
/// a5e4d7a6). Anything else returns None so the general path and its
/// fallbacks are unchanged.
fn drawio_facing_orthogonal_route(
  edge_style : String,
  source : DrawioTerminal?,
  target : DrawioTerminal?,
) -> Array[(Double, Double)]? {
  let s = match source {
    Some(value) => value
    None => return None
  }
  let t = match target {
    Some(value) => value
    None => return None
  }
  if drawio_style(edge_style, "edgeStyle", "") != "orthogonalEdgeStyle" {
    return None
  }
  for key in ["exitX", "exitY", "entryX", "entryY", "sourcePortConstraint", "targetPortConstraint", "portConstraint", "sourcePerimeterSpacing", "targetPerimeterSpacing", "perimeterSpacing"] {
    if drawio_style(edge_style, key, "") != "" {
      return None
    }
  }
  for key in ["jettySize", "sourceJettySize", "targetJettySize"] {
    let value = drawio_style(edge_style, key, "")
    if value != "" && value != "10" {
      return None
    }
  }
  for terminal in [s, t] {
    if terminal.w <= 0.0 || terminal.h <= 0.0 {
      return None
    }
    if drawio_num_from_style(terminal.style, "rotation", 0.0) != 0.0 {
      return None
    }
    for key in ["portConstraint", "perimeter", "perimeterSpacing"] {
      if drawio_style(terminal.style, key, "") != "" {
        return None
      }
    }
    let rectangle = terminal.kind == DkRect || terminal.kind == DkRoundedRect
    let aws = terminal.kind == DkStencil &&
      drawio_shape_name(terminal.style).has_prefix("mxgraph.aws") &&
      drawio_style(terminal.style, "outlineConnect", "") == "0"
    if !rectangle && !aws {
      return None
    }
  }
  // preferredHorizDist > 0 and preferredVertDist <= 0: the terminals are
  // horizontally separated with overlapping Y ranges.
  if s.y + s.h < t.y || t.y + t.h < s.y {
    return None
  }
  let (start, end) = if s.x + s.w <= t.x {
    if t.x - (s.x + s.w) < 20.0 {
      return None
    }
    ((s.x + s.w, s.center.1), (t.x, t.center.1))
  } else if t.x + t.w <= s.x {
    if s.x - (t.x + t.w) < 20.0 {
      return None
    }
    ((s.x, s.center.1), (t.x + t.w, t.center.1))
  } else {
    return None
  }
  let mid_x = (start.0 + end.0) / 2.0
  let route : Array[(Double, Double)] = []
  for point in [start, (mid_x, start.1), (mid_x, end.1), end] {
    if route.is_empty() || route[route.length() - 1] != point {
      route.push(point)
    }
  }
  let mut index = 1
  while index < route.length() - 1 {
    let before = route[index - 1]
    let middle = route[index]
    let after = route[index + 1]
    let horizontal = before.1 == middle.1 && middle.1 == after.1
    let vertical = before.0 == middle.0 && middle.0 == after.0
    if horizontal || vertical {
      ignore(route.remove(index))
    } else {
      index = index + 1
    }
  }
  if route.length() < 2 {
    return None
  }
  Some(route)
}

///|
/// The route of an edge: fixed ends from exit/entry constraints (or the
/// geometry's terminal points for a dangling end), the control points, and
/// floating ends placed on the terminals' perimeters towards the next
/// point (mxGraphView.updateEdgeState, with the practical perimeters of
/// perimeter.mbt).
fn DrawioModel::edge_route(
  self : DrawioModel,
  cell : DrawioCell,
  warn : DrawioWarn,
) -> Array[(Double, Double)] {
  let geo = cell.geometry()
  let source = self.cell(cell.source)
  let target = self.cell(cell.target)
  let (origin_x, origin_y) = self.origin(cell)
  let source_point = match geo {
    Some(value) => drawio_point(value, "sourcePoint")
    None => None
  }
  let target_point = match geo {
    Some(value) => drawio_point(value, "targetPoint")
    None => None
  }
  let source_terminal = match source {
    Some(value) => Some(drawio_terminal(self, value, warn))
    None => None
  }
  let target_terminal = match target {
    Some(value) => Some(drawio_terminal(self, value, warn))
    None => None
  }
  let middle : Array[(Double, Double)] = []
  match geo {
    Some(value) => {
      for point in drawio_waypoints(value) {
        middle.push((point.0 + origin_x, point.1 + origin_y))
      }
    }
    None => ()
  }
  let mut source_fixed : (Double, Double)? = None
  let mut target_fixed : (Double, Double)? = None
  match source_terminal {
    Some(terminal) => source_fixed = drawio_connection_point(terminal, cell.style, true)
    None =>
      match source_point {
        Some(point) => source_fixed = Some((point.0 + origin_x, point.1 + origin_y))
        None => ()
      }
  }
  match target_terminal {
    Some(terminal) => target_fixed = drawio_connection_point(terminal, cell.style, false)
    None =>
      match target_point {
        Some(point) => target_fixed = Some((point.0 + origin_x, point.1 + origin_y))
        None => ()
      }
  }
  let source_center = match source_terminal {
    Some(terminal) => Some(terminal.center)
    None => None
  }
  let target_center = match target_terminal {
    Some(terminal) => Some(terminal.center)
    None => None
  }
  // The guaranteed facing-rectangle shortcut resolves the whole route
  // here; only rejected cases continue into the general path.
  if middle.is_empty() && source_fixed is None && target_fixed is None {
    match drawio_facing_orthogonal_route(cell.style, source_terminal, target_terminal) {
      Some(route) => return route
      None => ()
    }
  }
  // A floating target goes first and is placed towards the previous point.
  let mut target_placed = target_fixed
  match target_terminal {
    Some(terminal) =>
      if target_placed is None {
        let previous = if !middle.is_empty() {
          Some(middle[middle.length() - 1])
        } else {
          match source_fixed {
            Some(value) => Some(value)
            None => source_center
          }
        }
        match previous {
          Some(point) =>
            target_placed = Some(drawio_shape_perimeter(
              terminal.kind,
              terminal.style,
              terminal.x,
              terminal.y,
              terminal.w,
              terminal.h,
              point.0,
              point.1,
            ))
          None => ()
        }
      }
    None => ()
  }
  let mut source_placed = source_fixed
  match source_terminal {
    Some(terminal) =>
      if source_placed is None {
        let next = if !middle.is_empty() {
          Some(middle[0])
        } else {
          match target_placed {
            Some(value) => Some(value)
            None => target_center
          }
        }
        match next {
          Some(point) =>
            source_placed = Some(drawio_shape_perimeter(
              terminal.kind,
              terminal.style,
              terminal.x,
              terminal.y,
              terminal.w,
              terminal.h,
              point.0,
              point.1,
            ))
          None => ()
        }
      }
    None => ()
  }
  let points : Array[(Double, Double)] = []
  match source_placed {
    Some(point) => points.push(point)
    None => ()
  }
  for point in middle {
    points.push(point)
  }
  match target_placed {
    Some(point) => points.push(point)
    None => ()
  }
  if points.length() < 2 {
    match geo {
      Some(value) => {
        let x = drawio_num(value, "x", 0.0) + origin_x
        let y = drawio_num(value, "y", 0.0) + origin_y
        return [(x, y), (x, y)]
      }
      None => ()
    }
  }
  if drawio_edge_is_orthogonal(cell.style) {
    drawio_orthogonal_route(points, cell.style)
  } else {
    points
  }
}

///|
/// The anchor of an edge label: along the route for a relative geometry
/// (x from -1 at the source to 1 at the target, y a perpendicular
/// offset), otherwise the midpoint of the two ends. Both are shifted by
/// the geometry's `offset` point (mxGraphView.getPoint).
fn drawio_edge_label_anchor(
  points : Array[(Double, Double)],
  geo : DrawioNode,
) -> (Double, Double) {
  let offset = drawio_offset(geo)
  if points.length() < 2 {
    return (
      drawio_num(geo, "x", 0.0) + offset.0,
      drawio_num(geo, "y", 0.0) + offset.1,
    )
  }
  let relative = drawio_attr(geo, "relative", "") == "1"
  if !relative {
    let first = points[0]
    let last = points[points.length() - 1]
    return (
      first.0 + (last.0 - first.0) / 2.0 + offset.0,
      first.1 + (last.1 - first.1) / 2.0 + offset.1,
    )
  }
  let mut total = 0.0
  for index in 1..<points.length() {
    let dx = points[index].0 - points[index - 1].0
    let dy = points[index].1 - points[index - 1].1
    total += (dx * dx + dy * dy).sqrt()
  }
  let fraction = drawio_num(geo, "x", 0.0) / 2.0 + 0.5
  let target = fraction * total
  let mut travelled = 0.0
  for index in 1..<points.length() {
    let from = points[index - 1]
    let to = points[index]
    let dx = to.0 - from.0
    let dy = to.1 - from.1
    let length = (dx * dx + dy * dy).sqrt()
    if travelled + length >= target || index == points.length() - 1 {
      let factor = if length > 0.0 {
        Double::min(Double::max((target - travelled) / length, 0.0), 1.0)
      } else {
        0.0
      }
      let mut nx = 0.0
      let mut ny = 0.0
      if length > 0.0 {
        nx = dy / length
        ny = dx / length
      }
      let perpendicular = drawio_num(geo, "y", 0.0)
      return (
        from.0 + dx * factor + nx * perpendicular + offset.0,
        from.1 + dy * factor - ny * perpendicular + offset.1,
      )
    }
    travelled += length
  }
  (points[0].0 + offset.0, points[0].1 + offset.1)
}

///|
/// The edge a cell's relative geometry hangs off, when the cell is an edge
/// label (`<mxCell style="edgeLabel;…" parent="edge">`).
fn DrawioModel::edge_parent(self : DrawioModel, cell : DrawioCell) -> DrawioCell? {
  match self.cell(cell.parent) {
    Some(parent) => if parent.edge { Some(parent) } else { None }
    None => None
  }
}

///|
fn DrawioModel::edge_label_anchor(
  self : DrawioModel,
  cell : DrawioCell,
  geo : DrawioNode,
  warn : DrawioWarn,
) -> (Double, Double) {
  match self.edge_parent(cell) {
    Some(parent) => {
      let points = self.edge_route(parent, warn)
      drawio_edge_label_anchor(points, geo)
    }
    None => (drawio_num(geo, "x", 0.0), drawio_num(geo, "y", 0.0))
  }
}

///|
/// The path of a polyline edge. Curved edges use a Catmull-Rom spline
/// through the route points (the same points still anchor labels and
/// arrowheads, so curved edges stay bounded by them).
fn drawio_edge_path(points : Array[(Double, Double)], curved : Bool) -> @cad.CadPath {
  let path = @cad.CadPath::new()
  if points.length() < 2 {
    return path
  }
  path.move_to(points[0].0, points[0].1)
  if !curved || points.length() == 2 {
    for index in 1..<points.length() {
      path.line_to(points[index].0, points[index].1)
    }
    return path
  }
  for index in 0..<(points.length() - 1) {
    let p0 = if index == 0 {
      points[index]
    } else {
      points[index - 1]
    }
    let p1 = points[index]
    let p2 = points[index + 1]
    let p3 = if index + 2 < points.length() {
      points[index + 2]
    } else {
      points[index + 1]
    }
    let c1 = (
      p1.0 + (p2.0 - p0.0) / 6.0,
      p1.1 + (p2.1 - p0.1) / 6.0,
    )
    let c2 = (
      p2.0 - (p3.0 - p1.0) / 6.0,
      p2.1 - (p3.1 - p1.1) / 6.0,
    )
    path.cubic_to(
      @cad.Point::new(c1.0, c1.1),
      @cad.Point::new(c2.0, c2.1),
      @cad.Point::new(p2.0, p2.1),
    )
  }
  path
}

///|
/// Draw a start or end marker. `tip` is on the terminal point and `toward`
/// is the next point of the route; the marker points back along that
/// direction.
fn drawio_edge_marker(
  drawing : @cad.Drawing,
  tip : (Double, Double),
  toward : (Double, Double),
  style : String,
  key : String,
  color : UInt32,
  stroke_width : Double,
) -> Unit {
  let kind = drawio_style(style, key, "none")
  if kind == "none" || kind == "" {
    return
  }
  let dx = toward.0 - tip.0
  let dy = toward.1 - tip.1
  let length = (dx * dx + dy * dy).sqrt()
  if length <= 0.0 {
    return
  }
  let ux = dx / length
  let uy = dy / length
  let size = drawio_num_from_style(
    style,
    if key == "startArrow" { "startSize" } else { "endSize" },
    8.0,
  )
  let bx = tip.0 + ux * size
  let by = tip.1 + uy * size
  let px = -uy * size * 0.45
  let py = ux * size * 0.45
  let fill_key = if key == "startArrow" { "startFill" } else { "endFill" }
  let filled = drawio_style(style, fill_key, "1") != "0"
  let path = @cad.CadPath::new()
  if kind == "open" {
    drawing.stroke(
      drawio_open_arrow_path(tip, toward, size, stroke_width),
      @cad.Pen::new(color=color, width=stroke_width),
    )
  } else if kind == "oval" {
    path.circle(@cad.Point::new(tip.0 + ux * size * 0.5, tip.1 + uy * size * 0.5), size * 0.5)
    if filled {
      drawing.fill(path, @cad.Fill::solid(color), false)
    } else {
      drawing.stroke(path, @cad.Pen::new(color=color, width=1.0))
    }
  } else if kind == "diamond" || kind.has_prefix("ER") {
    let mx = tip.0 + ux * size * 0.5
    let my = tip.1 + uy * size * 0.5
    path.move_to(tip.0, tip.1)
    path.line_to(mx + px, my + py)
    path.line_to(bx, by)
    path.line_to(mx - px, my - py)
    path.close()
    if filled {
      drawing.fill(path, @cad.Fill::solid(color), false)
    } else {
      drawing.stroke(path, @cad.Pen::new(color=color, width=1.0))
    }
  } else {
    // classic, block and unknown markers share the filled triangle.
    path.move_to(tip.0, tip.1)
    path.line_to(bx + px, by + py)
    path.line_to(bx - px, by - py)
    path.close()
    if filled {
      drawing.fill(path, @cad.Fill::solid(color), false)
    } else {
      drawing.stroke(path, @cad.Pen::new(color=color, width=1.0))
    }
  }
}

///|
/// The open-arrow V draw.io strokes (upstream converter/drawio
/// createOpenArrow): the notch sits one half-gap (stroke_width * 1.118)
/// inside the tip, the wings run size + stroke_width back along the edge
/// and spread half of that length to each side. A zero-length segment
/// yields an empty path, so the marker is skipped.
fn drawio_open_arrow_path(
  tip : (Double, Double),
  toward : (Double, Double),
  size : Double,
  stroke_width : Double,
) -> @cad.CadPath {
  let path = @cad.CadPath::new()
  let dx = toward.0 - tip.0
  let dy = toward.1 - tip.1
  let length = (dx * dx + dy * dy).sqrt()
  if length <= 0.0 {
    return path
  }
  let ux = dx / length
  let uy = dy / length
  let nx = tip.0 + ux * stroke_width * 1.118
  let ny = tip.1 + uy * stroke_width * 1.118
  let vx = ux * (size + stroke_width)
  let vy = uy * (size + stroke_width)
  path.move_to(nx + vx + vy * 0.5, ny + vy - vx * 0.5)
  path.line_to(nx, ny)
  path.line_to(nx + vx - vy * 0.5, ny + vy + vx * 0.5)
  path
}

///|
/// The endpoint of the drawn edge line when an open arrow marks it:
/// draw.io pulls the tip back by twice the marker half-gap
/// (stroke_width * 1.118), so the line stops short of the notch while
/// labels and the marker itself keep the original tip. Any other marker
/// (or a zero-length segment) keeps the tip.
fn drawio_edge_open_end(
  tip : (Double, Double),
  toward : (Double, Double),
  style : String,
  key : String,
  stroke_width : Double,
) -> (Double, Double) {
  if drawio_style(style, key, "none") != "open" {
    return tip
  }
  let dx = toward.0 - tip.0
  let dy = toward.1 - tip.1
  let length = (dx * dx + dy * dy).sqrt()
  if length <= 0.0 {
    return tip
  }
  let gap = stroke_width * 1.118 * 2.0
  (tip.0 + dx / length * gap, tip.1 + dy / length * gap)
}

///|
fn drawio_arrow(
  drawing : @cad.Drawing,
  from : (Double, Double),
  to : (Double, Double),
  style : String,
  color : UInt32,
  stroke_width : Double,
) -> Unit {
  drawio_edge_marker(drawing, to, from, style, "endArrow", color, stroke_width)
}

///|
fn drawio_start_arrow(
  drawing : @cad.Drawing,
  from : (Double, Double),
  toward : (Double, Double),
  style : String,
  color : UInt32,
  stroke_width : Double,
) -> Unit {
  drawio_edge_marker(drawing, from, toward, style, "startArrow", color, stroke_width)
}

///|
/// Draw label text centred on a point: edge labels and edge-label cells.
fn drawio_anchor_text(
  drawing : @cad.Drawing,
  text : String,
  anchor_x : Double,
  anchor_y : Double,
  align : String,
  valign : String,
  size : Double,
  color : UInt32,
  family : String,
  bold : Bool,
  italic : Bool,
  font : @canvas.Fonts,
) -> Unit {
  if text == "" {
    return
  }
  let em = size * 0.75
  let lines = text.split("\n").map(fn(line) { sfc_drawio_trim(line) }).collect()
  let line_height = em * 1.2
  let total = line_height * lines.length().to_double()
  for index, line in lines {
    if line == "" {
      continue
    }
    let width = font.measure(family, "", bold, italic, line)
    let mut origin_x = anchor_x
    if align == "left" {
      origin_x = anchor_x
    } else if align == "right" {
      origin_x = anchor_x - width * em
    } else {
      origin_x = anchor_x - width * em / 2.0
    }
    let line_top = if valign == "top" {
      anchor_y
    } else if valign == "bottom" {
      anchor_y - total
    } else {
      anchor_y - total / 2.0
    }
    let baseline = line_top + line_height * index.to_double() + em * 0.55 + em * 0.35
    let choice = font.face(family, "", line[0].to_int(), bold~, italic~)
    let metrics = font.metrics(choice)
    drawing.text(@cad.CadText::new(
      line,
      @canvas.Matrix::translate(origin_x, baseline).mul(
        @canvas.Matrix::scale(em, -em),
      ),
      color=color,
      advance=width,
      asc=metrics.asc,
      desc=metrics.desc,
      cap=metrics.cap,
    ))
  }
}

///|
fn drawio_edge_label_style(cell : DrawioCell) -> DrawioRunStyle {
  let style = cell.style
  let size = drawio_num_from_style(style, "fontSize", 11.0)
  let font_style = drawio_num_from_style(style, "fontStyle", 0.0).to_int()
  {
    bold: (font_style & 1) != 0,
    italic: (font_style & 2) != 0,
    underline: (font_style & 4) != 0,
    color: drawio_color(drawio_style(style, "fontColor", ""), 0x000000ffU),
    size,
  }
}

///|
fn drawio_render_edge_label(
  drawing : @cad.Drawing,
  cell : DrawioCell,
  anchor_x : Double,
  anchor_y : Double,
  font : @canvas.Fonts,
  labels : Array[String],
  math_enabled : Bool,
  warn : DrawioWarn,
) -> Unit {
  let raw = drawio_plain(cell.value)
  if raw == "" {
    return
  }
  let (text, converted) = drawio_math_text(raw, math_enabled, warn)
  let text_style = drawio_edge_label_style(cell)
  let style = cell.style
  let family = drawio_style(style, "fontFamily", "")
  let align = drawio_style(style, "align", "center")
  let valign = drawio_style(style, "verticalAlign", "middle")
  let background = drawio_style(style, "labelBackgroundColor", "auto")
  if background != "none" {
    let mut width = 0.0
    let mut lines = 0
    for line in text.split("\n") {
      lines += 1
      width = Double::max(
        width,
        font.measure(family, "", text_style.bold, text_style.italic, sfc_drawio_trim(line)),
      )
    }
    let em = text_style.size * 0.75
    let block_width = width * em
    let block_height = lines.to_double() * em * 1.2
    let rect = @cad.CadPath::new()
    rect.polyline([
      { x: anchor_x - block_width / 2.0 - 2.0, y: anchor_y - block_height / 2.0 - 1.0 },
      { x: anchor_x + block_width / 2.0 + 2.0, y: anchor_y - block_height / 2.0 - 1.0 },
      { x: anchor_x + block_width / 2.0 + 2.0, y: anchor_y + block_height / 2.0 + 1.0 },
      { x: anchor_x - block_width / 2.0 - 2.0, y: anchor_y + block_height / 2.0 + 1.0 },
    ], true)
    let color = if background == "auto" {
      0xffffffffU
    } else {
      drawio_color(background, 0xffffffffU)
    }
    drawing.fill(rect, @cad.Fill::solid(color), false)
  }
  drawio_anchor_text(
    drawing,
    text,
    anchor_x,
    anchor_y,
    align,
    valign,
    text_style.size,
    text_style.color,
    family,
    text_style.bold,
    text_style.italic,
    font,
  )
  if converted {
    labels.push(raw)
  }
  for line in text.split("\n") {
    let value = sfc_drawio_trim(line)
    if value != "" {
      labels.push(value)
    }
  }
}

///|
fn drawio_render_item(
  drawing : @cad.Drawing,
  item : DrawioRenderItem,
  fonts : @canvas.Fonts,
  labels : Array[String],
  math_enabled : Bool,
  warn : DrawioWarn,
) -> Unit {
  match item {
    Shape(cell, kind, x, y, w, h) => {
      let style = cell.style
      if !drawio_shape_is_text(kind) {
        if kind == DkStencil {
          drawio_stencil_render(cell, drawing, warn, x, y, w, h) |> ignore
        }
        let paint = drawio_shape_paint(kind, style, x, y, w, h)
        let rotation = drawio_num_from_style(style, "rotation", 0.0)
        let turn = if rotation != 0.0 {
          let cx = x + w / 2.0
          let cy = y + h / 2.0
          Some(
            @canvas.Matrix::translate(cx, cy).mul(
              @canvas.Matrix::rotate(rotation),
            ).mul(@canvas.Matrix::translate(-cx, -cy)),
          )
        } else {
          None
        }
        let fill_path = match turn {
          Some(matrix) => paint.fill.transform(matrix)
          None => paint.fill
        }
        let stroke_path = match turn {
          Some(matrix) => paint.stroke.transform(matrix)
          None => paint.stroke
        }
        let fill_spec = drawio_style(style, "fillColor", "")
        if paint.has_fill && fill_spec != "none" {
          let fill = drawio_color(fill_spec, 0xffffffffU)
          drawing.fill(fill_path, @cad.Fill::solid(fill), false)
        }
        let stroke_spec = drawio_style(style, "strokeColor", "")
        if paint.has_stroke && stroke_spec != "none" {
          let stroke = drawio_color(stroke_spec, 0x000000ffU)
          let width = drawio_num_from_style(style, "strokeWidth", 1.0)
          let dash = if drawio_style(style, "dashed", "") == "1" {
            Some([4.0, 4.0])
          } else {
            None
          }
          drawing.stroke(stroke_path, @cad.Pen::new(
            color=stroke,
            width=width,
            dash~,
            cap=@cad.CAP_ROUND,
            join=@cad.JOIN_ROUND,
          ))
        }
      }
      drawio_label_runs(
        cell,
        kind,
        x,
        y,
        w,
        h,
        fonts,
        drawing,
        labels,
        math_enabled,
        warn,
      )
    }
    Edge(cell, points) => {
      if points.length() < 2 {
        return
      }
      let curved = drawio_style(cell.style, "curved", "0") == "1"
      let stroke = drawio_color(drawio_style(cell.style, "strokeColor", ""), 0x000000ffU)
      let width = drawio_num_from_style(cell.style, "strokeWidth", 1.0)
      let dash = if drawio_style(cell.style, "dashed", "") == "1" {
        Some([4.0, 4.0])
      } else {
        None
      }
      let block_arrow = drawio_edge_is_block_arrow(cell.style)
      if !block_arrow {
        // Open markers pull the drawn line back from the tips; the
        // markers and the label anchors still use the original route.
        let drawn = points.copy()
        drawn[drawn.length() - 1] = drawio_edge_open_end(
          points[points.length() - 1],
          points[points.length() - 2],
          cell.style,
          "endArrow",
          width,
        )
        drawn[0] = drawio_edge_open_end(
          points[0],
          points[1],
          cell.style,
          "startArrow",
          width,
        )
        drawing.stroke(drawio_edge_path(drawn, curved), @cad.Pen::new(
          color=stroke,
          width=width,
          dash~,
          cap=@cad.CAP_ROUND,
          join=@cad.JOIN_ROUND,
        ))
        drawio_arrow(
          drawing,
          points[points.length() - 2],
          points[points.length() - 1],
          cell.style,
          stroke,
          width,
        )
        drawio_start_arrow(
          drawing,
          points[0],
          points[1],
          cell.style,
          stroke,
          width,
        )
      } else {
        drawio_paint_block_arrow(
          drawing,
          points[0],
          points[points.length() - 1],
          cell.style,
          stroke,
        )
      }
      if drawio_plain(cell.value) != "" {
        let anchor = match cell.geometry() {
          Some(geo) => drawio_edge_label_anchor(points, geo)
          None => points[points.length() / 2]
        }
        drawio_render_edge_label(
          drawing,
          cell,
          anchor.0,
          anchor.1,
          fonts,
          labels,
          math_enabled,
          warn,
        )
      }
    }
  }
}

///|
/// The lines of a table: the outline, the boundaries between its rows and
/// the boundaries between the cells of each row. draw.io paints them from
/// the table shape; the cells themselves are partial rectangles that may
/// ask for no border at all.
fn drawio_table_grid(
  drawing : @cad.Drawing,
  model : DrawioModel,
  table : DrawioCell,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit {
  let style = table.style
  if drawio_style(style, "strokeColor", "") == "none" {
    return
  }
  let path = @cad.CadPath::new()
  path.polyline([
    { x, y },
    { x: x + w, y },
    { x: x + w, y: y + h },
    { x, y: y + h },
  ], true)
  for row in model.cells {
    if row.parent != table.id || !row.vertex || !model.visible(row) {
      continue
    }
    if drawio_shape_name(row.style) != "tableRow" {
      continue
    }
    let (_, row_y, _, _) = model.absolute(row)
    if row_y > y + 0.5 && row_y < y + h - 0.5 {
      path.move_to(x, row_y)
      path.line_to(x + w, row_y)
    }
    for cell in model.cells {
      if cell.parent != row.id || !cell.vertex || !model.visible(cell) {
        continue
      }
      if drawio_shape_name(cell.style) != "partialRectangle" {
        continue
      }
      let (cell_x, cell_y, _, cell_h) = model.absolute(cell)
      if cell_x > x + 0.5 && cell_x < x + w - 0.5 {
        path.move_to(cell_x, cell_y)
        path.line_to(cell_x, cell_y + cell_h)
      }
    }
  }
  let color = drawio_color(drawio_style(style, "strokeColor", ""), 0x000000ffU)
  let width = drawio_num_from_style(style, "strokeWidth", 1.0)
  drawing.stroke(path, @cad.Pen::new(
    color=color,
    width=width,
    cap=@cad.CAP_ROUND,
    join=@cad.JOIN_ROUND,
  ))
}

///|
/// The measured label of a cell for page bounds: how wide and tall its
/// text block is, and the box it is laid out in.
priv struct DrawioLabelMeasure {
  width : Double
  height : Double
  box : DrawioLabelBox
  spacing : DrawioLabelSpacing
}

///|
fn drawio_measure_label(
  cell : DrawioCell,
  kind : DrawioShapeKind,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  fonts : @canvas.Fonts,
  math_enabled : Bool,
  warn : DrawioWarn,
) -> DrawioLabelMeasure? {
  let raw = drawio_plain(cell.value)
  if raw == "" {
    return None
  }
  let style = cell.style
  let box = drawio_label_box(kind, style, x, y, w, h)
  let size = drawio_num_from_style(style, "fontSize", 11.0)
  let em = size * 0.75
  let family = drawio_style(style, "fontFamily", "")
  let font_style = drawio_num_from_style(style, "fontStyle", 0.0).to_int()
  let bold = (font_style & 1) != 0
  let italic = (font_style & 2) != 0
  let spacing = drawio_label_spacing(style)
  let max_width = if box.w > 0.0 && box.w < 1.0e8 {
    box.w - spacing.left - spacing.right
  } else {
    1.0e9
  }
  let wrap = drawio_label_wraps(style) && max_width > 1.0
  let mut width = 0.0
  let mut height = 0.0
  if drawio_has_html(cell.value) {
    let mut lines = drawio_rich_lines(cell.value, size, 0x000000ffU)
    if math_enabled {
      for line_index in 0..<lines.length() {
        for run_index in 0..<lines[line_index].length() {
          let run = lines[line_index][run_index]
          let (text, _) = drawio_math_text(run.text, math_enabled, warn)
          lines[line_index][run_index] = { text, style: run.style }
        }
      }
    }
    if wrap {
      lines = drawio_wrap_rich_lines(
        lines,
        max_width,
        fonts,
        family,
        bold,
        italic,
        size,
      )
    }
    for line in lines {
      let mut line_width = 0.0
      let mut line_height = em * 1.2
      for run in line {
        let run_em = drawio_run_em(run.style, size)
        line_width += fonts.measure(
          family,
          "",
          bold || run.style.bold,
          italic || run.style.italic,
          run.text,
        ) * run_em
        line_height = Double::max(line_height, run_em * 1.2)
      }
      width = Double::max(width, line_width)
      height += line_height
    }
  } else {
    let (text, _) = drawio_math_text(raw, math_enabled, warn)
    let lines = if wrap {
      drawio_wrap_text(text, max_width, fonts, family, bold, italic, em)
    } else {
      text.split("\n").map(fn(line) { sfc_drawio_trim(line) }).collect()
    }
    for line in lines {
      width = Double::max(width, fonts.measure(family, "", bold, italic, line) * em)
    }
    height = em * 1.2 * lines.length().to_double()
  }
  Some({ width, height, box, spacing, })
}

///|
fn drawio_label_extent(
  measure : DrawioLabelMeasure,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> (Double, Double, Double, Double) {
  let box = measure.box
  // The drawn text rectangle: the same origin the drawing uses, so the
  // extent covers a label that its directional spacing pushes out.
  let text_left = drawio_label_origin_x(box, measure.width, measure.spacing)
  let text_top = drawio_label_block_top(box, measure.height, measure.spacing)
  if box.rotation != 0.0 {
    // The label turns about its anchor: rotate the four corners of the
    // spaced text rectangle (draw.io rotateLabelBounds) around it and
    // cover them together with the shape.
    let radians = box.rotation * 3.141592653589793 / 180.0
    let cosine = @math.cos(radians)
    let sine = @math.sin(radians)
    let turn = fn(px : Double, py : Double) -> (Double, Double) {
      let dx = px - box.anchor_x
      let dy = py - box.anchor_y
      (box.anchor_x + dx * cosine - dy * sine, box.anchor_y + dx * sine + dy * cosine)
    }
    let corners = [
      turn(text_left, text_top),
      turn(text_left + measure.width, text_top),
      turn(text_left + measure.width, text_top + measure.height),
      turn(text_left, text_top + measure.height),
    ]
    let mut min_x = x
    let mut max_x = x + w
    let mut min_y = y
    let mut max_y = y + h
    for corner in corners {
      min_x = Double::min(min_x, corner.0)
      max_x = Double::max(max_x, corner.0)
      min_y = Double::min(min_y, corner.1)
      max_y = Double::max(max_y, corner.1)
    }
    (min_x, min_y, max_x, max_y)
  } else {
    let mut min_x = x
    let mut max_x = x + w
    let mut min_y = y
    let mut max_y = y + h
    // The text block occupies the same rectangle the drawing does, which
    // can extend past the shape and the label box (an external label
    // pushed out by spacingLeft).
    min_x = Double::min(min_x, text_left)
    max_x = Double::max(max_x, text_left + measure.width)
    min_y = Double::min(min_y, text_top)
    max_y = Double::max(max_y, text_top + measure.height)
    if box.w >= 1.0e8 {
      // A label outside the shape: it grows away from the shape.
      if box.align == "right" {
        min_x = Double::min(min_x, box.x - measure.width)
        max_x = Double::max(max_x, box.x)
      } else {
        min_x = Double::min(min_x, box.x)
        max_x = Double::max(max_x, box.x + measure.width)
      }
    } else if box.w > 0.0 {
      min_x = Double::min(min_x, box.x)
      max_x = Double::max(max_x, box.x + box.w)
      if measure.width > box.w {
        max_x = Double::max(max_x, box.x + measure.width)
      }
    }
    if box.h >= 1.0e8 {
      if box.valign == "bottom" {
        min_y = Double::min(min_y, box.y - measure.height)
        max_y = Double::max(max_y, box.y)
      } else {
        min_y = Double::min(min_y, box.y)
        max_y = Double::max(max_y, box.y + measure.height)
      }
    } else if box.h > 0.0 {
      min_y = Double::min(min_y, box.y)
      max_y = Double::max(max_y, box.y + box.h)
      if measure.height > box.h {
        max_y = Double::max(max_y, box.y + measure.height)
      }
    }
    (min_x, min_y, max_x, max_y)
  }
}

///|
fn drawio_page_bounds(
  model : DrawioModel,
  fonts : @canvas.Fonts,
  math_enabled : Bool,
  warn : DrawioWarn,
) -> (Double, Double, Double, Double, Bool) {
  let mut min_x = 1.0e300
  let mut min_y = 1.0e300
  let mut max_x = -1.0e300
  let mut max_y = -1.0e300
  let mut found = false
  let grow = fn(x0 : Double, y0 : Double, x1 : Double, y1 : Double) {
    min_x = Double::min(min_x, x0)
    min_y = Double::min(min_y, y0)
    max_x = Double::max(max_x, x1)
    max_y = Double::max(max_y, y1)
    found = true
  }
  for cell in model.cells {
    if !model.visible(cell) {
      continue
    }
    if cell.vertex {
      match model.edge_parent(cell) {
        Some(_) => {
          match cell.geometry() {
            Some(geo) => {
              let anchor = model.edge_label_anchor(cell, geo, warn)
              match drawio_measure_label(
                cell,
                DkText,
                anchor.0,
                anchor.1,
                0.0,
                0.0,
                fonts,
                math_enabled,
                warn,
              ) {
                Some(value) =>
                  grow(
                    anchor.0 - value.width / 2.0,
                    anchor.1 - value.height / 2.0,
                    anchor.0 + value.width / 2.0,
                    anchor.1 + value.height / 2.0,
                  )
                None => ()
              }
            }
            None => ()
          }
          continue
        }
        None => ()
      }
      let (x, y, w, h) = model.absolute(cell)
      if w <= 0.0 || h <= 0.0 {
        continue
      }
      grow(x, y, x + w, y + h)
      let shape_rotation = drawio_num_from_style(cell.style, "rotation", 0.0)
      if shape_rotation != 0.0 {
        let radians = shape_rotation * 3.141592653589793 / 180.0
        let cosine = @math.cos(radians).abs()
        let sine = @math.sin(radians).abs()
        let half_w = (w * cosine + h * sine) / 2.0
        let half_h = (w * sine + h * cosine) / 2.0
        let cx = x + w / 2.0
        let cy = y + h / 2.0
        grow(cx - half_w, cy - half_h, cx + half_w, cy + half_h)
      }
      let kind = drawio_shape_kind(cell.style, warn)
      match drawio_measure_label(cell, kind, x, y, w, h, fonts, math_enabled, warn) {
        Some(measure) => {
          let (lx0, ly0, lx1, ly1) = drawio_label_extent(measure, x, y, w, h)
          grow(lx0, ly0, lx1, ly1)
        }
        None => ()
      }
    } else if cell.edge {
      let points = model.edge_route(cell, warn)
      for point in points {
        grow(point.0, point.1, point.0, point.1)
      }
      let text = drawio_plain(cell.value)
      if text != "" {
        let anchor = match cell.geometry() {
          Some(geo) => drawio_edge_label_anchor(points, geo)
          None => points[points.length() / 2]
        }
        let text_style = drawio_edge_label_style(cell)
        let em = text_style.size * 0.75
        let family = drawio_style(cell.style, "fontFamily", "")
        let mut width = 0.0
        for line in text.split("\n") {
          width = Double::max(
            width,
            fonts.measure(
              family,
              "",
              text_style.bold,
              text_style.italic,
              sfc_drawio_trim(line),
            ) * em,
          )
        }
        let height = em * 1.2 * text.split("\n").length().to_double()
        grow(
          anchor.0 - width / 2.0,
          anchor.1 - height / 2.0,
          anchor.0 + width / 2.0,
          anchor.1 + height / 2.0,
        )
      }
    }
  }
  (min_x, min_y, max_x - min_x, max_y - min_y, found)
}

///|
fn drawio_view(page : Json, id : String, title : String) -> Json {
  let view : Map[String, Json] = {
    "id": Json::string(id),
    "kind": Json::string("fixed"),
    "pages": Json::array([page]),
  }
  if title != "" {
    view["title"] = Json::string(title)
  }
  Json::object(view)
}

///|
fn drawio_render_page(
  writer : @core.DocumentWriter,
  page_info : DrawioPage,
  fonts : @canvas.Fonts,
  warnings : Array[String],
  warn : DrawioWarn,
) -> (Json, String, String, Array[String])? {
  let model = drawio_model(page_info.model)
  ignore(drawio_aws_legacy_substitute(model, warn))
  let math_enabled = drawio_attr(page_info.model, "math", "") == "1"
  let (min_x, min_y, bounds_w, bounds_h, found) = drawio_page_bounds(
    model,
    fonts,
    math_enabled,
    warn,
  )
  let mut border = 10.0
  let mut page_w = 827.0
  let mut page_h = 1169.0
  if found && bounds_w > 0.0 && bounds_h > 0.0 {
    page_w = @math.ceil((bounds_w + border * 2.0) * 0.75)
    page_h = @math.ceil((bounds_h + border * 2.0) * 0.75)
    if page_w < 1.0 {
      page_w = 1.0
    }
    if page_h < 1.0 {
      page_h = 1.0
    }
  } else {
    border = 0.0
    page_w = @math.ceil(drawio_num(page_info.model, "pageWidth", page_w) * 0.75)
    page_h = @math.ceil(drawio_num(page_info.model, "pageHeight", page_h) * 0.75)
    page_w = Double::max(page_w, 1.0)
    page_h = Double::max(page_h, 1.0)
  }
  let labels : Array[String] = []
  let layers : Array[Json] = []
  let background = drawio_color(drawio_attr(page_info.model, "background", ""), 0x00000000U)
  if (background & 255U) != 0U {
    let canvas = @canvas.Canvas::new()
    canvas.object().set_bbox(0.0F, 0.0F, @canvas.f32(page_w), @canvas.f32(page_h))
    canvas.object().fill_color(background)
    canvas.object().fill_rect(0.0F, 0.0F, @canvas.f32(page_w), @canvas.f32(page_h))
    canvas.set_drawn()
    let hash = canvas.encode(writer, fonts, warnings) catch {
      error => {
        warnings.push("drawio: " + error.to_string())
        return None
      }
    }
    layers.push(@cad.layer("background", hash))
  }
  let matrix = @canvas.Matrix::translate(-min_x + border, -min_y + border).mul(
    @canvas.Matrix::scale(0.75, 0.75),
  )
  for layer in model.layers {
    if !layer.visible {
      continue
    }
    let drawing = @cad.Drawing::new()
    let mut has_item = false
    for cell in model.cells {
      if !model.visible(cell) || cell.layer != layer.id {
        continue
      }
      if cell.vertex {
        match model.edge_parent(cell) {
          Some(_) => {
            match cell.geometry() {
              Some(geo) => {
                let anchor = model.edge_label_anchor(cell, geo, warn)
                drawio_render_edge_label(
                  drawing,
                  cell,
                  anchor.0,
                  anchor.1,
                  fonts,
                  labels,
                  math_enabled,
                  warn,
                )
                has_item = true
              }
              None => ()
            }
            continue
          }
          None => ()
        }
        let (x, y, w, h) = model.absolute(cell)
        let kind = drawio_shape_kind(cell.style, warn)
        drawio_render_item(
          drawing,
          Shape(cell, kind, x, y, w, h),
          fonts,
          labels,
          math_enabled,
          warn,
        )
        has_item = true
      } else if cell.edge {
        let points = model.edge_route(cell, warn)
        if points.length() >= 2 {
          drawio_render_item(
            drawing,
            Edge(cell, points),
            fonts,
            labels,
            math_enabled,
            warn,
          )
          has_item = true
        }
      }
    }
    if has_item {
      for cell in model.cells {
        if !model.visible(cell) || cell.layer != layer.id || !cell.vertex {
          continue
        }
        if drawio_shape_name(cell.style) == "table" {
          let (x, y, w, h) = model.absolute(cell)
          drawio_table_grid(drawing, model, cell, x, y, w, h)
        }
      }
    }
    if !has_item {
      continue
    }
    let canvas = @canvas.Canvas::new()
    canvas.object().set_bbox(0.0F, 0.0F, @canvas.f32(page_w), @canvas.f32(page_h))
    let plotter = @cad.Plotter::new(fonts, thin=0.1)
    plotter.plot(canvas, drawing, matrix, {
      min: { x: 0.0, y: 0.0 },
      max: { x: page_w, y: page_h },
      ok: true,
    }) catch {
      error => {
        warnings.push("drawio: " + error.to_string())
        return None
      }
    }
    let hash = canvas.encode(writer, fonts, warnings) catch {
      error => {
        warnings.push("drawio: " + error.to_string())
        return None
      }
    }
    layers.push(@cad.layer("body", hash))
  }
  if layers.is_empty() {
    let canvas = @canvas.Canvas::new()
    canvas.object().set_bbox(0.0F, 0.0F, @canvas.f32(page_w), @canvas.f32(page_h))
    canvas.set_drawn()
    let hash = canvas.encode(writer, fonts, warnings) catch {
      error => {
        warnings.push("drawio: " + error.to_string())
        return None
      }
    }
    layers.push(@cad.layer("body", hash))
  }
  let page = @cad.page(page_w, page_h, layers)
  let id = if page_info.id == "" { "page1" } else { page_info.id }
  let title = if page_info.name == "" { "Page-1" } else { page_info.name }
  Some((drawio_view(page, id, title), id, title, labels))
}
