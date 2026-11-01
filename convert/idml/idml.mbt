///|
/// An InDesign IDML package conversion failure.
pub suberror IdmlError {
  IdmlInvalid(String)
}

///|
pub(all) struct IdmlResult {
  bdf : Bytes
  pages : Int32
  summary : String
  warnings : Array[String]
}

///|
/// Detect an IDML package by its ZIP prefix and package mimetype.
pub fn detect(data : Bytes) -> Bool {
  if data.length() < 4 || data[0] != 0x50 || data[1] != 0x4b {
    return false
  }
  let head = @utf8.decode_lossy(data[:data.length().min(4096)], ignore_bom=true)
  head.contains("application/vnd.adobe.indesign-idml-package")
}

///|
/// Convert an IDML package into a fixed-view BDF document.
pub fn convert(
  data : Bytes,
  title~ : String = "",
) -> IdmlResult raise IdmlError {
  let doc = idml_open(data)
  let pages : Array[IdmlPage] = []
  for spread in doc.spreads {
    for page in spread.pages {
      pages.push(page)
    }
  }
  if pages.is_empty() {
    raise IdmlInvalid("IDML: the document has no pages")
  }
  let meta : Map[String, Json] = {
    "source": Json::string("idml"),
    "generator": Json::string("bdf-go/0.1"),
  }
  let dc : Map[String, Json] = Map([])
  let document_title = if title != "" { title } else { doc.title }
  if document_title != "" {
    dc["title"] = Json::string(document_title)
  }
  if doc.creator != "" {
    dc["creator"] = Json::string(doc.creator)
  }
  if doc.language != "" {
    dc["language"] = Json::string(doc.language)
  }
  if !dc.is_empty() {
    meta["dc"] = Json::object(dc)
  }
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
  let warnings : Array[String] = []
  if doc.flow_overflow {
    warnings.push("IDML story is overset; the remaining text is not shown")
  }
  let page_json : Array[Json] = []
  let index_runs : Array[@core.IndexRun] = []
  let mut number = 1
  for spread in doc.spreads {
    for page in spread.pages {
      let (rendered, runs) = idml_render_page(
        doc, spread, page, number, writer, warnings,
      )
      page_json.push(rendered)
      for run in runs {
        index_runs.push(run)
      }
      number += 1
    }
  }
  let view : Map[String, Json] = {
    "id": Json::string("pages"),
    "kind": Json::string("fixed"),
    "pages": Json::array(page_json),
  }
  if document_title != "" {
    view["title"] = Json::string(document_title)
  }
  if !index_runs.is_empty() {
    let encoded = @core.encode_text_index(index_runs) catch { _ => b"" }
    if encoded.length() > 0 {
      let hash = writer.add_part("idx", encoded) catch {
        _ => raise IdmlInvalid("IDML text index could not be stored")
      }
      view["textIndex"] = Json::string(hash)
    }
  }
  writer.add_view(Json::object(view))
  let bdf = writer.write_single() catch {
    _ => raise IdmlInvalid("IDML document could not be written")
  }
  let count = page_json.length()
  {
    bdf,
    pages: count,
    summary: "\{count} page(s), 0 embedded font(s)",
    warnings,
  }
}
