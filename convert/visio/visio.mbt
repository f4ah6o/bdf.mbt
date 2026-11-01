///|
/// A Visio VSDX conversion failure.
pub suberror VisioError {
  VisioInvalid(String)
}

///|
pub(all) struct VisioResult {
  bdf : Bytes
  pages : Int32
  summary : String
  warnings : Array[String]
}

///|
/// Detect a Visio 2013+ package.
pub fn detect(data : Bytes) -> Bool {
  if data.length() < 4 || data[0] != 0x50 || data[1] != 0x4b {
    return false
  }
  let head = @utf8.decode_lossy(data[:data.length().min(4096)], ignore_bom=true)
  head.contains("visio/") ||
  head.contains("schemas.microsoft.com/office/visio")
}

///|
/// Convert a Visio VSDX drawing into a fixed-view BDF document.
pub fn convert(
  data : Bytes,
  title~ : String = "",
) -> VisioResult raise VisioError {
  let doc = visio_open(data)
  let meta : Map[String, Json] = {
    "source": Json::string("vsdx"),
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
  let (pages, index_runs) = visio_render(doc, writer, warnings)
  let view : Map[String, Json] = {
    "id": Json::string("pages"),
    "kind": Json::string("fixed"),
    "pages": Json::array(pages),
  }
  if document_title != "" {
    view["title"] = Json::string(document_title)
  }
  if !index_runs.is_empty() {
    let encoded = @core.encode_text_index(index_runs) catch { _ => b"" }
    if encoded.length() > 0 {
      let hash = writer.add_part("idx", encoded) catch {
        _ => raise VisioInvalid("Visio text index could not be stored")
      }
      view["textIndex"] = Json::string(hash)
    }
  }
  writer.add_view(Json::object(view))
  let bdf = writer.write_single() catch {
    _ => raise VisioInvalid("Visio document could not be written")
  }
  let count = pages.length()
  {
    bdf,
    pages: count,
    summary: "\{count} page(s), 0 embedded font(s)",
    warnings,
  }
}
