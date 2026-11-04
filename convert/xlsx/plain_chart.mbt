
///|
struct XlsxChartModel {
  title : String
  title_size : Double
  title_color : String
  value_title : String
  category_title : String
  kind : String
  series_name : String
  values : Array[Double]
  categories : Array[String]
  color : String
  marker : String
  marker_size : Double
  show_percent : Bool
  show_value : Bool
  label_separator : String
  label_position : String
  leader_lines : Bool
  first_slice_ang : Double
  explosions : Array[Double]
  hole_size : Double
  show_cat_name : Bool
  show_ser_name : Bool
  axis_min : Double
  axis_max : Double
}

///|
fn xlsx_chart_is_pie(kind : String) -> Bool {
  kind == "pieChart" || kind == "doughnutChart"
}

///|
fn xlsx_chart_clean_ref(formula : String) -> String {
  let out = StringBuilder()
  for character in formula.trim() {
    if character != '$' && character != '=' {
      out.write_char(character)
    } else if character == '=' {
      () // drop the leading formula mark
    }
  }
  out.to_string()
}

///|
fn XlsxWorkbook::xlsx_chart_cells(
  self : XlsxWorkbook,
  formula : String,
) -> Array[(String, Double)] raise {
  let text = formula.trim().to_owned()
  let mut sheet_name = ""
  let mut rest = ""
  if text.has_prefix("'") {
    let tail = text.unsafe_substring(start=1, end=text.length())
    match tail.find("'") {
      Some(offset) => {
        let end = offset + 1
        sheet_name = text.unsafe_substring(start=1, end=end)
        if end + 1 < text.length() && text[end + 1] == '!' {
          rest = text.unsafe_substring(start=end + 2, end=text.length())
        }
      }
      None => return []
    }
  } else {
    match text.find("!") {
      Some(index) => {
        sheet_name = text.unsafe_substring(start=0, end=index)
        rest = text.unsafe_substring(start=index + 1, end=text.length())
      }
      None => return []
    }
  }
  let mut part = ""
  for ref in self.sheets {
    if ref.name == sheet_name {
      part = ref.part
    }
  }
  if part == "" {
    return []
  }
  let cleaned = xlsx_chart_clean_ref(rest)
  let range = match xlsx_parse_range(cleaned) {
    Some(value) => value
    None => return []
  }
  let cells = self.read_sheet_cells(part) catch { _ => return [] }
  let texts : Map[Int64, String] = Map([])
  let numbers : Map[Int64, Double] = Map([])
  for row in cells.rows {
    for cell in row.cells {
      let key = row.index.to_int64() * 16384L + cell.column.to_int64()
      let text = match cell.kind {
        1 => xlsx_chart_number(cell.number)
        2 => cell.text
        3 => if cell.number != 0.0 { "TRUE" } else { "FALSE" }
        _ => cell.text
      }
      let number = if cell.kind == 1 {
        cell.number
      } else {
        @string.parse_double(cell.text) catch { _ => 0.0 }
      }
      texts[key] = text
      numbers[key] = number
    }
  }
  let keys : Array[Int64] = []
  if range.column_start == range.column_end {
    for row in range.row_start..<=range.row_end {
      keys.push(row * 16384L + range.column_start.to_int64())
    }
  } else if range.row_start == range.row_end {
    for column in range.column_start..<=range.column_end {
      keys.push(range.row_start * 16384L + column.to_int64())
    }
  }
  let result : Array[(String, Double)] = []
  for key in keys {
    result.push(
      (texts.get(key).unwrap_or(""), numbers.get(key).unwrap_or(0.0)),
    )
  }
  result
}

///|
fn xlsx_chart_number(value : Double) -> String {
  if value == value.trunc() && value.abs() < 1.0e15 {
    value.to_int64().to_string()
  } else {
    value.to_string()
  }
}

///|
fn xlsx_chart_series(
  workbook : XlsxWorkbook,
  node : XlsxDrawNode,
  name : String,
) -> Array[String] {
  let reference = match xlsx_draw_child(node, name) {
    Some(value) => value
    None => return []
  }
  for kind in ["strRef", "numRef"] {
    match xlsx_draw_child(reference, kind) {
      Some(ref_node) =>
        match xlsx_draw_child(ref_node, "f") {
          Some(formula) => {
            let cells = workbook.xlsx_chart_cells(formula.text) catch { _ => [] }
            return cells.map(cell => cell.0)
          }
          None => ()
        }
      None => ()
    }
  }
  []
}

///|
fn xlsx_chart_numbers(
  workbook : XlsxWorkbook,
  node : XlsxDrawNode,
  name : String,
) -> Array[Double] {
  let reference = match xlsx_draw_child(node, name) {
    Some(value) => value
    None => return []
  }
  for kind in ["numRef", "numLit"] {
    match xlsx_draw_child(reference, kind) {
      Some(ref_node) =>
        match xlsx_draw_child(ref_node, "f") {
          Some(formula) => {
            let cells = workbook.xlsx_chart_cells(formula.text) catch { _ => [] }
            return cells.map(cell => cell.1)
          }
          None => ()
        }
      None => ()
    }
  }
  []
}

