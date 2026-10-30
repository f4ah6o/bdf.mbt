///|
priv struct GridEdge {
  row : Int32
  column : Int32
  border : GridStyleBorder
}

///|
priv struct GridSegment {
  x0 : Double
  y0 : Double
  x1 : Double
  y1 : Double
}

///|
priv struct GridDiagonalSegment {
  border : GridStyleBorder
  segment : GridSegment
}

///|
priv struct GridEdgeGroup {
  border : GridStyleBorder
  segments : Array[GridSegment]
}

///|
priv struct GridStroke {
  tile : DrawTile
  verbs : Array[Byte]
  coordinates : Array[Double]
}

///|
fn put_grid_edge(
  edges : Map[String, GridEdge],
  row : Int32,
  column : Int32,
  border : GridStyleBorder,
) -> Unit {
  if border.weight == 0 {
    return
  }
  let key = "\{row},\{column}"
  match edges.get(key) {
    Some(existing) => if existing.border.weight >= border.weight { return }
    None => ()
  }
  edges[key] = { row, column, border, }
}

///|
fn add_grid_segment(
  groups : Array[GridEdgeGroup],
  border : GridStyleBorder,
  segment : GridSegment,
) -> Unit {
  for group in groups {
    if group.border.weight == border.weight &&
      group.border.color == border.color {
      group.segments.push(segment)
      return
    }
  }
  groups.push({ border, segments: [segment], })
}

///|
fn GridDrawContext::paint_table_borders(
  self : GridDrawContext,
  style : GridStyle,
  row_count : Int32,
  column_count : Int32,
  header : Int32,
  columns : Array[Double],
  rows : Array[Double],
) -> Unit raise {
  let horizontal : Map[String, GridEdge] = Map([])
  let vertical : Map[String, GridEdge] = Map([])
  for row in 0..<row_count {
    for col in 0..<column_count {
      let borders = style.at(row, col, row_count, column_count, header).borders
      put_grid_edge(horizontal, row, col, borders[0])
      put_grid_edge(horizontal, row + 1, col, borders[1])
      put_grid_edge(vertical, row, col, borders[2])
      put_grid_edge(vertical, row, col + 1, borders[3])
    }
  }
  self.draw_grid_edges(horizontal, vertical, columns, rows)
}

///|
// XLSX orders equal-weight strokes by Go's textual RGB tuple.
fn xlsx_grid_border_color_key(color : UInt32) -> String {
  let red = ((color >> 24) & 255U).to_double() / 255.0
  let green = ((color >> 16) & 255U).to_double() / 255.0
  let blue = ((color >> 8) & 255U).to_double() / 255.0
  "{" + red.to_string() + " " + green.to_string() + " " + blue.to_string() + "}"
}

///|
fn xlsx_grid_border_color_compare(a : UInt32, b : UInt32) -> Int32 {
  let left : Array[Char] = [ for c in xlsx_grid_border_color_key(a) => c ]
  let right : Array[Char] = [ for c in xlsx_grid_border_color_key(b) => c ]
  for i in 0..<Int32::min(left.length(), right.length()) {
    if left[i] != right[i] {
      return left[i].to_int().compare(right[i].to_int())
    }
  }
  left.length().compare(right.length())
}

