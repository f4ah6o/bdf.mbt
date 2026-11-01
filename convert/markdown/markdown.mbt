///|
/// A Markdown conversion failure.
pub suberror MarkdownError {
  MarkdownInvalid(String)
}

///|
pub(all) struct MarkdownResult {
  bdf : Bytes
  pages : Int32
  summary : String
  warnings : Array[String]
}

///|
/// Markdown is recognised by its extension, not by its content.
pub fn detect(_data : Bytes) -> Bool {
  false
}

///|
fn markdown_front_matter(text : String) -> (String, Map[String, Array[String]]) {
  let meta : Map[String, Array[String]] = Map([])
  if !text.has_prefix("---\n") {
    return (text, meta)
  }
  let end = text.find("\n---\n")
  match end {
    Some(index) => {
      let head = text[4:index].to_owned()
      for line in head.split("\n") {
        let colon = line.find(":")
        match colon {
          Some(at) => {
            let key = line[:at].to_owned().trim().to_string().to_lower()
            let value = line[at + 1:].to_owned().trim().to_string()
            if value != "" {
              let key = match key {
                "author" | "authors" => "creator"
                "description" => "description"
                _ => key
              }
              meta[key] = [value]
            }
          }
          None => ()
        }
      }
      let body = text[index + 5:].to_owned()
      (body, meta)
    }
    None => (text, meta)
  }
}

///|
fn markdown_inline(text : String) -> String {
  let out = StringBuilder()
  let chars = text.to_array()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == '!' && i + 1 < chars.length() && chars[i + 1] == '[' {
      // Image: keep the alt text and drop the target.
      i += 2
      let alt = StringBuilder()
      while i < chars.length() && chars[i] != ']' {
        alt.write_char(chars[i])
        i += 1
      }
      out.write_string(alt.to_string())
      while i < chars.length() && chars[i] != ')' {
        i += 1
      }
      i += 1
    } else if c == '[' {
      let label = StringBuilder()
      i += 1
      while i < chars.length() && chars[i] != ']' {
        label.write_char(chars[i])
        i += 1
      }
      while i < chars.length() && chars[i] != ')' {
        i += 1
      }
      i += 1
      out.write_string(markdown_inline(label.to_string()))
    } else if c == '*' || c == '_' || c == '`' {
      i += 1
    } else if c == '<' {
      while i < chars.length() && chars[i] != '>' {
        i += 1
      }
      i += 1
    } else if c == '\\' && i + 1 < chars.length() {
      out.write_char(chars[i + 1])
      i += 2
    } else {
      out.write_char(c)
      i += 1
    }
  }
  out.to_string().trim().to_string()
}

