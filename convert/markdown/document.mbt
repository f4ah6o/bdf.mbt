///|
/// An image laid out inline with the text: a data: URL image, or the SVG
/// document made of an inline svg element.
priv struct MdImage {
  data : Bytes
  width : Double
  height : Double
  // An SVG with only a view box is as wide as the text column.
  fill : Bool
}

///|
/// An svg element found before Markdown parsing. Its document is made (with
/// the definitions of sprite sheets) when it is drawn.
priv struct MdSvg {
  markup : String
  alt : String
  width : Double
  height : Double
  fill : Bool
}

///|
priv struct MdRun {
  text : String
  style : @drawingml.TextStyle
  link : String
  image : MdImage?
}

///|
priv enum MdBlock {
  MdHeading(Int, Array[MdRun])
  MdParagraph(Array[MdRun])
  MdDefinition(Array[MdRun], Array[Array[MdRun]])
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
  warnings : Array[String]
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
      last.link == link &&
      last.image is None {
      runs[runs.length() - 1] = { text: last.text + text, style, link, image: None }
      return
    }
  }
  runs.push({ text, style, link, image: None })
}

///|
fn md_push_image(
  runs : Array[MdRun],
  image : MdImage,
  style : @drawingml.TextStyle,
  link : String,
) -> Unit {
  runs.push({ text: "", style, link, image: Some(image) })
}

