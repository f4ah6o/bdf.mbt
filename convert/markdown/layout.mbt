///|
priv struct MdChar {
  c : Char
  style : @drawingml.TextStyle
  link : String
}

///|
fn md_slice_chars(chars : Array[MdChar], start : Int, end : Int) -> Array[MdChar] {
  let out : Array[MdChar] = []
  for i in start..<end {
    out.push(chars[i])
  }
  out
}

///|
fn md_chars_width(chars : Array[MdChar]) -> Double {
  let mut width = 0.0
  for ch in chars {
    width += md_char_width(ch)
  }
  width
}

///|
fn md_char_width(ch : MdChar) -> Double {
  @drawingml.text_width(ch.c.to_string(), ch.style.size)
}

///|
fn md_chars_to_runs(chars : Array[MdChar]) -> Array[MdRun] {
  let runs : Array[MdRun] = []
  for ch in chars {
    md_push_run(runs, ch.c.to_string(), ch.style, ch.link)
  }
  runs
}

///|
fn md_runs_to_chars(runs : Array[MdRun]) -> Array[MdChar] {
  let chars : Array[MdChar] = []
  for run in runs {
    for c in run.text {
      chars.push({ c, style: run.style, link: run.link })
    }
  }
  chars
}

///|
fn md_trim_chars(chars : Array[MdChar]) -> Array[MdChar] {
  let mut end = chars.length()
  while end > 0 && chars[end - 1].c == ' ' {
    end -= 1
  }
  md_slice_chars(chars, 0, end)
}

///|
fn md_is_cjk(c : Char) -> Bool {
  let code = c.to_int()
  code >= 0x2e80 || code == 0x3000 || (code >= 0xff00 && code <= 0xffef)
}

///|
fn md_prohibited_start(c : Char) -> Bool {
  match c {
    '、' | '。' | '，' | '．' | '・' | '：' | '；' | '？' | '！' | '）' | '〕' |
    '」' | '』' | '】' | '〉' | '》' | '｝' | 'ー' | '々' | 'ぁ' | 'ぃ' | 'ぅ' |
    'ぇ' | 'ぉ' | 'っ' | 'ゃ' | 'ゅ' | 'ょ' | 'ァ' | 'ィ' | 'ゥ' | 'ェ' | 'ォ' |
    'ッ' | 'ャ' | 'ュ' | 'ョ' => true
    _ => false
  }
}

///|
fn md_wrap_chars(chars : Array[MdChar], width : Double) -> Array[Array[MdChar]] {
  let lines : Array[Array[MdChar]] = []
  let current : Array[MdChar] = []
  let mut current_width = 0.0
  fn flush() -> Unit {
    let trimmed = md_trim_chars(current)
    if !trimmed.is_empty() {
      lines.push(trimmed)
    }
    current.clear()
  }
  for ch in chars {
    if ch.c == '\n' {
      flush()
      current_width = 0.0
      continue
    }
    if ch.c == ' ' && current.is_empty() {
      continue
    }
    let advance = md_char_width(ch)
    if current_width + advance > width && !current.is_empty() {
      let mut space = -1
      for i in 0..<current.length() {
        if current[i].c == ' ' {
          space = i
        }
      }
      if md_prohibited_start(ch.c) && current.length() > 1 {
        let last = current.pop().unwrap()
        flush()
        current.push(last)
        current_width = md_char_width(last)
      } else if space > 0 &&
        !md_is_cjk(ch.c) &&
        !md_is_cjk(current[current.length() - 1].c) {
        let tail = md_slice_chars(current, space + 1, current.length())
        let head = md_slice_chars(current, 0, space)
        current.clear()
        for value in head {
          current.push(value)
        }
        flush()
        for value in tail {
          current.push(value)
        }
        current_width = md_chars_width(tail)
      } else {
        flush()
        current_width = 0.0
      }
    }
    current.push(ch)
    current_width += advance
  }
  flush()
  lines
}

///|
fn md_wrap_runs(runs : Array[MdRun], width : Double) -> Array[Array[MdRun]] {
  let lines = md_wrap_chars(md_runs_to_chars(runs), width)
  lines.map(md_chars_to_runs)
}

///|
priv struct MdPainter {
  object : @core.ObjectBuilder
  writer : @core.DocumentWriter
  fonts : Map[String, Int32]
  mut y : Double
  mut images : Int32
  warnings : Array[String]
}