///|
fn markdown_parse(text : String, warnings : Array[String]) -> (@reader.ReaderDocument, Map[String, Array[String]]) {
  let (text, meta) = markdown_front_matter(text)
  let paragraphs : Array[String] = []
  let blocks : Array[@reader.ReaderBlock] = []
  let lines = text.split("\n").to_array()
  let mut i = 0
  let paragraph = StringBuilder()
  let mut title = ""
  let flush = fn() -> Unit {
    let value = paragraph.to_string().trim().to_string()
    if value != "" {
      blocks.push(Paragraph(markdown_inline(value)))
    }
    paragraph.reset()
  }
  while i < lines.length() {
    let raw = lines[i].to_owned()
    let line = raw.trim().to_string()
    if line == "" {
      flush()
      i += 1
      continue
    }
    if line.has_prefix("```") || line.has_prefix("~~~") {
      flush()
      let fence = line[:3].to_owned()
      i += 1
      let code = StringBuilder()
      while i < lines.length() && !lines[i].trim().to_owned().has_prefix(fence) {
        code.write_string(lines[i].to_owned())
        code.write_char('\n')
        i += 1
      }
      i += 1
      blocks.push(Code(code.to_string().trim_end().to_owned()))
      continue
    }
    let mut level = 0
    while level < line.length() && level < 6 && line[level] == '#' {
      level += 1
    }
    if level > 0 && level < line.length() && line[level] == ' ' {
      flush()
      let heading = markdown_inline(line[level + 1:].to_owned())
      if title == "" {
        title = heading
      }
      blocks.push(Heading(level, heading))
      i += 1
      continue
    }
    if line == "---" || line == "***" || line == "___" {
      flush()
      blocks.push(Rule)
      i += 1
      continue
    }
    if line.has_prefix("- ") || line.has_prefix("* ") || line.has_prefix("+ ") {
      flush()
      let mut level = 0
      for ch in raw {
        if ch == ' ' {
          level += 1
        } else {
          break
        }
      }
      let mut item = line[2:].to_owned().trim().to_string()
      if item.has_prefix("[x]") || item.has_prefix("[X]") {
        item = "✓ " + item[3:].to_owned().trim().to_string()
      } else if item.has_prefix("[ ]") {
        item = "☐ " + item[3:].to_owned().trim().to_string()
      }
      blocks.push(ListItem(level / 2, false, markdown_inline(item)))
      i += 1
      continue
    }
    let chars = line.to_array()
    let mut digit = 0
    while digit < chars.length() && chars[digit] >= '0' && chars[digit] <= '9' {
      digit += 1
    }
    if digit > 0 && digit + 1 < chars.length() && chars[digit] == '.' &&
      chars[digit + 1] == ' ' {
      flush()
      blocks.push(ListItem(0, true, markdown_inline(line[digit + 2:].to_owned())))
      i += 1
      continue
    }
    if line.has_prefix("> ") {
      flush()
      blocks.push(Quote(markdown_inline(line[2:].to_owned())))
      i += 1
      continue
    }
    if line.has_prefix("|") && line.has_suffix("|") {
      flush()
      let cells : Array[String] = []
      for cell in line[1:line.length() - 1].split("|") {
        let value = cell.trim()
        if value != "" && !value.contains("---") {
          cells.push(value.to_string())
        }
      }
      if !cells.is_empty() {
        blocks.push(Paragraph(cells.join("\t")))
      }
      i += 1
      continue
    }
    if line.has_prefix("<") && line.has_suffix(">") {
      // Raw HTML blocks are kept as their text.
      let stripped = markdown_inline(line)
      if stripped != "" {
        if paragraph.to_string() != "" {
          paragraph.write_char(' ')
        }
        paragraph.write_string(stripped)
      }
      i += 1
      continue
    }
    if paragraph.to_string() != "" {
      paragraph.write_char(' ')
    }
    paragraph.write_string(line)
    i += 1
  }
  flush()
  if blocks.is_empty() {
    blocks.push(Paragraph(""))
  }
  ignore(paragraphs)
  ignore(warnings)
  ({ title, blocks }, meta)
}

///|
/// Convert a Markdown document into fixed reader pages.
pub fn convert(
  data : Bytes,
  title~ : String = "",
) -> MarkdownResult raise MarkdownError {
  let text = @utf8.decode_lossy(data[:], ignore_bom=true)
  let warnings : Array[String] = []
  let (document, meta) = markdown_parse(text, warnings)
  let document_title = if title != "" {
    title
  } else {
    match meta.get("title") {
      Some(value) if !value.is_empty() => value[0]
      _ => document.title
    }
  }
  let meta_json : Map[String, Json] = {
    "source": Json::string("markdown"),
    "generator": Json::string("bdf-go/0.1"),
  }
  let dc : Map[String, Json] = Map([])
  if document_title != "" {
    dc["title"] = Json::string(document_title)
  }
  for key in ["creator", "language", "description"] {
    match meta.get(key) {
      Some(value) if !value.is_empty() => dc[key] = Json::string(value[0])
      _ => ()
    }
  }
  if !dc.is_empty() {
    meta_json["dc"] = Json::object(dc)
  }
  let writer = @core.DocumentWriter::new(meta=Json::object(meta_json))
  let layout = @reader.render(document, writer)
  for warning in layout.warnings {
    warnings.push(warning)
  }
  let view : Map[String, Json] = {
    "id": Json::string("pages"),
    "kind": Json::string("fixed"),
    "pages": Json::array(layout.pages),
  }
  if document_title != "" {
    view["title"] = Json::string(document_title)
  }
  if !layout.index_runs.is_empty() {
    let encoded = @core.encode_text_index(layout.index_runs) catch { _ => b"" }
    if encoded.length() > 0 {
      let hash = writer.add_part("idx", encoded) catch {
        _ => raise MarkdownInvalid("Markdown text index could not be stored")
      }
      view["textIndex"] = Json::string(hash)
    }
  }
  writer.add_view(Json::object(view))
  let bdf = writer.write_single() catch {
    _ => raise MarkdownInvalid("Markdown document could not be written")
  }
  let count = layout.pages.length()
  {
    bdf,
    pages: count,
    summary: "\{count} page(s)",
    warnings,
  }
}
