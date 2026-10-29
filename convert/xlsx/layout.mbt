///|
/// Run-length encoded sheet sizes in BDF points.
pub(all) struct XlsxSizeRun {
  count : Int32
  size : Float
}

///|
/// Initial view extent from cells, merges, frozen panes and extra objects.
/// Supply table, drawing, comment and picture endpoints in `extra`.
pub fn xlsx_initial_extent(
  cells : XlsxSheetCells,
  geometry : XlsxSheetGeometry,
  extra : Array[(Int32, Int32)],
) -> (Int32, Int32) {
  let mut max_row = -1
  let mut max_column = -1
  for row in cells.rows {
    for cell in row.cells {
      if cell.kind != 0 || cell.style != 0 {
        max_row = Int32::max(max_row, row.index)
        max_column = Int32::max(max_column, cell.column)
      }
    }
    if row.height >= 0.0 || row.style >= 0 {
      max_row = Int32::max(max_row, row.index)
    }
  }
  let mut room = 4194304L
  for range in geometry.merges {
    let last_row = Int64::min(range.row_end, 1048575L)
    let last_column = Int32::min(range.column_end, 16383)
    if last_row >= range.row_start && last_column >= range.column_start {
      let n = (last_row - range.row_start + 1L) *
        (last_column - range.column_start + 1).to_int64()
      if n > 0L && n <= room {
        room -= n
        max_row = Int32::max(max_row, last_row.to_int())
        max_column = Int32::max(max_column, last_column)
      }
    }
  }
  for (row, column) in extra {
    max_row = Int32::max(max_row, row)
    max_column = Int32::max(max_column, column)
  }
  let mut rows = Int32::min(
    Int32::max(Int32::min(max_row, 1048576) + 6, 30),
    1048576,
  )
  let mut columns = Int32::min(
    Int32::max(Int32::min(max_column, 16384) + 3, 12),
    16384,
  )
  if geometry.frozen_rows > 0 {
    rows = Int32::min(
      Int32::max(rows, Int32::min(geometry.frozen_rows, 1048576) + 5),
      1048576,
    )
  }
  if geometry.frozen_columns > 0 {
    columns = Int32::min(
      Int32::max(columns, Int32::min(geometry.frozen_columns, 16384) + 2),
      16384,
    )
  }
  (rows, columns)
}

///|
fn xlsx_col_width_points(width : Double, mdw : Double) -> Double {
  Double::max(
    ((256.0 * width + (128.0 / mdw).trunc()) / 256.0 * mdw).trunc(),
    0.0,
  ) *
  0.75
}

///|
/// Build column-size runs, applying the last column definition over overlaps.
pub fn xlsx_column_runs(
  geometry : XlsxSheetGeometry,
  count : Int32,
  mdw : Double,
) -> Array[XlsxSizeRun] {
  let count = Int32::min(Int32::max(count, 0), 16384)
  let default = if geometry.default_column_width > 0.0 {
    xlsx_col_width_points(geometry.default_column_width, mdw)
  } else {
    ((geometry.base_column_width * mdw + 5.0) / 8.0).ceil() * 8.0 * 0.75
  }
  let sizes = Array::make(count, default)
  let next = Array::makei(count + 1, i => i)
  let mut index = geometry.columns.length() - 1
  while index >= 0 {
    let col = geometry.columns[index]
    if col.first >= 0 && col.first < count {
      let mut cursor = col.first
      while next[cursor] != cursor {
        next[cursor] = next[next[cursor]]
        cursor = next[cursor]
      }
      while cursor < count && cursor <= col.last {
        sizes[cursor] = if col.hidden {
          0.0
        } else if col.width >= 0.0 {
          xlsx_col_width_points(col.width, mdw)
        } else {
          default
        }
        next[cursor] = cursor + 1
        cursor += 1
        while next[cursor] != cursor {
          next[cursor] = next[next[cursor]]
          cursor = next[cursor]
        }
      }
    }
    index -= 1
  }
  let runs : Array[XlsxSizeRun] = []
  for size in sizes {
    let size = Float::from_double(size)
    let last = runs.length() - 1
    if last >= 0 && runs[last].size == size {
      runs[last] = { count: runs[last].count + 1, size, }
    } else {
      runs.push({ count: 1, size, })
    }
  }
  runs
}

///|
/// Build row-size runs; `fitted` supplies measured automatic text heights.
/// Rows must be sorted and deduplicated, as returned by `sorted_rows`.
pub fn xlsx_row_runs(
  cells : Array[XlsxRow],
  geometry : XlsxSheetGeometry,
  count : Int32,
  default_line_height : Double,
  fitted : Map[Int32, Double],
) -> Array[XlsxSizeRun] {
  let count = Int32::min(Int32::max(count, 0), 1048576)
  let default_row = if geometry.default_row_height <= 0.0 {
    ((default_line_height / 0.75 - 0.05).ceil() + 2.0) * 0.75
  } else {
    geometry.default_row_height
  }
  let visible_default = if geometry.zero_height { 0.0 } else { default_row }
  let runs : Array[XlsxSizeRun] = []
  let add = fn(count : Int32, height : Double) {
    if count <= 0 {
      return
    }
    let height = Float::from_double(height)
    let last = runs.length() - 1
    if last >= 0 && runs[last].size == height {
      runs[last] = { count: runs[last].count + count, size: height, }
    } else {
      runs.push({ count, size: height, })
    }
  }
  let mut cursor = 0
  for row in cells {
    if row.index >= count {
      break
    }
    if row.index < cursor {
      continue
    }
    add(row.index - cursor, visible_default)
    let height = if row.hidden {
      0.0
    } else if row.height >= 0.0 {
      row.height
    } else {
      Double::min(
        Double::max(default_row, fitted.get(row.index).unwrap_or(0.0)),
        409.5,
      )
    }
    add(1, height)
    cursor = row.index + 1
  }
  add(count - cursor, visible_default)
  runs
}
