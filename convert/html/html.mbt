///|
/// An HTML conversion failure.
pub suberror HtmlError {
  HtmlInvalid(String)
}

///|
pub(all) struct HtmlResult {
  bdf : Bytes
  pages : Int32
  summary : String
  warnings : Array[String]
}

///|
/// Detect an HTML document or a web archive from its opening bytes.
pub fn detect(data : Bytes) -> Bool {
  let head = @utf8.decode_lossy(data[:data.length().min(2048)], ignore_bom=true)
    .to_lower()
  head.contains("<html") || head.contains("<!doctype html") ||
  head.contains("<body") || head.contains("<meta charset")
}

///|
fn html_entity(text : String) -> String {
  let mut out = text
  for (entity, replacement) in [
    ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""),
    ("&#39;", "'"), ("&apos;", "'"), ("&nbsp;", " "),
  ] {
    out = out.replace(old=entity, new=replacement)
  }
  out
}

///|
fn html_clean(text : String, pre : Bool) -> String {
  if pre {
    text
  } else {
    let out = StringBuilder()
    let mut space = false
    for ch in text {
      if ch == ' ' || ch == '\n' || ch == '\t' || ch == '\r' {
        space = true
      } else {
        if space && out.to_string() != "" {
          out.write_char(' ')
        }
        space = false
        out.write_char(ch)
      }
    }
    html_entity(out.to_string()).trim().to_string()
  }
}

///|
fn html_run_clean(text : String, pre : Bool) -> String {
  if pre || text == "\n" {
    return html_entity(text)
  }
  let out = StringBuilder()
  let mut space = false
  for ch in text {
    if ch == ' ' || ch == '\n' || ch == '\t' || ch == '\r' {
      space = true
    } else {
      if space && out.to_string() != "" {
        out.write_char(' ')
      }
      space = false
      out.write_char(ch)
    }
  }
  html_entity(out.to_string())
}

///|
fn html_trim_start(text : String) -> String {
  let chars = text.to_array()
  let mut i = 0
  while i < chars.length() &&
    (chars[i] == ' ' || chars[i] == '\t' || chars[i] == '\n' || chars[i] == '\r') {
    i += 1
  }
  String::from_array(chars[i:]).to_string()
}

///|
fn html_trim_end(text : String) -> String {
  let chars = text.to_array()
  let mut i = chars.length()
  while i > 0 &&
    (chars[i - 1] == ' ' || chars[i - 1] == '\t' ||
     chars[i - 1] == '\n' || chars[i - 1] == '\r') {
    i -= 1
  }
  String::from_array(chars[:i]).to_string()
}

///|
priv struct CssCompound {
  tag : String
  classes : Array[String]
  id : String
}

///|
priv struct CssRule {
  selectors : Array[Array[CssCompound]]
  decls : Map[String, String]
}

///|
priv struct HtmlElem {
  tag : String
  id : String
  classes : Array[String]
  decls : Map[String, String]
}

///|
fn css_strip_comments(css : String) -> String {
  let out = StringBuilder()
  let chars = css.to_array()
  let mut i = 0
  while i < chars.length() {
    if i + 1 < chars.length() && chars[i] == '/' && chars[i + 1] == '*' {
      i += 2
      while i + 1 < chars.length() &&
        !(chars[i] == '*' && chars[i + 1] == '/') {
        i += 1
      }
      i += 2
    } else {
      out.write_char(chars[i])
      i += 1
    }
  }
  out.to_string()
}

///|
fn css_parse_decl(css : String) -> Map[String, String] {
  let decls : Map[String, String] = Map([])
  for part in css.split(";") {
    let piece = part.to_string()
    match piece.find(":") {
      Some(colon) => {
        let key = piece[:colon].trim().to_lower().to_string()
        let value = piece[colon + 1:].trim().to_string()
        if key != "" {
          decls[key] = value
        }
      }
      None => ()
    }
  }
  decls
}

