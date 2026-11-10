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
  blocks : Array[Block]
  rows : Array[Block]
  row_of : Array[Int]
  block_of_tok : Array[Int]
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
  ({ blocks, rows, row_of, block_of_tok }, tokens)
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
  if sec.b0 == sec.b1 {
    return (sec.open_tok + 1, sec.close_tok - 1)
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
    if sec.b0 == sec.b1 {
      sec.enter_tok = sec.open_tok
      sec.exit_tok = sec.close_tok
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
fn ooxml_update_dimension(xml : String, last : Int) -> String {
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
    Some(index) => index
    None => return xml
  }
  let value_start = at + needle.length()
  let value_end = match tag[value_start:].find("\"") {
    Some(index) => value_start + index
    None => return xml
  }
  let value = tag[value_start:value_end].to_owned()
  let colon = match value.find(":") {
    Some(index) => index
    None => return xml
  }
  let chars = value[colon + 1:].to_owned().to_array()
  let mut cut = chars.length()
  while cut > 0 && chars[cut - 1].to_int() >= 48 && chars[cut - 1].to_int() <= 57 {
    cut -= 1
  }
  let letters = String::from_array(chars[:cut])
  let new_value = value[:colon].to_owned() + ":" + letters + last.to_string()
  xml[:start].to_owned() +
  tag[:value_start].to_owned() +
  new_value +
  tag[value_end:].to_owned() +
  xml[end + 1:].to_owned()
}

///|
/// Number the rows of a worksheet in the order of the document, keeping the
/// gaps of the template and giving a repeated row the next number, and number
/// the cells of each row with it, so that repeated rows keep a valid sheet.
fn ooxml_renumber_rows(xml : String) -> String {
  if !xml.contains("<row") {
    return xml
  }
  let out = StringBuilder()
  let mut pos = 0
  let mut number = 0
  let mut previous_original = -1
  let mut previous_new = 0
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
    let tag = xml[start:end + 1].to_owned()
    let original = ooxml_row_number(tag)
    number = if previous_original < 0 {
      if original < 0 { 1 } else { original }
    } else {
      previous_new + 1
    }
    previous_original = if original < 0 { previous_original } else { original }
    previous_new = number
    out.write_string(ooxml_replace_row_attr(tag, number))
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
  ooxml_update_dimension(out.to_string(), number)
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
