///|
/// The icon set catalogue, matching the upstream built-in sets.
fn grid_icon_descriptor(set : String, index : Int32) -> (String, UInt32, Double) {
  let red = 0xE0301EFFU
  let yellow = 0xFFB628FFU
  let green = 0x1D9E48FFU
  let gray = 0x808080FFU
  let black = 0x404040FFU
  let pink = 0xF4A6A6FFU
  let blue = 0x4472C4FFU
  let gold = 0xF6B31BFFU
  let fallback = "3TrafficLights1"
  let set = if set == "" { fallback } else { set }
  let entries : Array[(String, UInt32, Double)] = match set {
    "3Arrows" => [("down", red, 0.0), ("side", yellow, 0.0), ("up", green, 0.0)]
    "3ArrowsGray" => [("down", gray, 0.0), ("side", gray, 0.0), ("up", gray, 0.0)]
    "3Flags" => [("flag", red, 0.0), ("flag", yellow, 0.0), ("flag", green, 0.0)]
    "3TrafficLights1" => [("circle", red, 0.0), ("circle", yellow, 0.0), ("circle", green, 0.0)]
    "3TrafficLights2" => [("rim", red, 0.0), ("rim", yellow, 0.0), ("rim", green, 0.0)]
    "3Signs" => [("diamond", red, 0.0), ("triangle", yellow, 0.0), ("circle", green, 0.0)]
    "3Symbols" => [("circle_cross", red, 0.0), ("circle_exclaim", yellow, 0.0), ("circle_check", green, 0.0)]
    "3Symbols2" => [("cross", red, 0.0), ("exclaim", yellow, 0.0), ("check", green, 0.0)]
    "3Stars" => [("star", gold, 0.0), ("star", gold, 0.5), ("star", gold, 1.0)]
    "3Triangles" => [("triangle_down", red, 0.0), ("dash", yellow, 0.0), ("triangle_up", green, 0.0)]
    "4Arrows" => [("down", red, 0.0), ("down_right", yellow, 0.0), ("up_right", yellow, 0.0), ("up", green, 0.0)]
    "4ArrowsGray" => [("down", gray, 0.0), ("down_right", gray, 0.0), ("up_right", gray, 0.0), ("up", gray, 0.0)]
    "4RedToBlack" => [("circle", black, 0.0), ("circle", gray, 0.0), ("circle", pink, 0.0), ("circle", red, 0.0)]
    "4Rating" => [("rating", blue, 0.25), ("rating", blue, 0.5), ("rating", blue, 0.75), ("rating", blue, 1.0)]
    "4TrafficLights" => [("circle", black, 0.0), ("circle", red, 0.0), ("circle", yellow, 0.0), ("circle", green, 0.0)]
    "5Arrows" => [("down", red, 0.0), ("down_right", yellow, 0.0), ("side", yellow, 0.0), ("up_right", yellow, 0.0), ("up", green, 0.0)]
    "5ArrowsGray" => [("down", gray, 0.0), ("down_right", gray, 0.0), ("side", gray, 0.0), ("up_right", gray, 0.0), ("up", gray, 0.0)]
    "5Rating" => [("rating", blue, 0.0), ("rating", blue, 0.25), ("rating", blue, 0.5), ("rating", blue, 0.75), ("rating", blue, 1.0)]
    "5Quarters" => [("quarter", black, 0.0), ("quarter", black, 0.25), ("quarter", black, 0.5), ("quarter", black, 0.75), ("quarter", black, 1.0)]
    "5Boxes" => [("boxes", blue, 0.0), ("boxes", blue, 0.25), ("boxes", blue, 0.5), ("boxes", blue, 0.75), ("boxes", blue, 1.0)]
    _ => [("circle", red, 0.0), ("circle", yellow, 0.0), ("circle", green, 0.0)]
  }
  let index = if index < 0 || index >= entries.length() { 0 } else { index }
  entries[index]
}

///|
fn grid_icon_points(
  x : Double, y : Double, size : Double, points : Array[(Double, Double)],
) -> @core.Path {
  let verbs : Array[Byte] = [0]
  let coordinates : Array[Double] = []
  for index, point in points {
    if index > 0 {
      verbs.push(1)
    }
    coordinates.push(x + point.0 * size)
    coordinates.push(y + point.1 * size)
  }
  verbs.push(4)
  { verbs: Bytes::from_array(verbs), coordinates }
}

///|
fn grid_icon_fill(
  tile : DrawTile,
  x : Double,
  y : Double,
  size : Double,
  points : Array[(Double, Double)],
  color : UInt32,
) -> Unit raise {
  tile.fill_color(color)
  tile.object.fill_path(
    tile.object.add_path(@core.Inline(grid_icon_points(x, y, size, points))),
    0,
  )
}

///|
fn grid_icon_circle_points(cx : Double, cy : Double, radius : Double) -> Array[(Double, Double)] {
  let points : Array[(Double, Double)] = []
  for i in 0..<24 {
    let angle = 6.283185307179586 * i.to_double() / 24.0
    points.push((cx + radius * @math.cos(angle), cy + radius * @math.sin(angle)))
  }
  points
}

