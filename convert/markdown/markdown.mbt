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
fn md_add_view(
  writer : @core.DocumentWriter,
  layout : MdRenderResult,
  id : String,
  kind : String,
  title : String,
) -> Unit raise MarkdownError {
  let view : Map[String, Json] = {
    "id": Json::string(id),
    "kind": Json::string(kind),
    "pages": Json::array(layout.pages),
  }
  if kind == "flow" {
    view["continuous"] = Json::object({ "gap": Json::number(24.0) })
  }
  if title != "" {
    view["title"] = Json::string(title)
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
}

///|
/// Convert a Markdown document into the upstream views: a scroll view of one
/// column of text (the default), A4-like pages, or both.
pub fn convert(
  data : Bytes,
  title~ : String = "",
  size~ : Double = 0.0,
  width~ : Double = 0.0,
  font~ : String = "",
  mono~ : String = "",
  views~ : String = "scroll",
) -> MarkdownResult raise MarkdownError {
  let views = if views == "" { "scroll" } else { views }
  if views != "scroll" && views != "pages" && views != "both" {
    raise MarkdownInvalid(
      "unknown views \"" + views + "\" (want both, pages or scroll)",
    )
  }
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
  for key, values in document.meta {
    if values.is_empty() {
      continue
    }
    if key == "subject" {
      dc[key] = Json::array(values.map(Json::string))
    } else {
      dc[key] = Json::string(values[0])
    }
  }
  if document_title != "" {
    dc["title"] = Json::string(document_title)
  }
  if !dc.is_empty() {
    meta["dc"] = Json::object(dc)
  }
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
  let text_size = if size > 0.0 { size } else { 12.0 }
  let text_width = if width > 0.0 { width } else { 432.0 }
  let scale = text_size / 12.0
  let blocks = document.blocks.map(fn(block) {
    md_scale_block(block, scale, font, mono)
  })
  let warnings = document.warnings
  let image_seen : Map[String, Bool] = Map([])
  let images = Ref(0)
  let mut page_layout : MdRenderResult? = None
  let mut scroll_layout : MdRenderResult? = None
  if views != "scroll" {
    page_layout = Some(
      md_render(
        blocks,
        writer,
        page_view=true,
        warnings=warnings,
        image_seen=image_seen,
        images=images,
        size=text_size,
        width=text_width,
      ) catch {
        _ => raise MarkdownInvalid("Markdown pages could not be laid out")
      },
    )
  }
  if views != "pages" {
    scroll_layout = Some(
      md_render(
        blocks,
        writer,
        page_view=false,
        warnings=warnings,
        image_seen=image_seen,
        images=images,
        size=text_size,
        width=text_width,
      ) catch {
        _ => raise MarkdownInvalid("Markdown document could not be laid out")
      },
    )
  }
  let mut page_count = 0
  let mut strips = 0
  match page_layout {
    Some(layout) => {
      page_count = layout.pages.length()
      md_add_view(writer, layout, "pages", "flow", document_title)
    }
    None => ()
  }
  match scroll_layout {
    Some(layout) => {
      strips = layout.strips
      md_add_view(writer, layout, "scroll", "scroll", document_title)
    }
    None => ()
  }
  let bdf = writer.write_single() catch {
    _ => raise MarkdownInvalid("Markdown document could not be written")
  }
  let image_count = images.val
  let summary = if views == "both" {
    "\{page_count} page(s), \{strips} scroll strip(s), \{image_count} image(s), 0 embedded font(s)"
  } else if views == "pages" {
    "\{page_count} page(s), \{image_count} image(s), 0 embedded font(s)"
  } else {
    "\{strips} scroll strip(s), \{image_count} image(s), 0 embedded font(s)"
  }
  {
    bdf,
    pages: if views == "scroll" { 1 } else { page_count },
    summary,
    warnings,
  }
}