///|
fn XlsxWorkbook::xlsx_chart_model(
  self : XlsxWorkbook,
  part : String,
) -> XlsxChartModel? raise {
  let bytes = self.package.read(part) catch { _ => return None }
  let root = xlsx_draw_parse(@utf8.decode_lossy(bytes[:], ignore_bom=true)) catch {
    _ => return None
  }
  let chart = match xlsx_draw_child(root, "chart") {
    Some(value) => value
    None => return None
  }
  let mut title = ""
  let mut title_size = 14.0
  let mut title_color = "#000000"
  match xlsx_draw_child(chart, "title") {
    Some(title_node) => title = xlsx_draw_all_text(title_node).trim().to_string()
    None => ()
  }
  match xlsx_draw_child(chart, "title") {
    Some(title_node) =>
      match xlsx_draw_child(title_node, "tx") {
        Some(tx) =>
          match xlsx_draw_child(tx, "rich") {
            Some(rich) =>
              match xlsx_draw_child(rich, "p") {
                Some(paragraph) =>
                  match xlsx_draw_child(paragraph, "pPr") {
                    Some(ppr) =>
                      match xlsx_draw_child(ppr, "defRPr") {
                        Some(rpr) => {
                          let size = xlsx_draw_attr(rpr, "sz")
                          if size != "" {
                            title_size = (@string.parse_double(size) catch {
                              _ => 1400.0
                            }) / 100.0
                          }
                          match xlsx_draw_child(rpr, "solidFill") {
                            Some(fill) =>
                              match xlsx_draw_child(fill, "srgbClr") {
                                Some(color) => {
                                  let rgb = xlsx_draw_attr(color, "val")
                                  if rgb.length() == 6 {
                                    title_color = "#" + rgb.to_lower()
                                  }
                                }
                                None => ()
                              }
                            None => ()
                          }
                        }
                        None => ()
                      }
                    None => ()
                  }
                None => ()
              }
            None => ()
          }
        None => ()
      }
    None => ()
  }
  let plot_area_node = xlsx_draw_child(chart, "plotArea")
  let value_title = match plot_area_node {
    Some(area) =>
      match xlsx_draw_child(area, "valAx") {
        Some(axis) =>
          match xlsx_draw_child(axis, "title") {
            Some(value) => xlsx_draw_all_text(value).trim().to_string()
            None => ""
          }
        None => ""
      }
    None => ""
  }
  let category_title = match plot_area_node {
    Some(area) =>
      match xlsx_draw_child(area, "catAx") {
        Some(axis) =>
          match xlsx_draw_child(axis, "title") {
            Some(value) => xlsx_draw_all_text(value).trim().to_string()
            None => ""
          }
        None => ""
      }
    None => ""
  }
  let plot_area = match xlsx_draw_child(chart, "plotArea") {
    Some(value) => value
    None => return None
  }
  let mut kind = ""
  let mut plot : XlsxDrawNode? = None
  for name in ["barChart", "lineChart", "pieChart", "doughnutChart", "radarChart"] {
    match xlsx_draw_child(plot_area, name) {
      Some(value) => {
        kind = name
        plot = Some(value)
      }
      None => ()
    }
  }
  let plot = match plot {
    Some(value) => value
    None => return None
  }
  let first = match xlsx_draw_child(plot, "ser") {
    Some(value) => value
    None => return None
  }
  let mut series_name = ""
  match xlsx_draw_child(first, "tx") {
    Some(tx) =>
      for name in ["strRef", "numRef"] {
        match xlsx_draw_child(tx, name) {
          Some(ref_node) =>
            match xlsx_draw_child(ref_node, "f") {
              Some(formula) => {
                let cells = self.xlsx_chart_cells(formula.text) catch { _ => [] }
                if !cells.is_empty() {
                  series_name = cells[0].0
                }
              }
              None => ()
            }
          None => ()
        }
      }
    None => ()
  }
  let values = xlsx_chart_numbers(self, first, "val")
  let categories = xlsx_chart_series(self, first, "cat")
  let mut color = "#4472c4"
  let marker_size = match xlsx_draw_child(first, "marker") {
    Some(marker_node) =>
      match xlsx_draw_child(marker_node, "size") {
        Some(size) =>
          @string.parse_double(xlsx_draw_attr(size, "val")) catch { _ => 5.0 }
        None => 5.0
      }
    None => 5.0
  }
  let marker = match xlsx_draw_child(first, "marker") {
    Some(marker_node) =>
      match xlsx_draw_child(marker_node, "symbol") {
        Some(symbol) => xlsx_draw_attr(symbol, "val")
        None => "none"
      }
    None => "none"
  }
  match xlsx_draw_child(first, "spPr") {
    Some(sp_pr) =>
      match xlsx_draw_child(sp_pr, "solidFill") {
        Some(fill) =>
          match xlsx_draw_child(fill, "srgbClr") {
            Some(value) => {
              let rgb = xlsx_draw_attr(value, "val")
              if rgb.length() == 6 {
                color = "#" + rgb.to_lower()
              }
            }
            None => ()
          }
        None => ()
      }
    None => ()
  }
  let mut show_percent = false
  let mut show_value = false
  let mut label_separator = " "
  let mut label_position = "outEnd"
  let mut leader_lines = false
  let mut first_slice_ang = 0.0
  let mut hole_size = 50.0
  match xlsx_draw_child(plot, "holeSize") {
    Some(value) =>
      hole_size = @string.parse_double(xlsx_draw_attr(value, "val")) catch {
        _ => 50.0
      }
    None => ()
  }
  let explosions : Array[Double] = []
  for child in first.children {
    if child.name != "dPt" {
      continue
    }
    let idx_node = xlsx_draw_child(child, "idx")
    let explosion_node = xlsx_draw_child(child, "explosion")
    if idx_node is None || explosion_node is None {
      continue
    }
    let index = @string.parse_int(
      xlsx_draw_attr(idx_node.unwrap(), "val"),
    ) catch {
      _ => -1
    }
    if index < 0 {
      continue
    }
    let value = @string.parse_double(
      xlsx_draw_attr(explosion_node.unwrap(), "val"),
    ) catch {
      _ => 0.0
    }
    while explosions.length() <= index {
      explosions.push(0.0)
    }
    explosions[index] = value
  }
  match xlsx_draw_child(plot, "firstSliceAng") {
    Some(value) =>
      first_slice_ang = @string.parse_double(
        xlsx_draw_attr(value, "val"),
      ) catch {
        _ => 0.0
      }
    None => ()
  }
  let mut show_cat_name = false
  let mut show_ser_name = false
  match xlsx_draw_child(plot, "dLbls") {
    Some(labels) => {
      match xlsx_draw_child(labels, "showLeaderLines") {
        Some(value) => leader_lines = xlsx_draw_attr(value, "val") != "0"
        None => ()
      }
      match xlsx_draw_child(labels, "dLblPos") {
        Some(position) => label_position = xlsx_draw_attr(position, "val")
        None => ()
      }
      match xlsx_draw_child(labels, "separator") {
        Some(separator) => label_separator = xlsx_draw_all_text(separator)
        None => ()
      }
      match xlsx_draw_child(labels, "showPercent") {
        Some(value) => show_percent = xlsx_draw_attr(value, "val") != "0"
        None => ()
      }
      match xlsx_draw_child(labels, "showVal") {
        Some(value) => show_value = xlsx_draw_attr(value, "val") != "0"
        None => ()
      }
      match xlsx_draw_child(labels, "showCatName") {
        Some(value) => show_cat_name = xlsx_draw_attr(value, "val") != "0"
        None => ()
      }
      match xlsx_draw_child(labels, "showSerName") {
        Some(value) => show_ser_name = xlsx_draw_attr(value, "val") != "0"
        None => ()
      }
    }
    None => ()
  }
  let mut axis_min = 0.0
  let mut axis_max = 0.0
  match xlsx_draw_child(plot, "valAx") {
    Some(axis) =>
      match xlsx_draw_child(axis, "scaling") {
        Some(scaling) => {
          match xlsx_draw_child(scaling, "min") {
            Some(value) =>
              axis_min = @string.parse_double(
                xlsx_draw_attr(value, "val"),
              ) catch {
                _ => 0.0
              }
            None => ()
          }
          match xlsx_draw_child(scaling, "max") {
            Some(value) =>
              axis_max = @string.parse_double(
                xlsx_draw_attr(value, "val"),
              ) catch {
                _ => 0.0
              }
            None => ()
          }
        }
        None => ()
      }
    None => ()
  }
  if categories.is_empty() {
    for index in 0..<values.length() {
      categories.push((index + 1).to_string())
    }
  }
  Some({
    title,
    title_size,
    title_color,
    value_title,
    category_title,
    kind,
    series_name,
    values,
    categories,
    color,
    marker,
    marker_size,
    show_percent,
    show_value,
    label_separator,
    label_position,
    leader_lines,
    first_slice_ang,
    explosions,
    hole_size,
    show_cat_name,
    show_ser_name,
    axis_min,
    axis_max,
  })
}