///|
fn md_image_run(
  svg : MdSvg,
  sprite : StringBuilder,
  style : @drawingml.TextStyle,
  link : String,
  runs : Array[MdRun],
) -> Unit {
  let data = md_svg_document(svg.markup, sprite.to_string())
  if data.length() == 0 {
    return
  }
  let width = if svg.width > 0.0 { svg.width } else { 225.0 }
  let height = if svg.height > 0.0 { svg.height } else { 112.5 }
  md_push_image(runs, { data, width, height, fill: svg.fill }, style, link)
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
  svgs : Array[MdSvg],
  sprite : StringBuilder,
) -> Unit {
  let mut rest = text
  while true {
    let formula_at = rest.find("\uE000")
    let svg_at = rest.find("\uE002")
    let at = match (formula_at, svg_at) {
      (None, None) => {
        md_push_run(runs, rest, style, link)
        return
      }
      (Some(value), None) => value
      (None, Some(value)) => value
      (Some(a), Some(b)) => Int::min(a, b)
    }
    md_push_run(runs, rest[:at].to_owned(), style, link)
    let after = rest[at:].to_owned()
    if after.has_prefix("\uE002") {
      match md_svg_placeholder_at(after) {
        Some((index, length)) => {
          if index >= 0 && index < svgs.length() {
            md_image_run(svgs[index], sprite, style, link, runs)
          }
          rest = after[length:].to_owned()
        }
        None => {
          md_push_run(runs, after[:1].to_owned(), style, link)
          rest = after[1:].to_owned()
        }
      }
    } else {
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

///|
fn md_collect_inlines(
  nodes : Array[@mmtypes.Inline],
  style : @drawingml.TextStyle,
  link : String,
  runs : Array[MdRun],
  formulas : Array[String],
  images : Array[(String, String, String)],
  svgs : Array[MdSvg],
  sprite : StringBuilder,
  warnings : Array[String],
) -> Unit {
  for node in nodes {
    match node {
      @mmtypes.Inline::Text(text) =>
        md_push_text(text, style, link, runs, formulas, svgs, sprite)
      @mmtypes.Inline::CodeSpan(text) => {
        let code_style = { ..style, family: "Courier New", }
        md_push_run(runs, text, code_style, link)
      }
      @mmtypes.Inline::Emphasis(children) =>
        md_collect_inlines(
          children, md_inline_style(style, false, true), link, runs, formulas,
          images, svgs, sprite, warnings,
        )
      @mmtypes.Inline::Strong(children) =>
        md_collect_inlines(
          children, md_inline_style(style, true, false), link, runs, formulas,
          images, svgs, sprite, warnings,
        )
      @mmtypes.Inline::Strikethrough(children) =>
        md_collect_inlines(
          children, style, link, runs, formulas, images, svgs, sprite, warnings,
        )
      @mmtypes.Inline::Link(children, url, _) =>
        md_collect_inlines(
          children, style, url, runs, formulas, images, svgs, sprite, warnings,
        )
      @mmtypes.Inline::Image(alt, url, title) => {
        let alt_runs : Array[MdRun] = []
        md_collect_inlines(
          alt, style, link, alt_runs, formulas, images, svgs, sprite, warnings,
        )
        let alt_text = md_runs_text(alt_runs)
        images.push((alt_text, url, title.unwrap_or("")))
        match md_resolve_image(url) {
          Some(image) => md_push_image(runs, image, style, link)
          None => {
            if alt_text != "" {
              md_push_run(runs, alt_text, style, link)
            }
            md_warn_image(warnings, url)
          }
        }
      }
      @mmtypes.Inline::HardBreak => md_push_run(runs, "\n", style, link)
      @mmtypes.Inline::SoftBreak => md_push_run(runs, " ", style, link)
      @mmtypes.Inline::RawHTML(html) =>
        md_push_text(md_strip_html(html), style, link, runs, formulas, svgs, sprite)
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
fn md_front_term(key : String) -> String {
  match key {
    "title" => "title"
    "author" | "authors" | "creator" => "creator"
    "contributor" | "contributors" => "contributor"
    "date" | "published" | "created" | "publishdate" => "created"
    "lastmod" | "updated" | "modified" => "modified"
    "lang" | "language" | "locale" => "language"
    "description" | "summary" | "abstract" | "excerpt" => "description"
    "tags" | "keywords" | "categories" | "subject" => "subject"
    "publisher" => "publisher"
    "license" | "rights" | "copyright" => "rights"
    "id" | "url" | "identifier" | "permalink" => "identifier"
    _ => ""
  }
}

///|
fn md_front_unquote(value : String) -> String {
  let trimmed = value.trim().to_string()
  if trimmed.length() >= 2 &&
    ((trimmed[0] == '"' && trimmed[trimmed.length() - 1] == '"') ||
      (trimmed[0] == '\'' && trimmed[trimmed.length() - 1] == '\'')) {
    trimmed[1:trimmed.length() - 1].to_owned()
  } else {
    match trimmed.find(" #") {
      Some(at) => trimmed[:at].to_owned().trim().to_string()
      None => trimmed
    }
  }
}

///|
fn md_front_add(
  meta : Map[String, Array[String]],
  key : String,
  value : String,
) -> Unit {
  if key == "" || value == "" {
    return
  }
  let values = match meta.get(key) {
    Some(values) => values
    None => {
      let values : Array[String] = []
      meta[key] = values
      values
    }
  }
  values.push(value)
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
      let lines : Array[String] = []
      for line in head.split("\n") {
        lines.push(line.to_owned())
      }
      let mut last_key = ""
      let mut i = 0
      while i < lines.length() {
        let raw = lines[i]
        i += 1
        let trimmed = raw.trim().to_string()
        if trimmed == "" || trimmed.has_prefix("#") {
          continue
        }
        if trimmed.has_prefix("- ") && last_key != "" {
          let item = trimmed[2:].to_owned()
          let value = match item.find(":") {
            Some(at) if item[:at].trim().to_string() == "name" =>
              item[at + 1:].to_owned()
            _ => item
          }
          md_front_add(meta, last_key, md_front_unquote(value))
          continue
        }
        let separator = if delimiter == "+++" {
          trimmed.find("=")
        } else {
          trimmed.find(":")
        }
        match separator {
          Some(at) => {
            let raw_key = trimmed[:at].to_owned().trim().to_string().to_lower()
            let key = md_front_term(raw_key)
            let value = trimmed[at + 1:].to_owned().trim().to_string()
            if key == "" {
              last_key = ""
              continue
            }
            if value == "" {
              last_key = key
              continue
            }
            last_key = key
            if value == "|" ||
              value == ">" ||
              value == "|-" ||
              value == ">-" {
              let parts : Array[String] = []
              while i < lines.length() &&
                (lines[i].trim().is_empty() ||
                  lines[i].has_prefix(" ") ||
                  lines[i].has_prefix("\t")) {
                let part = lines[i].trim().to_string()
                if part != "" {
                  parts.push(part)
                }
                i += 1
              }
              md_front_add(meta, key, parts.join(" "))
              continue
            }
            if value.has_prefix("[") && value.has_suffix("]") {
              let inner = value[1:value.length() - 1]
              for item in inner.split(",") {
                md_front_add(meta, key, md_front_unquote(item.to_owned()))
              }
            } else {
              md_front_add(meta, key, md_front_unquote(value))
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
    MdDefinition(term, definitions) =>
      MdDefinition(
        md_scale_runs(term, scale, font, mono),
        definitions.map(fn(runs) {
          md_scale_runs(runs, scale, font, mono)
        }),
      )
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
  let svgs : Array[MdSvg] = []
  let sprite = StringBuilder::new()
  let math_text = md_parse_math_before(body, formulas)
  let svg_text = md_parse_svg_before(math_text, svgs, sprite)
  let lines = md_lines(svg_text)
  let (lines, definitions) = md_footnote_prepare(lines)
  let parser : MdParser = {
    formulas,
    images,
    warnings,
    title: "",
    svgs,
    sprite,
  }
  let blocks = parser.parse_blocks(lines, 0)
  for definition in definitions {
    let (number, body) = definition
    let runs = md_inline_runs(
      number.to_string() +
      ". " +
      body +
      " [↑](#fnref-" +
      number.to_string() +
      ")",
      md_style(),
      formulas,
      images,
      svgs,
      sprite,
      warnings,
    )
    blocks.push(MdParagraph(runs))
  }
  if blocks.is_empty() {
    blocks.push(MdParagraph([]))
  }
  { blocks, title: parser.title, meta, formulas, images, warnings }
}
