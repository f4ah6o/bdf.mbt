///|
// The fill of OOXML parts: a section repeats the rows, paragraphs or shapes
// it covers, and the tags inside them are filled with the data. The parts are
// read as text, so a tag that markup splits is still one tag.

///|
priv enum Tok {
  TText(String)
  TValue(TagTok)
  TOpen(TagTok)
  TClose(TagTok)
}

///|
priv struct TagTok {
  token : @tag.TagToken
  raw : String
}

///|
priv struct Block {
  start : Int
  end : Int
  mut start_tok : Int
  mut end_tok : Int
  mut marker_only : Bool
}

///|
priv struct Sec {
  name : String
  path : Array[String]
  mode : String
  inverted : Bool
  mut inline : Bool
  mut row_level : Bool
  mut b0 : Int
  mut b1 : Int
  open_tok : Int
  mut close_tok : Int
  mut enter_tok : Int
  mut exit_tok : Int
  mut body_start : Int
  mut body_end : Int
  parent : Int
}

///|
priv struct Layout {
  kind : Int
  blocks : Array[Block]
  rows : Array[Block]
  row_of : Array[Int]
  block_of_tok : Array[Int]
  container_of_tok : Array[Int]
}

///|
priv struct Ctx {
  tokens : Array[Tok]
  layout : Layout
  sections : Array[Sec]
  starts_at : Map[Int, Int]
  strict : Bool
  sections_on : Bool
  warnings : Array[String]
}

///|
fn ooxml_name_end(rest : StringView) -> Bool {
  rest.has_prefix(" ") ||
  rest.has_prefix("\t") ||
  rest.has_prefix("\r") ||
  rest.has_prefix("\n") ||
  rest.has_prefix(">") ||
  rest.has_prefix("/")
}

///|
/// The byte ranges of the elements of a tag, in the order of the document.
fn ooxml_elements(
  xml : String,
  tag : String,
  from : Int,
  to : Int,
) -> Array[(Int, Int)] {
  let out : Array[(Int, Int)] = []
  let open_needle = "<" + tag
  let close_needle = "</" + tag
  let mut pos = from
  while pos < to {
    let start = match xml[pos:to].find(open_needle) {
      Some(index) => pos + index
      None => break
    }
    let after = start + open_needle.length()
    if after > to || !ooxml_name_end(xml[after:to]) {
      pos = after
      continue
    }
    let gt = match xml[after:to].find(">") {
      Some(index) => after + index
      None => break
    }
    if xml[gt - 1:].has_prefix("/") {
      out.push((start, gt + 1))
      pos = gt + 1
      continue
    }
    let mut depth = 1
    let mut scan = gt + 1
    let mut end = -1
    while scan < to {
      let next_open = xml[scan:to].find(open_needle)
      let next_close = xml[scan:to].find(close_needle)
      let (index, is_open) = match (next_open, next_close) {
        (Some(a), Some(b)) => if a < b { (scan + a, true) } else { (scan + b, false) }
        (Some(a), None) => (scan + a, true)
        (None, Some(b)) => (scan + b, false)
        (None, None) => break
      }
      if is_open {
        let a = index + open_needle.length()
        if a <= to && ooxml_name_end(xml[a:to]) {
          let g = match xml[a:to].find(">") {
            Some(i) => a + i
            None => break
          }
          if !xml[g - 1:].has_prefix("/") {
            depth += 1
          }
          scan = g + 1
        } else {
          scan = a
        }
      } else {
        depth -= 1
        let a = index + close_needle.length()
        let g = match xml[a:to].find(">") {
          Some(i) => a + i
          None => break
        }
        if depth == 0 {
          end = g + 1
          break
        }
        scan = g + 1
      }
    }
    if end < 0 {
      break
    }
    out.push((start, end))
    pos = end
  }
  out
}

///|
/// The ranges of the text between the boundaries, so that the ranges cover
/// the whole part.
fn ooxml_leaf_ranges(
  xml : String,
  boundaries : Array[Int],
) -> Array[(Int, Int)] {
  let out : Array[(Int, Int)] = []
  let mut pos = 0
  for boundary in boundaries {
    if boundary > pos {
      out.push((pos, boundary))
    }
    pos = boundary
  }
  if pos < xml.length() {
    out.push((pos, xml.length()))
  }
  out
}

///|
fn ooxml_boundaries(
  xml : String,
  elements : Array[(Int, Int)],
) -> Array[Int] {
  let points : Array[Int] = [0, xml.length()]
  for element in elements {
    let (start, end) = element
    points.push(start)
    points.push(end)
  }
  points.sort()
  let out : Array[Int] = []
  for point in points {
    if out.is_empty() || out[out.length() - 1] != point {
      out.push(point)
    }
  }
  out
}

