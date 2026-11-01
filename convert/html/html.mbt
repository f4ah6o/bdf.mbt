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
fn html_blocks(source : String, warnings : Array[String]) -> (String, Array[@reader.ReaderBlock]) {
  let chars = source.to_array()
  let blocks : Array[@reader.ReaderBlock] = []
  let title = StringBuilder()
  let text = StringBuilder()
  let mut kind = 0 // 0 paragraph, 1 heading, 2 list, 3 code, 4 quote
  let mut level = 0
  let mut ordered = false
  let mut in_pre = false
  let mut skip = 0 // 1 script, 2 style
  let mut in_title = false
  let flush = fn() -> Unit {
    let value = html_clean(text.to_string(), in_pre)
    text.reset()
    if value == "" {
      return
    }
    match kind {
      1 => blocks.push(Heading(level, value))
      2 => blocks.push(ListItem(0, ordered, value))
      3 => blocks.push(Code(value))
      4 => blocks.push(Quote(value))
      _ => blocks.push(Paragraph(value))
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
        skip = if closing { 0 } else { 2 }
      } else if skip != 0 {
        // content of script/style is not reader text
      } else if name == "title" {
        in_title = !closing
      } else if name == "br" {
        text.write_char('\n')
      } else if name == "img" {
        let alt = {
          let lower = tag_text
          let at = lower.find("alt=")
          match at {
            Some(index) => {
              let rest = lower[index + 4:].to_owned()
              if rest == "" {
                ""
              } else {
                let quote = rest[0]
                let tail = rest[1:].to_owned()
                let close = if quote == '"' { tail.find("\"") } else { tail.find("'") }
                match close {
                  Some(end_index) => rest[1:end_index + 1].to_owned()
                  None => ""
                }
              }
            }
            None => ""
          }
        }
        if alt != "" {
          text.write_string(alt)
        }
      } else if name == "h1" || name == "h2" || name == "h3" || name == "h4" ||
        name == "h5" || name == "h6" {
        flush()
        level = name[1].to_int() - '0'.to_int()
        kind = 1
      } else if name == "p" || name == "div" || name == "tr" || name == "section" ||
        name == "article" {
        flush()
        kind = 0
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
        blocks.push(Rule)
      } else if name == "td" || name == "th" {
        text.write_char('\t')
      } else if name == "p" || name == "ul" || name == "ol" || name == "table" {
        flush()
      }
      if closing && (name == "p" || name == "div" || name == "li" ||
        name == "h1" || name == "h2" || name == "h3" || name == "h4" ||
        name == "h5" || name == "h6" || name == "blockquote" || name == "tr") {
        flush()
        kind = 0
        in_pre = false
      }
      if name == "img" && !self_closing {
        // an unclosed img is still an empty element
      }
      i = end + 1
    } else {
      if in_title {
        title.write_char(chars[i])
      } else if skip == 0 {
        text.write_char(chars[i])
      }
      i += 1
    }
  }
  flush()
  ignore(warnings)
  (html_clean(title.to_string(), false), blocks)
}

///|
/// Parse an HTML document into the shared reader document model.
pub fn reader_document(
  data : Bytes,
  title~ : String = "",
) -> @reader.ReaderDocument {
  let source = @utf8.decode_lossy(data[:], ignore_bom=true)
  let (document_title, blocks) = html_blocks(source, [])
  let title = if title != "" { title } else { document_title }
  { title, blocks }
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
