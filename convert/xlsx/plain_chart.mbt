
///|
struct XlsxChartModel {
  title : String
  kind : String
  series_name : String
  values : Array[Double]
  categories : Array[String]
  color : String
  axis_min : Double
  axis_max : Double
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
  match xlsx_draw_child(chart, "title") {
    Some(title_node) => title = xlsx_draw_all_text(title_node).trim().to_string()
    None => ()
  }
  let plot_area = match xlsx_draw_child(chart, "plotArea") {
    Some(value) => value
    None => return None
  }
  let mut kind = ""
  let mut plot : XlsxDrawNode? = None
  for name in ["barChart", "lineChart", "pieChart"] {
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
    kind,
    series_name,
    values,
    categories,
    color,
    axis_min,
    axis_max,
  })
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
      "\" y=\"20\" text-anchor=\"middle\" font-size=\"14\" font-weight=\"bold\" fill=\"#000000\">" +
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
  if model.kind == "pieChart" {
    let total = model.values.fold(init=0.0, (sum, value) => sum + value)
    if total > 0.0 {
      let cx = left + plot_width / 2.0
      let cy = plot_top + plot_height / 2.0
      let radius = Double::min(plot_width, plot_height) / 2.0
      let palette = [
        "#4472c4", "#ed7d31", "#a5a5a5", "#ffc000", "#5b9bd5", "#70ad47",
      ]
      let mut angle = -3.141592653589793 / 2.0
      for index, value in model.values {
        let sweep = 2.0 * 3.141592653589793 * value / total
        let end = angle + sweep
        let x1 = cx + @math.cos(angle) * radius
        let y1 = cy + @math.sin(angle) * radius
        let x2 = cx + @math.cos(end) * radius
        let y2 = cy + @math.sin(end) * radius
        let large = if sweep > 3.141592653589793 { 1 } else { 0 }
        svg.write_string(
          "<path d=\"M " +
          cx.to_string() +
          " " +
          cy.to_string() +
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
  if model.kind == "pieChart" && pie_total > 0.0 {
    let cx = left + plot_width / 2.0
    let cy = plot_top + plot_height / 2.0
    let radius = Double::min(plot_width, plot_height) / 2.0
    let mut angle = -3.141592653589793 / 2.0
    for index, value in model.values {
      let sweep = 2.0 * 3.141592653589793 * value / pie_total
      let mid = angle + sweep / 2.0
      let x = cx + @math.cos(mid) * radius * 1.12
      let y = cy + @math.sin(mid) * radius * 1.12
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
      advance += @sheet.sized_fallback_advance(character, true, 14.0)
    }
    label(
      model.title, (width - advance) / 2.0, 20.0, 14.0, 700,
    )
  }
  if model.series_name != "" {
    label(model.series_name, width - 110.0, plot_top + 20.0, 11.0, 400)
  }
  for tick in ticks {
    let y = plot_top + plot_height -
      plot_height * (tick - axis_base) / axis_range
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
  if model.kind == "pieChart" {
    let total = model.values.fold(init=0.0, (sum, value) => sum + value)
    if total > 0.0 {
      let cx = left + plot_width / 2.0
      let cy = plot_top + plot_height / 2.0
      let radius = Double::min(plot_width, plot_height) / 2.0
      let palette = [
        0x4472c4ffU, 0xed7d31ffU, 0xa5a5a5ffU, 0xffc000ffU, 0x5b9bd5ffU,
        0x70ad47ffU,
      ]
      let mut angle = -3.141592653589793 / 2.0
      for index, value in model.values {
        let sweep = 2.0 * 3.141592653589793 * value / total
        let verbs : Array[Byte] = [0]
        let coordinates : Array[Double] = [cx, cy]
        let steps = 24
        for step in 0..<steps {
          let step_angle = angle + sweep * step.to_double() / steps.to_double()
          verbs.push(1)
          coordinates.push(cx + @math.cos(step_angle) * radius)
          coordinates.push(cy + @math.sin(step_angle) * radius)
        }
        verbs.push(1)
        coordinates.push(cx + @math.cos(angle + sweep) * radius)
        coordinates.push(cy + @math.sin(angle + sweep) * radius)
        verbs.push(4)
        object.fill_color(palette[index % palette.length()])
        let path = object.add_path(
          @core.Inline({ verbs: Bytes::from_array(verbs), coordinates }),
        )
        object.fill_path(path, 0)
        angle += sweep
      }
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
  }
  let pie_total = model.values.fold(init=0.0, (sum, value) => sum + value)
  if model.kind == "pieChart" && pie_total > 0.0 {
    let cx = left + plot_width / 2.0
    let cy = plot_top + plot_height / 2.0
    let radius = Double::min(plot_width, plot_height) / 2.0
    let mut angle = -3.141592653589793 / 2.0
    for index, value in model.values {
      let sweep = 2.0 * 3.141592653589793 * value / pie_total
      let mid = angle + sweep / 2.0
      if index < model.categories.length() {
        let category = model.categories[index]
        let mut advance = 0.0
        for character in category {
          advance += @sheet.sized_fallback_advance(character, false, 10.0)
        }
        label(
          category,
          cx + @math.cos(mid) * radius * 1.12 - advance / 2.0,
          cy + @math.sin(mid) * radius * 1.12 + 3.0,
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
  object
}
