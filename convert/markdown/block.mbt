///|
priv struct MdListMarker {
  ordered : Bool
  number : Int
  indent : Int
  content_start : Int
  content : String
}

///|
fn md_indent_of(line : String) -> Int {
  let mut column = 0
  for c in line {
    if c == ' ' {
      column += 1
    } else if c == '\t' {
      column += 4 - column % 4
    } else {
      break
    }
  }
  column
}

///|
fn md_dedent(line : String, amount : Int) -> String {
  let mut column = 0
  let mut index = 0
  let chars = line.to_array()
  while index < chars.length() && column < amount {
    if chars[index] == ' ' {
      column += 1
    } else if chars[index] == '\t' {
      column += 4 - column % 4
    } else {
      break
    }
    index += 1
  }
  String::from_array(chars[index:])
}

///|
fn md_list_marker(line : String) -> MdListMarker? {
  let indent = md_indent_of(line)
  let chars = line.to_array()
  let mut i = 0
  let mut column = 0
  while i < chars.length() && column < indent {
    if chars[i] == ' ' {
      column += 1
    } else if chars[i] == '\t' {
      column += 4 - column % 4
    }
    i += 1
  }
  if i >= chars.length() {
    return None
  }
  let c = chars[i]
  if c == '-' || c == '*' || c == '+' {
    if i + 1 < chars.length() &&
      (chars[i + 1] == ' ' || chars[i + 1] == '\t') {
      let mut start = i + 1
      while start < chars.length() &&
        (chars[start] == ' ' || chars[start] == '\t') {
        start += 1
      }
      return Some({
        ordered: false,
        number: 0,
        indent,
        content_start: start,
        content: String::from_array(chars[start:]),
      })
    }
    return None
  }
  if c >= '0' && c <= '9' {
    let mut end = i
    while end < chars.length() && chars[end] >= '0' && chars[end] <= '9' {
      end += 1
    }
    if end < chars.length() &&
      (chars[end] == '.' || chars[end] == ')') &&
      end + 1 < chars.length() &&
      (chars[end + 1] == ' ' || chars[end + 1] == '\t') {
      let number = @string.parse_int(String::from_array(chars[i:end])) catch {
        _ => 1
      }
      let mut start = end + 1
      while start < chars.length() &&
        (chars[start] == ' ' || chars[start] == '\t') {
        start += 1
      }
      return Some({
        ordered: true,
        number,
        indent,
        content_start: start,
        content: String::from_array(chars[start:]),
      })
    }
  }
  None
}

///|
fn md_atx_heading(line : String) -> (Int, String)? {
  let indent = md_indent_of(line)
  if indent > 3 {
    return None
  }
  let chars = line.to_array()
  let mut i = 0
  while i < chars.length() && (chars[i] == ' ' || chars[i] == '\t') {
    i += 1
  }
  let mut level = 0
  while i + level < chars.length() && chars[i + level] == '#' && level < 6 {
    level += 1
  }
  if level == 0 {
    return None
  }
  if i + level < chars.length() &&
    chars[i + level] != ' ' &&
    chars[i + level] != '\t' {
    return None
  }
  let mut start = i + level
  while start < chars.length() &&
    (chars[start] == ' ' || chars[start] == '\t') {
    start += 1
  }
  let mut text = String::from_array(chars[start:]).trim().to_string()
  // Closing sequence of # characters.
  while text.has_suffix("#") {
    text = text[:text.length() - 1].to_owned().trim_end().to_string()
  }
  Some((level, text))
}

///|
fn md_fence(line : String) -> (String, String)? {
  let indent = md_indent_of(line)
  if indent > 3 {
    return None
  }
  let trimmed = line.trim()
  if trimmed.has_prefix("\u0060\u0060\u0060") || trimmed.has_prefix("~~~") {
    let marker = trimmed[:3].to_owned()
    let info = trimmed[3:].to_owned().trim().to_string()
    Some((marker, info))
  } else {
    None
  }
}

///|
fn md_is_thematic(line : String) -> Bool {
  let trimmed = line.trim()
  if trimmed.length() < 3 {
    return false
  }
  let first = trimmed[0].to_char().unwrap()
  if first != '-' && first != '*' && first != '_' {
    return false
  }
  let mut count = 0
  for c in trimmed {
    if c == first {
      count += 1
    } else if c != ' ' && c != '\t' {
      return false
    }
  }
  count >= 3
}