///|
fn xlsx_chart_data_label(
  model : XlsxChartModel,
  index : Int,
  value : Double,
) -> String {
  let parts : Array[String] = []
  if model.show_ser_name && model.series_name != "" {
    parts.push(model.series_name)
  }
  if model.show_cat_name && index < model.categories.length() {
    parts.push(model.categories[index])
  }
  if model.show_value {
    parts.push(xlsx_chart_number(value))
  }
  if model.show_percent {
    let total = model.values.fold(init=0.0, (sum, item) => sum + item)
    let percent = if total > 0.0 { value / total * 100.0 } else { 0.0 }
    parts.push((percent + 0.5).to_int().to_string() + "%")
  }
  parts.join(model.label_separator)
}

///|
fn xlsx_chart_ticks(maximum : Double) -> (Array[Double], Double) {
  let ticks : Array[Double] = []
  if maximum <= 0.0 {
    ticks.push(0.0)
    ticks.push(1.0)
    return (ticks, 1.0)
  }
  let high = maximum + maximum / 20.0
  let magnitude = @math.pow(10.0, @math.log10(high / 10.0).floor())
  let mut step = magnitude
  for candidate in [1.0, 2.0, 5.0, 10.0, 20.0, 50.0] {
    step = candidate * magnitude
    if (high / step).ceil() <= 10.0 {
      break
    }
  }
  let top = (high / step).ceil() * step
  let mut value = 0.0
  while value <= top + step * 1.0e-6 {
    ticks.push(value)
    value += step
  }
  (ticks, step)
}

///|
fn XlsxWorkbook::xlsx_chart_labels(
  self : XlsxWorkbook,
  part : String,
) -> Array[@sheet.GridShapeTextLine] raise {
  let lines : Array[@sheet.GridShapeTextLine] = []
  let model = match self.xlsx_chart_model(part) {
    Some(value) => value
    None => return lines
  }
  let (ticks, _) = xlsx_chart_ticks(
    model.values.fold(init=0.0, (value, item) => Double::max(value, item)),
  )
  let add = (text : String, size : Double) => {
    lines.push({
      runs: [{ text, size, bold: false, italic: false, color: 0x00000000U }],
      align: "chart",
    })
  }
  if model.title != "" {
    add(model.title, 12.0)
  }
  if model.series_name != "" {
    add(model.series_name, 11.0)
  }
  for tick in ticks {
    add(xlsx_chart_number(tick), 10.0)
  }
  for category in model.categories {
    add(category, 10.0)
  }
  lines
}

///|
fn xlsx_chart_text(text : String) -> String {
  let out = StringBuilder()
  for character in text {
    if character == '&' {
      out.write_string("&amp;")
    } else if character == '<' {
      out.write_string("&lt;")
    } else if character == '>' {
      out.write_string("&gt;")
    } else {
      out.write_char(character)
    }
  }
  out.to_string()
}

