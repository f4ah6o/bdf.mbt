///|
/// A reader-mode document conversion failure.
pub suberror ReaderError {
  ReaderInvalid(String)
}

///|
pub(all) struct ReaderRun {
  mut text : String
  upright : Bool
  tcy : Bool
  emphasis : Bool
}

///|
pub fn plain_runs(text : String) -> Array[ReaderRun] {
  if text == "" {
    []
  } else {
    [{ text, upright: false, tcy: false, emphasis: false }]
  }
}

///|
pub fn runs_text(runs : Array[ReaderRun]) -> String {
  let out = StringBuilder()
  for run in runs {
    out.write_string(run.text)
  }
  out.to_string()
}

///|
pub(all) enum ReaderBlock {
  Heading(Int32, Array[ReaderRun])
  Paragraph(Array[ReaderRun], Int32)
  ListItem(Int32, Bool, Array[ReaderRun])
  Code(Array[ReaderRun])
  Quote(Array[ReaderRun])
  Rule
}

///|
pub(all) struct ReaderDocument {
  title : String
  blocks : Array[ReaderBlock]
  vertical : Bool
}

///|
pub(all) struct ReaderOptions {
  width : Double
  height : Double
  margin : Double
  font_size : Double
}

///|
pub fn ReaderOptions::new(
  width~ : Double = 595.0,
  height~ : Double = 842.0,
  margin~ : Double = 72.0,
  font_size~ : Double = 12.0,
) -> ReaderOptions {
  { width, height, margin, font_size }
}

///|
pub(all) struct ReaderLayout {
  pages : Array[Json]
  index_runs : Array[@core.IndexRun]
  warnings : Array[String]
}

///|
priv struct ReaderLine {
  text : String
  size : Double
  indent : Double
  before : Double
  after : Double
  bold : Bool
  mono : Bool
  rule : Bool
}

///|
fn reader_wrap(text : String, width : Double, style : @drawingml.TextStyle) -> Array[String] {
  let lines = @drawingml.wrap_runs([{ text, style }], width, 0)
  let out : Array[String] = []
  for line in lines {
    out.push(line.text)
  }
  if out.is_empty() {
    out.push("")
  }
  out
}

///|
fn reader_lines(document : ReaderDocument, options : ReaderOptions) -> Array[ReaderLine] {
  let lines : Array[ReaderLine] = []
  for block in document.blocks {
    match block {
      Heading(level, runs) => {
        let text = runs_text(runs)
        let size = match level {
          1 => 24.0
          2 => 19.0
          3 => 15.0
          _ => options.font_size + 2.0
        }
        let style = @drawingml.TextStyle::new(size=size, bold=true)
        let wrapped = reader_wrap(text, options.width - options.margin * 2.0, style)
        for i, line in wrapped {
          lines.push({
            text: line,
            size,
            indent: 0.0,
            before: if i == 0 { 14.0 } else { 0.0 },
            after: if i == wrapped.length() - 1 { 8.0 } else { 0.0 },
            bold: true,
            mono: false,
            rule: false,
          })
        }
      }
      Paragraph(runs, _align) => {
        let text = runs_text(runs)
        let style = @drawingml.TextStyle::new(size=options.font_size)
        let wrapped = reader_wrap(text, options.width - options.margin * 2.0, style)
        for i, line in wrapped {
          lines.push({
            text: line,
            size: options.font_size,
            indent: 0.0,
            before: 0.0,
            after: if i == wrapped.length() - 1 { 7.0 } else { 0.0 },
            bold: false,
            mono: false,
            rule: false,
          })
        }
      }
      ListItem(level, ordered, runs) => {
        let text = runs_text(runs)
        let prefix = if ordered { "1. " } else { "• " }
        let style = @drawingml.TextStyle::new(size=options.font_size)
        let indent = 18.0 * (level.to_double() + 1.0)
        let wrapped = reader_wrap(prefix + text, options.width - options.margin * 2.0 - indent, style)
        for i, line in wrapped {
          lines.push({
            text: line,
            size: options.font_size,
            indent,
            before: 0.0,
            after: if i == wrapped.length() - 1 { 2.0 } else { 0.0 },
            bold: false,
            mono: false,
            rule: false,
          })
        }
      }
      Code(runs) => {
        let text = runs_text(runs)
        let code_lines = text.split("\n")
        for i, line in code_lines {
          lines.push({
            text: line.to_string(),
            size: options.font_size - 1.0,
            indent: 12.0,
            before: if i == 0 { 6.0 } else { 0.0 },
            after: if i == code_lines.length() - 1 { 8.0 } else { 0.0 },
            bold: false,
            mono: true,
            rule: false,
          })
        }
      }
      Quote(runs) => {
        let text = runs_text(runs)
        let style = @drawingml.TextStyle::new(size=options.font_size)
        let wrapped = reader_wrap(text, options.width - options.margin * 2.0 - 24.0, style)
        for i, line in wrapped {
          lines.push({
            text: line,
            size: options.font_size,
            indent: 24.0,
            before: 0.0,
            after: if i == wrapped.length() - 1 { 6.0 } else { 0.0 },
            bold: false,
            mono: false,
            rule: false,
          })
        }
      }
      Rule =>
        lines.push({
          text: "",
          size: 1.0,
          indent: 0.0,
          before: 8.0,
          after: 8.0,
          bold: false,
          mono: false,
          rule: true,
        })
    }
  }
  lines
}