///|
fn md_is_quote(line : String) -> Bool {
  md_indent_of(line) <= 3 && line.trim().has_prefix(">")
}

///|
fn md_quote_content(line : String) -> String {
  let trimmed = line.trim()
  if trimmed.length() > 1 && trimmed[1].to_char().unwrap() == ' ' {
    trimmed[2:].to_owned()
  } else if trimmed.length() > 1 {
    trimmed[1:].to_owned()
  } else {
    ""
  }
}

///|
fn md_is_html_start(line : String) -> Bool {
  let trimmed = line.trim().to_lower()
  if !trimmed.has_prefix("<") {
    return false
  }
  for name in [
    "<table", "<div", "<details", "<p", "<svg", "<img", "<style", "<script",
    "<pre", "<blockquote", "<ul", "<ol", "<h1", "<h2", "<h3", "<h4", "<h5",
    "<h6", "<figure", "<section", "<article", "<center", "<!doctype", "<!--",
  ] {
    if trimmed.has_prefix(name) {
      return true
    }
  }
  false
}

///|
fn md_is_table_delimiter(line : String) -> Bool {
  let trimmed = line.trim()
  if !trimmed.contains("-") {
    return false
  }
  if !trimmed.contains("|") {
    return false
  }
  for c in trimmed {
    if c != '|' && c != '-' && c != ':' && c != ' ' && c != '\t' {
      return false
    }
  }
  true
}

///|
fn md_split_table_row(line : String) -> Array[String] {
  let trimmed = line.trim()
  let mut body = trimmed
  if body.has_prefix("|") {
    body = body[1:].to_owned()
  }
  if body.has_suffix("|") {
    body = body[:body.length() - 1].to_owned()
  }
  let cells : Array[String] = []
  for cell in body.split("|") {
    cells.push(cell.trim().to_string())
  }
  cells
}

///|
fn md_table_alignments(line : String) -> Array[Int] {
  let cells = md_split_table_row(line)
  let out : Array[Int] = []
  for cell in cells {
    let trimmed = cell.trim()
    let left = trimmed.has_prefix(":")
    let right = trimmed.has_suffix(":")
    if left && right {
      out.push(1)
    } else if right {
      out.push(2)
    } else {
      out.push(0)
    }
  }
  out
}

///|
fn md_inline_runs(
  text : String,
  style : @drawingml.TextStyle,
  formulas : Array[String],
  images : Array[(String, String, String)],
  svgs : Array[MdSvg],
  sprite : StringBuilder,
  warnings : Array[String],
) -> Array[MdRun] {
  let runs : Array[MdRun] = []
  let inlines = @mdinline.parse_inlines_with_options(
    text,
    @mmtypes.MarkdownOptions::gfm(),
  )
  md_collect_inlines(inlines, style, "", runs, formulas, images, svgs, sprite, warnings)
  runs
}

///|
priv struct MdParser {
  formulas : Array[String]
  images : Array[(String, String, String)]
  warnings : Array[String]
  mut title : String
  svgs : Array[MdSvg]
  sprite : StringBuilder
}

///|
fn MdParser::paragraph(self : MdParser, text : String) -> MdBlock {
  let runs = md_inline_runs(
    text, md_style(), self.formulas, self.images, self.svgs, self.sprite,
    self.warnings,
  )
  MdParagraph(runs)
}

///|
fn MdParser::heading(self : MdParser, level : Int, text : String) -> MdBlock {
  let runs = md_inline_runs(
    text,
    md_style(size=md_heading_size(level), bold=true),
    self.formulas,
    self.images,
    self.svgs,
    self.sprite,
    self.warnings,
  )
  if level == 1 && self.title == "" {
    self.title = md_runs_text(runs)
  }
  MdHeading(level, runs)
}

///|
fn md_heading_size(level : Int) -> Double {
  match level {
    1 => 24.0
    2 => 20.0
    3 => 16.0
    _ => 14.0
  }
}