///|
fn XlsxWorkbook::xlsx_chart_svg(
  self : XlsxWorkbook,
  part : String,
  width : Double,
  height : Double,
) -> String raise {
  let model = match self.xlsx_chart_model(part) {
    Some(value) => value
    None => return "<svg xmlns=\"http://www.w3.org/2000/svg\"></svg>"
  }
  let (ticks, _) = xlsx_chart_ticks(
    model.values.fold(init=0.0, (value, item) => Double::max(value, item)),
  )
  let top = ticks[ticks.length() - 1]
  let axis_exists = model.axis_max > model.axis_min
  let axis_top = if axis_exists { model.axis_max } else { top }
  let axis_base = if axis_exists { model.axis_min } else { 0.0 }
  let axis_range = Double::max(axis_top - axis_base, 0.000001)
  let left = 60.0
  let plot_top = 40.0
  let plot_width = Double::max(width - left - 140.0, 10.0)
  let plot_height = Double::max(height - plot_top - 50.0, 10.0)
  let svg = StringBuilder()
  svg.write_string(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"" +
    width.to_string() +
    "\" height=\"" +
    height.to_string() +
    "\" viewBox=\"0 0 " +
    width.to_string() +
    " " +
    height.to_string() +
    "\"><rect width=\"100%\" height=\"100%\" fill=\"#ffffff\"/>",
  )
  if model.title != "" {
    svg.write_string(
      "<text x=\"" +
      (width / 2.0).to_string() +
      "\" y=\"20\" text-anchor=\"middle\" font-size=\"" +
      model.title_size.to_string() +
      "\" font-weight=\"bold\" fill=\"" +
      model.title_color +
      "\">" +
      xlsx_chart_text(model.title) +
      "</text>",
    )
  }
  if model.series_name != "" {
    svg.write_string(
      "<text x=\"" +
      (width - 110.0).to_string() +
      "\" y=\"" +
      (plot_top + 20.0).to_string() +
      "\" font-size=\"11\" fill=\"#000000\">" +
      xlsx_chart_text(model.series_name) +
      "</text>",
    )
  }
  for tick in ticks {
    let y = plot_top + plot_height -
      plot_height * (tick - axis_base) / axis_range
    svg.write_string(
      "<line x1=\"" +
      left.to_string() +
      "\" y1=\"" +
      y.to_string() +
      "\" x2=\"" +
      (left + plot_width).to_string() +
      "\" y2=\"" +
      y.to_string() +
      "\" stroke=\"#e0e0e0\"/>",
    )
    svg.write_string(
      "<text x=\"" +
      (left - 8.0).to_string() +
      "\" y=\"" +
      (y + 4.0).to_string() +
      "\" text-anchor=\"end\" font-size=\"10\" fill=\"#000000\">" +
      xlsx_chart_number(tick) +
      "</text>",
    )
  }
  svg.write_string(
    "<line x1=\"" +
    left.to_string() +
    "\" y1=\"" +
    plot_top.to_string() +
    "\" x2=\"" +
    left.to_string() +
    "\" y2=\"" +
    (plot_top + plot_height).to_string() +
    "\" stroke=\"#000000\"/>",
  )
  let count = model.values.length()
  if xlsx_chart_is_pie(model.kind) {
    let total = model.values.fold(init=0.0, (sum, value) => sum + value)
    if total > 0.0 {
      let cx = left + plot_width / 2.0
      let cy = plot_top + plot_height / 2.0
      let radius = Double::min(plot_width, plot_height) / 2.0
      let palette = [
        "#4472c4", "#ed7d31", "#a5a5a5", "#ffc000", "#5b9bd5", "#70ad47",
      ]
      let mut angle = -3.141592653589793 / 2.0 + model.first_slice_ang * 3.141592653589793 / 180.0
      for index, value in model.values {
        let sweep = 2.0 * 3.141592653589793 * value / total
        let end = angle + sweep
        let mid = angle + sweep / 2.0
        let explosion = if index < model.explosions.length() {
          model.explosions[index] / 100.0 * radius
        } else {
          0.0
        }
        let sx = cx + @math.cos(mid) * explosion
        let sy = cy + @math.sin(mid) * explosion
        let x1 = sx + @math.cos(angle) * radius
        let y1 = sy + @math.sin(angle) * radius
        let x2 = sx + @math.cos(end) * radius
        let y2 = sy + @math.sin(end) * radius
        let large = if sweep > 3.141592653589793 { 1 } else { 0 }
        svg.write_string(
          "<path d=\"M " +
          sx.to_string() +
          " " +
          sy.to_string() +
          " L " +
          x1.to_string() +
          " " +
          y1.to_string() +
          " A " +
          radius.to_string() +
          " " +
          radius.to_string() +
          " 0 " +
          large.to_string() +
          " 1 " +
          x2.to_string() +
          " " +
          y2.to_string() +
          " Z\" fill=\"" +
          palette[index % palette.length()] +
          "\"/>",
        )
        angle = end
      }
    }
    if model.kind == "doughnutChart" {
      svg.write_string(
        "<circle cx=\"" +
        (left + plot_width / 2.0).to_string() +
        "\" cy=\"" +
        (plot_top + plot_height / 2.0).to_string() +
        "\" r=\"" +
        (Double::min(plot_width, plot_height) / 2.0 *
          model.hole_size / 100.0).to_string() +
        "\" fill=\"#ffffff\"/>",
      )
    }
  } else if model.kind == "radarChart" {
    let radar_count = model.values.length()
    if radar_count > 0 {
      let cx = left + plot_width / 2.0
      let cy = plot_top + plot_height / 2.0
      let radar_radius = Double::min(plot_width, plot_height) / 2.0
      let peak = Double::max(top, 0.000001)
      for ring in [0.25, 0.5, 0.75, 1.0] {
        let ring_points = StringBuilder()
        for index in 0..<radar_count {
          let angle = -3.141592653589793 / 2.0 +
            2.0 * 3.141592653589793 * index.to_double() /
            radar_count.to_double()
          if index > 0 {
            ring_points.write_string(" ")
          }
          ring_points.write_string(
            (cx + @math.cos(angle) * radar_radius * ring).to_string() +
            "," +
            (cy + @math.sin(angle) * radar_radius * ring).to_string(),
          )
        }
        svg.write_string(
          "<polygon points=\"" +
          ring_points.to_string() +
          "\" fill=\"none\" stroke=\"#d9d9d9\"/>",
        )
      }
      for index in 0..<radar_count {
        let angle = -3.141592653589793 / 2.0 +
          2.0 * 3.141592653589793 * index.to_double() /
          radar_count.to_double()
        svg.write_string(
          "<line x1=\"" +
          cx.to_string() +
          "\" y1=\"" +
          cy.to_string() +
          "\" x2=\"" +
          (cx + @math.cos(angle) * radar_radius).to_string() +
          "\" y2=\"" +
          (cy + @math.sin(angle) * radar_radius).to_string() +
          "\" stroke=\"#d9d9d9\"/>",
        )
      }
      let points = StringBuilder()
      for index, value in model.values {
        let angle = -3.141592653589793 / 2.0 +
          2.0 * 3.141592653589793 * index.to_double() /
          radar_count.to_double()
        let rr = radar_radius * Double::max(value, 0.0) / peak
        if index > 0 {
          points.write_string(" ")
        }
        points.write_string(
          (cx + @math.cos(angle) * rr).to_string() +
          "," +
          (cy + @math.sin(angle) * rr).to_string(),
        )
      }
      svg.write_string(
        "<polygon points=\"" +
        points.to_string() +
        "\" fill=\"" +
        model.color +
        "\" fill-opacity=\"0.3\" stroke=\"" +
        model.color +
        "\" stroke-width=\"2\"/>",
      )
    }
  } else if model.kind == "barChart" {
    let slot = plot_width / Double::max(count.to_double(), 1.0)
    for index, value in model.values {
      let bar_height = plot_height * (value - axis_base) / axis_range
      svg.write_string(
        "<rect x=\"" +
        (left + slot * index.to_double() + slot * 0.2).to_string() +
        "\" y=\"" +
        (plot_top + plot_height - bar_height).to_string() +
        "\" width=\"" +
        (slot * 0.6).to_string() +
        "\" height=\"" +
        bar_height.to_string() +
        "\" fill=\"" + model.color + "\"/>",
      )
      let label_text = xlsx_chart_data_label(model, index, value)
      if label_text != "" {
        let label_y = match model.label_position {
          "ctr" => plot_top + plot_height - bar_height / 2.0 + 4.0
          "inEnd" => plot_top + plot_height - bar_height + 12.0
          "inBase" => plot_top + plot_height - 4.0
          _ => plot_top + plot_height - bar_height - 4.0
        }
        svg.write_string(
          "<text x=\"" +
          (left + slot * index.to_double() + slot * 0.5).to_string() +
          "\" y=\"" +
          label_y.to_string() +
          "\" text-anchor=\"middle\" font-size=\"10\" fill=\"#000000\">" +
          xlsx_chart_text(label_text) +
          "</text>",
        )
      }
    }
  } else {
    let mut path = "M "
    for index, value in model.values {
      let x = if count <= 1 {
        left + plot_width / 2.0
      } else {
        left + plot_width * index.to_double() / (count - 1).to_double()
      }
      let y = plot_top + plot_height -
        plot_height * (value - axis_base) / axis_range
      path = path +
        (if index == 0 { "" } else { " L " }) +
        x.to_string() +
        " " +
        y.to_string()
      let label_text = xlsx_chart_data_label(model, index, value)
      if label_text != "" {
        let label_y = match model.label_position {
          "ctr" => y + 4.0
          "inBase" => y - 10.0
          _ => y - 4.0
        }
        svg.write_string(
          "<text x=\"" +
          x.to_string() +
          "\" y=\"" +
          label_y.to_string() +
          "\" text-anchor=\"middle\" font-size=\"10\" fill=\"#000000\">" +
          xlsx_chart_text(label_text) +
          "</text>",
        )
      }
      if model.marker != "none" {
        let size = model.marker_size
        let half = size / 2.0
        if model.marker == "diamond" {
          svg.write_string(
            "<polygon points=\"" +
            x.to_string() + "," + (y - half).to_string() + " " +
            (x + half).to_string() + "," + y.to_string() + " " +
            x.to_string() + "," + (y + half).to_string() + " " +
            (x - half).to_string() + "," + y.to_string() +
            "\" fill=\"" + model.color + "\"/>",
          )
        } else if model.marker == "triangle" {
          svg.write_string(
            "<polygon points=\"" +
            x.to_string() + "," + (y - half).to_string() + " " +
            (x + half).to_string() + "," + (y + half).to_string() + " " +
            (x - half).to_string() + "," + (y + half).to_string() +
            "\" fill=\"" + model.color + "\"/>",
          )
        } else if model.marker == "x" {
          svg.write_string(
            "<line x1=\"" + (x - half).to_string() +
            "\" y1=\"" + (y - half).to_string() +
            "\" x2=\"" + (x + half).to_string() +
            "\" y2=\"" + (y + half).to_string() +
            "\" stroke=\"" + model.color + "\" stroke-width=\"2\"/>",
          )
          svg.write_string(
            "<line x1=\"" + (x - half).to_string() +
            "\" y1=\"" + (y + half).to_string() +
            "\" x2=\"" + (x + half).to_string() +
            "\" y2=\"" + (y - half).to_string() +
            "\" stroke=\"" + model.color + "\" stroke-width=\"2\"/>",
          )
        } else if model.marker == "plus" {
          svg.write_string(
            "<line x1=\"" + x.to_string() +
            "\" y1=\"" + (y - half).to_string() +
            "\" x2=\"" + x.to_string() +
            "\" y2=\"" + (y + half).to_string() +
            "\" stroke=\"" + model.color + "\" stroke-width=\"2\"/>",
          )
          svg.write_string(
            "<line x1=\"" + (x - half).to_string() +
            "\" y1=\"" + y.to_string() +
            "\" x2=\"" + (x + half).to_string() +
            "\" y2=\"" + y.to_string() +
            "\" stroke=\"" + model.color + "\" stroke-width=\"2\"/>",
          )
        } else if model.marker == "star" {
          for sx in [-1.0, 1.0] {
            svg.write_string(
              "<line x1=\"" + (x - half * sx).to_string() +
              "\" y1=\"" + (y - half).to_string() +
              "\" x2=\"" + (x + half * sx).to_string() +
              "\" y2=\"" + (y + half).to_string() +
              "\" stroke=\"" + model.color + "\" stroke-width=\"2\"/>",
            )
          }
          svg.write_string(
            "<line x1=\"" + (x - half).to_string() +
            "\" y1=\"" + y.to_string() +
            "\" x2=\"" + (x + half).to_string() +
            "\" y2=\"" + y.to_string() +
            "\" stroke=\"" + model.color + "\" stroke-width=\"2\"/>",
          )
          svg.write_string(
            "<line x1=\"" + x.to_string() +
            "\" y1=\"" + (y - half).to_string() +
            "\" x2=\"" + x.to_string() +
            "\" y2=\"" + (y + half).to_string() +
            "\" stroke=\"" + model.color + "\" stroke-width=\"2\"/>",
          )
        } else if model.marker == "square" {
          svg.write_string(
            "<rect x=\"" + (x - half).to_string() +
            "\" y=\"" + (y - half).to_string() +
            "\" width=\"" + size.to_string() +
            "\" height=\"" + size.to_string() +
            "\" fill=\"" + model.color + "\"/>",
          )
        } else {
          svg.write_string(
            "<circle cx=\"" + x.to_string() +
            "\" cy=\"" + y.to_string() +
            "\" r=\"" + half.to_string() +
            "\" fill=\"" + model.color + "\"/>",
          )
        }
      }
    }
    svg.write_string(
      "<path d=\"" +
      path +
      "\" fill=\"none\" stroke=\"" +
      model.color +
      "\" stroke-width=\"2\"/>",
    )
  }
  let slot = plot_width / Double::max(count.to_double(), 1.0)
  let pie_total = model.values.fold(init=0.0, (sum, value) => sum + value)
  if xlsx_chart_is_pie(model.kind) && pie_total > 0.0 {
    let cx = left + plot_width / 2.0
    let cy = plot_top + plot_height / 2.0
    let radius = Double::min(plot_width, plot_height) / 2.0
    let mut angle = -3.141592653589793 / 2.0 + model.first_slice_ang * 3.141592653589793 / 180.0
    for index, value in model.values {
      let sweep = 2.0 * 3.141592653589793 * value / pie_total
      let mid = angle + sweep / 2.0
      let explosion = if index < model.explosions.length() {
        model.explosions[index] / 100.0 * radius
      } else {
        0.0
      }
      let sx = cx + @math.cos(mid) * explosion
      let sy = cy + @math.sin(mid) * explosion
      let category_radius = match model.label_position {
        "ctr" | "inEnd" => radius * 0.75
        _ => radius * 1.12
      }
      let x = sx + @math.cos(mid) * category_radius
      let y = sy + @math.sin(mid) * category_radius
      if model.leader_lines && category_radius > radius {
        svg.write_string(
          "<line x1=\"" +
          (sx + @math.cos(mid) * radius).to_string() +
          "\" y1=\"" +
          (sy + @math.sin(mid) * radius).to_string() +
          "\" x2=\"" +
          x.to_string() +
          "\" y2=\"" +
          y.to_string() +
          "\" stroke=\"#808080\"/>",
        )
      }
      if index < model.categories.length() {
        svg.write_string(
          "<text x=\"" +
          x.to_string() +
          "\" y=\"" +
          (y + 4.0).to_string() +
          "\" text-anchor=\"middle\" font-size=\"10\" fill=\"#000000\">" +
          xlsx_chart_text(model.categories[index]) +
          "</text>",
        )
      }
      let label_text = xlsx_chart_data_label(model, index, value)
      if label_text != "" {
        let data_radius = if model.label_position == "outEnd" {
          radius * 0.85
        } else {
          radius * 0.55
        }
        let inner_x = sx + @math.cos(mid) * data_radius
        let inner_y = sy + @math.sin(mid) * data_radius
        svg.write_string(
          "<text x=\"" +
          inner_x.to_string() +
          "\" y=\"" +
          (inner_y + 4.0).to_string() +
          "\" text-anchor=\"middle\" font-size=\"10\" fill=\"#ffffff\">" +
          xlsx_chart_text(label_text) +
          "</text>",
        )
      }
      angle += sweep
    }
  } else {
    for index, category in model.categories {
      let x = left + slot * index.to_double() + slot * 0.5
      svg.write_string(
        "<text x=\"" +
        x.to_string() +
        "\" y=\"" +
        (plot_top + plot_height + 18.0).to_string() +
        "\" text-anchor=\"middle\" font-size=\"10\" fill=\"#000000\">" +
        xlsx_chart_text(category) +
        "</text>",
      )
    }
  }
  if model.value_title != "" && !xlsx_chart_is_pie(model.kind) {
    let axis_y = plot_top + plot_height / 2.0
    svg.write_string(
      "<text x=\"14\" y=\"" +
      axis_y.to_string() +
      "\" transform=\"rotate(-90 14 " +
      axis_y.to_string() +
      ")\" text-anchor=\"middle\" font-size=\"11\" fill=\"#000000\">" +
      xlsx_chart_text(model.value_title) +
      "</text>",
    )
  }
  if model.category_title != "" && !xlsx_chart_is_pie(model.kind) {
    svg.write_string(
      "<text x=\"" +
      (left + plot_width / 2.0).to_string() +
      "\" y=\"" +
      (height - 6.0).to_string() +
      "\" text-anchor=\"middle\" font-size=\"11\" fill=\"#000000\">" +
      xlsx_chart_text(model.category_title) +
      "</text>",
    )
  }
  let legend_x = width - 125.0
  let mut legend_y = plot_top + 8.0
  let legend_palette = [
    "#4472c4", "#ed7d31", "#a5a5a5", "#ffc000", "#5b9bd5", "#70ad47",
  ]
  if xlsx_chart_is_pie(model.kind) {
    for index, category in model.categories {
      if index >= 12 {
        break
      }
      svg.write_string(
        "<rect x=\"" +
        legend_x.to_string() +
        "\" y=\"" +
        (legend_y - 8.0).to_string() +
        "\" width=\"10\" height=\"10\" fill=\"" +
        legend_palette[index % legend_palette.length()] +
        "\"/>",
      )
      svg.write_string(
        "<text x=\"" +
        (legend_x + 14.0).to_string() +
        "\" y=\"" +
        legend_y.to_string() +
        "\" font-size=\"10\" fill=\"#000000\">" +
        xlsx_chart_text(category) +
        "</text>",
      )
      legend_y += 16.0
    }
  } else if model.series_name != "" {
    svg.write_string(
      "<rect x=\"" +
      legend_x.to_string() +
      "\" y=\"" +
      (legend_y - 8.0).to_string() +
      "\" width=\"10\" height=\"10\" fill=\"" +
      model.color +
      "\"/>",
    )
    svg.write_string(
      "<text x=\"" +
      (legend_x + 14.0).to_string() +
      "\" y=\"" +
      legend_y.to_string() +
      "\" font-size=\"10\" fill=\"#000000\">" +
      xlsx_chart_text(model.series_name) +
      "</text>",
    )
  }
  svg.write_string("</svg>")
  svg.to_string()
}