///|
fn MdPainter::font(self : MdPainter, style : @drawingml.TextStyle) -> Int32 raise {
  let key = style.family +
    "|" +
    style.size.to_string() +
    "|" +
    (if style.bold { "1" } else { "0" }) +
    (if style.italic { "1" } else { "0" })
  match self.fonts.get(key) {
    Some(index) => index
    None => {
      let index = self.object.add_font({
        hash: None,
        family: style.family,
        weight: if style.bold { 700 } else { 400 },
        style: if style.italic { 1 } else { 0 },
      })
      self.fonts[key] = index
      index
    }
  }
}

///|
fn MdPainter::draw_text(
  self : MdPainter,
  runs : Array[MdRun],
  x : Double,
  baseline : Double,
) -> Unit raise {
  let mut cursor = x
  for run in runs {
    if run.text == "" {
      continue
    }
    let index = self.font(run.style)
    self.object.font(index, Float::from_double(run.style.size))
    self.object.fill_color(run.style.color)
    let width = @drawingml.text_width(run.text, run.style.size)
    self.object.fill_text(
      run.text,
      Float::from_double(cursor),
      Float::from_double(baseline),
      Float::from_double(width),
    )
    cursor += width
  }
}

///|
fn md_line_width(runs : Array[MdRun]) -> Double {
  let mut width = 0.0
  for run in runs {
    width += @drawingml.text_width(run.text, run.style.size)
  }
  width
}

///|
fn MdPainter::draw_aligned(
  self : MdPainter,
  runs : Array[MdRun],
  x : Double,
  width : Double,
  baseline : Double,
  align : Int,
) -> Unit raise {
  let line_width = md_line_width(runs)
  let offset = match align {
    1 => (width - line_width) / 2.0
    2 => width - line_width
    _ => 0.0
  }
  self.draw_text(runs, x + Double::max(0.0, offset), baseline)
}

///|
fn md_expand_tabs(line : String) -> String {
  let out = StringBuilder()
  let mut column = 0
  for c in line {
    if c == '\t' {
      let spaces = 4 - column % 4
      for _ in 0..<spaces {
        out.write_char(' ')
      }
      column += spaces
    } else {
      out.write_char(c)
      column += 1
    }
  }
  out.to_string()
}

///|
fn md_heading_style(level : Int) -> @drawingml.TextStyle {
  match level {
    1 => md_style(size=24.0, bold=true)
    2 => md_style(size=20.0, bold=true)
    3 => md_style(size=16.0, bold=true)
    _ => md_style(size=14.0, bold=true)
  }
}

