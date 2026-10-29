///|
/// A cell positioned within a sparse sheet row.
pub(all) struct SizedGridCell {
  column : Int32
  cell : Cell
  center : Bool
  visible : Bool
  occupied : Bool
  color : UInt32
}

///|
/// A sparse row of cells in an already-sized sheet.
pub(all) struct SizedGridRow {
  index : Int32
  cells : Array[SizedGridCell]
}

///|
/// A solid fill and the key used to combine adjacent equal fills.
pub(all) struct GridSolidFill {
  key : String
  color : UInt32
}

///|
/// Border weights on the four sides of a cell.
pub(all) struct GridCellBorder {
  top : Int32
  bottom : Int32
  left : Int32
  right : Int32
}

///|
priv struct GridFillRect {
  x0 : Double
  x1 : Double
  y0 : Double
  y1 : Double
  fill : GridSolidFill
}

///|
/// Measure a character using the upstream fallback metrics at the given size.
pub fn sized_fallback_advance(
  character : Char,
  bold : Bool,
  size : Double,
) -> Double {
  let base = fallback_advance(character, bold)
  if size == 11.0 {
    base
  } else {
    base / 11.0 * size
  }
}

///|
/// Draw unstyled cells in an already-sized sheet with fallback font metrics.
pub fn draw_sized_grid_no_fonts(
  rows : Array[SizedGridRow],
  geometry : GridGeometry,
  all_columns : Array[Run],
  language : String,
  document_language : String,
  verticals~ : Map[Int32, Map[Int32, String]] = Map([]),
  horizontals~ : Map[Int32, Map[Int32, String]] = Map([]),
  bolds~ : Map[Int32, Map[Int32, Bool]] = Map([]),
  fills~ : Map[Int32, Map[Int32, GridSolidFill]] = Map([]),
  sizes~ : Map[Int32, Map[Int32, Double]] = Map([]),
  borders~ : Map[Int32, Map[Int32, GridCellBorder]] = Map([]),
  spans~ : Map[Int32, Map[Int32, Int32]] = Map([]),
  border_colors~ : Map[Int32, Map[Int32, Array[UInt32]]] = Map([]),
) -> DrawnGrid raise {
  let mut span_room = 4194304L
  for row, columns in spans {
    if row < 0 || row >= 1048576 {
      raise InvalidArgument("merged row is outside the sheet")
    }
    let starts : Array[Int32] = [ for start, _ in columns => start ]
    starts.sort()
    let mut previous_end = -1
    for start in starts {
      let end = columns[start]
      if start < 0 || end >= 16384 || end < start || start <= previous_end {
        raise InvalidArgument("invalid or overlapping merged columns")
      }
      span_room -= (end - start + 1).to_int64()
      if span_room < 0L {
        raise InvalidArgument("too many merged cells")
      }
      previous_end = end
    }
  }
  let col_positions = grid_positions(all_columns)
  if col_positions.length() != 16385 {
    raise InvalidArgument("expected sizes for 16384 columns")
  }
  let row_positions = grid_positions(geometry.rows)
  let count = row_positions.length() - 1
  let context : GridDrawContext = {
    tiles: [],
    indexes: Map([]),
    width: col_positions[16384],
    height: row_positions[count],
    document_language,
  }
  let family = grid_family("")
  let visible_columns = grid_positions(geometry.columns).length() - 1
  context.sized_grid_fills(
    rows, fills, col_positions, row_positions, visible_columns,
  )
  let mut text_columns = 0
  for sparse in rows {
    let i = sparse.index
    if i >= count || i >= 1048576 {
      break
    }
    if i < 0 {
      continue
    }
    let row : Array[Cell] = []
    let render_cells : Map[Int32, Cell] = Map([])
    let colors : Map[Int32, UInt32] = Map([])
    let centered : Map[Int32, Bool] = Map([])
    let visibility : Map[Int32, Bool] = Map([])
    for entry in sparse.cells {
      if entry.column < 0 || entry.column >= 16384 {
        continue
      }
      while row.length() <= entry.column {
        row.push({ text: "", number: false, })
      }
      row[entry.column] = if entry.occupied && entry.cell.text == "" {
        { text: "\u0000", number: entry.cell.number, }
      } else {
        entry.cell
      }
      render_cells[entry.column] = entry.cell
      colors[entry.column] = entry.color
      centered[entry.column] = entry.center
      visibility[entry.column] = entry.visible
    }
    let row_spans = spans.get(i).unwrap_or(Map([]))
    for start, end in row_spans {
      while row.length() <= end {
        row.push({ text: "", number: false, })
      }
      for column in start..<=end {
        if row[column].text == "" {
          row[column] = { text: "\u0000", number: false, }
        }
      }
    }
    let y = row_positions[i]
    let height = row_positions[i + 1] - y
    if height <= 0.0 {
      continue
    }
    for column, _ in row {
      if column >= 16384 {
        break
      }
      let mut last = column
      let mut hidden_by_span = false
      for start, end in row_spans {
        if column >= start && column <= end {
          if column == start {
            last = end
          } else {
            hidden_by_span = true
          }
          break
        }
      }
      if hidden_by_span ||
        !visibility.get(column).unwrap_or(false) ||
        col_positions[last + 1] <= col_positions[column] {
        continue
      }
      let cell = render_cells[column]
      let bold = match bolds.get(i) {
        Some(columns) => columns.get(column).unwrap_or(false)
        None => false
      }
      let size = match sizes.get(i) {
        Some(columns) => columns.get(column).unwrap_or(11.0)
        None => 11.0
      }
      let advance = (character : Char, is_bold : Bool) => {
        sized_fallback_advance(character, is_bold, size)
      }
      let metrics = (_ : Char, _ : Bool) => (0.9 * size, 0.25 * size)
      let text = sized_grid_text(cell.text)
      let display : Cell = { text, number: cell.number, }
      let initial = grid_cell_layout(
        row,
        display,
        column,
        col_positions,
        y,
        height,
        bold,
        language,
        advance,
        metrics,
        end_column=last,
      )
      let horizontal : DrawCell = if centered.get(column).unwrap_or(false) {
        let lines = initial.lines.map(fn(line) {
          {
            text: line.text,
            x: col_positions[column] +
            (col_positions[last + 1] - col_positions[column] - line.width) / 2.0,
            baseline: line.baseline,
            width: line.width,
            cjk_wrap: line.cjk_wrap,
          }
        })
        let mut x0 = col_positions[column]
        let mut x1 = col_positions[last + 1]
        let text0 = lines[0].x
        let text1 = lines[0].x + lines[0].width
        if text0 < x0 || text1 > x1 {
          let mut next = last + 1
          while next < 16384 && x1 < text1 {
            if next < row.length() && row[next].text != "" {
              break
            }
            x1 = col_positions[next + 1]
            next += 1
          }
          let mut previous = column - 1
          while previous >= 0 && x0 > text0 {
            if previous < row.length() && row[previous].text != "" {
              break
            }
            x0 = col_positions[previous]
            previous -= 1
          }
        }
        let (ascent, descent) = metrics('x', bold)
        let ty0 = lines[0].baseline - ascent
        let ty1 = lines[lines.length() - 1].baseline + descent
        let clipped = text0 < x0 - 0.01 ||
          text1 > x1 + 0.01 ||
          ty0 < y - 0.01 ||
          ty1 > y + height + 0.01
        if !clipped {
          x0 = Double::min(text0, col_positions[column])
          x1 = Double::max(text1, col_positions[last + 1])
        }
        {
          x0,
          x1,
          y0: initial.y0,
          y1: initial.y1,
          clip: clipped,
          lang: initial.lang,
          lang_known: initial.lang_known,
          lines,
        }
      } else {
        initial
      }
      let horizontal_kind = match horizontals.get(i) {
        Some(columns) => columns.get(column).unwrap_or("general")
        None => "general"
      }
      let horizontal = sized_grid_horizontal_layout(
        horizontal, horizontal_kind, row, display, column, last, col_positions, y,
        height, size,
      )
      let vertical = match verticals.get(i) {
        Some(columns) => columns.get(column).unwrap_or("bottom")
        None => "bottom"
      }
      let layout = sized_grid_vertical_layout(
        horizontal, y, height, vertical, size,
      )
      if layout.x1 > col_positions[visible_columns] {
        let target = layout.x1 - 0.01
        let mut lo = 0
        let mut hi = 16384
        while lo < hi {
          let mid = lo + (hi - lo) / 2
          if col_positions[mid + 1] > target {
            hi = mid
          } else {
            lo = mid + 1
          }
        }
        text_columns = Int32::max(text_columns, Int32::min(lo, 16383) + 1)
      }
      let reference = cell_reference(i, column, false) +
        (if row_spans.contains(column) {
          ":" + cell_reference(i, last, false)
        } else {
          ""
        })
      for tile in context.in_bounds(layout.x0, layout.y0, layout.x1, layout.y1) {
        tile.emit_cell(
          layout,
          reference,
          family,
          bold,
          colors.get(column).unwrap_or(0x000000ffU),
          advance,
          None,
          None,
          None,
          Map([]),
          size~,
        )
      }
    }
  }
  context.sized_grid_borders(
    rows, borders, border_colors, col_positions, row_positions, visible_columns,
  )
  let tiles = context.tiles.map(fn(tile) {
    { x: tile.x, y: tile.y, object: tile.object.encode(), drawn: tile.drawn, }
  })
  let final_count = Int32::min(
    16384,
    Int32::max(visible_columns, text_columns + 2),
  )
  let columns : Array[Run] = []
  let mut remaining = final_count
  for run in all_columns {
    let count = Int32::min(remaining, run.count)
    if count > 0 {
      columns.push({ count, size: run.size, })
      remaining -= count
    }
    if remaining <= 0 {
      break
    }
  }
  {
    geometry: {
      columns,
      rows: geometry.rows,
      frozen_rows: geometry.frozen_rows,
    },
    tiles,
  }
}

