///|
// Filling a plain-text template with data: sections, values, columns, pages
// and the print image of the filled form.
const MAX_OUT_LINES : Int = 1 << 20
const MAX_LINE_COLS : Int = 1 << 16
const MAX_STEPS : Int = 8 << 20

///|
pub(all) struct TextTemplateData {
  data : Map[String, Json]
  strict : Bool
  format : ((Json, String) -> String)?
}

///|
pub fn TextTemplateData::new(data : Map[String, Json]) -> TextTemplateData {
  { data, strict: false, format: None }
}

///|
priv struct TextCell {
  mut text : String
  w : Int
  attrs : Int
}

///|
fn text_cell(text : String, w : Int, attrs : Int) -> TextCell {
  { text, w, attrs }
}

///|
fn TextCell::cols(self : TextCell) -> Int {
  if (self.attrs & ATTR_WIDE) != 0 {
    self.w * 2
  } else {
    self.w
  }
}

///|
fn cells_cols(cells : Array[TextCell]) -> Int {
  let mut total = 0
  for cell in cells {
    total += cell.cols()
  }
  total
}

///|
priv struct TextOutLine {
  cells : Array[TextCell]
  brk : Bool
  table : Int
  no : Int
}

///|
fn TextOutLine::tall(self : TextOutLine) -> Bool {
  for cell in self.cells {
    if (cell.attrs & ATTR_TALL) != 0 {
      return true
    }
  }
  false
}

///|
priv struct TextCont {
  col : Int
  pieces : Array[Array[TextCell]]
}

///|
priv struct TextLineBuilder {
  cells : Array[TextCell]
  mut cols : Int
  conts : Array[TextCont]
}

///|
fn TextLineBuilder::add(self : TextLineBuilder, cell : TextCell) -> Unit {
  self.cells.push(cell)
  self.cols += cell.cols()
}

///|
priv struct TextFiller {
  tpl : TextTemplate
  td : TextTemplateData
  out : Array[TextOutLine]
  mut table : Int
  mut tables : Int
  warnings : Array[String]
  mut steps : Int
}

///|
priv struct TextPage {
  lines : Array[TextOutLine]
  tables : Array[Int]
}

///|
fn text_filler(tpl : TextTemplate, td : TextTemplateData) -> TextFiller {
  {
    tpl,
    td,
    out: [],
    table: 0,
    tables: 0,
    warnings: [],
    steps: 0,
  }
}

///|
fn TextFiller::step(self : TextFiller, at : String) -> Unit raise TextFormError {
  self.steps += 1
  if self.steps > MAX_STEPS {
    raise TextFormError(
      "text: " +
      at +
      ": the filled template needs more than " +
      MAX_STEPS.to_string() +
      " repetitions of sections",
    )
  }
}

///|
fn TextFiller::lookup(
  self : TextFiller,
  name : String,
  path : Array[String],
  scope : @tag.Scope,
  at : String,
) -> Json raise TextFormError {
  match scope.lookup(path) {
    Some(value) => value
    None =>
      if scope.is_blank() {
        Json::null()
      } else if self.td.strict {
        raise TextFormError("text: " + at + ": the data has no " + name)
      } else {
        let warning = at + ": the data has no " + name + "; it is left empty"
        if !self.warnings.contains(warning) {
          self.warnings.push(warning)
        }
        Json::null()
      }
  }
}

///|
fn TextFiller::lines(
  self : TextFiller,
  section : TextSection,
  from : Int,
  to : Int,
  scope : @tag.Scope,
) -> Unit raise TextFormError {
  let mut child_index = 0
  let mut i = from
  while i <= to {
    while child_index < section.children.length() &&
      section.children[child_index].a < i {
      child_index += 1
    }
    if child_index < section.children.length() &&
      section.children[child_index].a == i {
      let child = section.children[child_index]
      self.section(child, scope)
      i = child.b + 1
      continue
    }
    let line = self.tpl.lines[i]
    self.emit(line, line.attrs, scope)
    i += 1
  }
}