///|
fn MdParser::parse_blocks(self : MdParser, lines : Array[String], level : Int) -> Array[MdBlock] {
  let out : Array[MdBlock] = []
  let mut i = 0
  while i < lines.length() {
    let line = lines[i]
    let trimmed = line.trim()
    if trimmed == "" {
      i += 1
      continue
    }
    match md_atx_heading(line) {
      Some((heading_level, text)) => {
        out.push(self.heading(heading_level, text))
        i += 1
        continue
      }
      None => ()
    }
    match md_fence(line) {
      Some((marker, info)) => {
        i += 1
        let code : Array[String] = []
        while i < lines.length() && !lines[i].trim().to_owned().has_prefix(marker) {
          code.push(lines[i])
          i += 1
        }
        if i < lines.length() {
          i += 1
        }
        if info.to_lower() == "math" {
          out.push(MdMath(code.join("\n")))
        } else {
          out.push(MdCode(code))
        }
        continue
      }
      None => ()
    }
    if md_is_thematic(line) {
      out.push(MdRule)
      i += 1
      continue
    }
    if md_is_quote(line) {
      let quote_lines : Array[String] = []
      let mut j = i
      while j < lines.length() {
        if md_is_quote(lines[j]) {
          quote_lines.push(md_quote_content(lines[j]))
          j += 1
        } else if lines[j].trim() == "" {
          let mut k = j + 1
          while k < lines.length() && lines[k].trim() == "" {
            k += 1
          }
          if k < lines.length() && md_is_quote(lines[k]) {
            quote_lines.push("")
            j += 1
          } else {
            break
          }
        } else {
          break
        }
      }
      out.push(MdQuote(self.parse_blocks(quote_lines, level)))
      i = j
      continue
    }
    match md_list_marker(line) {
      Some(marker) => {
        let (items, next) = self.parse_list(lines, i, level, marker)
        for item in items {
          out.push(item)
        }
        i = next
        continue
      }
      None => ()
    }
    if i + 1 < lines.length() &&
      trimmed.contains("|") &&
      md_is_table_delimiter(lines[i + 1]) {
      let header_cells = md_split_table_row(line)
      let alignments = md_table_alignments(lines[i + 1])
      let header : Array[Array[MdRun]] = []
      for cell in header_cells {
        header.push(
          md_inline_runs(
            cell, md_style(bold=true), self.formulas, self.images, self.svgs,
            self.sprite, self.warnings,
          ),
        )
      }
      let rows : Array[Array[Array[MdRun]]] = []
      i += 2
      while i < lines.length() &&
        lines[i].trim() != "" &&
        lines[i].contains("|") {
        let cells = md_split_table_row(lines[i])
        let row : Array[Array[MdRun]] = []
        for cell in cells {
          row.push(
            md_inline_runs(
              cell, md_style(), self.formulas, self.images, self.svgs,
              self.sprite, self.warnings,
            ),
          )
        }
        rows.push(row)
        i += 1
      }
      out.push(MdTable(header, rows, alignments))
      continue
    }
    if md_is_html_start(line) {
      let html_lines : Array[String] = []
      let lower = trimmed.to_lower()
      let closing = if lower.has_prefix("<details") {
        "</details>"
      } else if lower.has_prefix("<svg") {
        "</svg>"
      } else {
        ""
      }
      let mut j = i
      while j < lines.length() {
        html_lines.push(lines[j])
        let line_lower = lines[j].to_lower()
        j += 1
        if closing != "" {
          if line_lower.contains(closing) {
            break
          }
        } else if j < lines.length() && lines[j].trim() == "" {
          break
        }
      }
      for block in md_block_from_html(
        html_lines.join("\n"), self.formulas, self.images, self.svgs, self.sprite,
        self.warnings,
      ) {
        out.push(block)
      }
      i = j
      continue
    }
    if md_indent_of(line) >= 4 {
      let code : Array[String] = []
      while i < lines.length() &&
        (lines[i].trim() == "" || md_indent_of(lines[i]) >= 4) {
        if lines[i].trim() == "" {
          code.push("")
        } else {
          code.push(md_dedent(lines[i], 4))
        }
        i += 1
      }
      out.push(MdCode(code))
      continue
    }
    if i + 1 < lines.length() {
      let next = lines[i + 1].trim()
      if next.length() > 0 && (next[0].to_char().unwrap() == '=' || next[0].to_char().unwrap() == '-') {
        let mut all_marker = true
        let marker = next[0].to_char().unwrap()
        for c in next {
          if c != marker {
            all_marker = false
            break
          }
        }
        if all_marker {
          out.push(
            self.heading(
              if marker == '=' { 1 } else { 2 }, trimmed.to_string(),
            ),
          )
          i += 2
          continue
        }
      }
      if next.has_prefix(": ") {
        out.push(self.paragraph(trimmed.to_string()))
        let mut j = i + 1
        while j < lines.length() {
          let current = lines[j].trim()
          if current.has_prefix(": ") {
            out.push(self.paragraph(current[2:].to_owned().trim().to_string()))
            j += 1
            continue
          }
          if current != "" && md_indent_of(lines[j]) > 0 {
            out.push(self.paragraph(current.to_string()))
            j += 1
            continue
          }
          break
        }
        i = j
        continue
      }
    }
    let paragraph_lines : Array[String] = []
    while i < lines.length() {
      let current = lines[i]
      if current.trim() == "" {
        break
      }
      if paragraph_lines.length() > 0 {
        if md_atx_heading(current) is Some(_) ||
          md_fence(current) is Some(_) ||
          md_is_thematic(current) ||
          md_is_quote(current) ||
          md_list_marker(current) is Some(_) ||
          md_is_html_start(current) ||
          (i + 1 < lines.length() && md_is_table_delimiter(lines[i + 1])) {
          break
        }
      }
      paragraph_lines.push(current.trim().to_string())
      i += 1
    }
    if paragraph_lines.is_empty() {
      i += 1
    } else {
      out.push(self.paragraph(paragraph_lines.join("\n")))
    }
  }
  out
}

