///|
/// Find the bounding rectangle of nonblank values in sorted worksheet rows.
pub fn xlsx_used_range(rows : Array[XlsxRow]) -> XlsxRange? {
  let mut first_row = -1
  let mut last_row = -1
  let mut first_column = 16384
  let mut last_column = -1
  for row in rows {
    for cell in row.cells {
      if cell.kind != 0 {
        if first_row < 0 {
          first_row = row.index
        }
        last_row = row.index
        first_column = Int32::min(first_column, cell.column)
        last_column = Int32::max(last_column, cell.column)
      }
    }
  }
  if first_row < 0 {
    None
  } else {
    Some({
      row_start: first_row.to_int64(),
      row_end: last_row.to_int64(),
      column_start: first_column,
      column_end: last_column,
    })
  }
}

///|
fn XlsxStyles::cached_number_sections(
  self : XlsxStyles,
  style : Int32,
  locale : String,
  cache : Map[Int32, Array[XlsxFormatSection]],
) -> Array[XlsxFormatSection] {
  let index = if style < 0 || style >= self.cell_formats.length() {
    0
  } else {
    style
  }
  let id = if self.cell_formats.is_empty() {
    0
  } else {
    self.cell_formats[index].number_format
  }
  match cache.get(id) {
    Some(sections) => sections
    None => {
      let sections = xlsx_parse_number_format(
        self.number_format(id, locale),
        self.palette,
      )
      cache[id] = sections
      sections
    }
  }
}

///|
fn xlsx_cell_kind(
  styles : XlsxStyles,
  cell : XlsxCell,
  locale : String,
  cache : Map[Int32, Array[XlsxFormatSection]],
) -> Int32 {
  match cell.kind {
    1 => {
      let sections = styles.cached_number_sections(cell.style, locale, cache)
      if sections[0].date {
        let mut has_time = false
        for token in sections[0].tokens {
          if token.kind == 11 ||
            token.kind == 13 ||
            (
              token.kind == 10 &&
              (
                token.text.has_prefix("h") ||
                token.text.has_prefix("s") ||
                token.text.has_prefix("a")
              )
            ) {
            has_time = true
          }
        }
        if has_time || cell.number != cell.number.trunc() {
          5
        } else {
          4
        }
      } else if cell.number == cell.number.trunc() &&
        cell.number.abs() < 9007199254740992.0 {
        1
      } else {
        2
      }
    }
    2 => 3
    3 => 6
    _ => 0
  }
}

///|
fn xlsx_table_time(value : Double, date1904 : Bool) -> (Int64, Int64)? {
  if value.is_nan() || value < 0.0 || value > 2958465.99999999 {
    return None
  }
  let mut days = value.floor().to_int64()
  let mut millis = ((value - days.to_double()) * 86400000.0).round().to_int64()
  if millis >= 86400000L {
    days += 1L
    millis -= 86400000L
  }
  let unix_day = if date1904 {
    xlsx_days(1904, 1, 1) + days
  } else if days == 60L {
    xlsx_days(1900, 2, 28)
  } else if days < 60L {
    xlsx_days(1899, 12, 31) + days
  } else {
    xlsx_days(1899, 12, 30) + days
  }
  Some((unix_day, unix_day * 86400000L + millis))
}

///|
/// Build the typed values of a worksheet range for BDF's Parquet tables.
/// Rows must be sorted and deduplicated using `sorted_rows`.
pub fn XlsxStyles::values_table(
  self : XlsxStyles,
  rows : Array[XlsxRow],
  range : XlsxRange,
  names : Array[String],
  date1904 : Bool,
  locale : String,
) -> @parquet.Table raise {
  let row_count = range.row_end - range.row_start + 1L
  let col_count = range.column_end.to_int64() -
    range.column_start.to_int64() +
    1L
  if row_count < 1L ||
    row_count > 67108864L ||
    col_count < 1L ||
    col_count > 16384L ||
    row_count * col_count > 67108864L ||
    range.column_start < 0 {
    raise InvalidXlsxInput("xlsx: invalid table range")
  }
  let nrows = row_count.to_int()
  let ncols = col_count.to_int()
  let types = Array::make(ncols, 0)
  let cache : Map[Int32, Array[XlsxFormatSection]] = Map([])
  for row in rows {
    if row.index.to_int64() < range.row_start ||
      row.index.to_int64() > range.row_end {
      continue
    }
    for cell in row.cells {
      if cell.column < range.column_start || cell.column > range.column_end {
        continue
      }
      let kind = xlsx_cell_kind(self, cell, locale, cache)
      if kind == 0 {
        continue
      }
      let j = cell.column - range.column_start
      let previous = types[j]
      types[j] = if previous == 0 || previous == kind {
        kind
      } else if (previous == 1 && kind == 2) || (previous == 2 && kind == 1) {
        2
      } else if (previous == 4 && kind == 5) || (previous == 5 && kind == 4) {
        5
      } else {
        3
      }
    }
  }
  let columns : Array[@parquet.Column] = []
  for j in 0..<ncols {
    let name = if j < names.length() && names[j] != "" {
      names[j]
    } else {
      xlsx_col_name(range.column_start + j)
    }
    let kind = match types[j] {
      1 => @parquet.IntegerColumn
      2 => @parquet.NumberColumn
      4 => @parquet.DateColumn
      5 => @parquet.DateTimeColumn
      6 => @parquet.BooleanColumn
      _ => @parquet.StringColumn
    }
    columns.push({ name, kind, })
  }
  let out : Array[Array[@parquet.Value]] = Array::makei(nrows, _ => {
    Array::make(ncols, @parquet.Null)
  })
  for row in rows {
    let i = row.index.to_int64() - range.row_start
    if i < 0L || i >= row_count {
      continue
    }
    for cell in row.cells {
      if cell.column < range.column_start || cell.column > range.column_end {
        continue
      }
      let j = cell.column - range.column_start
      let value = match cell.kind {
        1 =>
          match types[j] {
            1 => @parquet.IntegerValue(cell.number.to_int64())
            2 => @parquet.NumberValue(cell.number)
            4 | 5 =>
              match xlsx_table_time(cell.number, date1904) {
                None => @parquet.Null
                Some((day, ms)) =>
                  if types[j] == 4 {
                    @parquet.DateValue(day)
                  } else {
                    @parquet.DateTimeValue(ms)
                  }
              }
            _ =>
              @parquet.StringValue(
                xlsx_format_number(
                  self.cached_number_sections(cell.style, locale, cache),
                  cell.number,
                  date1904,
                ).text(),
              )
          }
        2 => @parquet.StringValue(cell.text)
        3 =>
          if types[j] == 6 {
            @parquet.BooleanValue(cell.number != 0.0)
          } else {
            @parquet.StringValue(
              if cell.number != 0.0 {
                "TRUE"
              } else {
                "FALSE"
              },
            )
          }
        _ => @parquet.Null
      }
      out[i.to_int()][j] = value
    }
  }
  { columns, rows: out, }
}