///|
/// Lay out a reader document as fixed pages.
pub fn render(
  document : ReaderDocument,
  writer : @core.DocumentWriter,
  options~ : ReaderOptions = ReaderOptions::new(),
) -> ReaderLayout {
  if document.vertical {
    return render_vertical(document, writer, options)
  }
  let lines = reader_lines(document, options)
  let pages : Array[Json] = []
  let index_runs : Array[@core.IndexRun] = []
  let warnings : Array[String] = []
  let mut object = @core.ObjectBuilder::new()
  object.set_bbox(
    0.0F,
    0.0F,
    Float::from_double(options.width),
    Float::from_double(options.height),
  )
  let fonts : Map[String, Int32] = Map([])
  let mut y = options.margin
  let page_lines : Array[String] = []
  let page_runs : Array[@core.IndexRun] = []
  let mut page_number = 0
  let new_page = fn() -> Unit {
    let encoded = object.encode() catch { _ => b"" }
    if encoded.is_empty() {
      return
    }
    let hash = writer.add_part("obj", encoded) catch { _ => "" }
    if hash == "" {
      return
    }
    pages.push(
      Json::object({
        "w": Json::number(options.width, repr=options.width.to_string()),
        "h": Json::number(options.height, repr=options.height.to_string()),
        "layers": Json::array([
          Json::object({
            "role": Json::string("body"),
            "obj": Json::string(hash),
          }),
        ]),
      }),
    )
    object = @core.ObjectBuilder::new()
    object.set_bbox(
      0.0F,
      0.0F,
      Float::from_double(options.width),
      Float::from_double(options.height),
    )
  }
  let draw_line = fn(line : ReaderLine) -> Unit {
    if line.rule {
      object.fill_color(0xccccccffU)
      object.fill_rect(
        Float::from_double(options.margin),
        Float::from_double(y),
        Float::from_double(options.width - options.margin * 2.0),
        0.8F,
      )
      y += line.before + line.after + 1.0
      return
    }
    if line.text == "" {
      y += line.size * 1.5
      return
    }
    let family = if line.mono { "Courier New" } else { "Arial" }
    let key = family + "|" + line.size.round().to_int().to_string() + "|" +
      (if line.bold { "1" } else { "0" })
    let font = match fonts.get(key) {
      Some(index) => index
      None => {
        let index = object.add_font(
          {
            hash: None,
            family,
            weight: if line.bold { 700 } else { 400 },
            style: 0,
          },
        )
        fonts[key] = index
        index
      }
    }
    object.fill_color(0x000000ffU)
    object.font(font, Float::from_double(line.size)) catch { _ => () }
    object.fill_text(
      line.text,
      Float::from_double(options.margin + line.indent),
      Float::from_double(y + line.size),
      0.0F,
    )
    page_lines.push(line.text)
    y += line.before + line.size * 1.5 + line.after
  }
  for line in lines {
    let height = line.size * 1.5
    if y + line.before + height > options.height - options.margin {
      if page_lines.is_empty() {
        // A single line taller than the page still gets a page.
      }
      new_page()
      page_runs.push({
        a: page_number,
        b: 0,
        ordinal: index_runs.length(),
        separator: 2,
        text: page_lines.join("\n"),
      })
      for run in page_runs {
        index_runs.push(run)
      }
      page_lines.clear()
      page_runs.clear()
      page_number += 1
      object.set_bbox(
        0.0F,
        0.0F,
        Float::from_double(options.width),
        Float::from_double(options.height),
      )
      y = options.margin
    }
    draw_line(line)
  }
  if !page_lines.is_empty() || pages.is_empty() {
    new_page()
    page_runs.push({
      a: page_number,
      b: 0,
      ordinal: index_runs.length(),
      separator: 2,
      text: page_lines.join("\n"),
    })
    for run in page_runs {
      index_runs.push(run)
    }
    page_number += 1
  }
  if index_runs.is_empty() {
    warnings.push("reader output has no text")
  }
  { pages, index_runs, warnings, }
}

