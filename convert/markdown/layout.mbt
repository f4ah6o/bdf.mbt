///|
priv struct MdChar {
  c : Char
  style : @drawingml.TextStyle
  link : String
  image : MdImage?
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
  match ch.image {
    Some(image) => image.width
    None => @drawingml.text_width(ch.c.to_string(), ch.style.size)
  }
}

///|
fn md_chars_to_runs(chars : Array[MdChar]) -> Array[MdRun] {
  let runs : Array[MdRun] = []
  for ch in chars {
    match ch.image {
      Some(image) => md_push_image(runs, image, ch.style, ch.link)
      None => md_push_run(runs, ch.c.to_string(), ch.style, ch.link)
    }
  }
  runs
}

///|
fn md_runs_to_chars(runs : Array[MdRun]) -> Array[MdChar] {
  let chars : Array[MdChar] = []
  for run in runs {
    match run.image {
      Some(image) => chars.push({
        c: '\uFFFC',
        style: run.style,
        link: run.link,
        image: Some(image),
      })
      None =>
        for c in run.text {
          chars.push({ c, style: run.style, link: run.link, image: None })
        }
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
  mut object : @core.ObjectBuilder
  writer : @core.DocumentWriter
  fonts : Map[String, Int32]
  mut y : Double
  images : Ref[Int]
  image_seen : Map[String, Bool]
  warnings : Array[String]
  content_width : Double
  margin : Double
  scale : Double
  // A positive page height lays the blocks out on pages instead of one strip.
  page_width : Double
  page_height : Double
  pages : Array[Json]
  index_runs : Array[@core.IndexRun]
  mut page : Int32
  mut page_dirty : Bool
  quote_bars : Array[Double]
}

///|
fn MdPainter::font(self : MdPainter, style : @drawingml.TextStyle) -> Int32 raise {
  let key = style.family +
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
fn md_fit_image(image : MdImage, width : Double) -> MdImage {
  if width > 0.0 && image.width > width {
    let height = if image.width > 0.0 {
      image.height * width / image.width
    } else {
      image.height
    }
    { ..image, width, height, }
  } else {
    image
  }
}

///|
fn md_fit_runs(runs : Array[MdRun], width : Double) -> Array[MdRun] {
  runs.map(fn(run) {
    match run.image {
      Some(image) => { ..run, image: Some(md_fit_image(image, width)) }
      None => run
    }
  })
}

///|
/// An SVG with only a view box fills a paragraph of its own.
fn md_expand_fill_runs(runs : Array[MdRun], width : Double) -> Array[MdRun] {
  if runs.length() != 1 {
    return runs
  }
  match runs[0].image {
    Some(image) if image.fill && image.width > 0.0 && image.height > 0.0 =>
      [{
        ..runs[0],
        image: Some({
          ..image,
          width,
          height: width * image.height / image.width,
          fill: false,
        }),
      }]
    _ => runs
  }
}

///|
fn md_line_image_height(runs : Array[MdRun]) -> Double {
  let mut height = 0.0
  for run in runs {
    match run.image {
      Some(image) => height = Double::max(height, image.height)
      None => ()
    }
  }
  height
}

///|
fn md_line_metrics(runs : Array[MdRun]) -> (Double, Double) {
  let mut size = 12.0
  let mut image_height = 0.0
  for run in runs {
    size = Double::max(size, run.style.size)
    match run.image {
      Some(image) => image_height = Double::max(image_height, image.height)
      None => ()
    }
  }
  let baseline = Double::max(size * 1.2, image_height + 2.0)
  let advance = Double::max(size * 1.7, image_height + 4.0)
  (baseline, advance)
}

///|
fn MdPainter::draw_image(
  self : MdPainter,
  image : MdImage,
  x : Double,
  bottom : Double,
) -> Unit raise {
  if image.width <= 0.0 || image.height <= 0.0 {
    return
  }
  let hash = self.writer.add_part("img", image.data)
  if !self.image_seen.contains(hash) {
    self.image_seen[hash] = true
    self.images.val += 1
  }
  let index = self.object.add_image(hash)
  self.object.image(
    index,
    Float::from_double(x),
    Float::from_double(bottom - image.height),
    Float::from_double(image.width),
    Float::from_double(image.height),
  )
}

///|
fn md_index_runs_for_object(encoded : Bytes, page : Int32) -> Array[@core.IndexRun] {
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
      a: page,
      b: 0,
      ordinal: run.ordinal,
      separator: if i == 0 { 2 } else { run.separator },
      text: run.text,
    })
  }
  index_runs
}

