///|
priv struct DocxScrollLine {
  items : Array[DocxLineItem]
  mut height : Double
  width : Double
  align : String
}

///|
fn docx_scroll_line_height(items : Array[DocxLineItem]) -> Double {
  let mut height = 12.0
  for item in items {
    if item.size * 1.2 > height {
      height = item.size * 1.2
    }
  }
  height
}

///|
fn docx_scroll_push_line(
  lines : Array[DocxScrollLine],
  items : Array[DocxLineItem],
  width : Double,
  align : String,
) -> Unit {
  let height = docx_scroll_line_height(items)
  lines.push({ items, height, width, align })
}

///|
fn docx_scroll_merge(items : Array[DocxLineItem]) -> Array[DocxLineItem] {
  let merged : Array[DocxLineItem] = []
  for item in items {
    let join = match merged.last() {
      Some(last) =>
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
  lines : Array[DocxScrollLine],
  width : Double,
  height : Double,
  strip_index : Int32,
  index_runs : Array[@core.IndexRun],
) -> Json raise {
  let object = @core.ObjectBuilder::new()
  object.set_bbox(0.0F, 0.0F, Float::from_double(width), Float::from_double(height))
  let fonts : Map[String, Int32] = Map([])
  let mut y = 0.0
  for line in lines {
    let runs = docx_scroll_merge(line.items)
    if !runs.is_empty() {
      let line_width = runs[runs.length() - 1].x +
        runs[runs.length() - 1].advance
      let offset = match line.align {
        "right" => Double::max(0.0, line.width - line_width)
        "center" => Double::max(0.0, (line.width - line_width) / 2.0)
        _ => 0.0
      }
      for item in runs {
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
          item.text,
          Float::from_double(offset + item.x),
          Float::from_double(y + item.size),
          Float::from_double(item.advance),
        )
      }
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
      separator: if i == 0 { 2 } else { run.separator },
      text: run.text,
    })
  }
  Json::object({
    "w": Json::number(width, repr=width.to_string()),
    "h": Json::number(height, repr=height.to_string()),
    "layers": Json::array([
      Json::object({
        "role": Json::string("body"),
        "obj": Json::string(hash),
      }),
    ]),
  })
}

///|
/// Lay the body text out once more as the page-free scroll view upstream
/// produces. Headers and footers are not repeated; long strips are cut
/// between lines.
fn docx_render_scroll(
  document : DocxTextDocument,
  writer : @core.DocumentWriter,
) -> (Array[Json], Array[@core.IndexRun], Int32) raise {
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
  let lines : Array[DocxScrollLine] = []
  for paragraph in document.paragraphs {
    let section = docx_section_at(document, paragraph.section_index)
    let width = Double::min(
      body_width,
      section.width - section.left - section.right,
    )
    let props = paragraph.props
    if props.before > 0.0 {
      docx_scroll_push_line(
        lines,
        [],
        width,
        "left",
      )
      lines[lines.length() - 1].height = props.before
    }
    let line : Array[DocxLineItem] = []
    let mut line_x = props.left
    let mut line_height = 12.0
    for item in paragraph.items {
      match item.kind {
        "page" | "column" => {
          docx_scroll_push_line(lines, line.copy(), width, props.alignment)
          line.clear()
          line_x = props.left
        }
        "break" => {
          docx_scroll_push_line(lines, line.copy(), width, props.alignment)
          line.clear()
          line_x = props.left
        }
        "tab" => {
          let relative = line_x - props.left
          let mut next = 0.0
          for stop in props.tabs {
            if stop.position > relative {
              next = stop.position
              break
            }
          }
          if next == 0.0 {
            next = docx_round_up(relative / 36.0) * 36.0
            if next <= relative {
              next += 36.0
            }
          }
          let advance = Double::max(0.0, next - relative)
          line.push({
            text: " ",
            font: "monospace",
            weight: 400,
            style: 0,
            size: Double::max(8.0, line_height / 1.2),
            color: 0x000000ffU,
            x: line_x - props.left,
            advance,
            shade: None,
            border_width: 0.0,
            border_color: None,
          })
          line_x += advance
        }
        "image" | "cell" => ()
        _ => {
          let size = if item.props.size > 0.0 { item.props.size } else { 10.0 }
          let advance = docx_text_width(item.text, size)
          if line_x + advance > props.left + width && !line.is_empty() {
            docx_scroll_push_line(
              lines, line.copy(), width, props.alignment,
            )
            line.clear()
            line_x = props.left
            line_height = 12.0
          }
          if line.is_empty() {
            line_height = size * 1.2
          }
          line.push({
            text: item.text,
            font: docx_font_family(item.props),
            weight: docx_font_weight(item.props),
            style: docx_font_style(item.props),
            size,
            color: docx_run_color(item.props),
            x: line_x - props.left,
            advance,
            shade: item.shade,
            border_width: item.border_width,
            border_color: item.border_color,
          })
          line_x += advance
        }
      }
    }
    docx_scroll_push_line(lines, line.copy(), width, props.alignment)
    line.clear()
    if props.after > 0.0 {
      docx_scroll_push_line(lines, [], width, "left")
      lines[lines.length() - 1].height = props.after
    }
  }
  let pages : Array[Json] = []
  let index_runs : Array[@core.IndexRun] = []
  let strip : Array[DocxScrollLine] = []
  let mut strip_height = 0.0
  let mut strip_index : Int32 = 0
  let flush = fn() -> Unit raise {
    if strip.is_empty() {
      return
    }
    let height = Double::max(1.0, strip_height)
    let page = docx_scroll_draw(
      writer, strip, body_width, height, strip_index, index_runs,
    )
    pages.push(page)
    strip.clear()
    strip_height = 0.0
    strip_index += 1
  }
  for line in lines {
    if strip_height + line.height > 1000.0 && !strip.is_empty() {
      flush()
    }
    strip.push(line)
    strip_height += line.height
  }
  flush()
  if pages.is_empty() {
    let page = docx_scroll_draw(
      writer, [], body_width, 1.0, 0, index_runs,
    )
    pages.push(page)
  }
  (pages, index_runs, pages.length())
}
