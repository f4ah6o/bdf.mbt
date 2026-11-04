///|
priv struct DocxScrollLine {
  items : Array[DocxLineItem]
  images : Array[DocxPlacedImage]
  height : Double
  width : Double
  align : String
  fills : Array[(Double, Double, Double, Double, UInt32)]
  rules : Array[(Double, Double, Double, Double, Double, UInt32)]
}

///|
fn docx_scroll_merge(items : Array[DocxLineItem]) -> Array[DocxLineItem] {
  let merged : Array[DocxLineItem] = []
  for item in items {
    let join = match merged.last() {
      Some(last) =>
        last.kind == "text" &&
        item.kind == "text" &&
        last.font == item.font &&
        last.weight == item.weight &&
        last.style == item.style &&
        last.size == item.size &&
        last.color == item.color &&
        (item.x - (last.x + last.advance)).abs() < 0.25
      None => false
    }
    if join {
      let last = merged[merged.length() - 1]
      merged[merged.length() - 1] = {
        ..last,
        text: last.text + item.text,
        advance: last.advance + item.advance,
      }
    } else {
      merged.push(item)
    }
  }
  merged
}

///|
fn docx_scroll_draw(
  writer : @core.DocumentWriter,
  package : @ooxml.OoxmlPackage,
  part : String,
  warnings : Array[String],
  lines : Array[DocxScrollLine],
  width : Double,
  height : Double,
  strip_index : Int32,
  index_runs : Array[@core.IndexRun],
) -> Json raise {
  let object = @core.ObjectBuilder::new()
  object.set_bbox(
    0.0F,
    0.0F,
    Float::from_double(width),
    Float::from_double(height),
  )
  let fonts : Map[String, Int32] = Map([])
  let ctx : DocxEmitContext = {
    object,
    writer,
    package,
    part,
    fonts,
    warnings,
    bookmark_pages: Map([]),
    field_value: fn(_, _) { "" },
  }
  let mut y = 0.0
  for line in lines {
    for fill in line.fills {
      let (x, fy, fw, fh, color) = fill
      object.fill_color(color)
      object.fill_rect(
        Float::from_double(x),
        Float::from_double(y + fy),
        Float::from_double(fw),
        Float::from_double(fh),
      )
    }
    for rule in line.rules {
      let (x0, ry0, x1, ry1, rule_width, color) = rule
      let border : DocxLineBorder? = Some({ width: rule_width, color, })
      docx_draw_rule(ctx, border, x0, y + ry0, x1, y + ry1)
    }
    let runs = docx_scroll_merge(line.items)
    if !runs.is_empty() {
      let mut text_width = 0.0
      for item in runs {
        if item.x + item.advance > text_width {
          text_width = item.x + item.advance
        }
      }
      let offset = match line.align {
        "right" => Double::max(0.0, line.width - text_width)
        "center" => Double::max(0.0, (line.width - text_width) / 2.0)
        _ => 0.0
      }
      for item in runs {
        let text = if item.kind == "field" { "" } else { item.text }
        let advance = if item.kind == "field" {
          docx_text_width(text, item.size)
        } else {
          item.advance
        }
        let key = item.font +
          "|" +
          item.weight.to_string() +
          "|" +
          item.style.to_string()
        let index = match fonts.get(key) {
          Some(value) => value
          None => {
            let value = object.add_font({
              hash: None,
              family: item.font,
              weight: item.weight,
              style: item.style,
            })
            fonts[key] = value
            value
          }
        }
        object.font(index, Float::from_double(item.size))
        object.fill_color(item.color)
        object.fill_text(
          text,
          Float::from_double(offset + item.x),
          Float::from_double(y + item.size),
          Float::from_double(advance),
        )
      }
    }
    for image in line.images {
      docx_emit_placed_image(
        object, writer, package, part, image, 0.0, y, warnings,
      )
    }
    y += line.height
  }
  let encoded = object.encode()
  let hash = writer.add_part("obj", encoded)
  let budget = @render.TextExtractionBudget::new()
  let content = @render.extract_text_with_budget(
    @core.decode_object_resources(encoded),
    fn(_) { None },
    budget,
  ) catch {
    _ => { runs: [], links: [], nodes: [], }
  }
  for i, run in content.runs {
    index_runs.push({
      a: strip_index,
      b: 0,
      ordinal: run.ordinal,
      separator: if i == 0 {
        2
      } else {
        run.separator
      },
      text: run.text,
    })
  }
  Json::object({
    "w": Json::number(width, repr=width.to_string()),
    "h": Json::number(height, repr=height.to_string()),
    "layers": Json::array([
      Json::object({ "role": Json::string("body"), "obj": Json::string(hash) }),
    ]),
  })
}

