///|
/// A cell positioned within a sparse sheet row.
pub(all) struct SizedGridCell {
  column : Int32
  cell : Cell
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
  default_column_width : Double,
  language : String,
) -> DrawnGrid raise {
  let col_positions = grid_positions(geometry.columns)
  while col_positions.length() <= 16384 {
    col_positions.push(
      col_positions[col_positions.length() - 1] + default_column_width,
    )
  }
  let row_positions = grid_positions(geometry.rows)
  let count = row_positions.length() - 1
  let context : GridDrawContext = {
    tiles: [],
    indexes: Map([]),
    width: col_positions[16384],
    height: row_positions[count],
  }
  let family = grid_family(language)
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
    for entry in sparse.cells {
      if entry.column < 0 || entry.column >= 16384 {
        continue
      }
      while row.length() <= entry.column {
        row.push({ text: "", number: false, })
      }
      row[entry.column] = entry.cell
    }
    let y = row_positions[i]
    let height = row_positions[i + 1] - y
    if height <= 0.0 {
      continue
    }
    for column, cell in row {
      if column >= 16384 {
        break
      }
      if cell.text == "" || col_positions[column + 1] <= col_positions[column] {
        continue
      }
      let text = cell.text.replace(old="\n", new="").replace(old="\r", new="")
      let display : Cell = { text, number: cell.number, }
      let layout = grid_cell_layout(
        row, display, column, col_positions, y, height, false, language, fallback_advance,
        fallback_line_metrics,
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
      let reference = cell_reference(i, column, false)
      for tile in context.in_bounds(layout.x0, layout.y0, layout.x1, layout.y1) {
        tile.emit_cell(
          layout,
          reference,
          family,
          false,
          0x000000ffU,
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
  let columns = geometry.columns.copy()
  let extended = Int32::min(
      16384,
      Int32::max(visible_columns, text_columns + 2),
    ) -
    visible_columns
  if extended > 0 {
    let size = Float::from_double(default_column_width)
    let last = columns.length() - 1
    if last >= 0 && columns[last].size == size {
      columns[last] = { count: columns[last].count + extended, size, }
    } else {
      columns.push({ count: extended, size, })
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
