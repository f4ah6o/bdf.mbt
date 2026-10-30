///|
// Evaluate relative references at each target cell. The bounded scan also
// follows the upstream sparse-row shortcut for very tall ranges.
fn xlsx_match_moving_conditionals(
  rows : Array[XlsxRow],
  ranges : Array[XlsxRange],
  row_count : Int32,
  col_count : Int32,
  reference1 : String,
  reference2 : String,
  threshold : Double,
  threshold_end : Double,
  literal1 : String?,
  literal2 : String?,
  operator : String,
  matched : Map[Int32, Map[Int32, Bool]],
  blanks : Map[Int32, Map[Int32, Bool]],
) -> Unit raise {
  let by_row : Map[Int32, XlsxRow] = Map([])
  let present : Array[Int32] = []
  let mut max_cells = 0
  for row in rows {
    by_row[row.index] = row
    present.push(row.index)
    max_cells = Int32::max(max_cells, row.cells.length())
  }
  present.sort()
  let mut area = 0L
  for range in ranges {
    let end_row = Int64::min(range.row_end, (row_count - 1).to_int64())
    let end_col = Int32::min(range.column_end, col_count - 1)
    if end_row < range.row_start || end_col < range.column_start {
      continue
    }
    area += (end_row - range.row_start + 1L) *
      (end_col - range.column_start + 1).to_int64()
    if area > 200000L ||
      area * (rows.length() + max_cells).to_int64() > 2000000L {
      xlsx_reject_conditional()
    }
    let mut r = range.row_start.to_int()
    let mut next = 0
    while next < present.length() && present[next] <= r {
      next += 1
    }
    while r <= end_row.to_int() {
      while next < present.length() && present[next] <= r {
        next += 1
      }
      let row = by_row.get(r)
      for c in range.column_start..<=end_col {
        let mut kind = 0
        let mut number = 0.0
        let mut content = ""
        if row is Some(row) {
          for cell in row.cells {
            if cell.column == c {
              kind = cell.kind
              number = cell.number
              content = cell.text
              break
            }
          }
        }
        let delta_row = r - ranges[0].row_start.to_int()
        let delta_col = c - ranges[0].column_start
        let lo = if reference1 == "" {
          Some({ number: threshold, text: literal1, })
        } else {
          xlsx_conditional_shifted_reference(
            reference1, rows, delta_row, delta_col,
          )
        }
        let hi = if reference2 == "" {
          Some({ number: threshold_end, text: literal2, })
        } else {
          xlsx_conditional_shifted_reference(
            reference2, rows, delta_row, delta_col,
          )
        }
        let lo = match lo {
          Some(v) => {
            if v.text is None && (v.number.is_nan() || v.number.is_inf()) {
              xlsx_reject_conditional()
            }
            v
          }
          None => {
            xlsx_reject_conditional()
            { number: 0.0, text: None, }
          }
        }
        let hi = match hi {
          Some(v) => {
            if v.text is None && (v.number.is_nan() || v.number.is_inf()) {
              xlsx_reject_conditional()
            }
            v
          }
          None => {
            xlsx_reject_conditional()
            { number: 0.0, text: None, }
          }
        }
        let applies = if lo.text is Some(_) || hi.text is Some(_) {
          let text : String? = if kind == 0 || kind == 1 {
            None
          } else if kind == 3 {
            Some(if number != 0.0 { "TRUE" } else { "FALSE" })
          } else if kind == 2 || kind == 4 {
            Some(content)
          } else {
            xlsx_reject_conditional()
            None
          }
          if kind == 1 && number.is_nan() {
            xlsx_reject_conditional()
          }
          xlsx_conditional_literal_matches(
            number,
            text,
            lo.number,
            lo.text,
            hi.number,
            hi.text,
            operator,
          )
        } else if kind == 0 || kind == 1 {
          if number.is_nan() {
            xlsx_reject_conditional()
          }
          xlsx_plain_conditional_matches(number, lo.number, hi.number, operator)
        } else if kind == 2 || kind == 3 || kind == 4 {
          ["greaterThan", "greaterThanOrEqual", "notEqual", "notBetween"].contains(
            operator,
          )
        } else {
          xlsx_reject_conditional()
          false
        }
        if applies {
          let target = if kind == 0 { blanks } else { matched }
          let columns = match target.get(r) {
            Some(columns) => columns
            None => {
              let columns : Map[Int32, Bool] = Map([])
              target[r] = columns
              columns
            }
          }
          columns[c] = true
        }
      }
      if range.row_end - range.row_start > 1000L && row is None {
        if next >= present.length() {
          break
        }
        r = present[next]
      } else {
        r += 1
      }
    }
  }
}