///|
fn GridDrawContext::sized_grid_borders(
  self : GridDrawContext,
  rows : Array[SizedGridRow],
  borders : Map[Int32, Map[Int32, GridCellBorder]],
  border_colors : Map[Int32, Map[Int32, Array[UInt32]]],
  columns : Array[Double],
  row_positions : Array[Double],
  visible_columns : Int32,
) -> Unit raise {
  let horizontal : Map[String, GridEdge] = Map([])
  let vertical : Map[String, GridEdge] = Map([])
  for row in rows {
    let index = row.index
    if index < 0 {
      continue
    }
    if index >= row_positions.length() - 1 {
      break
    }
    if row_positions[index] >= row_positions[index + 1] {
      continue
    }
    if borders.get(index) is Some(values) {
      let keys : Array[Int32] = [ for column, _ in values => column ]
      keys.sort()
      for column in keys {
        if column < 0 ||
          column >= visible_columns ||
          columns[column] >= columns[column + 1] {
          continue
        }
        let border = values[column]
        let colors = match border_colors.get(index) {
          Some(row_colors) => row_colors.get(column).unwrap_or([])
          None => []
        }
        let color = fn(i : Int32) { colors.get(i).unwrap_or(0x000000ffU) }
        put_grid_edge(horizontal, index, column, {
          weight: border.top,
          color: color(0),
        })
        put_grid_edge(horizontal, index + 1, column, {
          weight: border.bottom,
          color: color(1),
        })
        put_grid_edge(vertical, index, column, {
          weight: border.left,
          color: color(2),
        })
        put_grid_edge(vertical, index, column + 1, {
          weight: border.right,
          color: color(3),
        })
      }
    }
  }
  self.draw_grid_edges(horizontal, vertical, columns, row_positions)
}