///|
fn css_parse_compound(text : String) -> CssCompound {
  let chars = text.to_array()
  let mut i = 0
  while i < chars.length() &&
    (chars[i] == ' ' || chars[i] == '\t') {
    i += 1
  }
  let start = i
  while i < chars.length() &&
    chars[i] != '.' && chars[i] != '#' && chars[i] != ':' &&
    chars[i] != '[' && chars[i] != ' ' && chars[i] != '\t' {
    i += 1
  }
  let tag = if chars[start] == '*' {
    ""
  } else {
    String::from_array(chars[start:i]).to_lower().to_string()
  }
  let classes : Array[String] = []
  let mut id = ""
  while i < chars.length() {
    let c = chars[i]
    if c == '.' || c == '#' {
      let kind = c
      i += 1
      let s = i
      while i < chars.length() && chars[i] != '.' && chars[i] != '#' &&
        chars[i] != ':' && chars[i] != '[' && chars[i] != ' ' &&
        chars[i] != '\t' {
        i += 1
      }
      let value = String::from_array(chars[s:i]).to_string()
      if kind == '.' {
        classes.push(value)
      } else {
        id = value
      }
    } else if c == ':' || c == '[' {
      // pseudo class or attribute selector: skip to whitespace/end
      while i < chars.length() && chars[i] != ' ' && chars[i] != '\t' {
        i += 1
      }
    } else {
      i += 1
    }
  }
  { tag, classes, id }
}

///|
fn css_parse_selector(selector : String) -> Array[CssCompound] {
  let compounds : Array[CssCompound] = []
  for part in selector.split(" ") {
    let piece = part.to_string().trim().to_string()
    if piece != "" {
      compounds.push(css_parse_compound(piece))
    }
  }
  // collapse runs caused by multiple spaces already handled by split+trim
  compounds
}

///|
fn css_parse(css : String) -> Array[CssRule] {
  let clean = css_strip_comments(css)
  let chars = clean.to_array()
  let rules : Array[CssRule] = []
  let mut pos = 0
  while pos < chars.length() {
    // find next '{'
    let mut brace = pos
    while brace < chars.length() && chars[brace] != '{' && chars[brace] != '}' {
      brace += 1
    }
    if brace >= chars.length() || chars[brace] == '}' {
      pos = brace + 1
      continue
    }
    let selector = String::from_array(chars[pos:brace]).trim().to_string()
    // find matching '}' (one level of nesting for @media etc.)
    let mut depth = 1
    let mut end = brace + 1
    while end < chars.length() && depth > 0 {
      if chars[end] == '{' {
        depth += 1
      } else if chars[end] == '}' {
        depth -= 1
      }
      end += 1
    }
    if selector.has_prefix("@") {
      // at-rule: skip entirely
      pos = end
      continue
    }
    if selector != "" {
      let body = String::from_array(chars[brace + 1:end - 1]).to_string()
      let selectors : Array[Array[CssCompound]] = []
      for sel in selector.split(",") {
        let s = sel.to_string().trim().to_string()
        if s != "" {
          selectors.push(css_parse_selector(s))
        }
      }
      if !selectors.is_empty() {
        rules.push({ selectors, decls: css_parse_decl(body) })
      }
    }
    pos = end
  }
  rules
}

///|
fn css_compound_match(comp : CssCompound, elem : HtmlElem) -> Bool {
  (comp.tag == "" || comp.tag == elem.tag) &&
  (comp.id == "" || comp.id == elem.id) &&
  comp.classes.all(fn(c) { elem.classes.contains(c) })
}

///|
fn css_selector_match(
  compounds : Array[CssCompound],
  stack : Array[HtmlElem],
) -> Bool {
  if compounds.is_empty() || stack.is_empty() {
    return false
  }
  if !css_compound_match(compounds[compounds.length() - 1], stack[stack.length() - 1]) {
    return false
  }
  let mut si = compounds.length() - 2
  let mut ei = stack.length() - 2
  while si >= 0 {
    if ei < 0 {
      return false
    }
    if css_compound_match(compounds[si], stack[ei]) {
      si -= 1
    }
    ei -= 1
  }
  true
}

///|
fn css_elem_decls(elem_tag : String, elem_id : String, elem_classes : Array[String], rules : Array[CssRule], stack : Array[HtmlElem]) -> Map[String, String] {
  let decls : Map[String, String] = Map([])
  let elem : HtmlElem = { tag: elem_tag, id: elem_id, classes: elem_classes, decls }
  let trial = stack.copy()
  trial.push(elem)
  for rule in rules {
    for selector in rule.selectors {
      if css_selector_match(selector, trial) {
        for key, value in rule.decls {
          decls[key] = value
        }
      }
    }
  }
  decls
}

