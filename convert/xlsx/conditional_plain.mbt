///|
// A single numeric rule can apply a supported differential font. Other
// matching rules are rejected until their styles and priority can be drawn.
fn XlsxWorkbook::xlsx_apply_plain_conditionals(
  self : XlsxWorkbook,
  part : String,
  rows : Array[XlsxRow],
  styles : XlsxStyles,
  row_count : Int32,
  col_count : Int32,
) -> Array[XlsxRow] raise {
  let bytes = self.package.read(part) catch {
    @ooxml.InvalidOoxml(message) => raise InvalidXlsxInput(message)
  }
  let reader = @xml.NamespaceReader::from_string(
    @utf8.decode_lossy(bytes[:], ignore_bom=true),
  )
  let mut depth = 0
  let mut conditional_depth = -1
  let mut rule_depth = -1
  let mut formula_depth = -1
  let mut rule_count = 0
  let mut formula_count = 0
  let mut formula = StringBuilder()
  let mut threshold = 0.0
  let mut ranges : Array[XlsxRange] = []
  let mut room = 4194304L
  let mut conditional_count = 0
  let mut dxf_id = -1
  let mut operator = ""
  let matched : Map[Int32, Map[Int32, Bool]] = Map([])
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        let name = element.name.local_name
        if depth == 1 && name == "conditionalFormatting" {
          if event.kind is Empty(_) {
            xlsx_reject_conditional()
          }
          conditional_depth = depth + 1
          conditional_count += 1
          rule_count = 0
          ranges = []
          let text = StringBuilder()
          for ch in xlsx_attr(element, "sqref", "") {
            if ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n' {
              text.write_char(' ')
            } else {
              text.write_char(ch)
            }
          }
          for item in text.to_string().split(" ") {
            if item == "" {
              continue
            }
            match xlsx_parse_range(item.to_owned()) {
              Some(range) => ranges.push(range)
              None => xlsx_reject_conditional()
            }
          }
          if ranges.is_empty() {
            xlsx_reject_conditional()
          }
        } else if depth == conditional_depth {
          if name != "cfRule" || event.kind is Empty(_) {
            xlsx_reject_conditional()
          }
          rule_count += 1
          if rule_count != 1 ||
            xlsx_attr(element, "type", "") != "cellIs" ||
            ![
              "greaterThan", "greaterThanOrEqual", "lessThan", "lessThanOrEqual",
              "equal", "notEqual",
            ].contains(xlsx_attr(element, "operator", "equal")) {
            xlsx_reject_conditional()
          }
          rule_depth = depth + 1
          dxf_id = xlsx_attr_int(element, "dxfId", -1)
          operator = xlsx_attr(element, "operator", "equal")
          formula_count = 0
        } else if depth == rule_depth {
          if name != "formula" || event.kind is Empty(_) {
            xlsx_reject_conditional()
          }
          formula_count += 1
          if formula_count != 1 {
            xlsx_reject_conditional()
          }
          formula = StringBuilder()
          formula_depth = depth + 1
        } else if depth == formula_depth {
          xlsx_reject_conditional()
        }
        if event.kind is Start(_) {
          depth += 1
        } else if depth == 0 {
          break
        }
      }
      Text(value) | CData(value) =>
        if depth == formula_depth {
          formula.write_string(value)
        }
      End(_) => {
        depth -= 1
        if depth + 1 == formula_depth {
          let text = xlsx_trim(formula.to_string())
          for c in text {
            if !((c >= '0' && c <= '9') ||
              c == '.' ||
              c == '+' ||
              c == '-' ||
              c == 'e' ||
              c == 'E') {
              xlsx_reject_conditional()
            }
          }
          threshold = @string.parse_double(text) catch {
            _ =>
              raise InvalidXlsxInput(
                "xlsx: plain conversion does not support conditional formatting",
              )
          }
          if threshold.is_nan() ||
            threshold.is_inf() ||
            xlsx_plain_conditional_matches(0.0, threshold, operator) {
            xlsx_reject_conditional()
          }
          formula_depth = -1
        }
        if depth + 1 == rule_depth {
          if formula_count != 1 {
            xlsx_reject_conditional()
          }
          rule_depth = -1
        }
        if depth + 1 == conditional_depth {
          if rule_count != 1 {
            xlsx_reject_conditional()
          }
          for range in ranges {
            let last_row = Int64::min(range.row_end, (row_count - 1).to_int64())
            let last_col = Int32::min(range.column_end, col_count - 1)
            if last_row >= range.row_start && last_col >= range.column_start {
              room -= (last_row - range.row_start + 1L) *
                (last_col - range.column_start + 1).to_int64()
              if room < 0L {
                xlsx_reject_conditional()
              }
            }
            for row in rows {
              if row.index.to_int64() < range.row_start ||
                row.index.to_int64() > last_row {
                continue
              }
              for cell in row.cells {
                if cell.column < range.column_start || cell.column > last_col {
                  continue
                }
                if cell.kind == 0 {
                  continue
                }
                if cell.kind != 1 || cell.number.is_nan() {
                  xlsx_reject_conditional()
                }
                if xlsx_plain_conditional_matches(
                    cell.number,
                    threshold,
                    operator,
                  ) {
                  let columns = match matched.get(row.index) {
                    Some(columns) => columns
                    None => {
                      let columns : Map[Int32, Bool] = Map([])
                      matched[row.index] = columns
                      columns
                    }
                  }
                  columns[cell.column] = true
                }
              }
            }
          }
          conditional_depth = -1
        }
        if depth == 0 {
          break
        }
      }
      Eof =>
        if depth == 0 {
          break
        } else {
          raise InvalidXlsxInput("xlsx: unexpected EOF")
        }
      _ => ()
    }
  }
  if matched.is_empty() {
    return rows
  }
  if conditional_count != 1 || dxf_id < 0 {
    xlsx_reject_conditional()
  }
  let font = self.xlsx_conditional_style(dxf_id)
  xlsx_apply_conditional_style(rows, styles, matched, font)
}

///|
fn xlsx_plain_conditional_matches(
  value : Double,
  threshold : Double,
  operator : String,
) -> Bool {
  match operator {
    "greaterThan" => value > threshold
    "greaterThanOrEqual" => value >= threshold
    "lessThan" => value < threshold
    "lessThanOrEqual" => value <= threshold
    "equal" => value == threshold
    "notEqual" => value != threshold
    _ => false
  }
}

///|
fn xlsx_reject_conditional() -> Unit raise {
  raise InvalidXlsxInput(
    "xlsx: plain conversion does not support conditional formatting",
  )
}