///|
fn GridDrawContext::sized_fill_rect(
  self : GridDrawContext,
  fill : GridFillRect,
) -> Unit {
  for tile in self.in_bounds(fill.x0, fill.y0, fill.x1, fill.y1) {
    tile.fill_color(fill.fill.color)
    tile.rectangle(fill.x0, fill.y0, fill.x1 - fill.x0, fill.y1 - fill.y0)
  }
}

///|
fn GridDrawContext::sized_grid_fills(
  self : GridDrawContext,
  rows : Array[SizedGridRow],
  fills : Map[Int32, Map[Int32, GridSolidFill]],
  columns : Array[Double],
  row_positions : Array[Double],
  visible_columns : Int32,
) -> Unit {
  let mut previous : Array[GridFillRect] = []
  for row in rows {
    let index = row.index
    if index < 0 {
      continue
    }
    if index >= row_positions.length() - 1 {
      break
    }
    let y0 = row_positions[index]
    let y1 = row_positions[index + 1]
    if y0 >= y1 {
      continue
    }
    if !previous.is_empty() && previous[0].y1 < y0 {
      for rect in previous {
        self.sized_fill_rect(rect)
      }
      previous = []
    }
    let current : Array[GridFillRect] = []
    if fills.get(index) is Some(values) {
      let keys : Array[Int32] = [ for column, _ in values => column ]
      keys.sort()
      for column in keys {
        if column < 0 || column >= visible_columns {
          continue
        }
        let x0 = columns[column]
        let x1 = columns[column + 1]
        if x0 >= x1 {
          continue
        }
        let fill = values[column]
        if !current.is_empty() {
          let last = current[current.length() - 1]
          if last.fill.key == fill.key && last.x1 == x0 {
            current[current.length() - 1] = { ..last, x1, }
            continue
          }
        }
        current.push({ x0, x1, y0, y1, fill, })
      }
    }
    let next : Array[GridFillRect] = []
    let mut j = 0
    for rect in current {
      while j < previous.length() && previous[j].x0 < rect.x0 {
        self.sized_fill_rect(previous[j])
        j += 1
      }
      if j < previous.length() &&
        previous[j].x0 == rect.x0 &&
        previous[j].x1 == rect.x1 &&
        previous[j].fill.key == rect.fill.key &&
        previous[j].y1 == rect.y0 {
        next.push({ ..rect, y0: previous[j].y0, })
        j += 1
      } else {
        next.push(rect)
      }
    }
    while j < previous.length() {
      self.sized_fill_rect(previous[j])
      j += 1
    }
    previous = next
  }
  for rect in previous {
    self.sized_fill_rect(rect)
  }
}