///|
fn TextFiller::section(
  self : TextFiller,
  section : TextSection,
  scope : @tag.Scope,
) -> Unit raise TextFormError {
  let value = self.lookup(section.name, section.path, scope, section.at)
  let saved_table = self.table
  if !section.inverted &&
    (section.mode == @tag.MODE_ROWS || section.mode == @tag.MODE_SLOTS) &&
    self.table == 0 {
    self.tables += 1
    self.table = self.tables
  }
  if section.mode == @tag.MODE_SLOTS {
    let items = @tag.items(value)
    let slots = text_section_slots(section, self.tpl)
    if items.length() > slots.length() {
      raise TextFormError(
        "text: " +
        section.at +
        ": " +
        items.length().to_string() +
        " items for the " +
        slots.length().to_string() +
        " lines of {{#" +
        section.name +
        "}}: the lines from this one to that of {{/" +
        section.name +
        "}} are slots, a line for an item (write {{#" +
        section.name +
        " | rows}} to repeat the lines instead)",
      )
    }
    let first = self.tpl.lines[slots[0]]
    for k, li in slots {
      self.step(section.at)
      let mut item_scope = scope.blank_scope(
        Map([
          ("_blank", Json::boolean(true)),
          ("_blank_first", Json::boolean(k == items.length())),
          ("_index", Json::number((k + 1).to_double())),
          ("_count", Json::number(items.length().to_double())),
        ]),
      )
      if k < items.length() {
        let vars = @tag.vars(k, items.length(), false)
        vars["_blank"] = Json::boolean(false)
        vars["_blank_first"] = Json::boolean(false)
        item_scope = scope.item(items[k], vars)
      }
      let line = self.tpl.lines[li]
      let template = if !line.tagged { first } else { line }
      self.emit(template, line.attrs, item_scope)
    }
    self.table = saved_table
    return
  }
  let items : Array[Json] = if section.inverted && !@tag.truthy(value) {
    [Json::null()]
  } else if !section.inverted {
    @tag.items(value)
  } else {
    []
  }
  for k, item in items {
    self.step(section.at)
    let item_scope = if !section.inverted {
      scope.item(item, @tag.vars(k, items.length(), section.mode == @tag.MODE_PAGES))
    } else {
      scope
    }
    if section.mode == @tag.MODE_PAGES && k > 0 {
      self.out.push({ cells: [], brk: true, table: 0, no: 0 })
    }
    self.lines(section, section.a, section.b, item_scope)
  }
  self.table = saved_table
}

///|
fn TextFiller::emit(
  self : TextFiller,
  template : TextLine,
  attrs : Int,
  scope : @tag.Scope,
) -> Unit raise TextFormError {
  if template.brk {
    self.out.push({ cells: [], brk: true, table: 0, no: 0 })
    return
  }
  if template.tag_only {
    return
  }
  let builder : TextLineBuilder = { cells: [], cols: 0, conts: [] }
  self.tokens(template, 0, template.toks.length(), scope, attrs, builder)
  self.out.push({
    cells: text_trim(builder.cells),
    brk: false,
    table: self.table,
    no: template.no,
  })
  let mut more = 0
  for cont in builder.conts {
    more = Int::max(more, cont.pieces.length())
  }
  for k in 0..<more {
    let line : TextLineBuilder = { cells: [], cols: 0, conts: [] }
    for cont in builder.conts {
      if k >= cont.pieces.length() {
        continue
      }
      while line.cols < cont.col {
        line.add(text_cell(" ", 1, 0))
      }
      for cell in cont.pieces[k] {
        line.add(cell)
      }
    }
    self.out.push({
      cells: text_trim(line.cells),
      brk: false,
      table: self.table,
      no: template.no,
    })
  }
  if self.out.length() > MAX_OUT_LINES {
    raise TextFormError(
      "text: the filled form has more than " + MAX_OUT_LINES.to_string() + " lines",
    )
  }
  if builder.cols > self.tpl.grid.width() {
    let warning = "line " +
      template.no.to_string() +
      ": the filled line is " +
      builder.cols.to_string() +
      " columns; the paper has " +
      self.tpl.grid.width().to_string() +
      " after the left margin"
    if !self.warnings.contains(warning) {
      self.warnings.push(warning)
    }
  }
}

///|
fn text_trim(cells : Array[TextCell]) -> Array[TextCell] {
  let mut end = cells.length()
  while end > 0 && cells[end - 1].text == " " {
    end -= 1
  }
  cells[:end].to_array()
}

