///|
// Conditional ranges can each apply a differential style. Different styles
// remain unsupported when their matching cells overlap.
priv struct XlsxConditionalBlock {
  ranges : Array[XlsxRange]
  matched : Map[Int32, Map[Int32, Bool]]
  blank_positions : Map[Int32, Map[Int32, Bool]]
  blank_matches : Bool
  moving_reference : Bool
  dxf_id : Int32
  stop_if_true : Bool
  priority : Int32
  priority_known : Bool
  covered : Int64
}

///|
fn XlsxWorkbook::xlsx_conditional_dxf_count(self : XlsxWorkbook) -> Int32 raise {
  let rel = match self.package.relationship_of_type(self.part, "/styles") {
    Some(value) => value
    None => return 0
  }
  let bytes = self.package.read(rel.target) catch { _ => return 0 }
  let text = @utf8.decode_lossy(bytes[:], ignore_bom=true)
  if text.contains("<!ENTITY") {
    return -1
  }
  let reader = @xml.NamespaceReader::from_string(text)
  let mut depth = 0
  let mut dxfs_depth = -1
  let mut count = 0
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        let name = element.name.local_name
        if depth == 1 && name == "dxfs" {
          if event.kind is Empty(_) {
            return 0
          }
          dxfs_depth = depth + 1
        } else if depth == dxfs_depth && name == "dxf" {
          count += 1
        }
        if event.kind is Start(_) {
          depth += 1
        } else if depth == 0 {
          break
        }
      }
      End(_) => {
        depth -= 1
        if depth + 1 == dxfs_depth {
          return count
        }
        if depth == 0 {
          break
        }
      }
      Eof => if depth == 0 { break } else { return -1 }
      _ => ()
    }
  }
  count
}

