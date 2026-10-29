///|
// Make blank cells that a conditional fill or border formats explicit for the
// sparse painter, retaining the base row/column style used by formatAt.
fn xlsx_materialize_conditional_blanks(
  rows : Array[XlsxRow],
  geometry : XlsxSheetGeometry,
  format_count : Int32,
  ranges : Array[XlsxRange],
  row_count : Int32,
  col_count : Int32,
  matched : Map[Int32, Map[Int32, Bool]],
) -> Array[XlsxRow] {
  let column_styles = Array::make(col_count, -1)
  for column in geometry.columns {
    let first = Int32::max(column.first, 0)
    let last = Int32::min(column.last, col_count - 1)
    if first <= last {
      for c in first..<=last {
        column_styles[c] = column.style
      }
    }
  }
  let by_row : Map[Int32, XlsxRow] = Map([])
  for row in rows {
    by_row[row.index] = row
  }
  let wanted : Map[Int32, Map[Int32, Bool]] = Map([])
  for range in ranges {
    let first_row = Int64::max(range.row_start, 0L)
    let last_row = Int64::min(range.row_end, (row_count - 1).to_int64())
    let first_col = Int32::max(range.column_start, 0)
    let last_col = Int32::min(range.column_end, col_count - 1)
    if first_row > last_row || first_col > last_col {
      continue
    }
    for r in first_row.to_int()..<=last_row.to_int() {
      let columns = match wanted.get(r) {
        Some(columns) => columns
        None => {
          let columns : Map[Int32, Bool] = Map([])
          wanted[r] = columns
          columns
        }
      }
      for c in first_col..<=last_col {
        columns[c] = true
      }
    }
  }
  let indices : Map[Int32, Bool] = Map([])
  for r, _ in by_row {
    indices[r] = true
  }
  for r, _ in wanted {
    indices[r] = true
  }
  let sorted : Array[Int32] = [ for r, _ in indices => r ]
  sorted.sort()
  let result : Array[XlsxRow] = []
  for r in sorted {
    let row : XlsxRow = by_row
      .get(r)
      .unwrap_or({
        index: r,
        height: -1.0,
        custom_height: false,
        hidden: false,
        style: -1,
        cells: [],
      })
    let cells = row.cells.copy()
    let explicit : Map[Int32, XlsxCell] = Map([])
    for cell in row.cells {
      explicit[cell.column] = cell
    }
    if wanted.get(r) is Some(columns) {
      for c, _ in columns {
        if explicit.get(c) is Some(cell) {
          if cell.kind != 0 {
            continue
          }
        } else {
          let base = if row.style >= 0 { row.style } else { column_styles[c] }
          let style = if base < 0 || base >= format_count { 0 } else { base }
          cells.push({ column: c, style, kind: 0, number: 0.0, text: "", })
        }
        let matches = match matched.get(r) {
          Some(matches) => matches
          None => {
            let matches : Map[Int32, Bool] = Map([])
            matched[r] = matches
            matches
          }
        }
        matches[c] = true
      }
    }
    cells.sort_by((a, b) => a.column.compare(b.column))
    result.push({ ..row, cells, })
  }
  result
}
