///|
// A single numeric rule can apply a supported differential font. Other
// matching rules are rejected until their styles and priority can be drawn.
fn XlsxWorkbook::xlsx_apply_plain_conditionals(
  self : XlsxWorkbook,
  part : String,
  rows : Array[XlsxRow],
  styles : XlsxStyles,
  geometry : XlsxSheetGeometry,
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
  let mut threshold_end = 0.0
  let mut reference1 = ""
  let mut reference2 = ""
  let mut moving_reference = false
  let mut any_moving_reference = false
  let blank_positions : Map[Int32, Map[Int32, Bool]] = Map([])
  let mut ranges : Array[XlsxRange] = []
  let mut room = 4194304L
  let mut conditional_count = 0
  let mut dxf_id = -1
  let mut operator = ""
  let mut rule_type = ""
  let mut blank_matches = false
  let mut any_blank_matches = false
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
          rule_type = xlsx_attr(element, "type", "")
          if rule_count != 1 ||
            ![
              "cellIs", "containsBlanks", "notContainsBlanks", "containsErrors",
              "notContainsErrors",
            ].contains(rule_type) ||
            (
              rule_type == "cellIs" &&
              ![
                "greaterThan", "greaterThanOrEqual", "lessThan", "lessThanOrEqual",
                "equal", "notEqual", "between", "notBetween",
              ].contains(xlsx_attr(element, "operator", "equal"))
            ) {
            xlsx_reject_conditional()
          }
          rule_depth = depth + 1
          dxf_id = xlsx_attr_int(element, "dxfId", -1)
          operator = xlsx_attr(element, "operator", "equal")
          formula_count = 0
          reference1 = ""
          reference2 = ""
          moving_reference = false
        } else if depth == rule_depth {
          if name != "formula" || event.kind is Empty(_) {
            xlsx_reject_conditional()
          }
          formula_count += 1
          if formula_count > 2 {
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
          if rule_type == "cellIs" {
            let text = xlsx_trim(formula.to_string())
            let text = if text.has_prefix("=") {
              xlsx_trim(text[1:].to_owned())
            } else {
              text
            }
            let data = @utf8.encode(text)
            let reference_start = if data.length() > 0 && data[0] == b'-' {
              1
            } else {
              0
            }
            let reference = data.length() > reference_start &&
              (
                data[reference_start] == b'$' ||
                (data[reference_start] >= b'A' && data[reference_start] <= b'Z') ||
                (data[reference_start] >= b'a' && data[reference_start] <= b'z')
              )
            let mut fixed_row = true
            let mut fixed_column = true
            for range in ranges {
              fixed_row = fixed_row &&
                range.row_start == ranges[0].row_start &&
                range.row_end == ranges[0].row_start
              fixed_column = fixed_column &&
                range.column_start == ranges[0].column_start &&
                range.column_end == ranges[0].column_start
            }
            let value = if reference {
              let fixed = xlsx_conditional_reference_value(
                text, rows, fixed_row, fixed_column,
              )
              if fixed is None {
                moving_reference = true
                any_moving_reference = true
              }
              if formula_count == 1 {
                reference1 = text
              } else {
                reference2 = text
              }
              match xlsx_conditional_reference_value(text, rows, true, true) {
                Some(value) => value
                None => {
                  xlsx_reject_conditional()
                  0.0
                }
              }
            } else {
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
              @string.parse_double(text) catch {
                _ =>
                  raise InvalidXlsxInput(
                    "xlsx: plain conversion does not support conditional formatting",
                  )
              }
            }
            if value.is_nan() || value.is_inf() {
              xlsx_reject_conditional()
            }
            if formula_count == 1 {
              threshold = value
            } else {
              threshold_end = value
            }
          }
          formula_depth = -1
        }
        if depth + 1 == rule_depth {
          let expected = if operator == "between" || operator == "notBetween" {
            2
          } else {
            1
          }
          if rule_type == "cellIs" && formula_count != expected {
            xlsx_reject_conditional()
          }
          blank_matches = if rule_type == "cellIs" {
            !moving_reference &&
            xlsx_plain_conditional_matches(
              0.0, threshold, threshold_end, operator,
            )
          } else {
            rule_type == "containsBlanks" || rule_type == "notContainsErrors"
          }
          any_blank_matches = blank_matches || any_blank_matches
          rule_depth = -1
        }
        if depth + 1 == conditional_depth {
          if rule_count != 1 {
            xlsx_reject_conditional()
          }
          if moving_reference {
            if conditional_count != 1 {
              xlsx_reject_conditional()
            }
            xlsx_match_moving_conditionals(
              rows, ranges, row_count, col_count, reference1, reference2, threshold,
              threshold_end, operator, matched, blank_positions,
            )
            any_blank_matches = !blank_positions.is_empty()
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
            if moving_reference {
              continue
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
                if cell.kind == 1 && cell.number.is_nan() {
                  xlsx_reject_conditional()
                }
                let matches = if rule_type != "cellIs" {
                  let blank = cell.kind == 2 && xlsx_trim(cell.text) == ""
                  match rule_type {
                    "containsBlanks" => blank
                    "notContainsBlanks" => !blank
                    "containsErrors" => cell.kind == 4
                    "notContainsErrors" => cell.kind != 4
                    _ => false
                  }
                } else if cell.kind == 1 {
                  xlsx_plain_conditional_matches(
                    cell.number,
                    threshold,
                    threshold_end,
                    operator,
                  )
                } else if cell.kind == 2 || cell.kind == 3 || cell.kind == 4 {
                  [
                    "greaterThan", "greaterThanOrEqual", "notEqual", "notBetween",
                  ].contains(operator)
                } else {
                  xlsx_reject_conditional()
                  false
                }
                if matches {
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
  if any_moving_reference && conditional_count != 1 {
    xlsx_reject_conditional()
  }
  if matched.is_empty() && !any_blank_matches {
    return rows
  }
  if conditional_count != 1 || dxf_id < 0 {
    xlsx_reject_conditional()
  }
  let style = self.xlsx_conditional_style(dxf_id)
  let rows = if any_blank_matches &&
    (style.fill is Some(_) || style.border is Some(_)) {
    if 4194304L - room > 200000L {
      xlsx_reject_conditional()
    }
    xlsx_materialize_conditional_blanks(
      rows,
      geometry,
      styles.cell_formats.length(),
      ranges,
      row_count,
      col_count,
      matched,
      if moving_reference {
        Some(blank_positions)
      } else {
        None
      },
    )
  } else {
    rows
  }
  xlsx_apply_conditional_style(rows, styles, matched, style)
}

///|
fn xlsx_conditional_reference_value(
  text : String,
  rows : Array[XlsxRow],
  fixed_row : Bool,
  fixed_column : Bool,
) -> Double? {
  let original = text
  let text = if text.has_prefix("-") { text[1:].to_owned() } else { text }
  let data = @utf8.encode(text)
  if data.length() < 2 {
    return None
  }
  let col_absolute = data[0] == b'$'
  let mut i = if col_absolute { 1 } else { 0 }
  let column_start = i
  while i < data.length() &&
        (
          (data[i] >= b'A' && data[i] <= b'Z') ||
          (data[i] >= b'a' && data[i] <= b'z')
        ) {
    i += 1
  }
  if i == column_start || i >= data.length() {
    return None
  }
  let row_absolute = data[i] == b'$'
  if row_absolute {
    i += 1
  }
  if (!col_absolute && !fixed_column) || (!row_absolute && !fixed_row) {
    return None
  }
  let start = i
  while i < data.length() && data[i] >= b'0' && data[i] <= b'9' {
    i += 1
  }
  if i == start || i != data.length() {
    return None
  }
  xlsx_conditional_shifted_reference(original, rows, 0, 0)
}

///|
fn xlsx_conditional_shifted_reference(
  text : String,
  rows : Array[XlsxRow],
  row_offset : Int32,
  column_offset : Int32,
) -> Double? {
  let negative = text.has_prefix("-")
  let text = if negative { text[1:].to_owned() } else { text }
  let data = @utf8.encode(text)
  if data.is_empty() {
    return None
  }
  let col_absolute = data[0] == b'$'
  let mut i = if col_absolute { 1 } else { 0 }
  while i < data.length() &&
        (
          (data[i] >= b'A' && data[i] <= b'Z') ||
          (data[i] >= b'a' && data[i] <= b'z')
        ) {
    i += 1
  }
  let row_absolute = i < data.length() && data[i] == b'$'
  let (column, row, valid) = xlsx_parse_ref(text)
  if !valid {
    return None
  }
  let row = row + (if row_absolute { 0 } else { row_offset })
  let column = column + (if col_absolute { 0 } else { column_offset })
  // The formula evaluator used for negation rejects references outside the
  // worksheet, while a plain reference is handled directly as a blank.
  if negative && (row < 0 || row >= 1048576 || column < 0 || column >= 16384) {
    return None
  }
  for candidate in rows {
    if candidate.index != row {
      continue
    }
    for cell in candidate.cells {
      if cell.column == column {
        if cell.kind == 0 {
          return Some(0.0)
        }
        if cell.kind == 1 {
          return Some(if negative { -cell.number } else { cell.number })
        }
        if negative && cell.kind == 3 {
          return Some(-cell.number)
        }
        return None
      }
    }
    return Some(0.0)
  }
  Some(0.0)
}

///|
fn xlsx_plain_conditional_matches(
  value : Double,
  threshold : Double,
  threshold_end : Double,
  operator : String,
) -> Bool {
  match operator {
    "greaterThan" => value > threshold
    "greaterThanOrEqual" => value >= threshold
    "lessThan" => value < threshold
    "lessThanOrEqual" => value <= threshold
    "equal" => value == threshold
    "notEqual" => value != threshold
    "between" =>
      value >= Double::min(threshold, threshold_end) &&
      value <= Double::max(threshold, threshold_end)
    "notBetween" =>
      value < Double::min(threshold, threshold_end) ||
      value > Double::max(threshold, threshold_end)
    _ => false
  }
}

///|
fn xlsx_reject_conditional() -> Unit raise {
  raise InvalidXlsxInput(
    "xlsx: plain conversion does not support conditional formatting",
  )
}
