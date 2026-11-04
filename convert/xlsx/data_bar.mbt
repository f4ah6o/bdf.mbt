///|
/// One `cfRule type="dataBar"` rule and its target ranges.
priv struct XlsxDataBarRule {
  ranges : Array[XlsxRange]
  stops : Array[XlsxColorScaleStop]
  color : XlsxColor
  negative_color : XlsxColor?
  min_length : Double
  max_length : Double
  axis_position : Double?
  right_to_left : Bool
  border : Bool
  gradient : Bool
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
  let mut negative_color : XlsxColor? = None
  let mut min_length = 10.0
  let mut max_length = 90.0
  let mut axis_position : Double? = None
  let mut right_to_left = false
  let mut border = false
  let mut gradient = true
  let mut last_stop = -1
  let mut formula_depth = -1
  let formula = StringBuilder()
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
          negative_color = None
          min_length = 10.0
          max_length = 90.0
          axis_position = None
          right_to_left = false
          border = false
          gradient = true
          last_stop = -1
          formula_depth = -1
          formula.reset()
        } else if rule_depth >= 0 &&
          depth == rule_depth + 1 &&
          name == "dataBar" {
          if event.kind is Start(_) {
            bar_depth = depth
          }
          min_length = (@string.parse_double(xlsx_attr(element, "minLength", "10")) catch { _ => 10.0 })
          max_length = (@string.parse_double(xlsx_attr(element, "maxLength", "90")) catch { _ => 90.0 })
          right_to_left = xlsx_attr(element, "direction", "") == "rightToLeft"
          border = ["1", "true"].contains(xlsx_attr(element, "border", ""))
          gradient = !["0", "false", "off"].contains(
            xlsx_attr(element, "gradient", "1"),
          )
          let axis = xlsx_attr(element, "axisPosition", "")
          if axis != "" {
            axis_position = Some(
              @string.parse_double(axis) catch { _ => 0.0 },
            )
          }
        } else if bar_depth >= 0 && depth == bar_depth + 1 {
          if name == "cfvo" {
            let raw = xlsx_attr(element, "val", "")
            let cleaned = if raw.has_prefix("=") {
              raw[1:].to_owned()
            } else {
              raw
            }
            let value = match cleaned {
              "" => 0.0
              value => @string.parse_double(value) catch { _ => 0.0 }
            }
            stops.push({
              kind: xlsx_attr(element, "type", "min"),
              value,
              formula: "",
            })
            last_stop = stops.length() - 1
          } else if name == "color" {
            color = xlsx_color(element)
          } else if name == "negativeBarColor" {
            negative_color = Some(xlsx_color(element))
          }
        } else if last_stop >= 0 &&
          bar_depth >= 0 &&
          depth == bar_depth + 2 &&
          name == "f" &&
          event.kind is Start(_) {
          formula.reset()
          formula_depth = depth + 1
        }
        if event.kind is Start(_) {
          depth += 1
        } else if depth == 0 {
          break
        }
      }
      Text(value) =>
        if formula_depth >= 0 && depth == formula_depth {
          formula.write_string(value)
        }
      End(_) => {
        if formula_depth >= 0 && depth == formula_depth {
          if last_stop >= 0 {
            stops[last_stop].formula = formula.to_string()
          }
          formula_depth = -1
        }
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
              out.push({
                ranges, stops, color, negative_color, min_length, max_length,
                axis_position, right_to_left, border, gradient,
              })
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
fn xlsx_data_bar_threshold(
  stop : XlsxColorScaleStop,
  min : Double,
  max : Double,
  values : Array[Double],
) -> Double {
  match stop.kind {
    "min" => min
    "max" => max
    "num" => stop.value
    "formula" => {
      let raw = if stop.formula.has_prefix("=") {
        stop.formula[1:].to_owned()
      } else {
        stop.formula
      }
      @string.parse_double(raw) catch { _ => stop.value }
    }
    "percent" => min + (max - min) * stop.value / 100.0
    "percentile" => {
      let sorted = values.copy()
      sorted.sort()
      let p = Double::min(1.0, Double::max(0.0, stop.value / 100.0))
      let position = p * (sorted.length() - 1).to_double()
      let lower = position.to_int()
      let fraction = position - lower.to_double()
      let low = sorted[lower]
      let high = if lower + 1 < sorted.length() { sorted[lower + 1] } else { low }
      low + (high - low) * fraction
    }
    _ => min
  }
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
    let actual_min = sorted[0]
    let actual_max = sorted[sorted.length() - 1]
    let min = xlsx_data_bar_threshold(
      rule.stops[0], actual_min, actual_max, values,
    )
    let max = xlsx_data_bar_threshold(
      rule.stops[1], actual_min, actual_max, values,
    )
    if (max - min).abs() < 0.0000001 {
      continue
    }
    let black = xlsx_rgb_from_uint(0x000000U)
    let color = styles.resolve_color(rule.color, black, theme_colors).rgba()
    let negative_color = match rule.negative_color {
      Some(value) => styles.resolve_color(value, black, theme_colors).rgba()
      None => color
    }
    let min_length = Double::min(100.0, Double::max(0.0, rule.min_length))
    let max_length = Double::min(100.0, Double::max(min_length, rule.max_length))
    let axis = match rule.axis_position {
      Some(value) => Double::min(1.0, Double::max(0.0, value))
      None =>
        if rule.right_to_left {
          1.0
        } else if max <= 0.0 {
          1.0
        } else if min < 0.0 {
          (0.0 - min) / (max - min)
        } else {
          0.0
        }
    }
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
          let mut fraction = 0.0
          let mut negative_fraction = 0.0
          if cell.number < 0.0 && min < 0.0 {
            let t = Double::min(
              1.0, Double::max(0.0, (0.0 - cell.number) / (0.0 - min)),
            )
            let length = min_length + (max_length - min_length) * t
            negative_fraction = length / 100.0
          } else {
            let t = if min < 0.0 && max > 0.0 {
              Double::min(1.0, Double::max(0.0, cell.number / max))
            } else {
              Double::min(1.0, Double::max(0.0, (cell.number - min) / (max - min)))
            }
            let length = min_length + (max_length - min_length) * t
            fraction = length / 100.0
          }
          let columns = match result.get(row.index) {
            Some(value) => value
            None => {
              let value : Map[Int32, @sheet.GridDataBar] = Map([])
              result[row.index] = value
              value
            }
          }
          columns[cell.column] = {
            fraction,
            negative_fraction,
            color,
            negative_color,
            axis,
            right_to_left: rule.right_to_left,
            border: rule.border,
            gradient: rule.gradient,
          }
        }
      }
    }
  }
  result
}