///|
fn html_attr(tag_text : String, name : String) -> String {
  // tag_text is lowercased and trimmed; find name="value" or name='value'
  let mut pos = 0
  while pos < tag_text.length() {
    let hay = tag_text[pos:].to_owned()
    match hay.find(name) {
      Some(rel) => {
        let found = pos + rel
        let after = found + name.length()
        // ensure boundary: preceded by space and followed by =
        let before_ok = found == 0 || tag_text[found - 1] == ' ' ||
          tag_text[found - 1] == '\t'
        let mut p = after
        while p < tag_text.length() &&
          (tag_text[p] == ' ' || tag_text[p] == '\t') {
          p += 1
        }
        if before_ok && p < tag_text.length() && tag_text[p] == '=' {
          p += 1
          while p < tag_text.length() &&
            (tag_text[p] == ' ' || tag_text[p] == '\t') {
            p += 1
          }
          if p < tag_text.length() &&
            (tag_text[p] == '"' || tag_text[p] == '\'') {
            let quote = tag_text[p]
            p += 1
            let start = p
            while p < tag_text.length() && tag_text[p] != quote {
              p += 1
            }
            return html_entity(tag_text[start:p].to_string())
          }
        }
        pos = after
      }
      None => return ""
    }
  }
  ""
}

///|
fn html_classes(tag_text : String) -> Array[String] {
  let value = html_attr(tag_text, "class")
  let classes : Array[String] = []
  if value == "" {
    return classes
  }
  for part in value.split(" ") {
    let c = part.to_string().trim().to_string()
    if c != "" {
      classes.push(c)
    }
  }
  classes
}

///|
fn html_writing_mode(decls : Map[String, String]) -> String {
  for key in ["writing-mode", "-epub-writing-mode", "-webkit-writing-mode"] {
    match decls.get(key) {
      Some(value) => return value
      None => ()
    }
  }
  ""
}

///|
fn stack_prop(
  stack : Array[HtmlElem],
  names : Array[String],
) -> (String, String) {
  let mut i = stack.length()
  while i > 0 {
    i -= 1
    for name in names {
      match stack[i].decls.get(name) {
        Some(value) => return (name, value)
        None => ()
      }
    }
  }
  ("", "")
}

///|
fn html_is_tcy(stack : Array[HtmlElem]) -> Bool {
  let (prop, value) = stack_prop(stack, [
    "text-combine-upright", "-webkit-text-combine", "-epub-text-combine",
  ])
  if prop == "" {
    return false
  }
  if prop == "text-combine-upright" {
    value == "all" || value == "digits" || value == "alphabetic"
  } else {
    value == "horizontal"
  }
}

///|
fn html_is_emphasis(stack : Array[HtmlElem]) -> Bool {
  let (prop, value) = stack_prop(stack, [
    "text-emphasis-style", "text-emphasis", "-webkit-text-emphasis-style",
    "-webkit-text-emphasis", "-epub-text-emphasis-style",
  ])
  prop != "" && value != "" && value != "normal" &&
  !value.has_prefix("none")
}

///|
fn html_align(stack : Array[HtmlElem]) -> Int32 {
  let (_, value) = stack_prop(stack, ["text-align"])
  match value {
    "center" => 1
    "right" | "end" => 2
    "left" | "start" => 0
    _ => -1
  }
}

