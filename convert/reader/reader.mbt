///|
/// A reader-mode document conversion failure.
pub suberror ReaderError {
  ReaderInvalid(String)
}

///|
pub(all) enum ReaderBlock {
  Heading(Int32, String)
  Paragraph(String)
  ListItem(Int32, Bool, String)
  Code(String)
  Quote(String)
  Rule
}

///|
pub(all) struct ReaderDocument {
  title : String
  blocks : Array[ReaderBlock]
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
      Heading(level, text) => {
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
      Paragraph(text) => {
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
      ListItem(level, ordered, text) => {
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
      Code(text) => {
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
      Quote(text) => {
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
      Float::from_double(options.width - options.margin * 2.0 - line.indent),
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
