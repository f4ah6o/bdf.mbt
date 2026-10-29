///|
/// Fit CSV sheet columns using the supplied font's per-character advance.
/// When no font is available, the default matches upstream's fallback.
pub fn fit_grid_columns(
  grid : Grid,
  filter_buttons~ : Bool = false,
  mdw~ : Double = 7.0,
  advance~ : (Char, Bool) -> Double = @sheet.fallback_advance,
) -> Array[Float] raise {
  let rows = sheet_cells(grid)
  @sheet.fit_columns(
    rows,
    header_rows=grid.header_rows,
    filter_buttons~,
    mdw~,
    advance~,
  )
}

///|
/// Calculate the heights of CSV sheet rows using the selected font metrics.
pub fn fit_grid_rows(
  grid : Grid,
  columns : Array[Float],
  mdw~ : Double = 7.0,
  advance~ : (Char, Bool) -> Double = @sheet.fallback_advance,
  metrics~ : (Char, Bool) -> (Double, Double) = @sheet.fallback_line_metrics,
  default_line_height~ : Double = (0.9 + 0.25) * 11.0,
  style_line_height~ : ((Bool) -> Double)? = None,
) -> Array[Float] raise {
  let rows = sheet_cells(grid)
  @sheet.fit_rows(
    rows,
    columns,
    header_rows=grid.header_rows,
    mdw~,
    advance~,
    metrics~,
    default_line_height~,
    style_line_height~,
  )
}

///|
fn sheet_cells(grid : Grid) -> Array[Array[@sheet.Cell]] {
  grid.rows.map(row => {
    row.map(cell => @sheet.Cell::{ text: cell.text, number: cell.number, })
  })
}

///|
/// Compute the CSV sheet's dimensions, margins and frozen header.
pub fn grid_geometry(
  grid : Grid,
  filter_buttons~ : Bool = false,
  mdw~ : Double = 7.0,
  advance~ : (Char, Bool) -> Double = @sheet.fallback_advance,
  metrics~ : (Char, Bool) -> (Double, Double) = @sheet.fallback_line_metrics,
  default_line_height~ : Double = (0.9 + 0.25) * 11.0,
  style_line_height~ : ((Bool) -> Double)? = None,
) -> @sheet.GridGeometry raise {
  @sheet.grid_geometry(
    sheet_cells(grid),
    header_rows=grid.header_rows,
    filter_buttons~,
    mdw~,
    advance~,
    metrics~,
    default_line_height~,
    style_line_height~,
  )
}