///|
fn TextFiller::tokens(
  self : TextFiller,
  line : TextLine,
  from : Int,
  to : Int,
  scope : @tag.Scope,
  attrs : Int,
  builder : TextLineBuilder,
) -> Unit raise TextFormError {
  let mut i = from
  while i < to {
    let token = line.toks[i]
    if line.line_level[i] {
      i += 1
      continue
    }
    if token.kind == @tag.TagKind::Text {
      self.text(builder, token.text, attrs)
    } else if token.kind == @tag.TagKind::Value {
      let value = self.lookup(token.name, token.path, scope, line.at())
      self.value(
        builder,
        token,
        @tag.value_text(value, token.format, self.td.format),
        attrs,
        line,
      )
    } else if token.kind == @tag.TagKind::Open ||
      token.kind == @tag.TagKind::Inverted {
      let end = line.matches[i]
      if end < 0 {
        i += 1
        continue
      }
      let attr = attr_of(token.name)
      if attr != 0 {
        self.tokens(line, i + 1, end, scope, attrs | attr, builder)
        i = end + 1
        continue
      }
      let value = self.lookup(token.name, token.path, scope, line.at())
      if token.kind == @tag.TagKind::Inverted {
        if !@tag.truthy(value) {
          self.tokens(line, i + 1, end, scope, attrs, builder)
        }
        i = end + 1
        continue
      }
      let items = @tag.items(value)
      for k, item in items {
        self.step(line.at())
        self.tokens(
          line,
          i + 1,
          end,
          scope.item(item, @tag.vars(k, items.length(), false)),
          attrs,
          builder,
        )
      }
      i = end + 1
      continue
    }
    if builder.cols > MAX_LINE_COLS {
      raise TextFormError(
        "text: " +
        line.at() +
        ": the filled line is more than " +
        MAX_LINE_COLS.to_string() +
        " columns",
      )
    }
    i += 1
  }
}

///|
fn TextFiller::cells(self : TextFiller, value : String, attrs : Int, start_col : Int) -> Array[TextCell] {
  let out : Array[TextCell] = []
  let mut col = start_col
  for r in value {
    if r == '\t' {
      let n = 8 - col % 8
      for _ in 0..<n {
        out.push(text_cell(" ", 1, attrs ^ (attrs & ATTR_WIDE)))
      }
      col += n
      continue
    }
    let code = r.to_int()
    if code < 0x20 || code == 0x7f || (code >= 0x80 && code < 0xa0) {
      continue
    }
    let w = @textpart.width(r, self.tpl.grid.ambiguous_wide)
    if w == 0 && !out.is_empty() {
      out[out.length() - 1].text += r.to_string()
      continue
    }
    let cell = text_cell(r.to_string(), w, attrs)
    out.push(cell)
    col += cell.cols()
  }
  out
}

///|
fn TextFiller::text(self : TextFiller, builder : TextLineBuilder, value : String, attrs : Int) -> Unit {
  for cell in self.cells(value, attrs, builder.cols) {
    if cell.w == 0 && !builder.cells.is_empty() {
      builder.cells[builder.cells.length() - 1].text += cell.text
      continue
    }
    builder.add(cell)
  }
}

///|
fn TextFiller::value(
  self : TextFiller,
  builder : TextLineBuilder,
  token : @tag.TagToken,
  value : String,
  attrs : Int,
  line : TextLine,
) -> Unit {
  let value = value
    .replace(old="\r\n", new="\n")
    .replace(old="\r", new="\n")
  let mut paras = value.split("\n").map(fn(part) { part.to_owned() }).to_array()
  if token.width > 0 &&
    token.overflow != @tag.OVERFLOW_WRAP &&
    paras.length() > 1 {
    paras = [paras.join(" ")]
  }
  let col = builder.cols
  let pieces : Array[Array[TextCell]] = []
  for para in paras {
    let cs = self.cells(para, attrs, col)
    if token.width == 0 {
      pieces.push(cs)
    } else if token.overflow == @tag.OVERFLOW_WRAP {
      let mut rest = cs
      while !rest.is_empty() {
        let mut n = 0
        let mut w = 0
        while n < rest.length() && (n == 0 || w + rest[n].cols() <= token.width) {
          w += rest[n].cols()
          n += 1
        }
        pieces.push(text_pad(rest[:n].to_array(), token, attrs))
        rest = rest[n:].to_array()
      }
      if rest.is_empty() && (pieces.is_empty() || para == "") {
        pieces.push(text_pad([], token, attrs))
      }
    } else if token.overflow == @tag.OVERFLOW_CUT {
      let mut n = 0
      let mut w = 0
      while n < cs.length() && w + cs[n].cols() <= token.width {
        w += cs[n].cols()
        n += 1
      }
      pieces.push(text_pad(cs[:n].to_array(), token, attrs))
    } else {
      if cells_cols(cs) > token.width {
        let warning = line.at() +
          ": the value of {{" +
          token.name +
          "}} is " +
          cells_cols(cs).to_string() +
          " columns, more than its " +
          token.width.to_string() +
          "; it is written whole (| cut cuts it, | wrap goes on to the next line)"
        if !self.warnings.contains(warning) {
          self.warnings.push(warning)
        }
      }
      pieces.push(text_pad(cs, token, attrs))
    }
  }
  if pieces.is_empty() {
    pieces.push(text_pad([], token, attrs))
  }
  for cell in pieces[0] {
    builder.add(cell)
  }
  if pieces.length() > 1 {
    let rest : Array[Array[TextCell]] = []
    for i in 1..<pieces.length() {
      rest.push(pieces[i])
    }
    builder.conts.push({ col, pieces: rest })
  }
}

