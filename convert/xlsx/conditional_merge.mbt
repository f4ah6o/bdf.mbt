///|
// Evaluate the cells that a conditional rule matches, following the upstream
// first-rule-wins model: rules run in ascending priority, a rule paints only
// the properties no higher-priority rule has painted for a cell, and
// stopIfTrue keeps later rules from touching the cells it matched.

///|
fn xlsx_conditional_was_stopped(
  stopped : Map[Int32, Map[Int32, Bool]],
  row : Int32,
  column : Int32,
) -> Bool {
  match stopped.get(row) {
    Some(columns) => columns.contains(column)
    None => false
  }
}

///|
fn xlsx_conditional_mark_stopped(
  stopped : Map[Int32, Map[Int32, Bool]],
  row : Int32,
  columns : Map[Int32, Bool],
) -> Unit {
  let target = match stopped.get(row) {
    Some(value) => value
    None => {
      let value : Map[Int32, Bool] = Map([])
      stopped[row] = value
      value
    }
  }
  for column, _ in columns {
    target[column] = true
  }
}

///|
fn xlsx_conditional_merge_into(
  target : Map[Int32, Map[Int32, XlsxConditionalStyle]],
  row : Int32,
  column : Int32,
  style : XlsxConditionalStyle,
) -> Unit {
  let columns = match target.get(row) {
    Some(value) => value
    None => {
      let value : Map[Int32, XlsxConditionalStyle] = Map([])
      target[row] = value
      value
    }
  }
  let merged = match columns.get(column) {
    Some(value) => xlsx_merge_conditional_style(value, style)
    None => style
  }
  columns[column] = merged
}

///|
// Blank cells are not values the sheet holds; a fill or border that matches
// them is recorded per position so they can be made explicit before the
// conditional format is applied. Stopped positions are left alone.
fn xlsx_conditional_merge_blank_cells(
  rows : Array[XlsxRow],
  ranges : Array[XlsxRange],
  row_count : Int32,
  col_count : Int32,
  stopped : Map[Int32, Map[Int32, Bool]],
  stopped_blank_ranges : Array[XlsxRange],
  style : XlsxConditionalStyle,
  target : Map[Int32, Map[Int32, XlsxConditionalStyle]],
) -> Unit {
  let kinds : Map[Int32, Map[Int32, Int32]] = Map([])
  let present : Array[Int32] = []
  for row in rows {
    let columns : Map[Int32, Int32] = Map([])
    for cell in row.cells {
      columns[cell.column] = cell.kind
    }
    kinds[row.index] = columns
    present.push(row.index)
  }
  present.sort()
  for range in ranges {
    let first_row = Int64::max(range.row_start, 0L)
    let last_row = Int64::min(range.row_end, (row_count - 1).to_int64())
    let first_col = Int32::max(range.column_start, 0)
    let last_col = Int32::min(range.column_end, col_count - 1)
    if first_row > last_row || first_col > last_col {
      continue
    }
    // Upstream only reads the rows a very tall range can hold when the sheet
    // has a row element there; cell ranges over empty rows stay unpainted.
    let mut r = first_row.to_int()
    let mut next = 0
    while next < present.length() && present[next] <= r {
      next += 1
    }
    while r <= last_row.to_int() {
      while next < present.length() && present[next] <= r {
        next += 1
      }
      let row = r
      for column in first_col..<=last_col {
        let kind = match kinds.get(row) {
          Some(columns) => columns.get(column).unwrap_or(0)
          None => 0
        }
        if kind != 0 {
          continue
        }
        if xlsx_conditional_was_stopped(stopped, row, column) {
          continue
        }
        let mut blocked = false
        for stopped_range in stopped_blank_ranges {
          if row.to_int64() >= stopped_range.row_start &&
            row.to_int64() <= stopped_range.row_end &&
            column >= stopped_range.column_start &&
            column <= stopped_range.column_end {
            blocked = true
            break
          }
        }
        if !blocked {
          xlsx_conditional_merge_into(target, row, column, style)
        }
      }
      if range.row_end - range.row_start > 1000L && !kinds.contains(row) {
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

///|
// Group the merged styles of the matched cells so one conditional format is
// appended per distinct style instead of one per cell.
fn xlsx_conditional_group_styles(
  source : Map[Int32, Map[Int32, XlsxConditionalStyle]],
  group_styles : Array[XlsxConditionalStyle],
  group_matches : Array[Map[Int32, Map[Int32, Bool]]],
) -> Unit {
  for row, columns in source {
    for column, style in columns {
      let mut group = -1
      for i, existing in group_styles {
        if xlsx_conditional_style_equal(existing, style) {
          group = i
          break
        }
      }
      if group < 0 {
        group = group_styles.length()
        group_styles.push(style)
        group_matches.push(Map([]))
      }
      let matched = group_matches[group]
      let target = match matched.get(row) {
        Some(value) => value
        None => {
          let value : Map[Int32, Bool] = Map([])
          matched[row] = value
          value
        }
      }
      target[column] = true
    }
  }
}
