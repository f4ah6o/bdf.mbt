///|
/// One `cfRule type="dataBar"` rule and its target ranges.
priv struct XlsxDataBarRule {
  ranges : Array[XlsxRange]
  stops : Array[XlsxColorScaleStop]
  color : XlsxColor
  min_length : Double
  max_length : Double
}

///|
fn XlsxWorkbook::xlsx_data_bar_rules(
  self : XlsxWorkbook,
  part : String,
) -> Array[XlsxDataBarRule] raise {
  let bytes = self.package.read(part) catch { _ => return [] }
  let text = @utf8.decode_lossy(bytes[:], ignore_bom=true)
  if text.contains("<!ENTITY") {
    return []
  }
  let reader = @xml.NamespaceReader::from_string(text)
  let out : Array[XlsxDataBarRule] = []
  let mut depth = 0
  let mut conditional_depth = -1
  let mut rule_depth = -1
  let mut bar_depth = -1
  let mut sqref = ""
  let mut stops : Array[XlsxColorScaleStop] = []
  let mut color : XlsxColor = xlsx_default_color()
  let mut min_length = 10.0
  let mut max_length = 90.0
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        let name = element.name.local_name
        if depth == 1 && name == "conditionalFormatting" {
          conditional_depth = depth
          sqref = xlsx_attr(element, "sqref", "")
        } else if conditional_depth >= 0 &&
          depth == conditional_depth + 1 &&
          name == "cfRule" &&
          xlsx_attr(element, "type", "") == "dataBar" {
          rule_depth = depth
          stops = []
          color = xlsx_default_color()
          min_length = 10.0
          max_length = 90.0
        } else if rule_depth >= 0 &&
          depth == rule_depth + 1 &&
          name == "dataBar" {
          if event.kind is Start(_) {
            bar_depth = depth
          }
          min_length = (@string.parse_double(xlsx_attr(element, "minLength", "10")) catch { _ => 10.0 })
          max_length = (@string.parse_double(xlsx_attr(element, "maxLength", "90")) catch { _ => 90.0 })
        } else if bar_depth >= 0 && depth == bar_depth + 1 {
          if name == "cfvo" {
            let value = match xlsx_attr(element, "val", "") {
              "" => 0.0
              value => @string.parse_double(value) catch { _ => 0.0 }
            }
            stops.push({ kind: xlsx_attr(element, "type", "min"), value })
          } else if name == "color" {
            color = xlsx_color(element)
          }
        }
        if event.kind is Start(_) {
          depth += 1
        } else if depth == 0 {
          break
        }
      }
      End(_) => {
        if bar_depth >= 0 && depth == bar_depth {
          if stops.length() == 2 {
            let ranges : Array[XlsxRange] = []
            for item in sqref.split(" ") {
              match xlsx_parse_range(item.to_owned()) {
                Some(range) => ranges.push(range)
                None => ()
              }
            }
            if !ranges.is_empty() {
              out.push({ ranges, stops, color, min_length, max_length })
            }
          }
          bar_depth = -1
        } else if rule_depth >= 0 && depth == rule_depth {
          rule_depth = -1
        } else if conditional_depth >= 0 && depth == conditional_depth {
          conditional_depth = -1
        }
        depth -= 1
      }
      Eof => break
      _ => ()
    }
  }
  out
}

///|
fn XlsxWorkbook::xlsx_data_bars(
  self : XlsxWorkbook,
  part : String,
  rows : Array[XlsxRow],
  styles : XlsxStyles,
  theme_colors : Map[Int32, XlsxRgb],
) -> Map[Int32, Map[Int32, @sheet.GridDataBar]] raise {
  let result : Map[Int32, Map[Int32, @sheet.GridDataBar]] = Map([])
  for rule in self.xlsx_data_bar_rules(part) {
    let values : Array[Double] = []
    for range in rule.ranges {
      for row in rows {
        if row.index.to_int64() < range.row_start ||
          row.index.to_int64() > range.row_end {
          continue
        }
        for cell in row.cells {
          if cell.kind == 1 &&
            cell.column >= range.column_start &&
            cell.column <= range.column_end {
            values.push(cell.number)
          }
        }
      }
    }
    if values.is_empty() {
      continue
    }
    let sorted = values.copy()
    sorted.sort()
    let min = sorted[0]
    let max = sorted[sorted.length() - 1]
    if (max - min).abs() < 0.0000001 {
      continue
    }
    let black = xlsx_rgb_from_uint(0x000000U)
    let color = styles.resolve_color(rule.color, black, theme_colors).rgba()
    let min_length = Double::min(100.0, Double::max(0.0, rule.min_length))
    let max_length = Double::min(100.0, Double::max(min_length, rule.max_length))
    for range in rule.ranges {
      for row in rows {
        if row.index.to_int64() < range.row_start ||
          row.index.to_int64() > range.row_end {
          continue
        }
        for cell in row.cells {
          if cell.kind != 1 ||
            cell.column < range.column_start ||
            cell.column > range.column_end {
            continue
          }
          let t = Double::min(1.0, Double::max(0.0, (cell.number - min) / (max - min)))
          let length = min_length + (max_length - min_length) * t
          let columns = match result.get(row.index) {
            Some(value) => value
            None => {
              let value : Map[Int32, @sheet.GridDataBar] = Map([])
              result[row.index] = value
              value
            }
          }
          columns[cell.column] = { fraction: length / 100.0, color }
        }
      }
    }
  }
  result
}