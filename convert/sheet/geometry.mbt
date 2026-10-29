///|
/// Consecutive sheet rows or columns with the same size.
pub(all) struct Run {
  count : Int32
  size : Float
} derive(Debug, Eq)

///|
/// The dimensions and frozen pane of a sheet view.
pub(all) struct GridGeometry {
  columns : Array[Run]
  rows : Array[Run]
  frozen_rows : Int32
} derive(Debug, Eq)

///|
fn append_run(runs : Array[Run], size : Float) -> Unit {
  let last = runs.length() - 1
  if last >= 0 && runs[last].size == size {
    runs[last] = { count: runs[last].count + 1, size, }
  } else {
    runs.push({ count: 1, size, })
  }
}

///|
/// Lay out a grid's row and column runs, including its blank margins and
/// any additional columns reached by overflowing text.
pub fn grid_geometry(
  cells : Array[Array[Cell]],
  header_rows~ : Int32 = 0,
  subheader~ : Bool = false,
  filter_buttons~ : Bool = false,
  mdw~ : Double = 7.0,
  advance~ : (Char, Bool) -> Double = fallback_advance,
  metrics~ : (Char, Bool) -> (Double, Double) = fallback_line_metrics,
  default_line_height~ : Double = (0.9 + 0.25) * 11.0,
  style_line_height~ : ((Bool) -> Double)? = None,
) -> GridGeometry raise {
  let widths = fit_columns(
    cells,
    header_rows~,
    subheader~,
    filter_buttons~,
    mdw~,
    advance~,
  )
  let heights = fit_rows(
    cells,
    widths,
    header_rows~,
    subheader~,
    mdw~,
    advance~,
    metrics~,
    default_line_height~,
    style_line_height~,
  )
  let default_col = ((8.0 * mdw + 5.0) / 8.0).ceil() * 8.0 * 0.75
  let default_row = Float::from_double(
    ((default_line_height / 0.75 - 0.05).ceil() + 2.0) * 0.75,
  )
  let mut last_row = -1
  let mut last_col = -1
  let mut records = 0
  for row in cells {
    if records >= 1048576 {
      break
    }
    for index, cell in row {
      if index >= 16384 {
        break
      }
      if cell.text != "" {
        last_row = records
        if index > last_col {
          last_col = index
        }
      }
    }
    records += 1
  }
  let frozen = if header_rows < 0 {
    0
  } else if header_rows > records {
    records
  } else {
    header_rows
  }
  let nrows = Int32::min(
    1048576,
    Int32::max(30, Int32::max(last_row + 6, frozen + 5)),
  )
  let mut ncols = Int32::min(16384, Int32::max(12, last_col + 3))
  // Position all possible columns so overflow can extend beyond the initial
  // visible sheet while still stopping at a nonempty cell.
  let positions : Array[Double] = [0.0]
  for i in 0..<16384 {
    let size = if i < widths.length() {
      widths[i].to_double()
    } else {
      default_col
    }
    positions.push(positions[i] + size)
  }
  let initial_cols = ncols
  let mut text_cols = 0
  for row_index, row in cells {
    if row_index >= 1048576 {
      break
    }
    let bold = row_index < header_rows &&
      !(subheader && row_index == header_rows - 1)
    for column, cell in row {
      if column >= 16384 {
        break
      }
      if cell.text == "" ||
        cell.number ||
        cell.text.contains("\n") ||
        cell.text.contains("\r") {
        continue
      }
      let lines = wrap_text(cell.text, 1.0e300, bold~, advance~)
      let right_text = positions[column] + 1.5 + lines[0].width
      let mut edge = positions[column + 1]
      let mut next = column + 1
      while next < 16384 && edge < right_text {
        if next < row.length() && row[next].text != "" {
          break
        }
        edge = positions[next + 1]
        next += 1
      }
      let right = if right_text > edge + 0.01 {
        edge
      } else {
        Double::max(right_text, positions[column + 1])
      }
      if right > positions[initial_cols] {
        let target = right - 0.01
        let mut lo = 0
        let mut hi = 16384
        while lo < hi {
          let mid = lo + (hi - lo) / 2
          if positions[mid + 1] > target {
            hi = mid
          } else {
            lo = mid + 1
          }
        }
        text_cols = Int32::max(text_cols, Int32::min(lo, 16383) + 1)
      }
    }
  }
  ncols = Int32::min(16384, Int32::max(ncols, text_cols + 2))
  let col_runs : Array[Run] = []
  for i in 0..<ncols {
    let size = if i < widths.length() {
      widths[i]
    } else {
      Float::from_double(default_col)
    }
    append_run(col_runs, size)
  }
  let row_runs : Array[Run] = []
  for i in 0..<nrows {
    append_run(
      row_runs,
      if i < heights.length() {
        heights[i]
      } else {
        default_row
      },
    )
  }
  { columns: col_runs, rows: row_runs, frozen_rows: frozen, }
}