///|
fn html_blocks(
  source : String,
  css : String,
  warnings : Array[String],
) -> (String, Array[@reader.ReaderBlock], Bool) {
  let rules = css_parse(css)
  let chars = source.to_array()
  let blocks : Array[@reader.ReaderBlock] = []
  let stack : Array[HtmlElem] = []
  let title = StringBuilder()
  let pending = StringBuilder()
  let void_tags = [
    "area", "base", "br", "col", "embed", "hr", "img", "input", "link",
    "meta", "param", "source", "track", "wbr",
  ]
  let runs : Array[@reader.ReaderRun] = []
  let mut kind = 0 // 0 paragraph, 1 heading, 2 list, 3 code, 4 quote
  let mut level = 0
  let mut ordered = false
  let mut in_pre = false
  let mut skip = 0 // 1 script, 2 style
  let mut in_title = false
  let mut rt_depth = 0
  let mut math_depth = 0
  let mut doc_vertical = false
  let mut doc_mode_seen = false
  let mut pending_align = -1
  let emit_pending = fn() -> Unit {
    let value = pending.to_string()
    pending.reset()
    if value == "" {
      return
    }
    let upright = math_depth > 0
    let tcy = !upright && html_is_tcy(stack)
    let emphasis = html_is_emphasis(stack)
    if !runs.is_empty() {
      let last = runs[runs.length() - 1]
      if last.upright == upright && last.tcy == tcy &&
        last.emphasis == emphasis {
        last.text = last.text + value
        return
      }
    }
    runs.push({
      text: value,
      upright,
      tcy,
      emphasis,
    })
  }
  let flush = fn() -> Unit {
    emit_pending()
    if runs.is_empty() {
      return
    }
    let cleaned : Array[@reader.ReaderRun] = []
    for run in runs {
      let value = html_run_clean(run.text, in_pre)
      if value != "" {
        cleaned.push({ ..run, text: value })
      }
    }
    runs.clear()
    if cleaned.is_empty() {
      return
    }
    if !in_pre {
      cleaned[0].text = html_trim_start(cleaned[0].text)
      let last_index = cleaned.length() - 1
      cleaned[last_index].text = html_trim_end(cleaned[last_index].text)
    }
    let visible = cleaned.all(fn(r) { r.text != "" })
    if !visible && cleaned.length() == 1 && cleaned[0].text == "" {
      return
    }
    let align = if pending_align >= 0 { pending_align } else { 0 }
    pending_align = -1
    match kind {
      1 => blocks.push(@reader.Heading(level, cleaned))
      2 => blocks.push(@reader.ListItem(0, ordered, cleaned))
      3 => blocks.push(@reader.Code(cleaned))
      4 => blocks.push(@reader.Quote(cleaned))
      _ => blocks.push(@reader.Paragraph(cleaned, align))
    }
  }
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '<' {
      let mut end = i + 1
      while end < chars.length() && chars[end] != '>' {
        end += 1
      }
      if end >= chars.length() {
        break
      }
      let tag_text = String::from_array(chars[i + 1:end]).to_lower().trim().to_string()
      let closing = tag_text.has_prefix("/")
      let self_closing = tag_text.has_suffix("/")
      let mut name_end = if closing { 1 } else { 0 }
      while name_end < tag_text.length() && tag_text[name_end] != ' ' &&
        tag_text[name_end] != '\t' && tag_text[name_end] != '/' {
        name_end += 1
      }
      let name = tag_text[if closing { 1 } else { 0 }:name_end].to_owned()
      if name == "script" {
        skip = if closing { 0 } else { 1 }
      } else if name == "style" {
        if closing {
          skip = 0
        } else {
          skip = 2
        }
      } else if skip != 0 {
        // script/style content is not reader markup
      } else if name == "title" {
        in_title = !closing
      } else if closing && name == "rt" || closing && name == "rp" {
        if rt_depth > 0 {
          rt_depth -= 1
        }
      } else if closing && name == "math" {
        if math_depth > 0 {
          math_depth -= 1
        }
      } else if name == "rt" || name == "rp" {
        if !closing {
          rt_depth += 1
        }
      } else if name == "math" {
        if !closing {
          math_depth += 1
        }
      } else if rt_depth > 0 {
        // ruby annotation text is not reader text
      } else if name == "br" {
        emit_pending()
        runs.push({
          text: "\n",
          upright: math_depth > 0,
          tcy: false,
          emphasis: false,
        })
      } else if name == "img" {
        emit_pending()
        let alt = html_attr(tag_text, "alt")
        if alt != "" {
          runs.push({
            text: alt,
            upright: true,
            tcy: false,
            emphasis: false,
          })
        }
      } else if name == "h1" || name == "h2" || name == "h3" || name == "h4" ||
        name == "h5" || name == "h6" {
        flush()
        emit_pending()
        level = name[1].to_int() - '0'.to_int()
        kind = 1
        let align = html_align(stack)
        if align >= 0 {
          pending_align = align
        }
      } else if name == "p" || name == "div" || name == "tr" || name == "section" ||
        name == "article" {
        flush()
        kind = 0
        if !closing {
          let align = html_align(stack)
          if align >= 0 {
            pending_align = align
          }
        }
      } else if name == "li" {
        flush()
        kind = 2
        ordered = tag_text.contains("ordered")
      } else if name == "pre" {
        flush()
        kind = 3
        in_pre = !closing
      } else if name == "blockquote" {
        flush()
        kind = 4
      } else if name == "hr" {
        flush()
        blocks.push(@reader.Rule)
      } else if name == "td" || name == "th" {
        pending.write_char('\t')
      }
      // element stack bookkeeping for non-void tags
      let is_void = void_tags.contains(name)
      if !is_void && name != "br" {
        if closing {
          // pop through the matching tag
          let mut idx = stack.length()
          while idx > 0 {
            idx -= 1
            if stack[idx].tag == name {
              while stack.length() > idx {
                ignore(stack.pop())
              }
              break
            }
          }
          if (name == "p" || name == "div" || name == "li" ||
            name == "h1" || name == "h2" || name == "h3" ||
            name == "h4" || name == "h5" || name == "h6" ||
            name == "blockquote" || name == "tr") && !doc_mode_seen {
            // no-op; mode checked on open
          }
        } else if !self_closing {
          if (name == "html" || name == "body") && !doc_mode_seen {
            let classes = html_classes(tag_text)
            let id = html_attr(tag_text, "id")
            let decls = css_elem_decls(name, id, classes, rules, stack)
            let mode = html_writing_mode(decls)
            if mode != "" {
              doc_mode_seen = true
              if mode == "vertical-rl" || mode == "tb-rl" || mode == "tb" {
                doc_vertical = true
              } else if mode == "vertical-lr" || mode == "tb-lr" {
                warnings.push(
                  "HTML: vertical-lr text is laid out horizontally",
                )
              }
            }
          }
          let classes = html_classes(tag_text)
          let id = html_attr(tag_text, "id")
          let decls = css_elem_decls(name, id, classes, rules, stack)
          stack.push({ tag: name, id, classes, decls })
        }
      }
      if skip == 2 && !closing && name != "style" {
        // inside style handled by text branch below
      }
      i = end + 1
    } else {
      if in_title {
        title.write_char(chars[i])
      } else if skip == 0 && rt_depth == 0 {
        pending.write_char(chars[i])
      }
      i += 1
    }
  }
  flush()
  ignore(warnings)
  (html_clean(title.to_string(), false), blocks, doc_vertical)
}

