///|
/// A colour-scale threshold (`min`, `max`, `num`, `percent` or `percentile`).
priv struct XlsxColorScaleStop {
  kind : String
  value : Double
}

///|
/// One `cfRule type="colorScale"` rule and its target ranges.
priv struct XlsxColorScale {
  ranges : Array[XlsxRange]
  stops : Array[XlsxColorScaleStop]
  colors : Array[XlsxColor]
}

///|
/// Parse the colour-scale rules of one worksheet. Malformed or incomplete
/// rules are skipped: the ordinary conditional pass already rejects the
/// structurally invalid ones.
fn XlsxWorkbook::xlsx_color_scales(
  self : XlsxWorkbook,
  part : String,
) -> Array[XlsxColorScale] raise {
  let bytes = self.package.read(part) catch { _ => return [] }
  let text = @utf8.decode_lossy(bytes[:], ignore_bom=true)
  if text.contains("<!ENTITY") {
    return []
  }
  let reader = @xml.NamespaceReader::from_string(text)
  let out : Array[XlsxColorScale] = []
  let mut depth = 0
  let mut conditional_depth = -1
  let mut rule_depth = -1
  let mut scale_depth = -1
  let mut sqref = ""
  let mut stops : Array[XlsxColorScaleStop] = []
  let mut colors : Array[XlsxColor] = []
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
          xlsx_attr(element, "type", "") == "colorScale" {
          rule_depth = depth
          stops = []
          colors = []
        } else if rule_depth >= 0 &&
          depth == rule_depth + 1 &&
          name == "colorScale" &&
          event.kind is Start(_) {
          scale_depth = depth
        } else if scale_depth >= 0 && depth == scale_depth + 1 {
          if name == "cfvo" {
            let value = match xlsx_attr(element, "val", "") {
              "" => 0.0
              value => @string.parse_double(value) catch { _ => 0.0 }
            }
            stops.push({ kind: xlsx_attr(element, "type", "min"), value })
          } else if name == "color" {
            colors.push(xlsx_color(element))
          }
        }
        if event.kind is Start(_) {
          depth += 1
        } else if depth == 0 {
          break
        }
      }
      End(_) => {
        if scale_depth >= 0 && depth == scale_depth {
          if (stops.length() == 2 || stops.length() == 3) &&
            colors.length() == stops.length() {
            let ranges : Array[XlsxRange] = []
            for item in sqref.split(" ") {
              match xlsx_parse_range(item.to_owned()) {
                Some(range) => ranges.push(range)
                None => ()
              }
            }
            if !ranges.is_empty() {
              out.push({ ranges, stops, colors })
            }
          }
          scale_depth = -1
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
fn xlsx_color_scale_channel(rgb : UInt32, shift : Int32) -> Double {
  ((rgb >> shift) & 0xffU).to_double()
}

///|
fn xlsx_color_scale_rgb(colors : Array[UInt32], t : Double) -> UInt32 {
  let position = if colors.length() == 2 { t } else { t * 2.0 }
  let index = if position >= 1.0 {
    colors.length() - 2
  } else {
    position.to_int()
  }
  let local = if colors.length() == 2 { position } else { position - index.to_double() }
  let lower = colors[index]
  let upper = colors[index + 1]
  let channel = fn(shift : Int32) -> Double {
    let a = xlsx_color_scale_channel(lower, shift)
    let b = xlsx_color_scale_channel(upper, shift)
    a + (b - a) * local
  }
  ((channel(24).to_uint() << 24) |
    (channel(16).to_uint() << 16) |
    (channel(8).to_uint() << 8) |
    0xffU)
}

///|
fn xlsx_color_scale_stop_value(
  stop : XlsxColorScaleStop,
  min : Double,
  max : Double,
  values : Array[Double],
) -> Double {
  match stop.kind {
    "min" => min
    "max" => max
    "num" => stop.value
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
/// Paint `colorScale` rules by adding one solid fill per distinct colour.
/// The text index is unchanged; only the cell backgrounds differ.
fn XlsxWorkbook::xlsx_apply_color_scales(
  self : XlsxWorkbook,
  part : String,
  rows : Array[XlsxRow],
  styles : XlsxStyles,
  theme_colors : Map[Int32, XlsxRgb],
) -> Array[XlsxRow] raise {
  let scales = self.xlsx_color_scales(part)
  if scales.is_empty() {
    return rows
  }
  let mut result = rows
  for scale in scales {
    let mut formula = false
    for stop in scale.stops {
      if stop.kind == "formula" {
        formula = true
      }
    }
    if formula {
      continue
    }
    let values : Array[Double] = []
    for range in scale.ranges {
      for row in result {
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
    let colors : Array[UInt32] = []
    let black = xlsx_rgb_from_uint(0x000000U)
    for color in scale.colors {
      colors.push(styles.resolve_color(color, black, theme_colors).rgba())
    }
    let groups : Map[UInt32, Map[Int32, Map[Int32, Bool]]] = Map([])
    for range in scale.ranges {
      for row in result {
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
          let color = xlsx_color_scale_rgb(colors, t)
          let columns = match groups.get(color) {
            Some(value) => value
            None => {
              let value : Map[Int32, Map[Int32, Bool]] = Map([])
              groups[color] = value
              value
            }
          }
          let row_map = match columns.get(row.index) {
            Some(value) => value
            None => {
              let value : Map[Int32, Bool] = Map([])
              columns[row.index] = value
              value
            }
          }
          row_map[cell.column] = true
        }
      }
    }
    let group_colors : Array[UInt32] = []
    for color, _ in groups {
      group_colors.push(color)
    }
    group_colors.sort()
    for color in group_colors {
      let matched = groups[color]
      let fill : XlsxFill = {
        pattern: "solid",
        foreground: {
          kind: 1,
          rgb: (color >> 8) & 0xffffffU,
          index: 0,
          tint: 0.0,
        },
        background: xlsx_default_color(),
        gradient: None,
      }
      let diff : XlsxConditionalStyle = {
        bold: None,
        italic: None,
        strike: None,
        underline: None,
        color: None,
        fill: Some(fill),
        border: None,
      }
      result = xlsx_apply_conditional_style(result, styles, matched, diff)
    }
  }
  result
}