///|
fn grid_icon_arrow_points(kind : String) -> Array[(Double, Double)] {
  let points : Array[(Double, Double)] = [
    (0.5, 0.05), (0.92, 0.5), (0.65, 0.5), (0.65, 0.95), (0.35, 0.95),
    (0.35, 0.5), (0.08, 0.5),
  ]
  let result : Array[(Double, Double)] = []
  for point in points {
    let (px, py) = point
    if kind == "down" {
      result.push((px, 1.0 - py))
    } else if kind == "side" {
      result.push((1.0 - py, px))
    } else {
      result.push((px, py))
    }
  }
  result
}

///|
fn grid_icon_rotate(points : Array[(Double, Double)], degrees : Double) -> Array[(Double, Double)] {
  let radians = degrees * 3.141592653589793 / 180.0
  let sine = @math.sin(radians)
  let cosine = @math.cos(radians)
  let result : Array[(Double, Double)] = []
  for point in points {
    let dx = point.0 - 0.5
    let dy = point.1 - 0.5
    result.push((
      0.5 + dx * cosine - dy * sine,
      0.5 + dx * sine + dy * cosine,
    ))
  }
  result
}
///|
fn grid_icon_cross_points(a : Double, b : Double, w : Double) -> Array[(Double, Double)] {
  let points : Array[(Double, Double)] = []
  let segments = [(a, a, b, b), (a, b, b, a)]
  for segment in segments {
    let (x1, y1, x2, y2) = segment
    let dx = x2 - x1
    let dy = y2 - y1
    let length = (dx * dx + dy * dy).sqrt()
    let nx = -dy / length * w
    let ny = dx / length * w
    points.push((x1 + nx, y1 + ny))
    points.push((x2 + nx, y2 + ny))
    points.push((x2 - nx, y2 - ny))
    points.push((x1 - nx, y1 - ny))
  }
  points
}