///|
priv struct VItem {
  text : String
  kind : Int32 // 0 upright, 1 sideways, 2 tcy, 3 gap, 4 rule
  size : Double
  bold : Bool
  extent : Double
  emphasis : Bool
}

///|
priv struct VColumn {
  items : Array[VItem]
  pitch : Double
  mut left : Double
  block : Int32
  align : Int32
  page : Int32
}

///|
fn v_sideways(ch : Char) -> Bool {
  let code = ch.to_int()
  code >= 0x21 && code <= 0x7e
}

///|
fn v_space(ch : Char) -> Bool {
  let code = ch.to_int()
  code == 0x20 || code == 0xa0 || code == 0x3000 || code == 0x200b ||
  code == 0xfeff || (code >= 0x09 && code <= 0x0d)
}

///|
fn v_push_item(items : Array[VItem], item : VItem) -> Unit {
  if item.text == "" && item.kind != 3 && item.kind != 4 {
    return
  }
  items.push(item)
}

///|
fn v_items_for_runs(
  runs : Array[ReaderRun],
  size : Double,
  bold : Bool,
  mono : Bool,
) -> Array[VItem] {
  let items : Array[VItem] = []
  for run in runs {
    if run.text == "" {
      continue
    }
    if run.tcy {
      v_push_item(items, {
        text: run.text,
        kind: 2,
        size,
        bold,
        extent: size,
        emphasis: run.emphasis,
      })
      continue
    }
    let buf = StringBuilder()
    let mut buf_side = false
    let flush_buf = fn() -> Unit {
      let value = buf.to_string()
      buf.reset()
      if value == "" {
        return
      }
      if buf_side {
        v_push_item(items, {
          text: value,
          kind: 1,
          size,
          bold,
          extent: @drawingml.text_width(value, size),
          emphasis: run.emphasis,
        })
      } else {
        for ch in value {
          v_push_item(items, {
            text: ch.to_string(),
            kind: 0,
            size,
            bold,
            extent: size,
            emphasis: run.emphasis,
          })
        }
      }
    }
    for ch in run.text {
      if v_space(ch) {
        flush_buf()
        continue
      }
      let side = !run.upright && v_sideways(ch)
      if buf.to_string() != "" && side != buf_side {
        flush_buf()
      }
      buf_side = side
      buf.write_char(ch)
    }
    flush_buf()
  }
  ignore(mono)
  items
}

