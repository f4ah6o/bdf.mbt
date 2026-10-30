///|
// The upstream rule ranks numeric cells once, including ties and deduplicating
// overlapping ranges. Blank, string, boolean, and error cells are excluded.
fn xlsx_conditional_top_threshold(
  rows : Array[XlsxRow],
  ranges : Array[XlsxRange],
  row_count : Int32,
  col_count : Int32,
  rank : Int32,
  percent : Bool,
  bottom : Bool,
) -> Double? raise {
  let values = xlsx_conditional_numeric_values(
    rows, ranges, row_count, col_count, false,
  )
  if values.is_empty() {
    return None
  }
  let rank = if percent {
    Int64::max(1L, values.length().to_int64() * rank.to_int64() / 100L)
  } else {
    rank.to_int64()
  }
  if rank <= 0L {
    return None
  }
  let rank = Int64::min(rank, values.length().to_int64()).to_int()
  values.sort_by((a, b) => if a < b { -1 } else if a > b { 1 } else { 0 })
  Some(if bottom { values[rank - 1] } else { values[values.length() - rank] })
}

///|
// Collect cells in range order, matching the upstream rule's deduplication.
fn xlsx_conditional_numeric_values(
  rows : Array[XlsxRow],
  ranges : Array[XlsxRange],
  row_count : Int32,
  col_count : Int32,
  allow_nan : Bool,
) -> Array[Double] raise {
  let values : Array[Double] = []
  let seen : Map[Int32, Map[Int32, Bool]] = Map([])
  for range in ranges {
    let last_row = Int64::min(range.row_end, (row_count - 1).to_int64())
    let last_col = Int32::min(range.column_end, col_count - 1)
    for row in rows {
      if row.index.to_int64() < range.row_start ||
        row.index.to_int64() > last_row {
        continue
      }
      for cell in row.cells {
        if cell.column < range.column_start ||
          cell.column > last_col ||
          cell.kind != 1 {
          continue
        }
        if cell.number.is_nan() && !allow_nan {
          xlsx_reject_conditional()
        }
        let columns = match seen.get(row.index) {
          Some(columns) => columns
          None => {
            let columns : Map[Int32, Bool] = Map([])
            seen[row.index] = columns
            columns
          }
        }
        if !columns.contains(cell.column) {
          columns[cell.column] = true
          values.push(cell.number)
        }
      }
    }
  }
  values
}

///|
fn xlsx_conditional_average_threshold(
  rows : Array[XlsxRow],
  ranges : Array[XlsxRange],
  row_count : Int32,
  col_count : Int32,
  multiplier : Double,
  above : Bool,
) -> Double? raise {
  let values = xlsx_conditional_numeric_values(
    rows, ranges, row_count, col_count, true,
  )
  if values.is_empty() {
    return None
  }
  let mut sum = 0.0
  for value in values {
    sum += value
  }
  if sum.is_nan() {
    return None
  }
  let mean = sum / values.length().to_double()
  if multiplier == 0.0 {
    return Some(mean)
  }
  if multiplier.is_nan() {
    return None
  }
  let mut squared = 0.0
  if values.length() >= 2 {
    for value in values {
      let difference = value - mean
      squared = xlsx_fma(difference, difference, squared)
    }
  }
  if squared.is_nan() {
    return None
  }
  let sd = if values.length() < 2 {
    0.0
  } else {
    (squared / (values.length() - 1).to_double()).sqrt()
  }
  let result = xlsx_fma(if above { multiplier } else { -multiplier }, sd, mean)
  if result.is_nan() {
    return None
  }
  Some(result)
}

///|
// Reject hexadecimal floats, which MoonBit does not parse.
fn xlsx_conditional_stddev(raw : String) -> Double raise {
  let text = xlsx_trim(raw)
  let lower = text.to_lower()
  if lower.has_prefix("0x") ||
    lower.has_prefix("+0x") ||
    lower.has_prefix("-0x") {
    xlsx_reject_conditional()
  }
  if lower == "+nan" || lower == "-nan" {
    return 0.0
  }
  let value = @string.parse_double(text) catch { _ => return 0.0 }
  if value.is_inf() &&
    !["inf", "+inf", "-inf", "infinity", "+infinity", "-infinity"].contains(
      lower,
    ) {
    return 0.0
  }
  if value.is_nan() && lower != "nan" {
    return 0.0
  }
  value
}

///|
// Go truncates decimal ranks towards zero. Saturating ranks that exceed the
// maximum covered-cell budget preserves their effect without Int32 overflow.
fn xlsx_conditional_rank(raw : String) -> Int32 raise {
  let text = xlsx_trim(raw)
  match xlsx_int(text) {
    Some(n) => {
      if n > 200000000000L {
        xlsx_reject_conditional()
      }
      if n <= 0L {
        return -1
      }
      Int64::min(n, 4194304L).to_int()
    }
    None => {
      // Go also accepts hexadecimal floats, which the MoonBit parser does not.
      if text.contains("x") ||
        text.contains("X") ||
        text.contains("p") ||
        text.contains("P") {
        xlsx_reject_conditional()
      }
      let value = @string.parse_double(text) catch { _ => return 10 }
      if value.is_nan() || value.is_inf() || value > 200000000000.0 {
        xlsx_reject_conditional()
      }
      if value <= 0.0 {
        return -1
      }
      if value >= 4194304.0 {
        return 4194304
      }
      value.to_int()
    }
  }
}