///|
fn MdPainter::layout_block(
  self : MdPainter,
  block : MdBlock,
  indent : Double,
) -> Unit raise {
  let content_width = 432.0
  let x = 36.0 + indent
  let width = Double::max(80.0, content_width - indent)
  match block {
    MdHeading(level, runs) => {
      self.y += if level == 1 { 14.0 } else { 10.0 }
      let style = md_heading_style(level)
      let styled = runs.map(fn(run) { { ..run, style, } })
      for line in md_wrap_runs(styled, width) {
        self.draw_text(line, x, self.y + style.size * 1.2)
        self.y += style.size * 1.45
      }
      self.y += 8.0
    }
    MdParagraph(runs) => {
      if runs.is_empty() {
        self.y += 12.0
        return
      }
      let size = if runs.is_empty() { 12.0 } else { runs[0].style.size }
      for line in md_wrap_runs(runs, width) {
        self.draw_text(line, x, self.y + size * 1.2)
        self.y += size * 1.7
      }
      self.y += 7.0
    }
    MdListItem(level, marker, runs) => {
      let item_indent = indent + 18.0 * (level + 1).to_double()
      let item_x = 36.0 + item_indent
      let item_width = Double::max(80.0, content_width - item_indent)
      let marker_style = if runs.is_empty() {
        md_style()
      } else {
        runs[0].style
      }
      let prefixed : Array[MdRun] = []
      md_push_run(prefixed, marker, marker_style, "")
      for run in runs {
        md_push_run(prefixed, run.text, run.style, run.link)
      }
      for line in md_wrap_runs(prefixed, item_width) {
        self.draw_text(line, item_x, self.y + marker_style.size * 1.2)
        self.y += marker_style.size * 1.65
      }
      self.y += 2.0
    }
    MdCode(lines) => {
      self.y += 7.0
      let style = md_style(size=10.5, family="Courier New")
      let code_x = x + 12.0
      for line in lines {
        let runs : Array[MdRun] = []
        md_push_run(runs, md_expand_tabs(line), style, "")
        self.draw_text(runs, code_x, self.y + 10.5)
        self.y += 14.0
      }
      self.y += 7.0
    }
    MdQuote(children) => {
      let bar_x = 36.0 + indent + 4.0
      self.object.fill_color(0xccccccffU)
      self.object.fill_rect(
        Float::from_double(bar_x),
        Float::from_double(self.y),
        2.0F,
        Float::from_double(24.0),
      )
      for child in children {
        self.layout_block(child, indent + 24.0)
      }
      self.y += 4.0
    }
    MdRule => {
      self.y += 8.0
      self.object.fill_color(0xccccccffU)
      self.object.fill_rect(
        Float::from_double(x),
        Float::from_double(self.y),
        Float::from_double(width),
        0.8F,
      )
      self.y += 9.0
    }
    MdMath(formula) => {
      self.y += 8.0
      let text = md_latex_linear(formula)
      let style = md_style(size=12.0, italic=true)
      let runs : Array[MdRun] = []
      md_push_run(runs, text, style, "")
      for line in md_wrap_runs(runs, width) {
        self.draw_aligned(line, x, width, self.y + 14.4, 1)
        self.y += 18.6
      }
      self.y += 8.0
    }
    MdImage(alt, url, _title) => {
      if alt != "" {
        let runs : Array[MdRun] = []
        md_push_run(runs, alt, md_style(), "")
        for line in md_wrap_runs(runs, width) {
          self.draw_text(line, x, self.y + 14.4)
          self.y += 18.6
        }
      }
      self.layout_image(url, alt, x, width)
    }
    MdTable(header, rows, alignments) => self.layout_table(header, rows, alignments, x, width)
  }
}

///|
fn md_data_image(url : String) -> Bytes? {
  if !url.has_prefix("data:") {
    return None
  }
  let comma = url.find(",")
  match comma {
    Some(index) => {
      let head = url[:index].to_owned()
      if !head.contains(";base64") {
        return None
      }
      let payload = url[index + 1:].to_owned()
      let bytes = @base64.decode(payload[:], ignore_whitespace=true) catch {
        _ => return None
      }
      Some(bytes)
    }
    None => None
  }
}

///|
fn md_png_size(data : Bytes) -> (Double, Double)? {
  if data.length() < 24 || data[:8] != b"\x89PNG\r\n\x1a\n"[:] {
    return None
  }
  let width = (data[16].to_int() << 24) |
    (data[17].to_int() << 16) |
    (data[18].to_int() << 8) |
    data[19].to_int()
  let height = (data[20].to_int() << 24) |
    (data[21].to_int() << 16) |
    (data[22].to_int() << 8) |
    data[23].to_int()
  if width <= 0 || height <= 0 {
    None
  } else {
    Some((width.to_double(), height.to_double()))
  }
}

///|
fn MdPainter::layout_image(
  self : MdPainter,
  url : String,
  alt : String,
  x : Double,
  width : Double,
) -> Unit raise {
  match md_data_image(url) {
    Some(bytes) => {
      let (image_width, image_height) = match md_png_size(bytes) {
        Some(size) => size
        None => (200.0, 150.0)
      }
      let mut draw_width = image_width
      let mut draw_height = image_height
      if draw_width > width {
        draw_height = draw_height * width / draw_width
        draw_width = width
      }
      let hash = self.writer.add_part("img", bytes)
      let index = self.object.add_image(hash)
      self.object.image(
        index,
        Float::from_double(x),
        Float::from_double(self.y),
        Float::from_double(draw_width),
        Float::from_double(draw_height),
      )
      self.images += 1
      self.y += draw_height + 6.0
    }
    None =>
      if url != "" {
        self.warnings.push(
          "image " + url + ": relative reference with no directory to resolve it in",
        )
      }
  }
  ignore(alt)
}

