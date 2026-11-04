///|
priv struct MdRun {
  text : String
  style : @drawingml.TextStyle
  link : String
}

///|
priv enum MdBlock {
  MdHeading(Int, Array[MdRun])
  MdParagraph(Array[MdRun])
  MdListItem(Int, String, Array[MdRun])
  MdCode(Array[String])
  MdQuote(Array[MdBlock])
  MdRule
  MdTable(Array[Array[MdRun]], Array[Array[Array[MdRun]]], Array[Int])
  MdImage(String, String, String)
  MdMath(String)
}

///|
priv struct MdDocument {
  blocks : Array[MdBlock]
  title : String
  meta : Map[String, Array[String]]
  formulas : Array[String]
  images : Array[(String, String, String)]
}

///|
fn md_style(
  size~ : Double = 12.0,
  bold~ : Bool = false,
  italic~ : Bool = false,
  family~ : String = "Arial",
  color~ : UInt32 = 0x000000ffU,
) -> @drawingml.TextStyle {
  @drawingml.TextStyle::new(size~, bold~, italic~, family~, color~)
}

///|
fn md_inline_style(base : @drawingml.TextStyle, bold : Bool, italic : Bool) -> @drawingml.TextStyle {
  { ..base, bold: base.bold || bold, italic: base.italic || italic, }
}

///|
fn md_runs_text(runs : Array[MdRun]) -> String {
  let out = StringBuilder()
  for run in runs {
    out.write_string(run.text)
  }
  out.to_string()
}

///|
fn md_push_run(runs : Array[MdRun], text : String, style : @drawingml.TextStyle, link : String) -> Unit {
  if text == "" {
    return
  }
  if !runs.is_empty() {
    let last = runs[runs.length() - 1]
    if last.style.family == style.family &&
      last.style.size == style.size &&
      last.style.bold == style.bold &&
      last.style.italic == style.italic &&
      last.style.color == style.color &&
      last.link == link {
      runs[runs.length() - 1] = { text: last.text + text, style, link }
      return
    }
  }
  runs.push({ text, style, link })
}

///|
fn md_placeholder(text : String) -> (Int, Int)? {
  if !text.has_prefix("\uE000") {
    return None
  }
  match text.find("\uE001") {
    Some(index) => {
      let digits = text[1:index].to_owned()
      let value = @string.parse_int(digits) catch { _ => -1 }
      if value < 0 {
        None
      } else {
        Some((value, index + 1))
      }
    }
    None => None
  }
}

///|
fn md_push_text(
  text : String,
  style : @drawingml.TextStyle,
  link : String,
  runs : Array[MdRun],
  formulas : Array[String],
) -> Unit {
  let mut rest = text
  while true {
    match rest.find("\uE000") {
      None => {
        md_push_run(runs, rest, style, link)
        return
      }
      Some(index) => {
        md_push_run(runs, rest[:index].to_owned(), style, link)
        let after = rest[index:].to_owned()
        match md_placeholder(after) {
          Some((formula, length)) => {
            if formula >= 0 && formula < formulas.length() {
              md_push_run(runs, md_latex_linear(formulas[formula]), style, link)
            }
            rest = after[length:].to_owned()
          }
          None => {
            md_push_run(runs, after[:1].to_owned(), style, link)
            rest = after[1:].to_owned()
          }
        }
      }
    }
  }
}

///|
fn md_collect_inlines(
  nodes : Array[@mmtypes.Inline],
  style : @drawingml.TextStyle,
  link : String,
  runs : Array[MdRun],
  formulas : Array[String],
  images : Array[(String, String, String)],
) -> Unit {
  for node in nodes {
    match node {
      @mmtypes.Inline::Text(text) => md_push_text(text, style, link, runs, formulas)
      @mmtypes.Inline::CodeSpan(text) => {
        let code_style = { ..style, family: "Courier New", }
        md_push_run(runs, text, code_style, link)
      }
      @mmtypes.Inline::Emphasis(children) =>
        md_collect_inlines(
          children, md_inline_style(style, false, true), link, runs, formulas, images,
        )
      @mmtypes.Inline::Strong(children) =>
        md_collect_inlines(
          children, md_inline_style(style, true, false), link, runs, formulas, images,
        )
      @mmtypes.Inline::Strikethrough(children) =>
        md_collect_inlines(children, style, link, runs, formulas, images)
      @mmtypes.Inline::Link(children, url, _) =>
        md_collect_inlines(children, style, url, runs, formulas, images)
      @mmtypes.Inline::Image(alt, url, title) => {
        let alt_runs : Array[MdRun] = []
        md_collect_inlines(alt, style, link, alt_runs, formulas, images)
        let alt_text = md_runs_text(alt_runs)
        images.push((alt_text, url, title.unwrap_or("")))
        md_push_run(runs, alt_text, style, link)
      }
      @mmtypes.Inline::HardBreak => md_push_run(runs, "\n", style, link)
      @mmtypes.Inline::SoftBreak => md_push_run(runs, " ", style, link)
      @mmtypes.Inline::RawHTML(html) =>
        md_push_text(md_strip_html(html), style, link, runs, formulas)
      @mmtypes.Inline::HtmlEntity(entity) =>
        md_push_run(runs, md_html_entity(entity), style, link)
      @mmtypes.Inline::Autolink(url) => md_push_run(runs, url, style, link)
    }
  }
}

