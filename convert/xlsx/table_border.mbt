///|
// Apply table-region differential borders beneath explicit cell borders.
fn XlsxWorkbook::xlsx_apply_table_borders(
  self : XlsxWorkbook,
  original : Array[XlsxRow],
  styles : XlsxStyles,
  geo : XlsxSheetGeometry,
  row_count : Int32,
  col_count : Int32,
  table_rules : Array[
    (
      XlsxRange,
      Int32,
      Int64,
      Int64,
      Int32,
      Int32,
      Int32,
      Int64,
      Int64,
      Int32,
      Int64,
      Int32,
      Int64,
    ),
  ],
  complex_rules : Map[Int32, XlsxComplexTable],
) -> Array[XlsxRow] raise {
  let mut rows = original
  for index, (range, _, _, _, _, _, region, _, _, _, _, _, _) in table_rules {
    if region != 25 {
      continue
    }
    let table = complex_rules[index]
    let borders : Array[XlsxBorder?] = Array::make(13, None)
    let mut has_border = false
    for i in 0..<table.style.ids.length() {
      let id = table.style.ids[i]
      if id >= 0 {
        let diff = self.xlsx_table_differential_style(id)
        borders[i] = diff.border
        if diff.border is Some(_) {
          has_border = true
        }
      }
    }
    if !has_border {
      continue
    }
    let first_row = Int64::max(range.row_start, 0L).to_int()
    let last_row = Int64::min(range.row_end, (row_count - 1).to_int64()).to_int()
    let first_col = Int32::max(range.column_start, 0)
    let last_col = Int32::min(range.column_end, col_count - 1)
    let allowed : Map[Int32, Map[Int32, Bool]] = Map([])
    if first_row <= last_row && first_col <= last_col {
      for r in first_row..<=last_row {
        let columns : Map[Int32, Bool] = Map([])
        for c in first_col..<=last_col {
          for owner, (other, _, _, _, _, _, _, _, _, _, _, _, _) in table_rules {
            if r.to_int64() >= other.row_start &&
              r.to_int64() <= other.row_end &&
              c >= other.column_start &&
              c <= other.column_end {
              if owner == index {
                columns[c] = true
              }
              break
            }
          }
        }
        allowed[r] = columns
      }
    }
    let chunks : Array[XlsxRange] = []
    let mut start = first_row
    while start <= last_row {
      let finish = Int32::min(start + 999, last_row)
      chunks.push({
        ..range,
        row_start: start.to_int64(),
        row_end: finish.to_int64(),
      })
      start = finish + 1
    }
    let matched : Map[Int32, Map[Int32, Bool]] = Map([])
    rows = xlsx_materialize_conditional_blanks(
      rows,
      geo,
      styles.cell_formats.length(),
      chunks,
      row_count,
      col_count,
      matched,
      Some(allowed),
    )
    let formats : Map[String, Int32] = Map([])
    let next_rows : Array[XlsxRow] = []
    for row in rows {
      let cells : Array[XlsxCell] = []
      for cell in row.cells {
        let included = match allowed.get(row.index) {
          Some(columns) => columns.contains(cell.column)
          None => false
        }
        if !included {
          cells.push(cell)
          continue
        }
        let (border, border_key) = xlsx_complex_table_border(
          table,
          borders,
          row.index,
          cell.column,
        )
        if border.top.style == "" &&
          border.bottom.style == "" &&
          border.left.style == "" &&
          border.right.style == "" {
          cells.push(cell)
          continue
        }
        let old_index = if cell.style < 0 ||
          cell.style >= styles.cell_formats.length() {
          0
        } else {
          cell.style
        }
        let key = old_index.to_string() + ":" + border_key
        let new_index = match formats.get(key) {
          Some(value) => value
          None => {
            let format = styles.cell_formats[old_index]
            let base = if format.border >= 0 &&
              format.border < styles.borders.length() {
              styles.borders[format.border]
            } else {
              {
                left: xlsx_empty_side(),
                right: xlsx_empty_side(),
                top: xlsx_empty_side(),
                bottom: xlsx_empty_side(),
                diagonal: xlsx_empty_side(),
                diagonal_up: false,
                diagonal_down: false,
                vertical: xlsx_empty_side(),
                horizontal: xlsx_empty_side(),
              }
            }
            let top = border.top
            let bottom = border.bottom
            let left = border.left
            let right = border.right
            let border_index = styles.borders.length()
            styles.borders.push({
              ..base,
              top: if base.top.style == "" {
                top
              } else {
                base.top
              },
              bottom: if base.bottom.style == "" {
                bottom
              } else {
                base.bottom
              },
              left: if base.left.style == "" {
                left
              } else {
                base.left
              },
              right: if base.right.style == "" {
                right
              } else {
                base.right
              },
            })
            let value = styles.cell_formats.length()
            styles.cell_formats.push({ ..format, border: border_index, })
            formats[key] = value
            value
          }
        }
        cells.push({ ..cell, style: new_index, })
      }
      next_rows.push({ ..row, cells, })
    }
    rows = next_rows
  }
  rows
}