///|
fn XlsxWorkbook::xlsx_chart_sheet_parts(
  self : XlsxWorkbook,
  part : String,
) -> (Double, Double, String?) raise {
  let bytes = self.package.read(part) catch { _ => return (720.0, 540.0, None) }
  let root = xlsx_draw_parse(@utf8.decode_lossy(bytes[:], ignore_bom=true)) catch {
    _ => return (720.0, 540.0, None)
  }
  let drawing_id = match xlsx_draw_child(root, "drawing") {
    Some(drawing) => xlsx_draw_attr(drawing, "id")
    None => ""
  }
  let mut drawing_part = ""
  if drawing_id != "" {
    for rel in self.package.relationships(part) {
      if rel.id == drawing_id {
        drawing_part = rel.target
      }
    }
  }
  if drawing_part == "" {
    return (720.0, 540.0, None)
  }
  let drawing_bytes = self.package.read(drawing_part) catch {
    _ => return (720.0, 540.0, None)
  }
  let drawing = xlsx_draw_parse(
    @utf8.decode_lossy(drawing_bytes[:], ignore_bom=true),
  ) catch {
    _ => return (720.0, 540.0, None)
  }
  let mut width = 720.0
  let mut height = 540.0
  for anchor in drawing.children {
    if anchor.name == "absoluteAnchor" {
      match xlsx_draw_child(anchor, "ext") {
        Some(ext) => {
          let w = xlsx_draw_emu(xlsx_draw_get_attr_int(ext, "cx"))
          let h = xlsx_draw_emu(xlsx_draw_get_attr_int(ext, "cy"))
          if w > 0.0 && h > 0.0 {
            width = w
            height = h
          }
        }
        None => ()
      }
    }
  }
  let mut chart_id = ""
  for anchor in drawing.children {
    if anchor.name == "absoluteAnchor" || anchor.name == "oneCellAnchor" ||
      anchor.name == "twoCellAnchor" {
      match xlsx_draw_child(anchor, "graphicFrame") {
        Some(frame) =>
          match xlsx_draw_child(frame, "graphic") {
            Some(graphic) =>
              match xlsx_draw_child(graphic, "graphicData") {
                Some(data) =>
                  match xlsx_draw_child(data, "chart") {
                    Some(chart) => chart_id = xlsx_draw_attr(chart, "id")
                    None => ()
                  }
                None => ()
              }
            None => ()
          }
        None => ()
      }
    }
  }
  let mut chart_part = ""
  if chart_id != "" {
    for rel in self.package.relationships(drawing_part) {
      if rel.id == chart_id {
        chart_part = rel.target
      }
    }
  }
  (width, height, if chart_part == "" { None } else { Some(chart_part) })
}