///|
/// Extract the text of every <style> element in an HTML document.
fn html_style_texts(source : String) -> String {
  let out = StringBuilder()
  let lower = source.to_lower()
  let chars = lower.to_array()
  let mut pos = 0
  while pos < chars.length() - 6 {
    if chars[pos] == '<' &&
      String::from_array(chars[pos + 1:pos + 6]).to_string() == "style" {
      // find '>'
      let mut gt = pos + 6
      while gt < chars.length() && chars[gt] != '>' {
        gt += 1
      }
      if gt >= chars.length() {
        break
      }
      let content_start = gt + 1
      let tail = lower[content_start:].to_owned()
      match tail.find("</style") {
        Some(rel) => {
          let c = content_start + rel
          out.write_string(source[content_start:c].to_string())
          pos = c + 8
        }
        None => break
      }
    } else {
      pos += 1
    }
  }
  out.to_string()
}

///|
/// Parse an HTML document into the shared reader document model.
pub fn reader_document(
  data : Bytes,
  title~ : String = "",
  css~ : String = "",
) -> @reader.ReaderDocument {
  let source = @utf8.decode_lossy(data[:], ignore_bom=true)
  let all_css = css + html_style_texts(source)
  let (document_title, blocks, vertical) = html_blocks(source, all_css, [])
  let title = if title != "" { title } else { document_title }
  { title, blocks, vertical }
}

///|
/// Convert an HTML document or archive into fixed reader pages.
pub fn convert(
  data : Bytes,
  title~ : String = "",
) -> HtmlResult raise HtmlError {
  let warnings : Array[String] = []
  let document = reader_document(data, title~)
  let title = document.title
  let meta : Map[String, Json] = {
    "source": Json::string("html"),
    "generator": Json::string("bdf-go/0.1"),
  }
  if title != "" {
    meta["dc"] = Json::object({ "title": Json::string(title) })
  }
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
  let layout = @reader.render(document, writer)
  for warning in layout.warnings {
    warnings.push(warning)
  }
  let view : Map[String, Json] = {
    "id": Json::string("pages"),
    "kind": Json::string("fixed"),
    "pages": Json::array(layout.pages),
  }
  if title != "" {
    view["title"] = Json::string(title)
  }
  if !layout.index_runs.is_empty() {
    let encoded = @core.encode_text_index(layout.index_runs) catch { _ => b"" }
    if encoded.length() > 0 {
      let hash = writer.add_part("idx", encoded) catch {
        _ => raise HtmlInvalid("HTML text index could not be stored")
      }
      view["textIndex"] = Json::string(hash)
    }
  }
  writer.add_view(Json::object(view))
  let bdf = writer.write_single() catch {
    _ => raise HtmlInvalid("HTML document could not be written")
  }
  let count = layout.pages.length()
  {
    bdf,
    pages: count,
    summary: "\{count} page(s)",
    warnings,
  }
}