///|
fn MdPainter::flush_page(self : MdPainter) -> Unit raise {
  if self.page_height <= 0.0 {
    return
  }
  self.object.set_bbox(
    0.0F,
    0.0F,
    Float::from_double(self.page_width),
    Float::from_double(self.page_height),
  )
  let encoded = self.object.encode()
  let hash = self.writer.add_part("obj", encoded) catch { _ => "" }
  if hash != "" {
    self.pages.push(
      Json::object({
        "w": Json::number(self.page_width, repr=self.page_width.to_string()),
        "h": Json::number(self.page_height, repr=self.page_height.to_string()),
        "body": Json::object({
          "x": Json::number(self.margin),
          "y": Json::number(self.margin),
          "w": Json::number(self.content_width),
          "h": Json::number(self.page_height - self.margin * 2.0),
        }),
        "layers": Json::array([
          Json::object({
            "role": Json::string("body"),
            "obj": Json::string(hash),
          }),
        ]),
      }),
    )
    for run in md_index_runs_for_object(encoded, self.page) {
      self.index_runs.push(run)
    }
  }
  self.object = @core.ObjectBuilder::new()
  self.fonts.clear()
  self.page += 1
  self.page_dirty = false
}

///|
fn MdPainter::ensure(self : MdPainter, height : Double) -> Unit raise {
  if self.page_height <= 0.0 {
    return
  }
  let bottom = self.page_height - self.margin
  if self.y + height > bottom + 0.001 &&
    (self.y > self.margin + 0.001 || self.page_dirty) {
    self.flush_page()
    self.y = self.margin
  }
}

///|
fn MdPainter::draw_text(
  self : MdPainter,
  runs : Array[MdRun],
  x : Double,
  baseline : Double,
) -> Unit raise {
  self.object.mark(1, "")
  if !self.quote_bars.is_empty() {
    let mut size = 12.0
    for run in runs {
      size = Double::max(size, run.style.size)
    }
    self.object.fill_color(0xccccccffU)
    for bar_x in self.quote_bars {
      self.object.fill_rect(
        Float::from_double(bar_x),
        Float::from_double(baseline - size * 1.1),
        2.0F,
        Float::from_double(size * 1.7),
      )
    }
  }
  let mut cursor = x
  for run in runs {
    match run.image {
      Some(image) => {
        self.object.mark(10, run.text)
        self.draw_image(image, cursor, baseline)
        self.object.mark(11, "")
        cursor += image.width
        self.page_dirty = true
        continue
      }
      None => ()
    }
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
    if run.link != "" {
      self.object.link(
        Float::from_double(cursor),
        Float::from_double(baseline - run.style.size * 0.9),
        Float::from_double(width),
        Float::from_double(run.style.size * 1.2),
        run.link,
      )
    }
    cursor += width
    self.page_dirty = true
  }
}