///|
fn xlsx_chart_circle_path(
  cx : Double,
  cy : Double,
  radius : Double,
) -> @core.Path {
  let verbs : Array[Byte] = [0]
  let coordinates : Array[Double] = [cx, cy]
  let steps = 24
  for index in 0..<steps {
    let angle = 2.0 * 3.141592653589793 * index.to_double() / steps.to_double()
    verbs.push(1)
    coordinates.push(cx + @math.cos(angle) * radius)
    coordinates.push(cy + @math.sin(angle) * radius)
  }
  verbs.push(4)
  { verbs: Bytes::from_array(verbs), coordinates, }
}

///|
fn xlsx_chart_color_uint(value : String) -> UInt32 {
  match xlsx_theme_hex(value) {
    Some(color) => {
      let red = (color.red * 255.0 + 0.5).to_int().to_uint()
      let green = (color.green * 255.0 + 0.5).to_int().to_uint()
      let blue = (color.blue * 255.0 + 0.5).to_int().to_uint()
      (red << 24) | (green << 16) | (blue << 8) | 0xffU
    }
    None => 0x4472c4ffU
  }
}

///|
fn XlsxWorkbook::xlsx_chart_object(
  self : XlsxWorkbook,
  part : String,
  width : Double,
  height : Double,
) -> @core.ObjectBuilder raise {
  let object = @core.ObjectBuilder::new()
  object.set_bbox(0.0F, 0.0F, Float::from_double(width), Float::from_double(height))
  object.fill_color(0xffffffffU)
  object.fill_rect(0.0F, 0.0F, Float::from_double(width), Float::from_double(height))
  let model = match self.xlsx_chart_model(part) {
    Some(value) => value
    None => return object
  }
  let (ticks, _) = xlsx_chart_ticks(
    if model.axis_max > model.axis_min {
      model.axis_max
    } else {
      model.values.fold(init=0.0, (value, item) => Double::max(value, item))
    },
  )
  let top = ticks[ticks.length() - 1]
  let axis_exists = model.axis_max > model.axis_min
  let axis_base = if axis_exists { model.axis_min } else { 0.0 }
  let axis_range = Double::max(top - axis_base, 0.000001)
  let left = 60.0
  let plot_top = 40.0
  let plot_width = Double::max(width - left - 140.0, 10.0)
  let plot_height = Double::max(height - plot_top - 50.0, 10.0)
  let bold = object.add_font({
    hash: None,
    family: "Calibri, sans-serif",
    weight: 700,
    style: 0,
  })
  let normal = object.add_font({
    hash: None,
    family: "Calibri, sans-serif",
    weight: 400,
    style: 0,
  })
  let label = (text : String, x : Double, y : Double, size : Double, weight : Int32) => {
    object.mark(2, "")
    object.font(if weight >= 700 { bold } else { normal }, Float::from_double(size))
    object.fill_color(0x000000ffU)
    let mut advance = 0.0
    for character in text {
      advance += @sheet.sized_fallback_advance(character, weight >= 700, size)
    }
    object.fill_text(
      text,
      Float::from_double(x),
      Float::from_double(y),
      Float::from_double(advance),
    )
  }
  if model.title != "" {
    let mut advance = 0.0
    for character in model.title {
      advance += @sheet.sized_fallback_advance(
        character, true, model.title_size,
      )
    }
    object.mark(2, "")
    object.font(bold, Float::from_double(model.title_size))
    object.fill_color(xlsx_chart_color_uint(model.title_color))
    object.fill_text(
      model.title,
      Float::from_double((width - advance) / 2.0),
      20.0F,
      Float::from_double(advance),
    )
  }
  if model.series_name != "" {
    label(model.series_name, width - 110.0, plot_top + 20.0, 11.0, 400)
  }
  for tick in ticks {
    let y = plot_top + plot_height -
      plot_height * (tick - axis_base) / axis_range
    object.line(0.5F, 0, 0, 8.0F)
    object.stroke_color(0xe0e0e0ffU)
    object.stroke_path(
      object.add_path(
        @core.Inline({
          verbs: b"\x00\x01",
          coordinates: [left, y, left + plot_width, y],
        }),
      ),
    )
    label(
      xlsx_chart_number(tick), left - 40.0, y + 3.0, 10.0, 400,
    )
  }
  object.line(0.75F, 0, 0, 8.0F)
  object.stroke_color(0x000000ffU)
  object.stroke_rect(
    Float::from_double(left),
    Float::from_double(plot_top),
    0.0F,
    Float::from_double(plot_height),
  )
  let count = model.values.length()
  let slot = plot_width / Double::max(count.to_double(), 1.0)
  let series_color = xlsx_chart_color_uint(model.color)
  if xlsx_chart_is_pie(model.kind) {
    let total = model.values.fold(init=0.0, (sum, value) => sum + value)
    if total > 0.0 {
      let cx = left + plot_width / 2.0
      let cy = plot_top + plot_height / 2.0
      let radius = Double::min(plot_width, plot_height) / 2.0
      let palette = [
        0x4472c4ffU, 0xed7d31ffU, 0xa5a5a5ffU, 0xffc000ffU, 0x5b9bd5ffU,
        0x70ad47ffU,
      ]
      let mut angle = -3.141592653589793 / 2.0 + model.first_slice_ang * 3.141592653589793 / 180.0
      for index, value in model.values {
        let sweep = 2.0 * 3.141592653589793 * value / total
        let mid = angle + sweep / 2.0
        let explosion = if index < model.explosions.length() {
          model.explosions[index] / 100.0 * radius
        } else {
          0.0
        }
        let sx = cx + @math.cos(mid) * explosion
        let sy = cy + @math.sin(mid) * explosion
        let verbs : Array[Byte] = [0]
        let coordinates : Array[Double] = [sx, sy]
        let steps = 24
        for step in 0..<steps {
          let step_angle = angle + sweep * step.to_double() / steps.to_double()
          verbs.push(1)
          coordinates.push(sx + @math.cos(step_angle) * radius)
          coordinates.push(sy + @math.sin(step_angle) * radius)
        }
        verbs.push(1)
        coordinates.push(sx + @math.cos(angle + sweep) * radius)
        coordinates.push(sy + @math.sin(angle + sweep) * radius)
        verbs.push(4)
        object.fill_color(palette[index % palette.length()])
        let path = object.add_path(
          @core.Inline({ verbs: Bytes::from_array(verbs), coordinates }),
        )
        object.fill_path(path, 0)
        angle += sweep
      }
      if model.kind == "doughnutChart" {
        object.fill_color(0xffffffffU)
        object.fill_path(
          object.add_path(
            @core.Inline(
              xlsx_chart_circle_path(
                left + plot_width / 2.0,
                plot_top + plot_height / 2.0,
                Double::min(plot_width, plot_height) / 2.0 *
                model.hole_size / 100.0,
              ),
            ),
          ),
          0,
        )
      }
    }
  } else if model.kind == "radarChart" {
    let radar_count = model.values.length()
    if radar_count > 0 {
      let cx = left + plot_width / 2.0
      let cy = plot_top + plot_height / 2.0
      let radar_radius = Double::min(plot_width, plot_height) / 2.0
      let peak = Double::max(top, 0.000001)
      for ring in [0.25, 0.5, 0.75, 1.0] {
        let ring_coordinates : Array[Double] = []
        for index in 0..<radar_count {
          let angle = -3.141592653589793 / 2.0 +
            2.0 * 3.141592653589793 * index.to_double() /
            radar_count.to_double()
          ring_coordinates.push(cx + @math.cos(angle) * radar_radius * ring)
          ring_coordinates.push(cy + @math.sin(angle) * radar_radius * ring)
        }
        object.line(0.5F, 0, 0, 8.0F)
        object.stroke_color(0xd9d9d9ffU)
        let ring_verbs : Array[Byte] = [0]
        for _ in 1..<radar_count {
          ring_verbs.push(1)
        }
        ring_verbs.push(4)
        object.stroke_path(
          object.add_path(
            @core.Inline({
              verbs: Bytes::from_array(ring_verbs),
              coordinates: ring_coordinates,
            }),
          ),
        )
      }
      for index in 0..<radar_count {
        let angle = -3.141592653589793 / 2.0 +
          2.0 * 3.141592653589793 * index.to_double() /
          radar_count.to_double()
        object.line(0.5F, 0, 0, 8.0F)
        object.stroke_color(0xd9d9d9ffU)
        object.stroke_path(
          object.add_path(
            @core.Inline({
              verbs: Bytes::from_array([0, 1]),
              coordinates: [
                cx,
                cy,
                cx + @math.cos(angle) * radar_radius,
                cy + @math.sin(angle) * radar_radius,
              ],
            }),
          ),
        )
      }
      let verbs : Array[Byte] = [0]
      let coordinates : Array[Double] = []
      for index, value in model.values {
        let angle = -3.141592653589793 / 2.0 +
          2.0 * 3.141592653589793 * index.to_double() /
          radar_count.to_double()
        let rr = radar_radius * Double::max(value, 0.0) / peak
        verbs.push(1)
        coordinates.push(cx + @math.cos(angle) * rr)
        coordinates.push(cy + @math.sin(angle) * rr)
      }
      verbs.push(4)
      object.fill_color(series_color)
      object.fill_path(
        object.add_path(
          @core.Inline({ verbs: Bytes::from_array(verbs), coordinates }),
        ),
        0,
      )
    }
  } else if model.kind == "barChart" {
    object.fill_color(series_color)
    for index, value in model.values {
      let bar_height = plot_height * (value - axis_base) / axis_range
      object.fill_rect(
        Float::from_double(left + slot * index.to_double() + slot * 0.2),
        Float::from_double(plot_top + plot_height - bar_height),
        Float::from_double(slot * 0.6),
        Float::from_double(bar_height),
      )
      let label_text = xlsx_chart_data_label(model, index, value)
      if label_text != "" {
        let mut advance = 0.0
        for character in label_text {
          advance += @sheet.sized_fallback_advance(character, false, 10.0)
        }
        let label_y = match model.label_position {
          "ctr" => plot_top + plot_height - bar_height / 2.0 + 3.0
          "inEnd" => plot_top + plot_height - bar_height + 11.0
          "inBase" => plot_top + plot_height - 3.0
          _ => plot_top + plot_height - bar_height - 14.0
        }
        label(
          label_text,
          left + slot * index.to_double() + slot * 0.5 - advance / 2.0,
          label_y,
          10.0,
          400,
        )
      }
    }
  } else {
    object.line(2.0F, 0, 0, 8.0F)
    object.stroke_color(series_color)
    let verbs : Array[Byte] = [0]
    let coordinates : Array[Double] = []
    for index, value in model.values {
      if index > 0 {
        verbs.push(1)
      }
      let x = if count <= 1 {
        left + plot_width / 2.0
      } else {
        left + plot_width * index.to_double() / (count - 1).to_double()
      }
      let y = plot_top + plot_height -
        plot_height * (value - axis_base) / axis_range
      coordinates.push(x)
      coordinates.push(y)
    }
    let path = object.add_path(
      @core.Inline({ verbs: Bytes::from_array(verbs), coordinates }),
    )
    object.stroke_path(path)
    if model.marker != "none" {
      let marker_half = model.marker_size / 2.0
      for index, value in model.values {
        let x = if count <= 1 {
          left + plot_width / 2.0
        } else {
          left + plot_width * index.to_double() / (count - 1).to_double()
        }
        let y = plot_top + plot_height -
          plot_height * (value - axis_base) / axis_range
        object.fill_color(series_color)
        if model.marker == "diamond" || model.marker == "triangle" {
          let coordinates : Array[Double] = if model.marker == "diamond" {
            [
              x, y - marker_half, x + marker_half, y, x, y + marker_half,
              x - marker_half, y, x, y - marker_half,
            ]
          } else {
            [
              x, y - marker_half, x + marker_half, y + marker_half,
              x - marker_half, y + marker_half, x, y - marker_half,
            ]
          }
          object.fill_path(
            object.add_path(
              @core.Inline({
                verbs: Bytes::from_array([0, 1, 1, 1, 1, 4]),
                coordinates,
              }),
            ),
            0,
          )
        } else if model.marker == "square" {
          object.fill_rect(
            Float::from_double(x - marker_half),
            Float::from_double(y - marker_half),
            Float::from_double(model.marker_size),
            Float::from_double(model.marker_size),
          )
        } else if model.marker == "x" || model.marker == "plus" ||
          model.marker == "star" {
          object.line(1.5F, 0, 0, 8.0F)
          object.stroke_color(series_color)
          let segments : Array[Array[Double]] = if model.marker == "x" {
            [
              [x - marker_half, y - marker_half, x + marker_half, y + marker_half],
              [x - marker_half, y + marker_half, x + marker_half, y - marker_half],
            ]
          } else if model.marker == "plus" {
            [
              [x, y - marker_half, x, y + marker_half],
              [x - marker_half, y, x + marker_half, y],
            ]
          } else {
            [
              [x - marker_half, y - marker_half, x + marker_half, y + marker_half],
              [x - marker_half, y + marker_half, x + marker_half, y - marker_half],
              [x, y - marker_half, x, y + marker_half],
              [x - marker_half, y, x + marker_half, y],
            ]
          }
          for segment in segments {
            object.stroke_path(
              object.add_path(
                @core.Inline({
                  verbs: Bytes::from_array([0, 1]),
                  coordinates: segment,
                }),
              ),
            )
          }
        } else {
          object.fill_path(
            object.add_path(
              @core.Inline(xlsx_chart_circle_path(x, y, marker_half)),
            ),
            0,
          )
        }
      }
    }
    for index, value in model.values {
      let label_text = xlsx_chart_data_label(model, index, value)
      if label_text != "" {
        let x = if count <= 1 {
          left + plot_width / 2.0
        } else {
          left + plot_width * index.to_double() / (count - 1).to_double()
        }
        let y = plot_top + plot_height -
          plot_height * (value - axis_base) / axis_range
        let mut advance = 0.0
        for character in label_text {
          advance += @sheet.sized_fallback_advance(character, false, 10.0)
        }
        let label_y = match model.label_position {
          "ctr" => y + 3.0
          "inBase" => y - 11.0
          _ => y - 14.0
        }
        label(label_text, x - advance / 2.0, label_y, 10.0, 400)
      }
    }
  }
  let pie_total = model.values.fold(init=0.0, (sum, value) => sum + value)
  if xlsx_chart_is_pie(model.kind) && pie_total > 0.0 {
    let cx = left + plot_width / 2.0
    let cy = plot_top + plot_height / 2.0
    let radius = Double::min(plot_width, plot_height) / 2.0
    let mut angle = -3.141592653589793 / 2.0 + model.first_slice_ang * 3.141592653589793 / 180.0
    for index, value in model.values {
      let sweep = 2.0 * 3.141592653589793 * value / pie_total
      let mid = angle + sweep / 2.0
      let explosion = if index < model.explosions.length() {
        model.explosions[index] / 100.0 * radius
      } else {
        0.0
      }
      let sx = cx + @math.cos(mid) * explosion
      let sy = cy + @math.sin(mid) * explosion
      if index < model.categories.length() {
        let category = model.categories[index]
        let category_radius = match model.label_position {
          "ctr" | "inEnd" => radius * 0.75
          _ => radius * 1.12
        }
        if model.leader_lines && category_radius > radius {
          object.line(0.75F, 0, 0, 8.0F)
          object.stroke_color(0x808080ffU)
          object.stroke_path(
            object.add_path(
              @core.Inline({
                verbs: Bytes::from_array([0, 1]),
                coordinates: [
                  sx + @math.cos(mid) * radius,
                  sy + @math.sin(mid) * radius,
                  sx + @math.cos(mid) * category_radius,
                  sy + @math.sin(mid) * category_radius,
                ],
              }),
            ),
          )
        }
        let mut advance = 0.0
        for character in category {
          advance += @sheet.sized_fallback_advance(character, false, 10.0)
        }
        label(
          category,
          sx + @math.cos(mid) * category_radius - advance / 2.0,
          sy + @math.sin(mid) * category_radius + 3.0,
          10.0,
          400,
        )
      }
      let label_text = xlsx_chart_data_label(model, index, value)
      if label_text != "" {
        let data_radius = if model.label_position == "outEnd" {
          radius * 0.85
        } else {
          radius * 0.55
        }
        let mut advance = 0.0
        for character in label_text {
          advance += @sheet.sized_fallback_advance(character, false, 10.0)
        }
        label(
          label_text,
          sx + @math.cos(mid) * data_radius - advance / 2.0,
          sy + @math.sin(mid) * data_radius + 3.0,
          10.0,
          400,
        )
      }
      angle += sweep
    }
  } else {
    for index, category in model.categories {
      let mut advance = 0.0
      for character in category {
        advance += @sheet.sized_fallback_advance(character, false, 10.0)
      }
      label(
        category,
        left + slot * index.to_double() + slot * 0.5 - advance / 2.0,
        plot_top + plot_height + 14.0,
        10.0,
        400,
      )
    }
  }
  if model.value_title != "" && !xlsx_chart_is_pie(model.kind) {
    label(model.value_title, 4.0, plot_top + plot_height / 2.0, 11.0, 400)
  }
  if model.category_title != "" && !xlsx_chart_is_pie(model.kind) {
    let mut advance = 0.0
    for character in model.category_title {
      advance += @sheet.sized_fallback_advance(character, false, 11.0)
    }
    label(
      model.category_title,
      left + (plot_width - advance) / 2.0,
      height - 6.0,
      11.0,
      400,
    )
  }
  object
}