///|
/// The text of a part without its markup.
fn ooxml_plain(text : String) -> String {
  let out = StringBuilder()
  let mut in_markup = false
  for c in text {
    if c == '<' {
      in_markup = true
    } else if c == '>' {
      in_markup = false
    } else if !in_markup {
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
fn ooxml_tok_len(token : Tok) -> Int {
  match token {
    TText(text) => text.length()
    TValue(t) | TOpen(t) | TClose(t) => t.raw.length()
  }
}

///|
/// Split the text tokens at the boundaries of the blocks, so that a token
/// belongs to one block.
fn ooxml_split_tokens(
  tokens : Array[Tok],
  boundaries : Array[Int],
) -> Array[Tok] {
  let out : Array[Tok] = []
  let mut offset = 0
  for token in tokens {
    match token {
      TText(text) => {
        let end = offset + text.length()
        let mut piece = 0
        let mut start = offset
        for boundary in boundaries {
          if boundary > start && boundary < end {
            let cut = boundary - offset
            out.push(TText(text[piece:cut].to_owned()))
            piece = cut
            start = boundary
          }
        }
        if piece < text.length() {
          out.push(TText(text[piece:].to_owned()))
        }
      }
      _ => out.push(token)
    }
    offset += ooxml_tok_len(token)
  }
  out
}

///|
fn ooxml_layout(xml : String, kind : Int, tokens : Array[Tok]) -> (Layout, Array[Tok]) {
  let elements = match kind {
    1 => ooxml_elements(xml, "row", 0, xml.length())
    2 => ooxml_elements(xml, "w:p", 0, xml.length())
    3 => ooxml_elements(xml, "p:sp", 0, xml.length())
    _ => []
  }
  let rows_elements = if kind == 2 {
    ooxml_elements(xml, "w:tr", 0, xml.length())
  } else {
    []
  }
  let all : Array[(Int, Int)] = []
  for element in elements {
    all.push(element)
  }
  for element in rows_elements {
    all.push(element)
  }
  let boundaries = ooxml_boundaries(xml, all)
  let ranges = ooxml_leaf_ranges(xml, boundaries)
  let tokens = ooxml_split_tokens(tokens, boundaries)
  let offsets : Array[Int] = []
  let mut offset = 0
  for token in tokens {
    offsets.push(offset)
    offset += ooxml_tok_len(token)
  }
  let blocks : Array[Block] = []
  for range in ranges {
    let (start, end) = range
    blocks.push({
      start,
      end,
      start_tok: 0,
      end_tok: 0,
      marker_only: true,
    })
  }
  let block_of_tok : Array[Int] = Array::make(tokens.length(), 0)
  let seen : Array[Bool] = Array::make(ranges.length(), false)
  let mut current = 0
  for i in 0..<tokens.length() {
    while current < ranges.length() && offsets[i] >= ranges[current].1 {
      current += 1
    }
    let b = if current < ranges.length() { current } else { ranges.length() - 1 }
    block_of_tok[i] = b
    if !seen[b] {
      seen[b] = true
      blocks[b].start_tok = i
    }
    blocks[b].end_tok = i
    match tokens[i] {
      TText(text) =>
        if ooxml_plain(text).trim().length() > 0 {
          blocks[b].marker_only = false
        }
      TValue(_) => blocks[b].marker_only = false
      _ => ()
    }
  }
  let container_tag = match kind {
    1 => "c"
    2 => "w:p"
    3 => "p:sp"
    _ => ""
  }
  let containers = if container_tag == "" {
    []
  } else {
    ooxml_elements(xml, container_tag, 0, xml.length())
  }
  let container_of_tok : Array[Int] = Array::make(tokens.length(), -1)
  let mut container = 0
  for i in 0..<tokens.length() {
    while container < containers.length() && offsets[i] >= containers[container].1 {
      container += 1
    }
    if container < containers.length() &&
      offsets[i] >= containers[container].0 {
      container_of_tok[i] = container
    }
  }
  let rows : Array[Block] = []
  let row_of : Array[Int] = Array::make(ranges.length(), -1)
  for element in rows_elements {
    let (start, end) = element
    let mut first = -1
    let mut last = -1
    let mut marker = true
    for b in 0..<ranges.length() {
      if ranges[b].0 >= start && ranges[b].1 <= end {
        row_of[b] = rows.length()
        if first < 0 {
          first = blocks[b].start_tok
        }
        last = blocks[b].end_tok
        if !blocks[b].marker_only {
          marker = false
        }
      }
    }
    rows.push({
      start,
      end,
      start_tok: if first < 0 { 0 } else { first },
      end_tok: if last < 0 { 0 } else { last },
      marker_only: marker,
    })
  }
  ({ kind, blocks, rows, row_of, block_of_tok, container_of_tok }, tokens)
}

///|
fn ooxml_tokenize(
  xml : String,
  warnings : Array[String],
) -> Array[Tok] raise OoxmlError {
  let out : Array[Tok] = []
  let mut pos = 0
  while pos < xml.length() {
    let start = match xml[pos:].find("{{") {
      Some(index) => pos + index
      None => {
        out.push(TText(xml[pos:].to_owned()))
        break
      }
    }
    if start > pos {
      out.push(TText(xml[pos:start].to_owned()))
    }
    let end = match xml[start + 2:].find("}}") {
      Some(index) => start + 2 + index
      None => raise OoxmlError("ooxml: a tag has no closing braces")
    }
    let raw = xml[start:end + 2].to_owned()
    let inner = visible_tag(xml[start + 2:end])
    if inner.has_prefix("!") {
      pos = end + 2
      continue
    }
    let parsed = @tag.parse("{{" + inner + "}}") catch {
      @tag.TagError(message, _) => raise OoxmlError("ooxml: " + message)
    }
    let mut found : @tag.TagToken? = None
    for token in parsed {
      if token.kind != @tag.TagKind::Text {
        found = Some(token)
        break
      }
    }
    match found {
      None => out.push(TText(raw))
      Some(token) =>
        match token.kind {
          @tag.TagKind::Open | @tag.TagKind::Inverted =>
            out.push(TOpen({ token, raw }))
          @tag.TagKind::Close => out.push(TClose({ token, raw }))
          _ => out.push(TValue({ token, raw }))
        }
    }
    pos = end + 2
  }
  out
}

///|
fn ooxml_body_range(sec : Sec, layout : Layout) -> (Int, Int) {
  let blocks = if sec.row_level { layout.rows } else { layout.blocks }
  if sec.inline {
    return (sec.open_tok + 1, sec.close_tok - 1)
  }
  if sec.b0 == sec.b1 {
    return (blocks[sec.b0].start_tok, blocks[sec.b0].end_tok)
  }
  let mut start = blocks[sec.b0].start_tok
  let mut end = blocks[sec.b1].end_tok
  if blocks[sec.b0].marker_only && sec.b0 + 1 <= sec.b1 {
    start = blocks[sec.b0 + 1].start_tok
  }
  if blocks[sec.b1].marker_only && sec.b1 - 1 >= sec.b0 {
    end = blocks[sec.b1 - 1].end_tok
  }
  if start > end {
    (start, start - 1)
  } else {
    (start, end)
  }
}

///|
fn ooxml_sections(
  tokens : Array[Tok],
  layout : Layout,
  strict : Bool,
  warnings : Array[String],
) -> (Array[Sec], Map[Int, Int]) raise OoxmlError {
  let sections : Array[Sec] = []
  let stack : Array[Int] = []
  for i, token in tokens {
    match token {
      TOpen(t) => {
        if t.token.mode == @tag.MODE_SLOTS {
          raise OoxmlError(
            "the section {{#" +
            t.token.name +
            " | slots}} is not supported; write {{#" +
            t.token.name +
            " | rows}} to repeat the rows",
          )
        }
        let parent = if stack.is_empty() { -1 } else { stack[stack.length() - 1] }
        let b = layout.block_of_tok[i]
        sections.push({
          name: t.token.name,
          path: t.token.path,
          mode: t.token.mode,
          inverted: t.token.kind == @tag.TagKind::Inverted,
          inline: false,
          row_level: false,
          b0: b,
          b1: b,
          open_tok: i,
          close_tok: i,
          enter_tok: i,
          exit_tok: i,
          body_start: 0,
          body_end: 0,
          parent,
        })
        stack.push(sections.length() - 1)
      }
      TClose(t) => {
        if stack.is_empty() {
          raise OoxmlError("{{/" + t.token.name + "}} closes no section")
        }
        let index = stack.pop().unwrap()
        let sec = sections[index]
        if t.token.name != "" && t.token.name != sec.name {
          raise OoxmlError(
            "{{/" +
            t.token.name +
            "}} closes the section {{#" +
            sec.name +
            "}}",
          )
        }
        sec.b1 = layout.block_of_tok[i]
        sec.close_tok = i
        let c0 = layout.container_of_tok[sec.open_tok]
        sec.inline = layout.kind == 0 ||
          (c0 >= 0 && c0 == layout.container_of_tok[i])
      }
      _ => ()
    }
  }
  if !stack.is_empty() {
    let sec = sections[stack[stack.length() - 1]]
    raise OoxmlError(
      "the section {{#" + sec.name + "}} is not closed with {{/" + sec.name + "}}",
    )
  }
  for sec in sections {
    if layout.rows.length() > 0 {
      let r0 = layout.row_of[sec.b0]
      let r1 = layout.row_of[sec.b1]
      if r0 >= 0 && r1 >= 0 && r0 != r1 {
        sec.row_level = true
        sec.b0 = r0
        sec.b1 = r1
      } else if (r0 >= 0) != (r1 >= 0) {
        raise OoxmlError(
          "the section {{#" +
          sec.name +
          "}} starts in a table row and ends outside it",
        )
      }
    }
  }
  let starts_at : Map[Int, Int] = Map([])
  for index in 0..<sections.length() {
    let sec = sections[index]
    let blocks = if sec.row_level { layout.rows } else { layout.blocks }
    if sec.inline {
      sec.enter_tok = sec.open_tok
      sec.exit_tok = sec.close_tok
    } else if sec.b0 == sec.b1 {
      sec.enter_tok = blocks[sec.b0].start_tok
      sec.exit_tok = blocks[sec.b0].end_tok
    } else {
      sec.enter_tok = blocks[sec.b0].start_tok
      sec.exit_tok = blocks[sec.b1].end_tok
    }
    if sec.parent >= 0 {
      let parent = sections[sec.parent]
      if sec.enter_tok <= parent.enter_tok || sec.exit_tok > parent.exit_tok {
        raise OoxmlError(
          "the section {{#" +
          sec.name +
          "}} is not inside {{#" +
          parent.name +
          "}}",
        )
      }
    }
    let (start, end) = ooxml_body_range(sec, layout)
    sec.body_start = start
    sec.body_end = end
    match starts_at.get(sec.enter_tok) {
      Some(other) => {
        let outer = sections[other]
        raise OoxmlError(
          "the sections {{#" +
          outer.name +
          "}} and {{#" +
          sec.name +
          "}} both repeat the same block; a block is repeated by one section, or by sections one inside the other",
        )
      }
      None => starts_at[sec.enter_tok] = index
    }
  }
  (sections, starts_at)
}

///|
fn ooxml_number_format(value : Json, format : String) -> String {
  if format == "" {
    return match value {
      Json::Number(number, ..) => number.to_string()
      Json::String(text) => text
      Json::True => "TRUE"
      Json::False => "FALSE"
      _ => ""
    }
  }
  let sections = @xlsx.xlsx_parse_number_format(
    format,
    @xlsx.xlsx_default_palette(),
  )
  match value {
    Json::Number(number, ..) =>
      @xlsx.xlsx_format_number(sections, number, false).text()
    Json::String(text) => @xlsx.xlsx_format_text(sections, text).text()
    Json::True => @xlsx.xlsx_format_text(sections, "TRUE").text()
    Json::False => @xlsx.xlsx_format_text(sections, "FALSE").text()
    _ => ""
  }
}

///|
fn ooxml_fill_value(
  ctx : Ctx,
  t : TagTok,
  scope : @tag.Scope,
  out : StringBuilder,
) -> Unit raise OoxmlError {
  match t.token.kind {
    @tag.TagKind::Image =>
      ctx.warnings.push(
        "ooxml: the image tag " + t.raw + " is not filled; images are not inlined",
      )
    @tag.TagKind::Text => out.write_string(t.token.text)
    _ =>
      match scope.lookup(t.token.path) {
        Some(value) =>
          out.write_string(
            xml_escape(
              @tag.value_text(value, t.token.format, Some(ooxml_number_format)),
            ),
          )
        None => missing_name(t.token.name, ctx.strict, ctx.warnings)
      }
  }
}

///|
fn ooxml_render_section(
  ctx : Ctx,
  index : Int,
  scope : @tag.Scope,
  out : StringBuilder,
) -> Unit raise OoxmlError {
  let sec = ctx.sections[index]
  let value = scope.lookup(sec.path)
  match value {
    None => missing_name(sec.name, ctx.strict, ctx.warnings)
    Some(_) => ()
  }
  if sec.inverted {
    let keep = match value {
      Some(v) => !@tag.truthy(v)
      None => true
    }
    if keep {
      ooxml_render_range(ctx, sec.body_start, sec.body_end, scope, index, out)
    }
    return
  }
  let items = match value {
    Some(v) => @tag.items(v)
    None => []
  }
  let count = items.length()
  for k in 0..<count {
    let vars = @tag.vars(k, count, sec.mode == @tag.MODE_PAGES)
    let inner = scope.item(items[k], vars)
    ooxml_render_range(ctx, sec.body_start, sec.body_end, inner, index, out)
  }
}

///|
fn ooxml_render_range(
  ctx : Ctx,
  start : Int,
  end : Int,
  scope : @tag.Scope,
  current : Int,
  out : StringBuilder,
) -> Unit raise OoxmlError {
  let mut i = start
  while i <= end {
    let mut jumped = false
    match ctx.starts_at.get(i) {
      Some(index) =>
        if index != current {
          ooxml_render_section(ctx, index, scope, out)
          i = ctx.sections[index].exit_tok + 1
          jumped = true
        }
      None => ()
    }
    if jumped {
      continue
    }
    match ctx.tokens[i] {
      TText(text) => out.write_string(text)
      TValue(t) => ooxml_fill_value(ctx, t, scope, out)
      TOpen(t) =>
        if !ctx.sections_on {
          ctx.warnings.push(
            "ooxml: the control tag " + t.raw + " is not supported",
          )
          out.write_string(t.raw)
        }
      TClose(t) =>
        if !ctx.sections_on {
          ctx.warnings.push(
            "ooxml: the control tag " + t.raw + " is not supported",
          )
          out.write_string(t.raw)
        }
    }
    i += 1
  }
}

///|
/// Fill the tags of one XML part. The kind says what a section repeats: 0
/// nothing (the whole part is one block), 1 the rows of a worksheet, 2 the
/// paragraphs and table rows of a Word part, 3 the shapes of a slide.
fn fill_part(
  xml : String,
  values : Json,
  strict : Bool,
  kind : Int,
  sections_on : Bool,
) -> (String, Array[String]) raise OoxmlError {
  let warnings : Array[String] = []
  let raw = ooxml_tokenize(xml, warnings)
  let (layout, tokens) = ooxml_layout(xml, kind, raw)
  let (sections, starts_at) = if sections_on {
    ooxml_sections(tokens, layout, strict, warnings)
  } else {
    ([], Map([]))
  }
  let ctx = {
    tokens,
    layout,
    sections,
    starts_at,
    strict,
    sections_on,
    warnings,
  }
  let out = StringBuilder()
  ooxml_render_range(ctx, 0, tokens.length() - 1, @tag.Scope::new(values), -1, out)
  (out.to_string(), warnings)
}

///|
fn ooxml_replace_row_attr(tag : String, number : Int) -> String {
  let needle = " r=\""
  match tag.find(needle) {
    Some(index) => {
      let start = index + needle.length()
      let end = match tag[start:].find("\"") {
        Some(i) => start + i
        None => return tag
      }
      tag[:index].to_owned() +
      " r=\"" +
      number.to_string() +
      "\"" +
      tag[end + 1:].to_owned()
    }
    None => {
      let mut at = tag.length() - 1
      if at > 0 && tag[at - 1:].has_prefix("/") {
        at -= 1
      }
      tag[:at].to_owned() + " r=\"" + number.to_string() + "\"" + tag[at:].to_owned()
    }
  }
}

///|
fn ooxml_rewrite_cell_ref(tag : String, number : Int) -> String {
  let needle = " r=\""
  match tag.find(needle) {
    Some(index) => {
      let start = index + needle.length()
      let end = match tag[start:].find("\"") {
        Some(i) => start + i
        None => return tag
      }
      let chars = tag[start:end].to_owned().to_array()
      let mut cut = chars.length()
      while cut > 0 &&
        chars[cut - 1].to_int() >= 48 &&
        chars[cut - 1].to_int() <= 57 {
        cut -= 1
      }
      let letters = String::from_array(chars[:cut])
      tag[:index].to_owned() +
      " r=\"" +
      letters +
      number.to_string() +
      "\"" +
      tag[end + 1:].to_owned()
    }
    None => tag
  }
}

///|
fn ooxml_renumber_cells(body : String, number : Int) -> String {
  let out = StringBuilder()
  let mut pos = 0
  while pos < body.length() {
    let start = match body[pos:].find("<c ") {
      Some(index) => pos + index
      None => {
        out.write_string(body[pos:].to_owned())
        break
      }
    }
    out.write_string(body[pos:start].to_owned())
    let end = match body[start:].find(">") {
      Some(index) => start + index
      None => {
        out.write_string(body[start:].to_owned())
        break
      }
    }
    out.write_string(ooxml_rewrite_cell_ref(body[start:end + 1].to_owned(), number))
    pos = end + 1
  }
  out.to_string()
}

///|
/// The numbers of the rows of a worksheet, in the order of the document. A
/// row without a number takes the number after the one before it.
fn ooxml_row_numbers(xml : String) -> Array[Int] {
  let out : Array[Int] = []
  let mut pos = 0
  let mut implied = 0
  while pos < xml.length() {
    let start = match xml[pos:].find("<row") {
      Some(index) => pos + index
      None => break
    }
    let after = start + 4
    if after > xml.length() || !ooxml_name_end(xml[after:]) {
      pos = after
      continue
    }
    let end = match xml[after:].find(">") {
      Some(index) => after + index
      None => break
    }
    let number = ooxml_row_number(xml[start:end + 1].to_owned())
    implied = if number < 0 { implied + 1 } else { number }
    out.push(implied)
    pos = end + 1
  }
  out
}

///|
/// The number of a row of a worksheet, or -1 when it has none.
fn ooxml_row_number(tag : String) -> Int {
  let needle = " r=\""
  let at = match tag.find(needle) {
    Some(index) => index + needle.length()
    None => return -1
  }
  let end = match tag[at:].find("\"") {
    Some(index) => at + index
    None => return -1
  }
  @string.parse_int(tag[at:end].to_owned()) catch { _ => -1 }
}

///|
/// The new number of each row of a filled worksheet: the rows of the template
/// keep their gaps, a row that a section repeats takes the next number, and a
/// row that a section drops leaves no gap.
fn ooxml_row_numbers_after(
  before : Array[Int],
  after : Array[Int],
) -> (Array[Int], Map[Int, Array[Int]]) {
  let present : Map[Int, Bool] = Map([])
  for number in after {
    present[number] = true
  }
  let dropped : Map[Int, Bool] = Map([])
  for number in before {
    if !present.contains(number) {
      dropped[number] = true
    }
  }
  let numbers : Array[Int] = []
  let map : Map[Int, Array[Int]] = Map([])
  let mut previous_source = -1
  let mut previous_new = 0
  for source in after {
    let number = if previous_source < 0 {
      source
    } else if source == previous_source {
      previous_new + 1
    } else if source > previous_source {
      let mut gap = source - previous_source
      for skipped in (previous_source + 1)..<source {
        if dropped.contains(skipped) {
          gap -= 1
        }
      }
      previous_new + (if gap < 1 { 1 } else { gap })
    } else {
      previous_new + 1
    }
    numbers.push(number)
    match map.get(source) {
      Some(list) => list.push(number)
      None => map[source] = [number]
    }
    previous_source = source
    previous_new = number
  }
  (numbers, map)
}

///|
/// The parts of a cell reference: the letters and the row.
fn ooxml_ref_parts(ref : String) -> (String, Int) {
  let chars = ref.to_array()
  let mut cut = chars.length()
  while cut > 0 && chars[cut - 1].to_int() >= 48 && chars[cut - 1].to_int() <= 57 {
    cut -= 1
  }
  let row = @string.parse_int(String::from_array(chars[cut:])) catch { _ => -1 }
  (String::from_array(chars[:cut]), row)
}

///|
/// A cell reference with its row moved to the row of the fill. A row that a
/// section repeats makes a range that covers it ambiguous, which is an error.
fn ooxml_map_ref(
  ref : String,
  map : Map[Int, Array[Int]],
  dropped : Map[Int, Bool],
) -> String raise OoxmlError {
  let out : Array[String] = []
  for part in ref.split(":") {
    let piece = part.to_owned()
    let (letters, row) = ooxml_ref_parts(piece)
    if row < 0 {
      out.push(piece)
      continue
    }
    if dropped.contains(row) {
      raise OoxmlError(
        "ooxml: the merged cells " +
        ref +
        " cover row " +
        row.to_string() +
        ", which a section drops; merged cells across a dropped row are not supported",
      )
    }
    match map.get(row) {
      Some(numbers) =>
        if numbers.length() > 1 {
          raise OoxmlError(
            "ooxml: the merged cells " +
            ref +
            " cover row " +
            row.to_string() +
            ", which a section repeats; merged cells across a repeated row are not supported",
          )
        } else {
          out.push(letters + numbers[0].to_string())
        }
      None => out.push(piece)
    }
  }
  out.join(":")
}

///|
/// A range with its first row moved to the first row of the fill and its last
/// row to the last, so that a range over a repeated row covers every copy.
fn ooxml_map_span(ref : String, map : Map[Int, Array[Int]]) -> String {
  let parts = ref.split(":")
  let out : Array[String] = []
  for index, part in parts {
    let piece = part.to_owned()
    let (letters, row) = ooxml_ref_parts(piece)
    if row < 0 {
      out.push(piece)
      continue
    }
    match map.get(row) {
      Some(numbers) => {
        let number = if index == 0 {
          numbers[0]
        } else {
          numbers[numbers.length() - 1]
        }
        out.push(letters + number.to_string())
      }
      None => out.push(piece)
    }
  }
  out.join(":")
}

///|
fn ooxml_rewrite_merges(
  xml : String,
  rows : RowMap,
) -> String raise OoxmlError {
  let out = StringBuilder()
  let mut pos = 0
  while pos < xml.length() {
    let start = match xml[pos:].find("<mergeCell ") {
      Some(index) => pos + index
      None => {
        out.write_string(xml[pos:].to_owned())
        break
      }
    }
    out.write_string(xml[pos:start].to_owned())
    let end = match xml[start:].find(">") {
      Some(index) => start + index
      None => {
        out.write_string(xml[start:].to_owned())
        break
      }
    }
    let tag = xml[start:end + 1].to_owned()
    let needle = "ref=\""
    let at = match tag.find(needle) {
      Some(index) => index + needle.length()
      None => {
        out.write_string(tag)
        pos = end + 1
        continue
      }
    }
    let value_end = match tag[at:].find("\"") {
      Some(index) => at + index
      None => {
        out.write_string(tag)
        pos = end + 1
        continue
      }
    }
    let mapped = ooxml_map_ref(
      tag[at:value_end].to_owned(),
      rows.map,
      rows.dropped,
    )
    out.write_string(tag[:at].to_owned() + mapped + tag[value_end:].to_owned())
    pos = end + 1
  }
  out.to_string()
}

///|
fn ooxml_rewrite_dimension(xml : String, map : Map[Int, Array[Int]]) -> String {
  let start = match xml.find("<dimension") {
    Some(index) => index
    None => return xml
  }
  let end = match xml[start:].find(">") {
    Some(index) => start + index
    None => return xml
  }
  let tag = xml[start:end + 1].to_owned()
  let needle = "ref=\""
  let at = match tag.find(needle) {
    Some(index) => index + needle.length()
    None => return xml
  }
  let value_end = match tag[at:].find("\"") {
    Some(index) => at + index
    None => return xml
  }
  let mapped = ooxml_map_span(tag[at:value_end].to_owned(), map)
  xml[:start].to_owned() +
  tag[:at].to_owned() +
  mapped +
  tag[value_end:].to_owned() +
  xml[end + 1:].to_owned()
}

///|
fn ooxml_rewrite_rows(xml : String, numbers : Array[Int]) -> String {
  let out = StringBuilder()
  let mut pos = 0
  let mut index = 0
  while pos < xml.length() {
    let start = match xml[pos:].find("<row") {
      Some(index) => pos + index
      None => {
        out.write_string(xml[pos:].to_owned())
        break
      }
    }
    let after = start + 4
    if after > xml.length() || !ooxml_name_end(xml[after:]) {
      out.write_string(xml[pos:after].to_owned())
      pos = after
      continue
    }
    out.write_string(xml[pos:start].to_owned())
    let end = match xml[after:].find(">") {
      Some(index) => after + index
      None => {
        out.write_string(xml[start:].to_owned())
        break
      }
    }
    let number = if index < numbers.length() { numbers[index] } else { 0 }
    index += 1
    out.write_string(ooxml_replace_row_attr(xml[start:end + 1].to_owned(), number))
    if xml[end - 1:].has_prefix("/") {
      pos = end + 1
      continue
    }
    let close = match xml[end + 1:].find("</row>") {
      Some(index) => end + 1 + index
      None => {
        out.write_string(xml[end + 1:].to_owned())
        break
      }
    }
    out.write_string(
      ooxml_renumber_cells(xml[end + 1:close].to_owned(), number),
    )
    out.write_string("</row>")
    pos = close + 6
  }
  out.to_string()
}

///|
/// Number the rows of a filled worksheet: a sheet that no section repeats is
/// left as it is, and a sheet that a section repeats keeps the gaps of its
/// template, moves the rows after a repeated row, and moves the cell
/// references, the merged cells and the dimension with them. A formula or a
/// reference that the fill cannot move is an error, never a wrong cell.
///|
// The rows a fill moved: `before` and `after` are the row numbers of the
// template and of the filled sheet, `numbers` is the new number of each row of
// `after`, `map` maps a template row to the rows it became, and `dropped` holds
// the template rows that the fill removed.
priv struct RowMap {
  changed : Bool
  before : Array[Int]
  after : Array[Int]
  numbers : Array[Int]
  map : Map[Int, Array[Int]]
  dropped : Map[Int, Bool]
}

///|
fn ooxml_row_map(template : String, filled : String) -> RowMap {
  let before = ooxml_row_numbers(template)
  let after = ooxml_row_numbers(filled)
  if before == after {
    return {
      changed: false,
      before,
      after,
      numbers: [],
      map: Map([]),
      dropped: Map([]),
    }
  }
  let (numbers, map) = ooxml_row_numbers_after(before, after)
  let present : Map[Int, Bool] = Map([])
  for number in after {
    present[number] = true
  }
  let dropped : Map[Int, Bool] = Map([])
  for number in before {
    if !present.contains(number) {
      dropped[number] = true
    }
  }
  { changed: true, before, after, numbers, map, dropped }
}

///|
// A formula is `<f>`, `<f ...>`, `<f/>` or a prefixed `<x:f>`; a bare
// `contains("<f>")` misses the self-closing, the attributed and the prefixed
// forms.
fn ooxml_has_formula(xml : String) -> Bool {
  let chars = xml.to_array()
  let mut pos = 0
  while pos < chars.length() {
    if chars[pos] != '<' {
      pos += 1
      continue
    }
    let (name, end) = ooxml_element_name(chars, pos)
    if name == "f" && end < chars.length() {
      let next = chars[end]
      if next == '>' ||
        next == ' ' ||
        next == '/' ||
        next == '\t' ||
        next == '\r' ||
        next == '\n' {
        return true
      }
    }
    pos += 1
  }
  false
}

///|
fn ooxml_formula_texts(xml : String) -> Array[String] {
  let out : Array[String] = []
  let chars = xml.to_array()
  let mut pos = 0
  while pos < chars.length() {
    if chars[pos] != '<' {
      pos += 1
      continue
    }
    let (name, end) = ooxml_element_name(chars, pos)
    if name != "f" || end >= chars.length() {
      pos += 1
      continue
    }
    let next = chars[end]
    if next == '/' {
      pos = end + 1
      continue
    }
    if !(next == '>' ||
      next == ' ' ||
      next == '\t' ||
      next == '\r' ||
      next == '\n') {
      pos += 1
      continue
    }
    let mut gt = end
    while gt < chars.length() && chars[gt] != '>' {
      gt += 1
    }
    if gt >= chars.length() {
      break
    }
    if chars[gt - 1] == '/' {
      pos = gt + 1
      continue
    }
    let close = match xml[gt + 1:].find("</") {
      Some(index) => gt + 1 + index
      None => break
    }
    let (close_name, close_end) = ooxml_element_name(chars, close)
    if close_name != "f" {
      pos = gt + 1
      continue
    }
    out.push(xml[gt + 1:close].to_owned())
    pos = close_end
  }
  out
}

///|
fn ooxml_is_name_char(c : Char) -> Bool {
  ooxml_is_letter(c) ||
  ooxml_is_digit(c) ||
  c == '_' ||
  c == '-' ||
  c == '.' ||
  c == ':'
}

///|
// The local name of the element that starts at `at` (a `<`), and the index
// after the name.
fn ooxml_element_name(chars : Array[Char], at : Int) -> (String, Int) {
  let mut start = at + 1
  if start < chars.length() && chars[start] == '/' {
    start += 1
  }
  let mut end = start
  while end < chars.length() && ooxml_is_name_char(chars[end]) {
    end += 1
  }
  let mut local_start = start
  for i in start..<end {
    if chars[i] == ':' {
      local_start = i + 1
    }
  }
  (String::from_array(chars[local_start:end]), end)
}

///|
fn ooxml_is_letter(c : Char) -> Bool {
  (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')
}

///|
fn ooxml_is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn ooxml_map_row(row : Int, rows : RowMap) -> Int raise OoxmlError {
  if rows.dropped.contains(row) {
    raise OoxmlError(
      "ooxml: a reference names row " +
      row.to_string() +
      ", which a section drops; references across a dropped row are not supported",
    )
  }
  match rows.map.get(row) {
    Some(numbers) =>
      if numbers.length() > 1 {
        raise OoxmlError(
          "ooxml: a reference names row " +
          row.to_string() +
          ", which a section repeats; references across a repeated row are not supported",
        )
      } else {
        numbers[0]
      }
    None => row
  }
}

///|
// Map the cell reference or range at the start of `rest`; return the mapped
// text and the number of characters it consumed.
fn ooxml_map_ref_text(
  rest : String,
  rows : RowMap,
) -> (String, Int) raise OoxmlError {
  let chars = rest.to_array()
  let out = StringBuilder()
  let mut pos = 0
  let mut count = 0
  while true {
    let start = pos
    if pos < chars.length() && chars[pos] == '$' {
      pos += 1
    }
    let letters_start = pos
    while pos < chars.length() && ooxml_is_letter(chars[pos]) {
      pos += 1
    }
    if pos == letters_start {
      break
    }
    if pos < chars.length() && chars[pos] == '$' {
      pos += 1
    }
    let digits_start = pos
    while pos < chars.length() && ooxml_is_digit(chars[pos]) {
      pos += 1
    }
    if pos == digits_start {
      break
    }
    let row = @string.parse_int(
      String::from_array(chars[digits_start:pos]),
    ) catch {
      _ => -1
    }
    if row < 0 {
      break
    }
    if count > 0 {
      out.write_string(":")
    }
    count += 1
    out.write_string(String::from_array(chars[start:digits_start]))
    out.write_string(ooxml_map_row(row, rows).to_string())
    if pos < chars.length() && chars[pos] == ':' {
      pos += 1
      continue
    }
    break
  }
  (out.to_string(), pos)
}

///|
// Whether `text` names `sheet`, in any letter case, as a cell reference, a
// range or a 3D reference. A name that the fill cannot move is refused rather
// than left stale.
fn ooxml_names_sheet(text : String, sheet : String) -> Bool {
  let lower = text.to_lower()
  let name = sheet.to_lower()
  lower.contains(name + "!") ||
  lower.contains("'" + name + "'!") ||
  lower.contains(name + ":") ||
  lower.contains("'" + name + "':")
}

///|
fn ooxml_map_defined_name(
  text : String,
  sheet : String,
  rows : RowMap,
) -> String raise OoxmlError {
  let plain = sheet + "!"
  let quoted = "'" + sheet + "'!"
  let body = if text.has_prefix("=") {
    text[1:].to_owned()
  } else {
    text
  }
  let (prefix, rest) = if body.has_prefix(plain) {
    (plain, body[plain.length():].to_owned())
  } else if body.has_prefix(quoted) {
    (quoted, body[quoted.length():].to_owned())
  } else {
    if ooxml_names_sheet(body, sheet) {
      raise OoxmlError(
        "ooxml: the defined name " +
        text +
        " names " +
        sheet +
        " in a way that the fill cannot move",
      )
    }
    return text
  }
  let (mapped, used) = ooxml_map_ref_text(rest, rows) catch {
    OoxmlError(message) =>
      raise OoxmlError(
        "ooxml: the defined name " + text + " cannot move: " + message,
      )
  }
  if used != rest.length() {
    raise OoxmlError(
      "ooxml: the defined name " +
      text +
      " names " +
      sheet +
      " in a way that the fill cannot move",
    )
  }
  (if text.has_prefix("=") { "=" } else { "" }) + prefix + mapped
}

///|
fn ooxml_attr(tag : String, name : String) -> String {
  let needle = " " + name + "=\""
  let at = match tag.find(needle) {
    Some(index) => index + needle.length()
    None => return ""
  }
  let end = match tag[at:].find("\"") {
    Some(index) => at + index
    None => return ""
  }
  tag[at:end].to_owned()
}

///|
fn ooxml_rel_target(rels : String, id : String) -> String {
  let mut pos = 0
  while pos < rels.length() {
    let at = match rels[pos:].find("<Relationship ") {
      Some(index) => pos + index
      None => return ""
    }
    let end = match rels[at:].find(">") {
      Some(index) => at + index
      None => return ""
    }
    let tag = rels[at:end + 1].to_owned()
    if ooxml_attr(tag, "Id") == id {
      return ooxml_attr(tag, "Target")
    }
    pos = end + 1
  }
  ""
}

///|
// The sheet name of each worksheet part and the part of each sheet name, read
// from the workbook and its relationships.
fn ooxml_sheet_parts(
  texts : Map[String, String],
) -> (Map[String, String], Map[String, String]) {
  let by_name : Map[String, String] = Map([])
  let by_part : Map[String, String] = Map([])
  let workbook = match texts.get("xl/workbook.xml") {
    Some(text) => text
    None => return (by_name, by_part)
  }
  let rels = match texts.get("xl/_rels/workbook.xml.rels") {
    Some(text) => text
    None => return (by_name, by_part)
  }
  let mut pos = 0
  while pos < workbook.length() {
    let at = match workbook[pos:].find("<sheet ") {
      Some(index) => pos + index
      None => break
    }
    let end = match workbook[at:].find(">") {
      Some(index) => at + index
      None => break
    }
    let tag = workbook[at:end + 1].to_owned()
    let name = ooxml_attr(tag, "name")
    let rid = ooxml_attr(tag, "r:id")
    if name != "" && rid != "" {
      let target = ooxml_rel_target(rels, rid)
      if target != "" {
        let part = if target.has_prefix("/") {
          target[1:].to_owned()
        } else {
          "xl/" + target
        }
        by_name[name] = part
        by_part[part] = name
      }
    }
    pos = end + 1
  }
  (by_name, by_part)
}

///|
fn ooxml_map_break(tag : String, rows : RowMap) -> String raise OoxmlError {
  let needle = "id=\""
  let at = match tag.find(needle) {
    Some(index) => index + needle.length()
    None => return tag
  }
  let end = match tag[at:].find("\"") {
    Some(index) => at + index
    None => return tag
  }
  let number = @string.parse_int(tag[at:end].to_owned()) catch { _ => -1 }
  if number < 0 {
    return tag
  }
  if rows.dropped.contains(number) {
    raise OoxmlError(
      "ooxml: a row break sits after row " +
      number.to_string() +
      ", which a section drops; row breaks across a dropped row are not supported",
    )
  }
  match rows.map.get(number) {
    Some(numbers) =>
      if numbers.length() > 1 {
        raise OoxmlError(
          "ooxml: a row break sits after row " +
          number.to_string() +
          ", which a section repeats; row breaks across a repeated row are not supported",
        )
      } else {
        tag[:at].to_owned() + numbers[0].to_string() + tag[end:].to_owned()
      }
    None => tag
  }
}

///|
fn ooxml_rewrite_breaks(
  xml : String,
  rows : RowMap,
) -> String raise OoxmlError {
  let start = match xml.find("<rowBreaks") {
    Some(index) => index
    None => return xml
  }
  let end = match xml[start:].find("</rowBreaks>") {
    Some(index) => start + index
    None => return xml
  }
  let body = xml[start:end].to_owned()
  let out = StringBuilder()
  let mut pos = 0
  while pos < body.length() {
    let at = match body[pos:].find("<brk ") {
      Some(index) => pos + index
      None => {
        out.write_string(body[pos:].to_owned())
        break
      }
    }
    out.write_string(body[pos:at].to_owned())
    let gt = match body[at:].find(">") {
      Some(index) => at + index
      None => {
        out.write_string(body[at:].to_owned())
        break
      }
    }
    out.write_string(ooxml_map_break(body[at:gt + 1].to_owned(), rows))
    pos = gt + 1
  }
  xml[:start].to_owned() + out.to_string() + xml[end:].to_owned()
}

///|
fn ooxml_renumber_rows(
  template : String,
  filled : String,
) -> (String, RowMap) raise OoxmlError {
  let rows = ooxml_row_map(template, filled)
  if !rows.changed {
    return (filled, rows)
  }
  if ooxml_has_formula(filled) {
    raise OoxmlError(
      "ooxml: the sheet has a formula and a section repeats rows; formulas are not moved when rows are repeated",
    )
  }
  for name in [
    "<hyperlink ",
    "<dataValidation ",
    "<conditionalFormatting ",
    "<autoFilter ",
    "<tablePart ",
  ] {
    if filled.contains(name) {
      raise OoxmlError(
        "ooxml: the sheet has " +
        name.trim().to_owned() +
        " and a section repeats rows; its references are not moved when rows are repeated",
      )
    }
  }
  let out = ooxml_rewrite_rows(filled, rows.numbers)
  let out = ooxml_rewrite_merges(out, rows)
  let out = ooxml_rewrite_breaks(out, rows)
  (ooxml_rewrite_dimension(out, rows.map), rows)
}

///|
fn ooxml_check_drawings(
  texts : Map[String, String],
  by_part : Map[String, String],
  maps : Map[String, RowMap],
) -> Unit raise OoxmlError {
  for part, name in by_part {
    let changed = match maps.get(part) {
      Some(rows) => rows.changed
      None => false
    }
    if !changed {
      continue
    }
    let text = match texts.get(part) {
      Some(value) => value
      None => continue
    }
    if text.contains("<drawing ") || text.contains("<legacyDrawing ") {
      raise OoxmlError(
        "ooxml: the sheet " +
        name +
        " has a drawing and a section repeats rows; the anchors of the drawing are not moved when rows are repeated",
      )
    }
  }
}

///|
fn ooxml_check_cross_sheet_formulas(
  texts : Map[String, String],
  by_part : Map[String, String],
  maps : Map[String, RowMap],
) -> Unit raise OoxmlError {
  for part, name in by_part {
    let changed = match maps.get(part) {
      Some(rows) => rows.changed
      None => false
    }
    if changed {
      continue
    }
    let text = match texts.get(part) {
      Some(value) => value
      None => continue
    }
    let formulas = ooxml_formula_texts(text)
    if formulas.length() == 0 {
      continue
    }
    for other_part, other_name in by_part {
      let other_changed = match maps.get(other_part) {
        Some(rows) => rows.changed
        None => false
      }
      if !other_changed {
        continue
      }
      for formula in formulas {
        if ooxml_names_sheet(formula, other_name) {
          raise OoxmlError(
            "ooxml: a formula of " +
            name +
            " names " +
            other_name +
            ", whose rows a section repeats; formulas that name a sheet whose rows move are not supported",
          )
        }
      }
    }
  }
}

///|
fn ooxml_check_chart_refs(
  texts : Map[String, String],
  by_part : Map[String, String],
  maps : Map[String, RowMap],
) -> Unit raise OoxmlError {
  for part, text in texts {
    if !(part.has_prefix("xl/charts/") ||
      part.has_prefix("xl/pivotTables/") ||
      part.has_prefix("xl/pivotCache/")) {
      continue
    }
    for sheet_part, name in by_part {
      let changed = match maps.get(sheet_part) {
        Some(rows) => rows.changed
        None => false
      }
      if !changed {
        continue
      }
      let names = ooxml_names_sheet(text, name) ||
        text.to_lower().contains("sheet=\"" + name.to_lower() + "\"")
      if names {
        raise OoxmlError(
          "ooxml: " +
          part +
          " names " +
          name +
          ", whose rows a section repeats; chart and pivot references are not moved when rows are repeated",
        )
      }
    }
  }
}

///|
fn ooxml_map_defined_names(
  workbook : String,
  by_name : Map[String, String],
  maps : Map[String, RowMap],
) -> String raise OoxmlError {
  let out = StringBuilder()
  let mut pos = 0
  while pos < workbook.length() {
    let at = match workbook[pos:].find("<definedName ") {
      Some(index) => pos + index
      None => {
        out.write_string(workbook[pos:].to_owned())
        break
      }
    }
    out.write_string(workbook[pos:at].to_owned())
    let open_end = match workbook[at:].find(">") {
      Some(index) => at + index
      None => {
        out.write_string(workbook[at:].to_owned())
        break
      }
    }
    let open = workbook[at:open_end + 1].to_owned()
    if open.has_suffix("/>") {
      out.write_string(open)
      pos = open_end + 1
      continue
    }
    let close = match workbook[open_end + 1:].find("</definedName>") {
      Some(index) => open_end + 1 + index
      None => {
        out.write_string(workbook[at:].to_owned())
        break
      }
    }
    let mut body = workbook[open_end + 1:close].to_owned()
    for name, part in by_name {
      match maps.get(part) {
        Some(rows) =>
          if rows.changed {
            body = ooxml_map_defined_name(body, name, rows)
          }
        None => ()
      }
    }
    out.write_string(open)
    out.write_string(body)
    out.write_string("</definedName>")
    pos = close + "</definedName>".length()
  }
  out.to_string()
}

///|
// Check and move the references that live outside the worksheet a section
// repeats: defined names, formulas of other sheets, drawings and charts.
fn ooxml_check_references(
  texts : Map[String, String],
  maps : Map[String, RowMap],
) -> Unit raise OoxmlError {
  let (by_name, by_part) = ooxml_sheet_parts(texts)
  ooxml_check_drawings(texts, by_part, maps)
  ooxml_check_cross_sheet_formulas(texts, by_part, maps)
  ooxml_check_chart_refs(texts, by_part, maps)
  match texts.get("xl/workbook.xml") {
    Some(workbook) =>
      if workbook.contains("<definedName ") {
        let mapped = ooxml_map_defined_names(workbook, by_name, maps)
        if mapped != workbook {
          texts["xl/workbook.xml"] = mapped
        }
      }
    None => ()
  }
}