///|
fn reader_vertical_columns(
  document : ReaderDocument,
  options : ReaderOptions,
) -> (Array[VColumn], Int32) {
  let text_w = options.width - options.margin * 2.0
  let capacity = options.height - options.margin * 2.0
  let columns : Array[VColumn] = []
  let mut block_id = 0
  let mut page = 0
  let mut cursor = options.width - options.margin
  let mut y = options.margin
  let mut col_items : Array[VItem] = []
  let mut col_pitch = 0.0
  let mut col_block = 0
  let mut col_align = 0
  let new_column = fn(force : Bool) -> Unit {
    if col_items.is_empty() && !force {
      return
    }
    if !col_items.is_empty() {
      if cursor - col_pitch < options.margin {
        page += 1
        cursor = options.width - options.margin
      }
      let left = if col_pitch > text_w {
        options.margin
      } else {
        cursor - col_pitch
      }
      columns.push({
        items: col_items,
        pitch: col_pitch,
        left,
        block: col_block,
        align: col_align,
        page,
      })
      cursor = left
    }
    col_items = []
    col_pitch = 0.0
    y = options.margin
  }
  let add_item = fn(item : VItem, align : Int32) -> Unit {
    if item.kind == 3 {
      y += item.extent
      return
    }
    if item.kind == 4 {
      if y + item.extent > options.margin + capacity {
        new_column(false)
      }
      col_items.push(item)
      col_pitch = Double::max(col_pitch, item.size * 1.2)
      y += item.extent
      return
    }
    if y + item.extent > options.margin + capacity && !col_items.is_empty() {
      new_column(false)
    }
    col_items.push(item)
    col_pitch = Double::max(col_pitch, item.size * 1.2)
    y += item.extent
  }
  for block in document.blocks {
    block_id += 1
    col_block = block_id
    let (runs, size, bold, mono, before, after, align) = match block {
      Heading(level, runs) => (
        runs,
        match level {
          1 => 24.0
          2 => 19.0
          3 => 15.0
          _ => options.font_size + 2.0
        },
        true,
        false,
        14.0,
        8.0,
        0,
      )
      Paragraph(runs, align) => (runs, options.font_size, false, false, 0.0, 7.0, align)
      ListItem(_, _, runs) => (runs, options.font_size, false, false, 0.0, 2.0, 0)
      Code(runs) => (runs, options.font_size - 1.0, false, true, 6.0, 8.0, 0)
      Quote(runs) => (runs, options.font_size, false, false, 0.0, 6.0, 0)
      Rule => ([], 1.0, false, false, 8.0, 8.0, 0)
    }
    col_align = align
    let is_rule = match block {
      Rule => true
      _ => false
    }
    if is_rule {
      add_item({
        text: "",
        kind: 4,
        size: 1.0,
        bold: false,
        extent: 1.0,
        emphasis: false,
      }, align)
      continue
    }
    if before > 0.0 {
      add_item({
        text: "",
        kind: 3,
        size: 1.0,
        bold: false,
        extent: before,
        emphasis: false,
      }, align)
    }
    let items = v_items_for_runs(runs, size, bold, mono)
    for i, item in items {
      let is_last = i == items.length() - 1
      add_item(item, align)
      if is_last && after > 0.0 {
        add_item({
          text: "",
          kind: 3,
          size: 1.0,
          bold: false,
          extent: after,
          emphasis: false,
        }, align)
      }
    }
    if items.is_empty() && before == 0.0 && after == 0.0 {
      continue
    }
  }
  new_column(true)
  // Center or end-align groups that fit on one page.
  let text_w2 = options.width - options.margin * 2.0
  let mut i = 0
  while i < columns.length() {
    let align = columns[i].align
    if align == 0 {
      i += 1
      continue
    }
    let block = columns[i].block
    let mut j = i
    let mut width = 0.0
    while j < columns.length() && columns[j].block == block &&
          columns[j].page == columns[i].page {
      width += columns[j].pitch
      j += 1
    }
    let mut left = columns[i].left
    for k in (i + 1)..<j {
      left = Double::min(left, columns[k].left)
    }
    let desired = if align == 1 {
      options.margin + (text_w2 - width) / 2.0
    } else {
      options.margin
    }
    if width <= text_w2 && desired >= options.margin - 0.01 {
      let delta = desired - left
      for k in i..<j {
        columns[k].left += delta
      }
    }
    i = j
  }
  (columns, page + 1)
}

