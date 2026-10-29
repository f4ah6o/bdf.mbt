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
/// Draw unstyled cells in an already-sized sheet with fallback font metrics.
pub fn draw_sized_grid_no_fonts(
  rows : Array[SizedGridRow],
  geometry : GridGeometry,
  all_columns : Array[Run],
  language : String,
  document_language : String,
) -> DrawnGrid raise {
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
    let y = row_positions[i]
    let height = row_positions[i + 1] - y
    if height <= 0.0 {
      continue
    }
    for column, _ in row {
      if column >= 16384 {
        break
      }
      if !visibility.get(column).unwrap_or(false) ||
        col_positions[column + 1] <= col_positions[column] {
        continue
      }
      let cell = render_cells[column]
      let text = sized_grid_text(cell.text)
      let display : Cell = { text, number: cell.number, }
      let initial = grid_cell_layout(
        row, display, column, col_positions, y, height, false, language, fallback_advance,
        fallback_line_metrics,
      )
      let layout : DrawCell = if centered.get(column).unwrap_or(false) {
        let lines = initial.lines.map(fn(line) {
          {
            text: line.text,
            x: col_positions[column] +
            (col_positions[column + 1] - col_positions[column] - line.width) /
            2.0,
            baseline: line.baseline,
            width: line.width,
            cjk_wrap: line.cjk_wrap,
          }
        })
        let mut x0 = col_positions[column]
        let mut x1 = col_positions[column + 1]
        let text0 = lines[0].x
        let text1 = lines[0].x + lines[0].width
        if text0 < x0 || text1 > x1 {
          let mut next = column + 1
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
        let (ascent, descent) = fallback_line_metrics('x', false)
        let ty0 = lines[0].baseline - ascent
        let ty1 = lines[lines.length() - 1].baseline + descent
        let clipped = text0 < x0 - 0.01 ||
          text1 > x1 + 0.01 ||
          ty0 < y - 0.01 ||
          ty1 > y + height + 0.01
        if !clipped {
          x0 = Double::min(text0, col_positions[column])
          x1 = Double::max(text1, col_positions[column + 1])
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
      let reference = cell_reference(i, column, false)
      for tile in context.in_bounds(layout.x0, layout.y0, layout.x1, layout.y1) {
        tile.emit_cell(
          layout,
          reference,
          family,
          false,
          colors.get(column).unwrap_or(0x000000ffU),
          fallback_advance,
          None,
          None,
          None,
          Map([]),
        )
      }
    }
  }
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