///|
fn MdPainter::layout_table(
  self : MdPainter,
  header : Array[Array[MdRun]],
  rows : Array[Array[Array[MdRun]]],
  alignments : Array[Int],
  x : Double,
  width : Double,
) -> Unit raise {
  let columns = Int::max(
    header.length(),
    if rows.is_empty() {
      0
    } else {
      rows[0].length()
    },
  )
  if columns == 0 {
    return
  }
  let natural : Array[Double] = []
  for column in 0..<columns {
    let mut cell_width = 30.0
    if column < header.length() {
      cell_width = Double::max(cell_width, md_line_width(header[column]) + 12.0)
    }
    for row in rows {
      if column < row.length() {
        cell_width = Double::max(cell_width, md_line_width(row[column]) + 12.0)
      }
    }
    natural.push(cell_width)
  }
  let mut total = 0.0
  for value in natural {
    total += value
  }
  let scale = if total > width { width / total } else { 1.0 }
  let column_widths : Array[Double] = []
  for value in natural {
    column_widths.push(Double::max(24.0, value * scale))
  }
  self.y += 6.0
  let table_top = self.y
  let mut row_top = self.y
  let all_rows : Array[Array[Array[MdRun]]] = []
  all_rows.push(header)
  for row in rows {
    all_rows.push(row)
  }
  for row_index, row in all_rows {
    let cell_lines : Array[Array[Array[MdRun]]] = []
    let mut row_height = 8.0
    for column in 0..<columns {
      let runs = if column < row.length() { row[column] } else { [] }
      let lines = md_wrap_runs(runs, column_widths[column] - 10.0)
      let height = lines.length().to_double() * 15.0 + 8.0
      row_height = Double::max(row_height, height)
      cell_lines.push(lines)
    }
    if row_index == 0 {
      self.object.fill_color(0xf2f2f2ffU)
      self.object.fill_rect(
        Float::from_double(x),
        Float::from_double(row_top),
        Float::from_double(width),
        Float::from_double(row_height),
      )
    }
    let mut cell_x = x
    for column in 0..<columns {
      let lines = cell_lines[column]
      let align = if column < alignments.length() { alignments[column] } else { 0 }
      let mut baseline = row_top + 15.0
      for line in lines {
        self.draw_aligned(
          line,
          cell_x + 5.0,
          column_widths[column] - 10.0,
          baseline,
          align,
        )
        baseline += 15.0
      }
      cell_x += column_widths[column]
    }
    row_top += row_height
    self.object.stroke_color(0xccccccffU)
    self.object.line(0.6F, 0, 0, 8.0F)
    self.object.stroke_path(
      self.object.add_path(
        @core.Inline({
          verbs: b"\x00\x01",
          coordinates: [
            x,
            row_top,
            x + width,
            row_top,
          ],
        }),
      ),
    )
  }
  let mut line_x = x
  self.object.stroke_color(0xccccccffU)
  self.object.line(0.6F, 0, 0, 8.0F)
  for column_width in column_widths {
    self.object.stroke_path(
      self.object.add_path(
        @core.Inline({
          verbs: b"\x00\x01",
          coordinates: [
            line_x,
            table_top,
            line_x,
            row_top,
          ],
        }),
      ),
    )
    line_x += column_width
  }
  self.object.stroke_path(
    self.object.add_path(
      @core.Inline({
        verbs: b"\x00\x01",
        coordinates: [
          line_x,
          table_top,
          line_x,
          row_top,
        ],
      }),
    ),
  )
  self.y = row_top + 8.0
}

///|
fn md_render(
  document : MdDocument,
  writer : @core.DocumentWriter,
) -> (Json, Array[@core.IndexRun], Int, Array[String]) raise {
  let object = @core.ObjectBuilder::new()
  let painter : MdPainter = {
    object,
    writer,
    fonts: Map([]),
    y: 36.0,
    images: 0,
    warnings: [],
  }
  for block in document.blocks {
    painter.layout_block(block, 0.0)
  }
  let mut height = painter.y + 36.0
  if height < 100.0 {
    height = 100.0
  }
  painter.object.set_bbox(0.0F, 0.0F, 504.0F, Float::from_double(height))
  let encoded = painter.object.encode()
  let hash = writer.add_part("obj", encoded)
  let index_runs : Array[@core.IndexRun] = []
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
      a: 0,
      b: 0,
      ordinal: run.ordinal,
      separator: if i == 0 { 2 } else { run.separator },
      text: run.text,
    })
  }
  let page = Json::object({
    "w": Json::number(504.0, repr="504"),
    "h": Json::number(height, repr=height.to_string()),
    "layers": Json::array([
      Json::object({
        "role": Json::string("body"),
        "obj": Json::string(hash),
      }),
    ]),
  })
  (page, index_runs, painter.images, painter.warnings)
}