///|
fn sized_grid_horizontal_layout(
  layout : DrawCell,
  alignment : String,
  row : Array[Cell],
  cell : Cell,
  column : Int32,
  last : Int32,
  positions : Array[Double],
  y : Double,
  height : Double,
  size : Double,
) -> DrawCell {
  if alignment != "left" && alignment != "right" {
    return layout
  }
  let left = positions[column]
  let right = positions[last + 1]
  let lines = layout.lines.map(line => {
    ..line,
    x: if alignment == "left" {
      left + 1.5
    } else {
      right - 2.25 - line.width
    },
  })
  let mut tx0 = 1.0e300
  let mut tx1 = -1.0e300
  for line in lines {
    tx0 = Double::min(tx0, line.x)
    tx1 = Double::max(tx1, line.x + line.width)
  }
  let mut x0 = left
  let mut x1 = right
  if !cell.number && !cell.text.contains("\n") && !cell.text.contains("\r") {
    if alignment == "right" {
      let mut previous = column - 1
      while previous >= 0 && x0 > tx0 {
        if previous < row.length() && row[previous].text != "" {
          break
        }
        x0 = positions[previous]
        previous -= 1
      }
    } else {
      let mut next = last + 1
      while next < 16384 && x1 < tx1 {
        if next < row.length() && row[next].text != "" {
          break
        }
        x1 = positions[next + 1]
        next += 1
      }
    }
  }
  let (ascent, descent) = (0.9 * size, 0.25 * size)
  let ty0 = lines[0].baseline - ascent
  let ty1 = lines[lines.length() - 1].baseline + descent
  let clip = tx0 < x0 - 0.01 ||
    tx1 > x1 + 0.01 ||
    ty0 < y - 0.01 ||
    ty1 > y + height + 0.01
  if !clip {
    x0 = Double::min(tx0, left)
    x1 = Double::max(tx1, right)
  }
  { ..layout, x0, x1, clip, lines, }
}

///|
fn sized_grid_vertical_layout(
  layout : DrawCell,
  y : Double,
  height : Double,
  vertical : String,
  size : Double,
) -> DrawCell {
  if vertical != "top" && vertical != "center" {
    return layout
  }
  let metrics : Array[(Double, Double)] = []
  let mut total = 0.0
  for line in layout.lines {
    let mut ascent = 0.0
    let mut descent = 0.0
    for character in line.text {
      let _ = character
      let (a, d) = (0.9 * size, 0.25 * size)
      ascent = Double::max(ascent, a)
      descent = Double::max(descent, d)
    }
    if ascent == 0.0 && descent == 0.0 {
      let (a, d) = (0.9 * size, 0.25 * size)
      ascent = a
      descent = d
    }
    metrics.push((ascent, descent))
    total += ascent + descent
  }
  let mut top = if vertical == "top" {
    y + 0.75
  } else {
    y + (height - total) / 2.0
  }
  let lines : Array[DrawLine] = []
  let mut tx0 = 1.0e300
  let mut tx1 = -1.0e300
  for i, line in layout.lines {
    let (ascent, descent) = metrics[i]
    tx0 = Double::min(tx0, line.x)
    tx1 = Double::max(tx1, line.x + line.width)
    lines.push({ ..line, baseline: top + ascent, })
    top += ascent + descent
  }
  let ty0 = lines[0].baseline - metrics[0].0
  let ty1 = lines[lines.length() - 1].baseline + metrics[metrics.length() - 1].1
  {
    ..layout,
    clip: tx0 < layout.x0 - 0.01 ||
    tx1 > layout.x1 + 0.01 ||
    ty0 < y - 0.01 ||
    ty1 > y + height + 0.01,
    lines,
  }
}

///|
fn sized_grid_text(text : String) -> String {
  let output = StringBuilder()
  let mut shown = 0
  for c in text {
    if c == '\n' {
      shown += 1
    } else {
      let char = if c == '\t' { ' ' } else { c }
      if char.to_int() < 0x20 {
        continue
      }
      output.write_char(char)
      shown += 1
    }
    if shown >= 1024 {
      break
    }
  }
  output.to_string()
}
