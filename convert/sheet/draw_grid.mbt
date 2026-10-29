///|
fn grid_positions(runs : Array[Run]) -> Array[Double] {
  let positions : Array[Double] = [0.0]
  for run in runs {
    for _ in 0..<run.count {
      positions.push(positions[positions.length() - 1] + run.size.to_double())
    }
  }
  positions
}

///|
/// Draw an unstyled grid with the upstream no-font fallback metrics. This is
/// the explicit no-font mode; a full converter also needs font discovery,
/// embedding and table styles.
pub fn draw_grid_no_fonts(
  rows : Array[Array[Cell]],
  header_rows~ : Int32 = 0,
  subheader~ : Bool = false,
  language~ : String = "",
) -> DrawnGrid raise {
  let geometry = grid_geometry(rows, header_rows~, subheader~)
  let col_positions = grid_positions(geometry.columns)
  while col_positions.length() <= 16384 {
    col_positions.push(col_positions[col_positions.length() - 1] + 48.0)
  }
  let row_positions = grid_positions(geometry.rows)
  let row_count = row_positions.length() - 1
  let family = grid_family(language)
  let tiles : Array[DrawTile] = []
  let indexes : Map[String, Int32] = Map([])
  for row_index, row in rows {
    if row_index >= 1048576 || row_index >= row_count {
      break
    }
    let y = row_positions[row_index]
    let height = row_positions[row_index + 1] - y
    let bold = row_index < header_rows &&
      !(subheader && row_index == header_rows - 1)
    let color : UInt32 = if subheader && row_index == header_rows - 1 {
      0x7f7f7fffU
    } else {
      0x000000ffU
    }
    for column, cell in row {
      if column >= 16384 {
        break
      }
      if cell.text == "" {
        continue
      }
      let layout = grid_cell_layout(
        row, cell, column, col_positions, y, height, bold, language,
      )
      let x0 = Double::max(layout.x0, 0.0)
      let y0 = Double::max(layout.y0, 0.0)
      let x1 = Double::min(layout.x1, col_positions[16384])
      let y1 = Double::min(layout.y1, row_positions[row_count])
      if !(x0 < x1 && y0 < y1) {
        continue
      }
      let tx0 = (x0 / 2048.0).to_int()
      let tx1 = (x1 / 2048.0).ceil().to_int()
      let ty0 = (y0 / 2048.0).to_int()
      let ty1 = (y1 / 2048.0).ceil().to_int()
      let ref = cell_reference(
        row_index,
        column,
        row_index < geometry.frozen_rows,
      )
      for ty in ty0..<ty1 {
        for tx in tx0..<tx1 {
          let key = "\{tx},\{ty}"
          let index = match indexes.get(key) {
            Some(index) => index
            None => {
              let index = tiles.length()
              tiles.push(DrawTile::new(tx, ty))
              indexes[key] = index
              index
            }
          }
          tiles[index].emit_cell(layout, ref, family, bold, color)
        }
      }
    }
  }
  let result : Array[GridTile] = []
  for tile in tiles {
    result.push({
      x: tile.x,
      y: tile.y,
      object: tile.object.encode(),
      drawn: tile.drawn,
    })
  }
  { geometry, tiles: result, }
}