///|
fn MdParser::parse_list(
  self : MdParser,
  lines : Array[String],
  start : Int,
  level : Int,
  first : MdListMarker,
) -> (Array[MdBlock], Int) {
  let out : Array[MdBlock] = []
  let base_indent = first.indent
  let ordered = first.ordered
  let mut i = start
  while i < lines.length() {
    let marker = match md_list_marker(lines[i]) {
      Some(value) => value
      None => break
    }
    if marker.indent != base_indent || marker.ordered != ordered {
      break
    }
    let content_indent = marker.content_start
    let item_lines : Array[String] = [marker.content]
    i += 1
    while i < lines.length() {
      let current = lines[i]
      if current.trim() == "" {
        let mut j = i + 1
        while j < lines.length() && lines[j].trim() == "" {
          j += 1
        }
        if j >= lines.length() {
          i = j
          break
        }
        match md_list_marker(lines[j]) {
          Some(next) =>
            if next.indent == base_indent {
              i = j
              break
            }
          None => ()
        }
        if md_indent_of(lines[j]) > base_indent {
          item_lines.push("")
          i += 1
          continue
        }
        i = j
        break
      }
      match md_list_marker(current) {
        Some(next) if next.indent == base_indent => break
        _ =>
          if md_indent_of(current) > base_indent {
            item_lines.push(md_dedent(current, content_indent))
            i += 1
          } else {
            break
          }
      }
    }
    let item_blocks = self.parse_blocks(item_lines, level + 1)
    let mut runs : Array[MdRun] = []
    let rest : Array[MdBlock] = []
    let mut found = false
    for block in item_blocks {
      match block {
        MdParagraph(value) if !found => {
          runs = value
          found = true
        }
        _ => rest.push(block)
      }
    }
    let joined = md_runs_text(runs)
    let task = joined.has_prefix("[ ] ") ||
      joined.has_prefix("[x] ") ||
      joined.has_prefix("[X] ")
    if task {
      runs = md_trim_task_marker(runs)
    }
    let marker_text = if task {
      ""
    } else if ordered {
      marker.number.to_string() + ". "
    } else {
      match level % 3 {
        0 => "• "
        1 => "◦ "
        _ => "▪ "
      }
    }
    out.push(MdListItem(level, marker_text, runs))
    for block in rest {
      out.push(block)
    }
  }
  (out, i)
}

///|
/// Read a footnote definition line: [^label]: body.
fn md_footnote_definition(line : String) -> (String, String)? {
  let trimmed = line.trim()
  if !trimmed.has_prefix("[^") {
    return None
  }
  let close = match trimmed.find("]:") {
    Some(index) => index
    None => return None
  }
  if close <= 2 {
    return None
  }
  let id = trimmed[2:close].to_owned()
  if id.contains("]") {
    return None
  }
  let body = trimmed[close + 2:].to_owned().trim().to_string()
  Some((id, body))
}