///|
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
  let mut literal1 : String? = None
  let mut literal2 : String? = None
  let mut invalid1 = false
  let mut invalid2 = false
  let mut moving_reference = false
  let mut blank_positions : Map[Int32, Map[Int32, Bool]] = Map([])
  let mut ranges : Array[XlsxRange] = []
  let mut room = 4194304L
  let mut block_room = room
  let blocks : Array[XlsxConditionalBlock] = []
  let mut dxf_id = -1
  let mut stop_if_true = false
  let mut priority = 1073741824
  let mut priority_known = true
  let mut operator = ""
  let mut rule_type = ""
  let mut rule_text = ""
  let mut top_rank = 10
  let mut top_percent = false
  let mut top_bottom = false
  let mut top_threshold : Double? = None
  let mut average_above = true
  let mut average_equal = false
  let mut average_stddev = 0.0
  let mut average_threshold : Double? = None
  let mut duplicate_counts : Map[String, Int32] = Map([])
  let mut blank_matches = false
  let mut any_blank_matches = false
  let mut matched : Map[Int32, Map[Int32, Bool]] = Map([])
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
          block_room = room
          matched = Map([])
          blank_positions = Map([])
          any_blank_matches = false
          rule_type = xlsx_attr(element, "type", "")
          if ![
              "cellIs", "containsBlanks", "notContainsBlanks", "containsErrors",
              "notContainsErrors", "containsText", "notContainsText", "beginsWith",
              "endsWith", "top10", "aboveAverage", "duplicateValues", "uniqueValues",
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
          rule_text = xlsx_go_lower(xlsx_attr(element, "text", ""))
          if rule_type == "top10" {
            top_rank = xlsx_conditional_rank(xlsx_attr(element, "rank", ""))
            top_percent = xlsx_attr_bool(element, "percent")
            top_bottom = xlsx_attr_bool(element, "bottom")
          }
          if rule_type == "aboveAverage" {
            average_above = !["0", "false", "off"].contains(
              xlsx_trim(xlsx_attr(element, "aboveAverage", "")),
            )
            average_equal = xlsx_attr_bool(element, "equalAverage")
            average_stddev = xlsx_conditional_stddev(
              xlsx_attr(element, "stdDev", ""),
            )
          }
          rule_depth = depth + 1
          let raw_dxf = xlsx_trim(xlsx_attr(element, "dxfId", "")).to_lower()
          if raw_dxf.contains("_") ||
            raw_dxf.has_prefix("0x") ||
            raw_dxf.has_prefix("+0x") ||
            raw_dxf.has_prefix("-0x") {
            xlsx_reject_conditional()
          }
          dxf_id = xlsx_node_int(element, "dxfId", -1)
          stop_if_true = xlsx_attr_bool(element, "stopIfTrue")
          let raw_priority = xlsx_trim(xlsx_attr(element, "priority", ""))
          priority_known = true
          if raw_priority != "" {
            let lower_priority = raw_priority.to_lower()
            if lower_priority.contains("_") ||
              lower_priority.has_prefix("0x") ||
              lower_priority.has_prefix("+0x") ||
              lower_priority.has_prefix("-0x") {
              priority_known = false
            } else {
              match xlsx_int(raw_priority) {
                Some(n) =>
                  if n < -2147483648L || n > 2147483647L {
                    priority_known = false
                  }
                None => {
                  let value = @string.parse_double(raw_priority) catch {
                    _ => {
                      priority_known = false
                      0.0
                    }
                  }
                  if value.is_nan() ||
                    value.is_inf() ||
                    value < -2147483648.0 ||
                    value > 2147483647.0 {
                    priority_known = false
                  }
                }
              }
            }
          }
          priority = xlsx_node_int(element, "priority", 1073741824)
          operator = xlsx_attr(element, "operator", "equal")
          formula_count = 0
          reference1 = ""
          reference2 = ""
          literal1 = None
          literal2 = None
          invalid1 = false
          invalid2 = false
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
            let literal : String? = if data.length() >= 2 &&
              data[0] == b'"' &&
              data[data.length() - 1] == b'"' {
              Some(
                @utf8.decode_lossy(data[1:data.length() - 1]).replace(
                  old="\"\"",
                  new="\"",
                ),
              )
            } else if text.to_lower() == "true" {
              Some("TRUE")
            } else if text.to_lower() == "false" {
              Some("FALSE")
            } else {
              None
            }
            if literal is Some(_) {
              if formula_count == 1 {
                literal1 = literal
              } else {
                literal2 = literal
              }
            } else {
              let reference_start = if data.length() > 0 && data[0] == b'-' {
                1
              } else {
                0
              }
              let reference = data.length() > reference_start &&
                (
                  data[reference_start] == b'$' ||
                  (
                    data[reference_start] >= b'A' &&
                    data[reference_start] <= b'Z'
                  ) ||
                  (
                    data[reference_start] >= b'a' &&
                    data[reference_start] <= b'z'
                  )
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
                }
                if formula_count == 1 {
                  reference1 = text
                } else {
                  reference2 = text
                }
                match xlsx_conditional_reference_value(text, rows, true, true) {
                  Some(value) => {
                    if formula_count == 1 {
                      literal1 = value.text
                      invalid1 = !value.valid
                    } else {
                      literal2 = value.text
                      invalid2 = !value.valid
                    }
                    value.number
                  }
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
            if moving_reference {
              false
            } else if invalid1 || invalid2 {
              false
            } else if literal1 is Some(_) || literal2 is Some(_) {
              xlsx_conditional_literal_matches(
                0.0,
                None,
                threshold,
                literal1,
                threshold_end,
                literal2,
                operator,
              )
            } else {
              !moving_reference &&
              xlsx_plain_conditional_matches(
                0.0, threshold, threshold_end, operator,
              )
            }
          } else {
            rule_type == "containsBlanks" ||
            rule_type == "notContainsErrors" ||
            xlsx_conditional_text_matches(rule_type, "", rule_text)
          }
          any_blank_matches = blank_matches || any_blank_matches
          if rule_type == "top10" {
            top_threshold = xlsx_conditional_top_threshold(
              rows, ranges, row_count, col_count, top_rank, top_percent, top_bottom,
            )
          }
          if rule_type == "aboveAverage" {
            average_threshold = xlsx_conditional_average_threshold(
              rows, ranges, row_count, col_count, average_stddev, average_above,
            )
          }
          if rule_type == "duplicateValues" || rule_type == "uniqueValues" {
            duplicate_counts = xlsx_conditional_duplicate_counts(
              rows, ranges, row_count, col_count,
            )
          }
          if moving_reference {
            xlsx_match_moving_conditionals(
              rows, ranges, row_count, col_count, reference1, reference2, threshold,
              threshold_end, literal1, literal2, operator, matched, blank_positions,
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
            if moving_reference || invalid1 || invalid2 {
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
                if cell.kind == 1 &&
                  cell.number.is_nan() &&
                  rule_type != "aboveAverage" {
                  xlsx_reject_conditional()
                }
                let matches = if rule_type != "cellIs" {
                  let blank = cell.kind == 2 && xlsx_trim(cell.text) == ""
                  match rule_type {
                    "containsBlanks" => blank
                    "notContainsBlanks" => !blank
                    "containsErrors" => cell.kind == 4
                    "notContainsErrors" => cell.kind != 4
                    "duplicateValues" | "uniqueValues" =>
                      match xlsx_conditional_duplicate_key(cell) {
                        Some(key) =>
                          (duplicate_counts.get(key).unwrap_or(0) > 1) ==
                          (rule_type == "duplicateValues")
                        None => false
                      }
                    "aboveAverage" =>
                      if cell.kind != 1 {
                        false
                      } else {
                        match average_threshold {
                          Some(threshold) =>
                            if average_above {
                              if average_equal {
                                cell.number >= threshold
                              } else {
                                cell.number > threshold
                              }
                            } else if average_equal {
                              cell.number <= threshold
                            } else {
                              cell.number < threshold
                            }
                          None => false
                        }
                      }
                    "top10" =>
                      if cell.kind != 1 {
                        false
                      } else {
                        match top_threshold {
                          Some(threshold) =>
                            if top_bottom {
                              cell.number <= threshold
                            } else {
                              cell.number >= threshold
                            }
                          None => false
                        }
                      }
                    "containsText"
                    | "notContainsText"
                    | "beginsWith"
                    | "endsWith" => {
                      let value = if cell.kind == 1 {
                        xlsx_format_general(cell.number, 15)
                      } else if cell.kind == 3 {
                        if cell.number != 0.0 {
                          "TRUE"
                        } else {
                          "FALSE"
                        }
                      } else {
                        cell.text
                      }
                      xlsx_conditional_text_matches(rule_type, value, rule_text)
                    }
                    _ => false
                  }
                } else if literal1 is Some(_) || literal2 is Some(_) {
                  let cell_text : String? = if cell.kind == 1 {
                    None
                  } else if cell.kind == 3 {
                    Some(if cell.number != 0.0 { "TRUE" } else { "FALSE" })
                  } else if cell.kind == 2 || cell.kind == 4 {
                    Some(cell.text)
                  } else {
                    xlsx_reject_conditional()
                    None
                  }
                  xlsx_conditional_literal_matches(
                    cell.number,
                    cell_text,
                    threshold,
                    literal1,
                    threshold_end,
                    literal2,
                    operator,
                  )
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
          if !matched.is_empty() || any_blank_matches {
            blocks.push({
              ranges,
              matched,
              blank_positions,
              blank_matches: any_blank_matches,
              moving_reference,
              dxf_id,
              stop_if_true,
              priority,
              priority_known,
              covered: block_room - room,
            })
          }
          rule_depth = -1
        }
        if depth + 1 == conditional_depth {
          if rule_count == 0 {
            xlsx_reject_conditional()
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
  let dxf_count = self.xlsx_conditional_dxf_count() catch { _ => -1 }
  let has_missing_stop = blocks.any(block => {
    block.stop_if_true &&
    (block.dxf_id < 0 || (dxf_count >= 0 && block.dxf_id >= dxf_count))
  })
  let ordered = [ for i, block in blocks => (i, block) ]
  if has_missing_stop {
    for entry in ordered {
      if !entry.1.priority_known {
        xlsx_reject_conditional()
      }
    }
    ordered.sort_by((a, b) => {
      if a.1.priority == b.1.priority {
        a.0.compare(b.0)
      } else {
        a.1.priority.compare(b.1.priority)
      }
    })
  }
  let relevant : Array[XlsxConditionalBlock] = []
  let stopped : Map[Int32, Map[Int32, Bool]] = Map([])
  let stopped_blank_ranges : Array[XlsxRange] = []
  let mut stop_comparisons = 4194304
  for entry in ordered {
    let block = entry.1
    let missing = block.dxf_id < 0 ||
      (dxf_count >= 0 && block.dxf_id >= dxf_count)
    if missing {
      if block.stop_if_true {
        if block.blank_matches {
          if block.moving_reference {
            for row, columns in block.blank_positions {
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
          } else {
            for range in block.ranges {
              stopped_blank_ranges.push(range)
            }
          }
        }
        for row, columns in block.matched {
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
      }
      continue
    }
    let paints_blanks = if block.blank_matches {
      let style = self.xlsx_conditional_style(block.dxf_id)
      style.fill is Some(_) || style.border is Some(_)
    } else {
      false
    }
    if paints_blanks {
      for range in block.ranges {
        for stopped_range in stopped_blank_ranges {
          stop_comparisons -= 1
          if stop_comparisons < 0 {
            xlsx_reject_conditional()
          }
          if range.row_start <= stopped_range.row_end &&
            stopped_range.row_start <= range.row_end &&
            range.column_start <= stopped_range.column_end &&
            stopped_range.column_start <= range.column_end {
            xlsx_reject_conditional()
          }
        }
        for row, columns in stopped {
          stop_comparisons -= 1
          if stop_comparisons < 0 {
            xlsx_reject_conditional()
          }
          if row.to_int64() >= range.row_start &&
            row.to_int64() <= range.row_end {
            for column, _ in columns {
              stop_comparisons -= 1
              if stop_comparisons < 0 ||
                (column >= range.column_start && column <= range.column_end) {
                xlsx_reject_conditional()
              }
            }
          }
        }
      }
    }
    if stopped.is_empty() {
      relevant.push(block)
      continue
    }
    let matched : Map[Int32, Map[Int32, Bool]] = Map([])
    for row, columns in block.matched {
      for column, _ in columns {
        let blocked = match stopped.get(row) {
          Some(value) => value.contains(column)
          None => false
        }
        if !blocked {
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
    if !matched.is_empty() || block.blank_matches {
      relevant.push({ ..block, matched, })
    }
  }
  // Bound pairwise range checks independently of the covered-cell budget.
  let mut comparisons = 4194304
  for i in 0..<relevant.length() {
    for j in 0..<i {
      let mut ranges_overlap = false
      for a in relevant[i].ranges {
        for b in relevant[j].ranges {
          comparisons -= 1
          if comparisons < 0 {
            xlsx_reject_conditional()
          }
          if a.row_start <= b.row_end &&
            b.row_start <= a.row_end &&
            a.column_start <= b.column_end &&
            b.column_start <= a.column_end {
            ranges_overlap = true
          }
        }
      }
      if ranges_overlap && relevant[i].dxf_id != relevant[j].dxf_id {
        if relevant[i].blank_matches || relevant[j].blank_matches {
          xlsx_reject_conditional()
        }
        for row, columns in relevant[i].matched {
          comparisons -= 1
          if comparisons < 0 {
            xlsx_reject_conditional()
          }
          if relevant[j].matched.get(row) is Some(other) {
            for column, _ in columns {
              comparisons -= 1
              if comparisons < 0 || other.contains(column) {
                xlsx_reject_conditional()
              }
            }
          }
        }
      }
    }
  }
  let mut result = rows
  for block in relevant {
    if block.dxf_id < 0 || (dxf_count >= 0 && block.dxf_id >= dxf_count) {
      continue
    }
    let style = self.xlsx_conditional_style(block.dxf_id)
    if block.blank_matches && (style.fill is Some(_) || style.border is Some(_)) {
      if block.covered > 200000L {
        xlsx_reject_conditional()
      }
      result = xlsx_materialize_conditional_blanks(
        result,
        geometry,
        styles.cell_formats.length(),
        block.ranges,
        row_count,
        col_count,
        block.matched,
        if block.moving_reference {
          Some(block.blank_positions)
        } else {
          None
        },
      )
    }
    result = xlsx_apply_conditional_style(result, styles, block.matched, style)
  }
  result
}

///|
fn xlsx_conditional_reference_value(
  text : String,
  rows : Array[XlsxRow],
  fixed_row : Bool,
  fixed_column : Bool,
) -> XlsxConditionalValue? {
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
) -> XlsxConditionalValue? {
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
    return Some({ number: 0.0, text: None, valid: false, })
  }
  for candidate in rows {
    if candidate.index != row {
      continue
    }
    for cell in candidate.cells {
      if cell.column != column {
        continue
      }
      if cell.kind == 0 {
        return Some({ number: 0.0, text: None, valid: true, })
      }
      if cell.kind == 1 {
        return Some({
          number: if negative {
            -cell.number
          } else {
            cell.number
          },
          text: None,
          valid: true,
        })
      }
      if negative && cell.kind == 3 {
        return Some({ number: -cell.number, text: None, valid: true, })
      }
      if negative && cell.kind == 2 {
        let source = xlsx_trim(cell.text)
        // Go also accepts hexadecimal floats, which MoonBit does not parse.
        let lower = source.to_lower()
        if lower.has_prefix("0x") ||
          lower.has_prefix("+0x") ||
          lower.has_prefix("-0x") {
          return None
        }
        let value = @string.parse_double(source) catch {
          _ => return Some({ number: 0.0, text: None, valid: false, })
        }
        if value.is_nan() || value.is_inf() {
          return None
        }
        return Some({ number: -value, text: None, valid: true, })
      }
      if negative {
        if cell.kind == 4 {
          return Some({ number: 0.0, text: None, valid: false, })
        }
        return None
      }
      if cell.kind == 3 {
        return Some({
          number: 0.0,
          text: Some(if cell.number != 0.0 { "TRUE" } else { "FALSE" }),
          valid: true,
        })
      }
      if cell.kind == 2 || cell.kind == 4 {
        return Some({ number: 0.0, text: Some(cell.text), valid: true, })
      }
      return None
    }
    return Some({ number: 0.0, text: None, valid: true, })
  }
  Some({ number: 0.0, text: None, valid: true, })
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