///|
fn text_pad(cells : Array[TextCell], token : @tag.TagToken, attrs : Int) -> Array[TextCell] {
  if token.width == 0 {
    return cells
  }
  let room = token.width - cells_cols(cells)
  if room <= 0 {
    return cells
  }
  let spaces = fn(n : Int) -> Array[TextCell] {
    let out : Array[TextCell] = []
    for _ in 0..<n {
      out.push(text_cell(" ", 1, attrs ^ (attrs & ATTR_WIDE)))
    }
    out
  }
  let left = if token.align == @tag.ALIGN_RIGHT {
    room
  } else if token.align == @tag.ALIGN_CENTER {
    room / 2
  } else {
    0
  }
  let out : Array[TextCell] = []
  for cell in spaces(left) {
    out.push(cell)
  }
  for cell in cells {
    out.push(cell)
  }
  for cell in spaces(room - left) {
    out.push(cell)
  }
  out
}

///|
fn text_used(lines : Array[TextOutLine]) -> Int {
  let mut n = 0
  for line in lines {
    n += 1
    if line.tall() {
      n += 1
    }
  }
  n
}

///|
fn TextFiller::paginate(self : TextFiller) -> Array[TextPage] raise TextFormError {
  let rows = self.tpl.grid.rows()
  let pages : Array[Array[TextOutLine]] = []
  let mut current : Array[TextOutLine] = []
  let title : Array[TextOutLine] = []
  let mut title_open = self.tpl.grid.title > 0
  for line in self.out {
    if line.brk {
      title_open = false
      pages.push(current)
      current = title.copy()
      continue
    }
    let need = if line.tall() { 2 } else { 1 }
    if rows > 0 && text_used(current) + need > rows {
      if line.cells.is_empty() && !self.tpl.grows {
        continue
      }
      if !self.tpl.grows {
        raise TextFormError(
          "text: page " +
          (pages.length() + 1).to_string() +
          ": line " +
          line.no.to_string() +
          " of the template is past the " +
          rows.to_string() +
          " lines of a page (" +
          self.tpl.grid.lines.to_string() +
          " lines of paper less the top margin " +
          self.tpl.grid.top.to_string() +
          " and the skip " +
          self.tpl.grid.skip.to_string() +
          "); only a form with a section of | rows goes on to another page by itself",
        )
      }
      title_open = false
      pages.push(current)
      current = title.copy()
      if text_used(current) + need > rows {
        raise TextFormError(
          "text: page " +
          (pages.length() + 1).to_string() +
          ": the title leaves no room for line " +
          line.no.to_string() +
          " of the template",
        )
      }
    }
    current.push(line)
    if title_open {
      title.push(line)
      if text_used(title) >= self.tpl.grid.title {
        title_open = false
      }
    }
  }
  if pages.is_empty() ||
    current.length() > title.length() ||
    (!self.out.is_empty() && !self.out[self.out.length() - 1].brk) {
    pages.push(current)
  }
  let out : Array[TextPage] = []
  for lines in pages {
    let tables : Array[Int] = []
    for line in lines {
      tables.push(line.table)
    }
    out.push({ lines, tables })
  }
  out
}

///|
fn text_size_of(attrs : Int) -> String {
  match attrs & (ATTR_WIDE | ATTR_TALL) {
    x if x == ATTR_WIDE => @textpart.SIZE_WIDE
    x if x == ATTR_TALL => @textpart.SIZE_TALL
    x if x == (ATTR_WIDE | ATTR_TALL) => @textpart.SIZE_BIG
    _ => ""
  }
}

