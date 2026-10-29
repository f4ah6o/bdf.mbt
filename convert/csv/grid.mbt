///|
/// A CSV value prepared for sheet layout, including its numeric alignment.
pub(all) struct GridCell {
  text : String
  number : Bool
} derive(Debug, Eq)

///|
/// The values and header count that the CSV converter passes to sheet layout.
pub(all) struct Grid {
  rows : Array[Array[GridCell]]
  header_rows : Int32
} derive(Debug, Eq)

///|
priv struct DigitStat {
  mut code : Bool
  mut other : Bool
}

///|
fn DigitStat::add(self : DigitStat, value : String) -> Unit {
  let text = csv_trim(value)
  if text == "" {
    return
  }
  if !csv_digits(text) {
    self.other = true
  } else if text.length() > 1 && text.has_prefix("0") {
    self.code = true
  }
}

///|
/// Prepare the parsed records for a sheet, preserving codes with leading
/// zeroes as text throughout a column that contains only digits.
pub fn prepare_grid(parsed : ParseResult) -> Grid {
  let rows : Array[Array[GridCell]] = []
  let first : Array[DigitStat] = []
  let rest : Array[DigitStat] = []
  for index, record in parsed.rows {
    let stats = if index == 0 { first } else { rest }
    while stats.length() < record.length() {
      stats.push({ code: false, other: false, })
    }
    let cells : Array[GridCell] = []
    for column, value in record {
      stats[column].add(value)
      let kind = csv_kind(value)
      cells.push({
        text: value,
        number: value != "" && (kind == 2 || kind == 3),
      })
    }
    rows.push(cells)
  }
  for column, stat in rest {
    let mut code = stat.code
    let mut other = stat.other
    if !parsed.header && column < first.length() {
      code = code || first[column].code
      other = other || first[column].other
    }
    if !code || other {
      continue
    }
    for index, row in rows {
      if column < row.length() && (index > 0 || !parsed.header) {
        row[column] = { ..row[column], number: false, }
      }
    }
  }
  { rows, header_rows: if parsed.header { 1 } else { 0 }, }
}
