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
/// Convert a Markdown document into the scroll view upstream produces: one
/// column of text, no fixed page breaks.
pub fn convert(
  data : Bytes,
  title~ : String = "",
  size~ : Double = 0.0,
  width~ : Double = 0.0,
  font~ : String = "",
  mono~ : String = "",
) -> MarkdownResult raise MarkdownError {
  let text = @utf8.decode_lossy(data[:], ignore_bom=true)
  let document = md_parse(text)
  let document_title = if title != "" {
    title
  } else {
    match document.meta.get("title") {
      Some(value) if !value.is_empty() => value[0]
      _ => document.title
    }
  }
  let meta : Map[String, Json] = {
    "source": Json::string("markdown"),
    "generator": Json::string("bdf-go/0.1"),
  }
  let dc : Map[String, Json] = Map([])
  if document_title != "" {
    dc["title"] = Json::string(document_title)
  }
  for key in ["creator", "language", "description", "date"] {
    match document.meta.get(key) {
      Some(value) if !value.is_empty() => dc[key] = Json::string(value[0])
      _ => ()
    }
  }
  if !dc.is_empty() {
    meta["dc"] = Json::object(dc)
  }
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
  let text_size = if size > 0.0 { size } else { 12.0 }
  let text_width = if width > 0.0 { width } else { 432.0 }
  let (page, index_runs, image_count, layout_warnings) = md_render(
    document, writer, size=text_size, width=text_width, font~, mono~,
  ) catch {
    _ => raise MarkdownInvalid("Markdown document could not be laid out")
  }
  let warnings : Array[String] = []
  for warning in layout_warnings {
    warnings.push(warning)
  }
  let view : Map[String, Json] = {
    "id": Json::string("scroll"),
    "kind": Json::string("scroll"),
    "pages": Json::array([page]),
  }
  if document_title != "" {
    view["title"] = Json::string(document_title)
  }
  if !index_runs.is_empty() {
    let encoded = @core.encode_text_index(index_runs) catch { _ => b"" }
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
  {
    bdf,
    pages: 1,
    summary: "1 scroll strip(s), \{image_count} image(s), 0 embedded font(s)",
    warnings,
  }
}