///|
fn render_vertical(
  document : ReaderDocument,
  writer : @core.DocumentWriter,
  options : ReaderOptions,
) -> ReaderLayout {
  let (columns, _) = reader_vertical_columns(document, options)
  let pages : Array[Json] = []
  let index_runs : Array[@core.IndexRun] = []
  let warnings : Array[String] = []
  let fonts : Map[String, Int32] = Map([])
  let mut object = @core.ObjectBuilder::new()
  object.set_bbox(
    0.0F,
    0.0F,
    Float::from_double(options.width),
    Float::from_double(options.height),
  )
  let mut page_lines : Array[String] = []
  let mut page_number = 0
  let new_page = fn() -> Unit {
    let encoded = object.encode() catch { _ => b"" }
    if encoded.is_empty() {
      return
    }
    let hash = writer.add_part("obj", encoded) catch { _ => "" }
    if hash == "" {
      return
    }
    pages.push(
      Json::object({
        "w": Json::number(options.width, repr=options.width.to_string()),
        "h": Json::number(options.height, repr=options.height.to_string()),
        "layers": Json::array([
          Json::object({
            "role": Json::string("body"),
            "obj": Json::string(hash),
          }),
        ]),
      }),
    )
    page_runs_push(index_runs, page_number, page_lines)
    page_lines = []
    page_number += 1
    object = @core.ObjectBuilder::new()
    object.set_bbox(
      0.0F,
      0.0F,
      Float::from_double(options.width),
      Float::from_double(options.height),
    )
  }
  let font_for = fn(bold : Bool) -> Int32 {
    let family = "Arial"
    let key = family + "|" + (if bold { "1" } else { "0" })
    match fonts.get(key) {
      Some(index) => index
      None => {
        let index = object.add_font(
          { hash: None, family, weight: if bold { 700 } else { 400 }, style: 0 },
        )
        fonts[key] = index
        index
      }
    }
  }
  let mut current_page = -1
  let mut y = 0.0
  for column in columns {
    if column.page != current_page {
      if current_page >= 0 {
        new_page()
      }
      current_page = column.page
    }
    y = options.margin
    let cx = column.left + column.pitch / 2.0
    let column_text = StringBuilder()
    for item in column.items {
      if item.kind == 3 {
        y += item.extent
        continue
      }
      if item.kind == 4 {
        object.fill_color(0xccccccffU)
        object.fill_rect(
          Float::from_double(cx - column.pitch * 0.4),
          Float::from_double(y + item.size * 0.4),
          Float::from_double(column.pitch * 0.8),
          0.8F,
        )
        y += item.extent
        continue
      }
      let font = font_for(item.bold)
      object.fill_color(0x000000ffU)
      if item.kind == 1 {
        // Sideways run: rotate the text 90 degrees so it reads downward.
        let w = item.extent
        object.save()
        let (a, b, c, d, e, f) = v_matrix_rotate90(cx - item.size * 0.35, y)
        object.transform(
          Float::from_double(a),
          Float::from_double(b),
          Float::from_double(c),
          Float::from_double(d),
          Float::from_double(e),
          Float::from_double(f),
        )
        object.font(font, Float::from_double(item.size)) catch { _ => () }
        object.fill_text(
          item.text,
          0.0F,
          0.0F,
          Float::from_double(w),
        )
        object.restore()
      } else if item.kind == 2 {
        let natural = @drawingml.text_width(item.text, item.size)
        let scale = if natural > item.size {
          item.size / natural
        } else {
          1.0
        }
        let tcy_size = item.size * scale
        let w = @drawingml.text_width(item.text, tcy_size)
        object.font(font, Float::from_double(tcy_size)) catch { _ => () }
        object.fill_text(
          item.text,
          Float::from_double(cx - w / 2.0),
          Float::from_double(y + item.size * 0.5 + tcy_size * 0.3),
          Float::from_double(w),
        )
      } else {
        let w = @drawingml.text_width(item.text, item.size)
        object.font(font, Float::from_double(item.size)) catch { _ => () }
        object.fill_text(
          item.text,
          Float::from_double(cx - w / 2.0),
          Float::from_double(y + item.size * 0.8),
          Float::from_double(w),
        )
      }
      if item.emphasis {
        let dot = item.size * 0.16
        object.fill_rect(
          Float::from_double(cx + item.size * 0.3 - dot / 2.0),
          Float::from_double(y + item.size * 0.3),
          Float::from_double(dot),
          Float::from_double(dot),
        )
      }
      column_text.write_string(item.text)
      y += item.extent
    }
    if column_text.to_string() != "" {
      page_lines.push(column_text.to_string())
    }
  }
  if !page_lines.is_empty() || pages.is_empty() {
    new_page()
  }
  if index_runs.is_empty() {
    warnings.push("reader output has no text")
  }
  { pages, index_runs, warnings }
}

///|
fn page_runs_push(
  index_runs : Array[@core.IndexRun],
  page_number : Int32,
  page_lines : Array[String],
) -> Unit {
  if page_lines.is_empty() {
    return
  }
  index_runs.push({
    a: page_number,
    b: 0,
    ordinal: index_runs.length(),
    separator: 2,
    text: page_lines.join("\n"),
  })
}

///|
fn v_matrix_rotate90(cx : Double, y : Double) -> (Double, Double, Double, Double, Double, Double) {
  // rotate(+90) in y-down space: user +x maps to page +y (downward text),
  // user -y (glyph tops) maps to page +x.
  (0.0, 1.0, -1.0, 0.0, cx, y)
}