///|
fn md_line_width(runs : Array[MdRun]) -> Double {
  let mut width = 0.0
  for run in runs {
    match run.image {
      Some(image) => width += image.width
      None => width += @drawingml.text_width(run.text, run.style.size)
    }
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
fn md_heading_style(level : Int, scale : Double) -> @drawingml.TextStyle {
  match level {
    1 => md_style(size=24.0 * scale, bold=true)
    2 => md_style(size=20.0 * scale, bold=true)
    3 => md_style(size=16.0 * scale, bold=true)
    _ => md_style(size=14.0 * scale, bold=true)
  }
}

///|
fn MdPainter::layout_block(
  self : MdPainter,
  block : MdBlock,
  indent : Double,
) -> Unit raise {
  let content_width = self.content_width
  let x = self.margin + indent
  let width = Double::max(80.0, content_width - indent)
  match block {
    MdHeading(level, runs) => {
      let before = if level == 1 { 14.0 } else { 10.0 }
      self.ensure(before + 24.0)
      self.y += before
      let style = md_heading_style(level, self.scale)
      self.object.mark(6, level.to_string())
      let styled = runs.map(fn(run) { { ..run, style, } })
      for index, line in md_wrap_runs(styled, width) {
        if index > 0 {
          self.object.mark(5, "")
        }
        let (measured_baseline, measured_advance) = md_line_metrics(line)
        let baseline = if md_line_image_height(line) > 0.0 {
          measured_baseline
        } else {
          style.size * 1.2
        }
        let advance = if md_line_image_height(line) > 0.0 {
          measured_advance
        } else {
          style.size * 1.45
        }
        self.ensure(advance)
        self.draw_text(line, x, self.y + baseline)
        self.y += advance
      }
      self.y += 8.0
    }
    MdParagraph(runs) => {
      if runs.is_empty() {
        self.y += 12.0
        return
      }
      let prepared = md_expand_fill_runs(runs, width)
      self.object.mark(0, "")
      let size = prepared[0].style.size
      for index, line in md_wrap_runs(prepared, width) {
        if index > 0 {
          self.object.mark(5, "")
        }
        let (measured_baseline, measured_advance) = md_line_metrics(line)
        let image_height = md_line_image_height(line)
        let baseline = if image_height > 0.0 {
          measured_baseline
        } else {
          size * 1.2
        }
        let advance = if image_height > 0.0 {
          measured_advance
        } else {
          size * 1.7
        }
        self.ensure(advance)
        self.draw_text(line, x, self.y + baseline)
        self.y += advance
      }
      self.y += 7.0
    }
    MdListItem(level, marker, runs) => {
      let item_indent = indent + 18.0 * (level + 1).to_double()
      let item_x = self.margin + item_indent
      let item_width = Double::max(80.0, content_width - item_indent)
      let marker_style = if runs.is_empty() {
        md_style()
      } else {
        runs[0].style
      }
      let prefixed : Array[MdRun] = []
      md_push_run(prefixed, marker, marker_style, "")
      for run in runs {
        match run.image {
          Some(image) => md_push_image(prefixed, image, run.style, run.link)
          None => md_push_run(prefixed, run.text, run.style, run.link)
        }
      }
      self.object.mark(8, "")
      for index, line in md_wrap_runs(prefixed, item_width) {
        if index > 0 {
          self.object.mark(5, "")
        }
        let (measured_baseline, measured_advance) = md_line_metrics(line)
        let baseline = if md_line_image_height(line) > 0.0 {
          measured_baseline
        } else {
          marker_style.size * 1.2
        }
        let advance = if md_line_image_height(line) > 0.0 {
          measured_advance
        } else {
          marker_style.size * 1.65
        }
        self.ensure(advance)
        self.draw_text(line, item_x, self.y + baseline)
        self.y += advance
      }
      self.y += 2.0
    }
    MdDefinition(term, definitions) => {
      self.layout_block(MdParagraph(term), indent)
      for runs in definitions {
        self.layout_block(MdParagraph(runs), indent + 24.0)
      }
    }
    MdCode(lines) => {
      self.y += 7.0
      let style = md_style(size=10.5 * self.scale, family="monospace")
      let code_x = x + 12.0
      for line in lines {
        let runs : Array[MdRun] = []
        md_push_run(runs, md_expand_tabs(line), style, "")
        self.ensure(14.0)
        self.draw_text(runs, code_x, self.y + 10.5)
        self.y += 14.0
      }
      self.y += 7.0
    }
    MdQuote(children) => {
      self.ensure(24.0)
      self.quote_bars.push(self.margin + indent + 4.0)
      for child in children {
        self.layout_block(child, indent + 24.0)
      }
      ignore(self.quote_bars.pop())
      self.y += 4.0
    }
    MdRule => {
      self.ensure(17.8)
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
      self.ensure(26.6)
      self.y += 8.0
      let text = md_latex_linear(formula)
      let style = md_style(size=12.0 * self.scale, italic=true)
      let runs : Array[MdRun] = []
      md_push_run(runs, text, style, "")
      for line in md_wrap_runs(runs, width) {
        let (measured_baseline, measured_advance) = md_line_metrics(line)
        let baseline = if md_line_image_height(line) > 0.0 {
          measured_baseline
        } else {
          14.4
        }
        let advance = if md_line_image_height(line) > 0.0 {
          measured_advance
        } else {
          18.6
        }
        self.ensure(advance)
        self.draw_aligned(line, x, width, self.y + baseline, 1)
        self.y += advance
      }
      self.y += 8.0
    }
    MdImage(alt, url, _title) => {
      self.object.mark(10, alt)
      match md_resolve_image(url) {
        Some(image) => {
          let fitted = md_fit_image(image, width)
          self.ensure(fitted.height + 6.0)
          self.draw_image(fitted, x, self.y + fitted.height)
          self.y += fitted.height + 6.0
        }
        None => {
          if alt != "" {
            let runs : Array[MdRun] = []
            md_push_run(runs, alt, md_style(size=12.0 * self.scale), "")
            for line in md_wrap_runs(runs, width) {
              let (baseline, advance) = md_line_metrics(line)
              self.ensure(advance)
              self.draw_text(line, x, self.y + baseline)
              self.y += advance
            }
          }
          md_warn_image(self.warnings, url)
        }
      }
      self.object.mark(11, "")
    }
    MdTable(header, rows, alignments) => self.layout_table(header, rows, alignments, x, width)
  }
}


///|
fn MdPainter::draw_table_row(
  self : MdPainter,
  x : Double,
  width : Double,
  row_top : Double,
  row_height : Double,
  cell_lines : Array[Array[Array[MdRun]]],
  column_widths : Array[Double],
  alignments : Array[Int],
  row_index : Int,
) -> Unit raise {
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
  for column in 0..<cell_lines.length() {
    self.object.mark(2, md_cell_name(column, row_index + 1))
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
  self.object.stroke_color(0xccccccffU)
  self.object.line(0.6F, 0, 0, 8.0F)
  self.object.stroke_path(
    self.object.add_path(
      @core.Inline({
        verbs: b"\x00\x01",
        coordinates: [x, row_top + row_height, x + width, row_top + row_height],
      }),
    ),
  )
}

///|
fn MdPainter::draw_table_vertical(
  self : MdPainter,
  x : Double,
  column_widths : Array[Double],
  top : Double,
  bottom : Double,
) -> Unit raise {
  let mut line_x = x
  self.object.stroke_color(0xccccccffU)
  self.object.line(0.6F, 0, 0, 8.0F)
  for column_width in column_widths {
    self.object.stroke_path(
      self.object.add_path(
        @core.Inline({
          verbs: b"\x00\x01",
          coordinates: [line_x, top, line_x, bottom],
        }),
      ),
    )
    line_x += column_width
  }
  self.object.stroke_path(
    self.object.add_path(
      @core.Inline({
        verbs: b"\x00\x01",
        coordinates: [line_x, top, line_x, bottom],
      }),
    ),
  )
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
  self.object.mark(9, "")
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
  let all_rows : Array[Array[Array[MdRun]]] = []
  all_rows.push(header)
  for row in rows {
    all_rows.push(row)
  }
  let row_cells : Array[Array[Array[Array[MdRun]]]] = []
  let row_heights : Array[Double] = []
  let mut table_height = 14.0
  for row in all_rows {
    let cell_lines : Array[Array[Array[MdRun]]] = []
    let mut row_height = 8.0
    for column in 0..<columns {
      let runs = if column < row.length() { row[column] } else { [] }
      let lines = md_wrap_runs(runs, column_widths[column] - 10.0)
      let height = lines.length().to_double() * 15.0 + 8.0
      row_height = Double::max(row_height, height)
      cell_lines.push(lines)
    }
    row_cells.push(cell_lines)
    row_heights.push(row_height)
    table_height += row_height
  }
  let limit = if self.page_height > 0.0 {
    self.page_height - self.margin * 2.0
  } else {
    0.0
  }
  if self.page_height > 0.0 {
    let first_rows = row_heights[0] +
      (if row_heights.length() > 1 { row_heights[1] } else { 0.0 }) +
      6.0
    self.ensure(
      if table_height > limit {
        Double::min(table_height, first_rows)
      } else {
        table_height
      },
    )
  }
  self.y += 6.0
  let mut row_top = self.y
  if self.page_height > 0.0 && table_height > limit {
    let page_bottom = self.margin + limit
    let mut segment_top = row_top
    let mut drawn = false
    for row_index, _row in all_rows {
      let row_height = row_heights[row_index]
      if drawn &&
        row_top + row_height > page_bottom + 0.001 &&
        row_height <= limit {
        self.draw_table_vertical(x, column_widths, segment_top, row_top)
        self.object.mark(11, "")
        self.y = row_top
        self.flush_page()
        self.y = self.margin
        row_top = self.y
        segment_top = self.y
        drawn = false
        self.object.mark(9, "")
        if row_index > 1 &&
          row_top + row_heights[0] + row_height <= page_bottom + 0.001 {
          self.draw_table_row(
            x, width, row_top, row_heights[0], row_cells[0], column_widths,
            alignments, 0,
          )
          row_top += row_heights[0]
          drawn = true
        }
      }
      self.draw_table_row(
        x, width, row_top, row_height, row_cells[row_index], column_widths,
        alignments, row_index,
      )
      row_top += row_height
      drawn = true
    }
    self.draw_table_vertical(x, column_widths, segment_top, row_top)
    self.object.mark(11, "")
    self.y = row_top + 8.0
    return
  }
  let table_top = row_top
  for row_index, _row in all_rows {
    let row_height = row_heights[row_index]
    self.draw_table_row(
      x, width, row_top, row_height, row_cells[row_index], column_widths,
      alignments, row_index,
    )
    row_top += row_height
  }
  self.draw_table_vertical(x, column_widths, table_top, row_top)
  self.object.mark(11, "")
  self.y = row_top + 8.0
}

///|
fn md_cell_name(column : Int, row : Int) -> String {
  let letters = StringBuilder()
  let mut value = column
  while true {
    letters.write_char(Char::from_int('A'.to_int() + value % 26))
    value = value / 26 - 1
    if value < 0 {
      break
    }
  }
  let out = StringBuilder()
  for character in letters.to_string().rev() {
    out.write_char(character)
  }
  out.write_string(row.to_string())
  out.to_string()
}

///|
priv struct MdRenderResult {
  pages : Array[Json]
  index_runs : Array[@core.IndexRun]
  strips : Int
}

///|
fn md_render(
  blocks : Array[MdBlock],
  writer : @core.DocumentWriter,
  page_view~ : Bool,
  warnings~ : Array[String],
  image_seen~ : Map[String, Bool],
  images~ : Ref[Int],
  size~ : Double = 12.0,
  width~ : Double = 432.0,
) -> MdRenderResult raise {
  let margin = if page_view { 56.7 } else { 36.0 }
  let content_width = if page_view { 481.9 } else { width }
  let page_width = if page_view { 595.3 } else { width + 36.0 * 2.0 }
  let scale = if size > 0.0 { size / 12.0 } else { 1.0 }
  let painter : MdPainter = {
    object: @core.ObjectBuilder::new(),
    writer,
    fonts: Map([]),
    y: margin,
    images,
    image_seen,
    warnings,
    content_width: content_width,
    margin,
    scale,
    page_width,
    page_height: if page_view { 841.9 } else { 0.0 },
    pages: [],
    index_runs: [],
    page: 0,
    page_dirty: false,
    quote_bars: [],
  }
  let mut list_open = false
  for block in blocks {
    match block {
      MdListItem(_, _, _) => if !list_open {
        painter.object.mark(7, "")
        list_open = true
      }
      _ => if list_open {
        painter.object.mark(11, "")
        list_open = false
      }
    }
    painter.layout_block(block, 0.0)
  }
  if list_open {
    painter.object.mark(11, "")
  }
  if page_view {
    if painter.pages.is_empty() || painter.y > margin + 0.001 {
      painter.flush_page()
    }
    return {
      pages: painter.pages,
      index_runs: painter.index_runs,
      strips: 0,
    }
  }
  let mut height = painter.y + margin
  if height < 100.0 {
    height = 100.0
  }
  painter.object.set_bbox(
    0.0F,
    0.0F,
    Float::from_double(page_width),
    Float::from_double(height),
  )
  let encoded = painter.object.encode()
  let hash = writer.add_part("obj", encoded)
  let page = Json::object({
    "w": Json::number(page_width, repr=page_width.to_string()),
    "h": Json::number(height, repr=height.to_string()),
    "layers": Json::array([
      Json::object({
        "role": Json::string("body"),
        "obj": Json::string(hash),
      }),
    ]),
  })
  let index_runs = md_index_runs_for_object(encoded, 0)
  { pages: [page], index_runs, strips: 1 }
}
