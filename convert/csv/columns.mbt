///|
/// Fit CSV sheet columns using the supplied font's per-character advance.
/// When no font is available, the default matches upstream's fallback.
pub fn fit_grid_columns(
  grid : Grid,
  filter_buttons~ : Bool = false,
  mdw~ : Double = 7.0,
  advance~ : (Char, Bool) -> Double = @sheet.fallback_advance,
) -> Array[Float] raise {
  let rows = grid.rows.map(row => {
    row.map(cell => @sheet.Cell::{ text: cell.text, number: cell.number, })
  })
  @sheet.fit_columns(
    rows,
    header_rows=grid.header_rows,
    filter_buttons~,
    mdw~,
    advance~,
  )
}