///|
fn text_part_line(cells : Array[TextCell]) -> @textpart.Line {
  let text = StringBuilder()
  let paper : Array[@textpart.Range] = []
  let sizes : Array[@textpart.Range] = []
  let mut col = 0
  let mut paper_open = false
  let mut paper_at = 0
  let mut size_open = false
  let mut size_at = 0
  let mut size_name = ""
  for cell in cells {
    text.write_string(cell.text)
    let n = cell.cols()
    let is_paper = (cell.attrs & ATTR_PAPER) != 0
    if is_paper {
      if paper_open && paper_at + paper[paper.length() - 1].cols == col {
        let last = paper[paper.length() - 1]
        paper[paper.length() - 1] = @textpart.Range::new(
          last.col,
          last.cols + n,
          last.size,
        )
      } else if n > 0 {
        paper.push(@textpart.Range::new(col, n, ""))
        paper_open = true
        paper_at = col
      }
    } else {
      paper_open = false
    }
    let size = text_size_of(cell.attrs)
    if size != "" {
      if size_open &&
        size_name == size &&
        size_at + sizes[sizes.length() - 1].cols == col {
        let last = sizes[sizes.length() - 1]
        sizes[sizes.length() - 1] = @textpart.Range::new(
          last.col,
          last.cols + n,
          last.size,
        )
      } else if n > 0 {
        sizes.push(@textpart.Range::new(col, n, size))
        size_open = true
        size_at = col
        size_name = size
      }
    } else {
      size_open = false
    }
    col += n
  }
  { text: text.to_string(), paper, size: sizes }
}

///|
fn TextFiller::image(self : TextFiller, pages : Array[TextPage]) -> @textpart.Image {
  let image : @textpart.Image = {
    version: @textpart.VERSION,
    cpi: self.tpl.grid.cpi,
    lpi: self.tpl.grid.lpi,
    columns: self.tpl.grid.columns,
    lines: self.tpl.grid.lines,
    margin: { left: self.tpl.grid.left, top: self.tpl.grid.top },
    skip: self.tpl.grid.skip,
    ambiguous_wide: self.tpl.grid.ambiguous_wide,
    font: self.tpl.grid.font,
    pages: [],
  }
  for page in pages {
    let lines : Array[@textpart.Line] = []
    for line in page.lines {
      lines.push(text_part_line(line.cells))
      if line.tall() {
        lines.push(@textpart.Line::new(""))
      }
    }
    image.pages.push({ lines })
  }
  image
}

///|
/// A filled text form: the print image and the table of each line of each
/// page (0 for none; a tall line takes two entries).
pub(all) struct TextFormResult {
  image : @textpart.Image
  tables : Array[Array[Int]]
}

///|
/// Fill a text template with data and its options.
pub fn fill_result_with(
  td : TextTemplateData,
  template : String,
) -> TextFormResult raise TextFormError {
  let tpl = parse_template(@utf8.encode(template))
  let filler = text_filler(tpl, td)
  filler.lines(
    tpl.root,
    0,
    tpl.lines.length() - 1,
    @tag.Scope::new(Json::object(td.data)),
  )
  let pages = filler.paginate()
  let tables : Array[Array[Int]] = []
  for page in pages {
    let rows : Array[Int] = []
    for i, line in page.lines {
      rows.push(page.tables[i])
      if line.tall() {
        rows.push(page.tables[i])
      }
    }
    tables.push(rows)
  }
  { image: filler.image(pages), tables }
}

///|
/// Fill a text template with data.
pub fn fill_result(
  data : Map[String, Json],
  template : String,
) -> TextFormResult raise TextFormError {
  fill_result_with(TextTemplateData::new(data), template)
}

///|
/// Fill a text template with data and return the print image of the form.
pub fn fill_image(
  data : Map[String, Json],
  template : String,
) -> @textpart.Image raise TextFormError {
  fill_result(data, template).image
}

///|
/// Fill a text template with the JSON/CSV sources of form/data.
pub fn fill_sources(
  template : String,
  sources : Array[@data.Source],
) -> TextFormResult raise TextFormError {
  let data = @data.load_data(sources) catch {
    @data.DataError(message) => raise TextFormError(message)
  }
  fill_result(data, template)
}