///|
fn grid_icon_draw_shape(
  tile : DrawTile,
  x : Double,
  y : Double,
  size : Double,
  set : String,
  index : Int32,
) -> Unit raise {
  let (kind, color, level) = grid_icon_descriptor(set, index)
  let white = 0xffffffffU
  let light = 0xd9d9d9ffU
  let dark = 0x303030ffU
  match kind {
    "circle" => grid_icon_fill(tile, x, y, size, grid_icon_circle_points(0.5, 0.5, 0.42), color)
    "rim" => {
      grid_icon_fill(tile, x, y, size, grid_icon_circle_points(0.5, 0.5, 0.48), dark)
      grid_icon_fill(tile, x, y, size, grid_icon_circle_points(0.5, 0.5, 0.36), color)
    }
    "diamond" => grid_icon_fill(tile, x, y, size, [(0.5, 0.05), (0.95, 0.5), (0.5, 0.95), (0.05, 0.5)], color)
    "triangle" => grid_icon_fill(tile, x, y, size, [(0.5, 0.08), (0.95, 0.9), (0.05, 0.9)], color)
    "triangle_up" => grid_icon_fill(tile, x, y, size, [(0.5, 0.2), (0.9, 0.8), (0.1, 0.8)], color)
    "triangle_down" => grid_icon_fill(tile, x, y, size, [(0.1, 0.2), (0.9, 0.2), (0.5, 0.8)], color)
    "dash" => grid_icon_fill(tile, x, y, size, [(0.15, 0.4), (0.85, 0.4), (0.85, 0.6), (0.15, 0.6)], color)
    "flag" => {
      grid_icon_fill(tile, x, y, size, [(0.15, 0.05), (0.25, 0.05), (0.25, 0.95), (0.15, 0.95)], dark)
      grid_icon_fill(tile, x, y, size, [(0.25, 0.08), (0.9, 0.3), (0.25, 0.55)], color)
    }
    "check" => grid_icon_fill(tile, x, y, size, [(0.08, 0.55), (0.22, 0.4), (0.4, 0.6), (0.8, 0.15), (0.94, 0.3), (0.4, 0.88)], color)
    "exclaim" => {
      grid_icon_fill(tile, x, y, size, [(0.4, 0.08), (0.6, 0.08), (0.56, 0.65), (0.44, 0.65)], color)
      grid_icon_fill(tile, x, y, size, grid_icon_circle_points(0.5, 0.82, 0.1), color)
    }
    "cross" => grid_icon_fill(tile, x, y, size, grid_icon_cross_points(0.15, 0.85, 0.1), color)
    "circle_check" => {
      grid_icon_fill(tile, x, y, size, grid_icon_circle_points(0.5, 0.5, 0.46), color)
      grid_icon_fill(tile, x, y, size, [(0.22, 0.52), (0.32, 0.42), (0.44, 0.56), (0.7, 0.28), (0.8, 0.38), (0.44, 0.74)], white)
    }
    "circle_exclaim" => {
      grid_icon_fill(tile, x, y, size, grid_icon_circle_points(0.5, 0.5, 0.46), color)
      grid_icon_fill(tile, x, y, size, [(0.44, 0.2), (0.56, 0.2), (0.54, 0.6), (0.46, 0.6)], white)
      grid_icon_fill(tile, x, y, size, grid_icon_circle_points(0.5, 0.74, 0.07), white)
    }
    "circle_cross" => {
      grid_icon_fill(tile, x, y, size, grid_icon_circle_points(0.5, 0.5, 0.46), color)
      grid_icon_fill(tile, x, y, size, grid_icon_cross_points(0.3, 0.7, 0.07), white)
    }
    "star" => {
      let points : Array[(Double, Double)] = []
      for i in 0..<10 {
        let radius = if i % 2 == 1 { 0.2 } else { 0.47 }
        let angle = -1.5707963267948966 + i.to_double() * 0.6283185307179586
        points.push((0.5 + radius * @math.cos(angle), 0.53 + radius * @math.sin(angle)))
      }
      if level < 1.0 {
        grid_icon_fill(tile, x, y, size, points, light)
      }
      if level > 0.0 {
        tile.object.save()
        tile.object.clip_rect(
          Float::from_double(x),
          Float::from_double(y),
          Float::from_double(x + size * level),
          Float::from_double(y + size),
        )
        grid_icon_fill(tile, x, y, size, points, color)
        tile.object.restore()
      }
    }
    "rating" => {
      for i in 0..<4 {
        let top = 0.9 - (0.25 + 0.2 * i.to_double())
        let left = 0.1 + 0.21 * i.to_double()
        let fill = if i.to_double() + 1.0 <= level * 4.0 + 0.000001 { color } else { light }
        grid_icon_fill(tile, x, y, size, [(left, top), (left + 0.16, top), (left + 0.16, 0.9), (left, 0.9)], fill)
      }
    }
    "quarter" => {
      grid_icon_fill(tile, x, y, size, grid_icon_circle_points(0.5, 0.5, 0.44), color)
      grid_icon_fill(tile, x, y, size, grid_icon_circle_points(0.5, 0.5, 0.36), white)
      if level > 0.0 {
        let points : Array[(Double, Double)] = [(0.5, 0.5)]
        let steps = 24
        for i in 0..<steps {
          let angle = -1.5707963267948966 + 6.283185307179586 * level * i.to_double() / 24.0
          points.push((0.5 + 0.36 * @math.cos(angle), 0.5 + 0.36 * @math.sin(angle)))
        }
        grid_icon_fill(tile, x, y, size, points, color)
      }
    }
    "boxes" => {
      for i in 0..<4 {
        let left = 0.1 + 0.42 * (i % 2).to_double()
        let top = 0.1 + 0.42 * (i / 2).to_double()
        let fill = if i.to_double() + 1.0 <= level * 4.0 + 0.000001 { color } else { light }
        grid_icon_fill(tile, x, y, size, [(left, top), (left + 0.38, top), (left + 0.38, top + 0.38), (left, top + 0.38)], fill)
      }
    }
    "down" | "up" | "side" =>
      grid_icon_fill(tile, x, y, size, grid_icon_arrow_points(kind), color)
    "up_right" | "down_right" => {
      let degrees = if kind == "up_right" { -45.0 } else { 45.0 }
      let points = grid_icon_rotate(grid_icon_arrow_points("side"), degrees)
      grid_icon_fill(tile, x, y, size, points, color)
    }
    _ => grid_icon_fill(tile, x, y, size, grid_icon_circle_points(0.5, 0.5, 0.42), color)
  }
}

///|
fn GridDrawContext::sized_grid_icons(
  self : GridDrawContext,
  icons : Map[Int32, Map[Int32, GridIcon]],
  region_rows : Map[Int32, Map[Int32, GridMergeRegion]],
  columns : Array[Double],
  row_positions : Array[Double],
  visible_columns : Int32,
) -> Unit raise {
  let row_keys : Array[Int32] = []
  for row, _ in icons {
    row_keys.push(row)
  }
  row_keys.sort()
  for row in row_keys {
    if row < 0 || row >= row_positions.length() - 1 {
      continue
    }
    let y1 = row_positions[row + 1]
    let values = icons[row]
    let column_keys : Array[Int32] = []
    for column, _ in values {
      column_keys.push(column)
    }
    column_keys.sort()
    for column in column_keys {
      if column < 0 || column >= visible_columns || column + 1 >= columns.length() {
        continue
      }
      if grid_region_contains(region_rows, row, column) {
        continue
      }
      let x0 = columns[column]
      let x1 = columns[column + 1]
      let mut size = Double::min(y1 - row_positions[row] - 2.0, 16.0)
      if size <= 0.0 || x0 >= x1 {
        continue
      }
      let x = x0 + 2.0
      size = Double::min(size, x1 - x - 1.0)
      if size <= 0.0 {
        continue
      }
      let y = y1 - 2.0 - size
      let icon = values[column]
      for tile in self.in_bounds(x, y, x + size, y + size) {
        grid_icon_draw_shape(tile, x, y, size, icon.set, icon.index)
      }
    }
  }
}