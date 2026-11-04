///|
/// One `cfRule type="iconSet"` rule and its target ranges.
priv struct XlsxIconSetRule {
  ranges : Array[XlsxRange]
  set : String
  reverse : Bool
  stops : Array[(XlsxColorScaleStop, Bool)]
  custom : Array[(String, Int32)]
}

///|
fn XlsxWorkbook::xlsx_icon_set_rules(
  self : XlsxWorkbook,
  part : String,
) -> Array[XlsxIconSetRule] raise {
  let bytes = self.package.read(part) catch { _ => return [] }
  let text = @utf8.decode_lossy(bytes[:], ignore_bom=true)
  if text.contains("<!ENTITY") {
    return []
  }
  let reader = @xml.NamespaceReader::from_string(text)
  let out : Array[XlsxIconSetRule] = []
  let mut depth = 0
  let mut conditional_depth = -1
  let mut rule_depth = -1
  let mut set_depth = -1
  let mut sqref = ""
  let mut set = "3TrafficLights1"
  let mut reverse = false
  let mut stops : Array[(XlsxColorScaleStop, Bool)] = []
  let mut custom : Array[(String, Int32)] = []
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
          xlsx_attr(element, "type", "") == "iconSet" {
          rule_depth = depth
          set = "3TrafficLights1"
          reverse = false
          stops = []
          custom = []
        } else if rule_depth >= 0 &&
          depth == rule_depth + 1 &&
          name == "iconSet" {
          set = xlsx_attr(element, "iconSet", "3TrafficLights1")
          reverse = ["1", "true"].contains(xlsx_attr(element, "reverse", ""))
          if event.kind is Start(_) {
            set_depth = depth
          }
        } else if set_depth >= 0 && depth == set_depth + 1 {
          if name == "cfvo" {
            let value = match xlsx_attr(element, "val", "") {
              "" => 0.0
              value => @string.parse_double(value) catch { _ => 0.0 }
            }
            let gte = !["0", "false", "off"].contains(xlsx_attr(element, "gte", "1"))
            stops.push((
              { kind: xlsx_attr(element, "type", "percent"), value, formula: "" },
              gte,
            ))
          } else if name == "cfIcon" {
            let icon_set = xlsx_attr(element, "iconSet", set)
            let icon_id = @string.parse_int(xlsx_attr(element, "iconId", "0")) catch { _ => 0 }
            custom.push((icon_set, icon_id))
          }
        }
        if event.kind is Start(_) {
          depth += 1
        } else if depth == 0 {
          break
        }
      }
      End(_) => {
        if set_depth >= 0 && depth == set_depth {
          if stops.length() >= 2 {
            let ranges : Array[XlsxRange] = []
            for item in sqref.split(" ") {
              match xlsx_parse_range(item.to_owned()) {
                Some(range) => ranges.push(range)
                None => ()
              }
            }
            if !ranges.is_empty() {
              out.push({ ranges, set, reverse, stops, custom })
            }
          }
          set_depth = -1
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
fn XlsxWorkbook::xlsx_data_icons(
  self : XlsxWorkbook,
  part : String,
  rows : Array[XlsxRow],
) -> Map[Int32, Map[Int32, @sheet.GridIcon]] raise {
  let result : Map[Int32, Map[Int32, @sheet.GridIcon]] = Map([])
  for rule in self.xlsx_icon_set_rules(part) {
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
          let mut index = 0
          for i in 1..<rule.stops.length() {
            let (stop, gte) = rule.stops[i]
            let threshold = match stop.kind {
              "min" => min
              "max" => max
              "num" => stop.value
              "percent" => min + (max - min) * stop.value / 100.0
              "percentile" => {
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
            if cell.number > threshold || (gte && cell.number == threshold) {
              index = i
            }
          }
          if rule.reverse {
            index = rule.stops.length() - 1 - index
          }
          let (set, icon_index) = if index < rule.custom.length() { rule.custom[index] } else { (rule.set, index) }
          let columns = match result.get(row.index) {
            Some(value) => value
            None => {
              let value : Map[Int32, @sheet.GridIcon] = Map([])
              result[row.index] = value
              value
            }
          }
          columns[cell.column] = { set, index: icon_index }
        }
      }
    }
  }
  result
}