///|
/// The first reference of every footnote of a line, in reading order, moves
/// from defs into numbered. Code spans and escaped brackets are not
/// references.
fn md_number_footnotes(
  line : String,
  defs : Map[String, String],
  numbers : Map[String, Int],
  numbered : Array[String],
) -> Unit {
  let chars = line.to_array()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '\\' && i + 1 < chars.length() {
      i += 2
      continue
    }
    if chars[i] == '\u0060' {
      let mut ticks = 1
      while i + ticks < chars.length() && chars[i + ticks] == '\u0060' {
        ticks += 1
      }
      let marker = String::from_array(chars[i:i + ticks])
      let rest = String::from_array(chars[i + ticks:])
      match rest.find(marker) {
        Some(index) => i = i + ticks + index + ticks
        None => i += ticks
      }
      continue
    }
    if chars[i] == '[' && i + 1 < chars.length() && chars[i + 1] == '^' {
      let mut close = i + 2
      while close < chars.length() && chars[close] != ']' {
        close += 1
      }
      if close < chars.length() {
        let id = String::from_array(chars[i + 2:close])
        if defs.contains(id) && !numbers.contains(id) {
          let number = numbered.length() + 1
          numbers[id] = number
          numbered.push(id)
        }
        i = close + 1
        continue
      }
    }
    i += 1
  }
}

///|
fn md_footnote_prepare(lines : Array[String]) -> (Array[String], Array[(Int, String)]) {
  let defs : Map[String, String] = Map([])
  let kept : Array[String] = []
  let mut fenced = false
  let mut fence = ""
  let mut i = 0
  while i < lines.length() {
    let line = lines[i]
    let trimmed = line.trim()
    if fenced {
      kept.push(line)
      if trimmed.has_prefix(fence) {
        fenced = false
      }
      i += 1
      continue
    }
    if trimmed.has_prefix("\u0060\u0060\u0060") || trimmed.has_prefix("~~~") {
      fenced = true
      fence = trimmed[:3].to_owned()
      kept.push(line)
      i += 1
      continue
    }
    if md_indent_of(line) >= 4 {
      kept.push(line)
      i += 1
      continue
    }
    match md_footnote_definition(line) {
      Some(entry) => {
        let (id, first) = entry
        let mut body = first
        i += 1
        while i < lines.length() {
          let current = lines[i]
          if current.trim() == "" {
            let mut j = i + 1
            while j < lines.length() && lines[j].trim() == "" {
              j += 1
            }
            if j < lines.length() && md_indent_of(lines[j]) > 0 {
              if body != "" {
                body += "\n"
              }
              i = j
              continue
            }
            break
          }
          if md_indent_of(current) > 0 {
            if body != "" {
              body += " "
            }
            body += current.trim().to_string()
            i += 1
            continue
          }
          break
        }
        if !defs.contains(id) {
          defs[id] = body
        }
        continue
      }
      None => ()
    }
    kept.push(line)
    i += 1
  }
  let numbers : Map[String, Int] = Map([])
  let numbered : Array[String] = []
  for line in kept {
    md_number_footnotes(line, defs, numbers, numbered)
  }
  let replaced : Array[String] = []
  for line in kept {
    replaced.push(md_replace_footnotes(line, numbers))
  }
  let definitions : Array[(Int, String)] = []
  for id in numbered {
    match defs.get(id) {
      Some(body) => definitions.push((numbers[id], body))
      None => ()
    }
  }
  (replaced, definitions)
}

///|
fn md_replace_footnotes(line : String, numbers : Map[String, Int]) -> String {
  let out = StringBuilder()
  let chars = line.to_array()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '\\' && i + 1 < chars.length() {
      out.write_char(chars[i])
      out.write_char(chars[i + 1])
      i += 2
      continue
    }
    if chars[i] == '\u0060' {
      let mut ticks = 1
      while i + ticks < chars.length() && chars[i + ticks] == '\u0060' {
        ticks += 1
      }
      let marker = String::from_array(chars[i:i + ticks])
      out.write_string(marker)
      i += ticks
      let rest = String::from_array(chars[i:])
      match rest.find(marker) {
        Some(index) => {
          out.write_string(String::from_array(chars[i:i + index + ticks]))
          i = i + index + ticks
        }
        None => ()
      }
      continue
    }
    if chars[i] == '[' && i + 1 < chars.length() && chars[i + 1] == '^' {
      let mut close = i + 2
      while close < chars.length() && chars[close] != ']' {
        close += 1
      }
      if close < chars.length() {
        let id = String::from_array(chars[i + 2:close])
        match numbers.get(id) {
          Some(number) => {
            out.write_char(' ')
            out.write_string(number.to_string())
            i = close + 1
            continue
          }
          None => ()
        }
      }
    }
    out.write_char(chars[i])
    i += 1
  }
  out.to_string()
}