///|
fn GridDrawContext::draw_grid_edges(
  self : GridDrawContext,
  horizontal : Map[String, GridEdge],
  vertical : Map[String, GridEdge],
  columns : Array[Double],
  rows : Array[Double],
  diagonals~ : Array[GridDiagonalSegment] = [],
  xlsx_color_order~ : Bool = false,
) -> Unit raise {
  let hs : Array[GridEdge] = [ for _, edge in horizontal => edge ]
  hs.sort_by((a, b) => {
    if a.row == b.row {
      a.column.compare(b.column)
    } else {
      a.row.compare(b.row)
    }
  })
  let vs : Array[GridEdge] = [ for _, edge in vertical => edge ]
  vs.sort_by((a, b) => {
    if a.column == b.column {
      a.row.compare(b.row)
    } else {
      a.column.compare(b.column)
    }
  })
  let groups : Array[GridEdgeGroup] = []
  let mut i = 0
  while i < hs.length() {
    let first = hs[i]
    let mut j = i + 1
    while j < hs.length() &&
          hs[j].row == first.row &&
          hs[j].column == hs[j - 1].column + 1 &&
          hs[j].border.weight == first.border.weight &&
          hs[j].border.color == first.border.color {
      j += 1
    }
    let y = rows[first.row]
    if columns[hs[j - 1].column + 1] > columns[first.column] {
      add_grid_segment(groups, first.border, {
        x0: columns[first.column],
        y0: y,
        x1: columns[hs[j - 1].column + 1],
        y1: y,
      })
    }
    i = j
  }
  i = 0
  while i < vs.length() {
    let first = vs[i]
    let mut j = i + 1
    while j < vs.length() &&
          vs[j].column == first.column &&
          vs[j].row == vs[j - 1].row + 1 &&
          vs[j].border.weight == first.border.weight &&
          vs[j].border.color == first.border.color {
      j += 1
    }
    let x = columns[first.column]
    if rows[vs[j - 1].row + 1] > rows[first.row] {
      add_grid_segment(groups, first.border, {
        x0: x,
        y0: rows[first.row],
        x1: x,
        y1: rows[vs[j - 1].row + 1],
      })
    }
    i = j
  }
  for diagonal in diagonals {
    add_grid_segment(groups, diagonal.border, diagonal.segment)
  }
  groups.sort_by((a, b) => {
    if a.border.weight == b.border.weight {
      if xlsx_color_order {
        xlsx_grid_border_color_compare(a.border.color, b.border.color)
      } else {
        a.border.color.compare(b.border.color)
      }
    } else {
      a.border.weight.compare(b.border.weight)
    }
  })
  let dashed_tiles : Map[String, Bool] = Map([])
  for group in groups {
    let weight = group.border.weight
    let width = match weight {
      1 => 0.5
      7 | 8 | 9 | 10 | 11 => 1.5
      13 => 2.25
      _ => 0.75
    }
    let dash : Array[Float] = match weight {
      1 | 2 => [0.75F, 0.75F]
      3 | 7 => [6.75F, 2.25F, 2.25F, 2.25F, 2.25F, 2.25F]
      4 | 9 => [6.75F, 2.25F, 2.25F, 2.25F]
      5 => [2.25F, 0.75F]
      8 => [7.5F, 0.75F, 3.0F, 0.75F]
      10 => [6.75F, 2.25F]
      _ => []
    }
    let strokes : Array[GridStroke] = []
    for segment in group.segments {
      let pad = width * 2.0
      for
        tile in self.in_bounds(
          Double::min(segment.x0, segment.x1) - pad,
          Double::min(segment.y0, segment.y1) - pad,
          Double::max(segment.x0, segment.x1) + pad,
          Double::max(segment.y0, segment.y1) + pad,
        ) {
        let mut index = -1
        for i, stroke in strokes {
          if stroke.tile.x == tile.x && stroke.tile.y == tile.y {
            index = i
            break
          }
        }
        if index < 0 {
          index = strokes.length()
          strokes.push({ tile, verbs: [], coordinates: [], })
        }
        let stroke = strokes[index]
        let ox = tile.x.to_double() * 2048.0
        let oy = tile.y.to_double() * 2048.0
        if weight == 12 {
          let dx = if segment.x0 == segment.x1 { 0.75 } else { 0.0 }
          let dy = if segment.x0 == segment.x1 { 0.0 } else { 0.75 }
          for offset in [-1.0, 1.0] {
            stroke.verbs.push(0)
            stroke.verbs.push(1)
            stroke.coordinates.push(segment.x0 + offset * dx - ox)
            stroke.coordinates.push(segment.y0 + offset * dy - oy)
            stroke.coordinates.push(segment.x1 + offset * dx - ox)
            stroke.coordinates.push(segment.y1 + offset * dy - oy)
          }
        } else {
          stroke.verbs.push(0)
          stroke.verbs.push(1)
          stroke.coordinates.push(segment.x0 - ox)
          stroke.coordinates.push(segment.y0 - oy)
          stroke.coordinates.push(segment.x1 - ox)
          stroke.coordinates.push(segment.y1 - oy)
        }
      }
    }
    for stroke in strokes {
      let key = "\{stroke.tile.x},\{stroke.tile.y}"
      stroke.tile.object.line(
        Float::from_double(width),
        if dash.is_empty() {
          2
        } else {
          0
        },
        0,
        10.0F,
      )
      if !dash.is_empty() {
        stroke.tile.object.dash(dash, 0.0F)
        dashed_tiles[key] = true
      } else if dashed_tiles.get(key).unwrap_or(false) {
        stroke.tile.object.dash([], 0.0F)
        dashed_tiles[key] = false
      }
      stroke.tile.object.stroke_color(group.border.color)
      let path : @core.Path = {
        verbs: Bytes::from_array(stroke.verbs),
        coordinates: stroke.coordinates,
      }
      let index = stroke.tile.object.add_path(@core.Inline(path))
      stroke.tile.object.stroke_path(index)
      stroke.tile.drawn = true
    }
  }
  for tile in self.tiles {
    let key = "\{tile.x},\{tile.y}"
    if dashed_tiles.get(key).unwrap_or(false) {
      tile.object.dash([], 0.0F)
    }
  }
}