///|
fn md_trim_task_marker(runs : Array[MdRun]) -> Array[MdRun] {
  let out : Array[MdRun] = []
  for run in runs {
    let text = if run.text.has_prefix("[ ] ") {
      run.text[4:].to_owned()
    } else if run.text.has_prefix("[x] ") || run.text.has_prefix("[X] ") {
      run.text[4:].to_owned()
    } else {
      run.text
    }
    if text != "" {
      out.push({ ..run, text, })
    }
  }
  out
}

///|
fn md_front_matter(text : String) -> (String, Map[String, Array[String]]) {
  let meta : Map[String, Array[String]] = Map([])
  let mut delimiter = ""
  let mut start = 0
  if text.has_prefix("---\n") {
    delimiter = "---"
    start = 4
  } else if text.has_prefix("+++\n") {
    delimiter = "+++"
    start = 4
  } else {
    return (text, meta)
  }
  let rest = text[start:].to_owned()
  let needle = "\n" + delimiter
  match rest.find(needle) {
    Some(index) => {
      let head = rest[:index].to_owned()
      for line in head.split("\n") {
        let trimmed = line.trim().to_string()
        if trimmed == "" || trimmed.has_prefix("#") {
          continue
        }
        let separator = if delimiter == "+++" {
          trimmed.find("=")
        } else {
          trimmed.find(":")
        }
        match separator {
          Some(at) => {
            let key = trimmed[:at].to_owned().trim().to_string().to_lower()
            let mut value = trimmed[at + 1:].to_owned().trim().to_string()
            if value.length() >= 2 &&
              ((value[0] == '"' && value[value.length() - 1] == '"') ||
                (value[0] == '\'' && value[value.length() - 1] == '\'')) {
              value = value[1:value.length() - 1].to_owned()
            }
            if value != "" {
              let key = match key {
                "author" | "authors" => "creator"
                "lang" | "language" => "language"
                _ => key
              }
              meta[key] = [value]
            }
          }
          None => ()
        }
      }
      let body_start = index + needle.length()
      let mut body = rest[body_start:].to_owned()
      if body.has_prefix("\n") {
        body = body[1:].to_owned()
      }
      (body, meta)
    }
    None => (text, meta)
  }
}

///|
fn md_lines(text : String) -> Array[String] {
  let out : Array[String] = []
  for line in text.split("\n") {
    out.push(line.to_string())
  }
  out
}

///|
fn md_scale_style(
  style : @drawingml.TextStyle,
  scale : Double,
  font : String,
  mono : String,
) -> @drawingml.TextStyle {
  let family = if style.family == "Courier New" {
    if mono != "" {
      mono
    } else {
      style.family
    }
  } else if font != "" {
    font
  } else {
    style.family
  }
  { ..style, size: style.size * scale, family }
}

///|
fn md_scale_runs(
  runs : Array[MdRun],
  scale : Double,
  font : String,
  mono : String,
) -> Array[MdRun] {
  runs.map(fn(run) {
    { ..run, style: md_scale_style(run.style, scale, font, mono) }
  })
}

///|
fn md_scale_block(
  block : MdBlock,
  scale : Double,
  font : String,
  mono : String,
) -> MdBlock {
  match block {
    MdHeading(level, runs) =>
      MdHeading(level, md_scale_runs(runs, scale, font, mono))
    MdParagraph(runs) => MdParagraph(md_scale_runs(runs, scale, font, mono))
    MdListItem(level, marker, runs) =>
      MdListItem(level, marker, md_scale_runs(runs, scale, font, mono))
    MdCode(lines) => MdCode(lines)
    MdQuote(children) =>
      MdQuote(
        children.map(fn(child) { md_scale_block(child, scale, font, mono) }),
      )
    MdRule => MdRule
    MdTable(header, rows, alignments) =>
      MdTable(
        header.map(fn(cell) { md_scale_runs(cell, scale, font, mono) }),
        rows.map(fn(row) {
          row.map(fn(cell) { md_scale_runs(cell, scale, font, mono) })
        }),
        alignments,
      )
    MdImage(alt, url, title) => MdImage(alt, url, title)
    MdMath(formula) => MdMath(formula)
  }
}

///|
fn md_parse(text : String) -> MdDocument {
  let (body, meta) = md_front_matter(text)
  let formulas : Array[String] = []
  let images : Array[(String, String, String)] = []
  let warnings : Array[String] = []
  let math_text = md_parse_math_before(body, formulas)
  let lines = md_lines(math_text)
  let (lines, definitions) = md_footnote_prepare(lines)
  let parser : MdParser = {
    formulas,
    images,
    warnings,
    title: "",
  }
  let blocks = parser.parse_blocks(lines, 0)
  for definition in definitions {
    let (number, body) = definition
    let runs = md_inline_runs(
      number.to_string() + ". " + body + "  ↑",
      md_style(),
      formulas,
      images,
    )
    blocks.push(MdParagraph(runs))
  }
  if blocks.is_empty() {
    blocks.push(MdParagraph([]))
  }
  { blocks, title: parser.title, meta, formulas, images }
}