///|
fn docx_scroll_sort_boundaries(values : Array[Double]) -> Array[Double] {
  let sorted : Array[Double] = []
  for value in values {
    let mut index = sorted.length()
    while index > 0 && sorted[index - 1] > value {
      index -= 1
    }
    if index < sorted.length() && (sorted[index] - value).abs() < 0.01 {
      continue
    }
    sorted.insert(index, value)
  }
  sorted
}

///|
fn docx_scroll_rule(
  line : DocxScrollLine,
  border : DocxLineBorder?,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> Unit {
  match border {
    Some(value) => line.rules.push((x0, y0, x1, y1, value.width, value.color))
    None => ()
  }
}

///|
fn docx_scroll_table_row(
  lines : Array[DocxScrollLine],
  layout : DocxTableLayout,
  row_index : Int32,
  x_origin : Double,
) -> Unit {
  let table = layout.table
  let row = table.rows[row_index]
  let row_layout = layout.rows[row_index]
  let entries : Array[(Double, Double, DocxParaLine)] = []
  for cell_index, cell in row.cells {
    if cell.vmerge == "continue" {
      continue
    }
    let cell_layout = row_layout.cells[cell_index]
    for block in cell_layout.blocks {
      match block {
        DocxCellLines(cell_lines) =>
          for positioned in cell_lines {
            entries.push(
              (
                cell_layout.mar_top + positioned.y,
                x_origin + layout.left + cell_layout.x + cell_layout.mar_left,
                positioned.line,
              ),
            )
          }
        DocxCellAnchors(_) => ()
        DocxCellNested(_) => ()
      }
    }
  }
  let boundaries : Array[Double] = [0.0, row_layout.height]
  for entry in entries {
    let (top, _, line) = entry
    boundaries.push(top)
    boundaries.push(Double::min(top + line.height, row_layout.height))
  }
  let sorted = docx_scroll_sort_boundaries(boundaries)
  for i in 0..<(sorted.length() - 1) {
    let top = sorted[i]
    let next = sorted[i + 1]
    let height = next - top
    if height < 0.01 {
      continue
    }
    let items : Array[DocxLineItem] = []
    let images : Array[DocxPlacedImage] = []
    for entry in entries {
      let (entry_top, cell_x, line) = entry
      if (entry_top - top).abs() < 0.01 {
        for item in line.items {
          items.push({ ..item, x: item.x + cell_x, })
        }
        for image in line.images {
          images.push({ ..image, x: image.x + cell_x, })
        }
      }
    }
    let scroll_line : DocxScrollLine = {
      items,
      images,
      height,
      width: layout.total_width,
      align: "left",
      fills: [],
      rules: [],
    }
    for cell_index, cell in row.cells {
      if cell.vmerge == "continue" {
        continue
      }
      let cell_layout = row_layout.cells[cell_index]
      let bx = x_origin + layout.left + cell_layout.x
      let shade = match cell.shade {
        Some(color) => Some(color)
        None => table.shade
      }
      match shade {
        Some(color) =>
          scroll_line.fills.push((bx, 0.0, cell_layout.w, height, color))
        None => ()
      }
      let top_border = if top <= 0.01 {
        docx_table_border_for(layout, row_index, cell, 0)
      } else {
        None
      }
      let bottom_border = if next >= row_layout.height - 0.01 {
        docx_table_border_for(layout, row_index, cell, 2)
      } else {
        None
      }
      let left_border = docx_table_border_for(layout, row_index, cell, 1)
      let right_border = docx_table_border_for(layout, row_index, cell, 3)
      docx_scroll_rule(
        scroll_line,
        top_border,
        bx,
        0.0,
        bx + cell_layout.w,
        0.0,
      )
      docx_scroll_rule(
        scroll_line,
        bottom_border,
        bx,
        height,
        bx + cell_layout.w,
        height,
      )
      docx_scroll_rule(scroll_line, left_border, bx, 0.0, bx, height)
      docx_scroll_rule(
        scroll_line,
        right_border,
        bx + cell_layout.w,
        0.0,
        bx + cell_layout.w,
        height,
      )
    }
    lines.push(scroll_line)
  }
}

///|
fn docx_scroll_note_lines(
  document : DocxTextDocument,
  width : Double,
) -> Array[String] {
  let note_ids : Array[String] = []
  for id, _lines in document.footnotes {
    note_ids.push(id)
  }
  for id, _lines in document.endnotes {
    note_ids.push(id)
  }
  for i in 1..<note_ids.length() {
    let mut j = i
    while j > 0 {
      let left = @string.parse_int(note_ids[j]) catch { _ => 0 }
      let right = @string.parse_int(note_ids[j - 1]) catch { _ => 0 }
      if left < right {
        let tmp = note_ids[j]
        note_ids[j] = note_ids[j - 1]
        note_ids[j - 1] = tmp
        j -= 1
      } else {
        break
      }
    }
  }
  let out : Array[String] = []
  for id in note_ids {
    let source = match document.footnotes.get(id) {
      Some(value) => Some(value)
      None => document.endnotes.get(id)
    }
    let note_lines = match source {
      Some(value) => value
      None => []
    }
    let mut first = true
    for text in note_lines {
      let prefix = if first { id + ". " } else { "" }
      first = false
      for wrapped in docx_wrap_note(prefix + text, width, 8.5) {
        out.push(wrapped)
      }
    }
  }
  out
}

///|
/// Lay the body text out once more as the page-free scroll view upstream
/// produces: one column of the text width, cut into strips between lines.
fn docx_render_scroll(
  document : DocxTextDocument,
  writer : @core.DocumentWriter,
  package : @ooxml.OoxmlPackage,
) -> (Array[Json], Array[@core.IndexRun], Int32) raise {
  let warnings : Array[String] = []
  let mut body_width = 0.0
  for section in document.sections {
    let width = section.width - section.left - section.right
    if width > body_width {
      body_width = width
    }
  }
  if body_width <= 0.0 {
    body_width = 451.0
  }
  let pad = 36.0
  let strip_width = body_width + pad * 2.0
  let lines : Array[DocxScrollLine] = []
  let blank_height = 12.0
  lines.push({
    items: [],
    images: [],
    height: pad,
    width: body_width,
    align: "left",
    fills: [],
    rules: [],
  })
  for block in document.blocks {
    match block {
      DocxParaBlock(paragraph) => {
        let section = docx_section_at(document, paragraph.section_index)
        let pitch = docx_section_grid_pitch(section)
        if paragraph.props.before > 0.0 {
          lines.push({
            items: [],
            images: [],
            height: paragraph.props.before,
            width: body_width,
            align: "left",
            fills: [],
            rules: [],
          })
        }
        let mark_size = if paragraph.mark.size > 0.0 {
          paragraph.mark.size
        } else {
          blank_height / 1.2
        }
        let layout = docx_layout_paragraph(
          paragraph.items,
          paragraph.props,
          body_width,
          pitch,
          mark_size,
          false,
        )
        for line in layout.lines {
          let items : Array[DocxLineItem] = []
          for item in line.items {
            items.push({ ..item, x: item.x + pad, })
          }
          let images : Array[DocxPlacedImage] = []
          for image in line.images {
            images.push({ ..image, x: image.x + pad, })
          }
          lines.push({
            items,
            images,
            height: line.height,
            width: body_width,
            align: line.align,
            fills: [],
            rules: [],
          })
        }
        if paragraph.props.after > 0.0 {
          lines.push({
            items: [],
            images: [],
            height: paragraph.props.after,
            width: body_width,
            align: "left",
            fills: [],
            rules: [],
          })
        }
      }
      DocxTableBlock(table) => {
        let section = docx_section_at(document, table.section_index)
        let layout = docx_layout_table(
          table,
          body_width,
          docx_section_grid_pitch(section),
        )
        for row_index, _row in layout.rows {
          docx_scroll_table_row(lines, layout, row_index, pad)
        }
      }
    }
  }
  let note_lines = docx_scroll_note_lines(document, body_width)
  if !note_lines.is_empty() {
    lines.push({
      items: [],
      images: [],
      height: 8.0,
      width: body_width,
      align: "left",
      fills: [],
      rules: [],
    })
    for text in note_lines {
      lines.push({
        items: [
          {
            kind: "text",
            text,
            link: "",
            field_format: "",
            font: "sans-serif",
            weight: 400,
            style: 0,
            size: 8.5,
            color: 0x000000ffU,
            rise: 0.0,
            underline: "",
            strike: false,
              emphasis: "",
            x: pad,
            advance: docx_text_width(text, 8.5),
            shade: None,
            border_width: 0.0,
            border_color: None,
          },
        ],
        images: [],
        height: 10.2,
        width: body_width,
        align: "left",
        fills: [],
        rules: [],
      })
    }
  }
  lines.push({
    items: [],
    images: [],
    height: pad,
    width: body_width,
    align: "left",
    fills: [],
    rules: [],
  })
  let pages : Array[Json] = []
  let index_runs : Array[@core.IndexRun] = []
  let mut total = 0.0
  for line in lines {
    total += line.height
  }
  // Cuts at stripHeight move up to a line boundary; the last strip may be
  // somewhat taller (upstream cuts only while 1.25 strips are left).
  let cuts : Array[Double] = [0.0]
  let mut cut = 0.0
  for _ in 0..<100000 {
    if cut + 1280.0 >= total {
      break
    }
    let target = cut + 1024.0
    let mut spot = target
    for _ in 0..<20 {
      let mut moved = false
      let mut top = 0.0
      for line in lines {
        let bottom = top + line.height
        if top < spot - 0.01 && bottom > spot + 0.01 {
          spot = top
          moved = true
        }
        top = bottom
      }
      if !moved {
        break
      }
    }
    if spot <= cut + 1.0 {
      spot = target
    }
    cuts.push(spot)
    cut = spot
  }
  cuts.push(Double::max(total, 1.0))
  let mut strip_index : Int32 = 0
  for index in 0..<(cuts.length() - 1) {
    let start = cuts[index]
    let end = cuts[index + 1]
    let strip : Array[DocxScrollLine] = []
    let mut top = 0.0
    for line in lines {
      let bottom = top + line.height
      if top >= start - 0.01 && bottom <= end + 0.01 {
        strip.push(line)
      }
      top = bottom
    }
    let height = Double::max(1.0, end - start)
    let page = docx_scroll_draw(
      writer,
      package,
      document.part,
      warnings,
      strip,
      strip_width,
      height,
      strip_index,
      index_runs,
    )
    pages.push(page)
    strip_index += 1
  }
  if pages.is_empty() {
    let page = docx_scroll_draw(
      writer,
      package,
      document.part,
      warnings,
      [],
      strip_width,
      1.0,
      0,
      index_runs,
    )
    pages.push(page)
  }
  (pages, index_runs, pages.length())
}
