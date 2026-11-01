///|
/// An EPUB conversion failure.
pub suberror EpubError {
  EpubInvalid(String)
}

///|
pub(all) struct EpubResult {
  bdf : Bytes
  pages : Int32
  summary : String
  warnings : Array[String]
}

///|
/// Detect an EPUB publication by its ZIP prefix and mimetype.
pub fn detect(data : Bytes) -> Bool {
  if data.length() < 4 || data[0] != 0x50 || data[1] != 0x4b {
    return false
  }
  let head = @utf8.decode_lossy(data[:data.length().min(4096)], ignore_bom=true)
  head.contains("application/epub+zip")
}

///|
fn epub_attr(text : String, tag : String, name : String) -> String {
  let mut search = 0
  while true {
    let at = text.find("<" + tag) catch { _ => None }
    ignore(at)
    break
  }
  let marker = "<" + tag
  let start = match text.find(marker) {
    Some(value) => value
    None => return ""
  }
  let tail = text[start:].to_owned()
  let key = name + "=\""
  let key_start = match tail.find(key) {
    Some(value) => value
    None => return ""
  }
  let value_start = key_start + key.length()
  let rest = tail[value_start:].to_owned()
  let end = match rest.find("\"") {
    Some(value) => value
    None => return ""
  }
  rest[:end].to_owned()
}

///|
fn epub_tag_text(text : String, tag : String) -> String {
  let open = "<" + tag
  let start = match text.find(open) {
    Some(value) => value
    None => return ""
  }
  let after = text[start:].to_owned()
  let gt = match after.find(">") {
    Some(value) => value
    None => return ""
  }
  let rest = after[gt + 1:].to_owned()
  let close = "</" + tag + ">"
  let end = match rest.find(close) {
    Some(value) => value
    None => return ""
  }
  rest[:end].to_owned().trim().to_string()
}

///|
fn epub_opf_parts(opf : String) -> (Array[String], String, String, String) {
  let ids : Map[String, String] = Map([])
  let mut search = 0
  while true {
    let at = opf.find("<item ")
    match at {
      Some(index) => {
        if index < search {
          break
        }
        let rest = opf[index:].to_owned()
        let gt = match rest.find(">") {
          Some(value) => value
          None => break
        }
        let tag = rest[:gt].to_owned()
        let id = epub_attr("<item " + tag, "item", "id")
        let href = epub_attr("<item " + tag, "item", "href")
        let media = epub_attr("<item " + tag, "item", "media-type")
        if href != "" && (media.contains("xhtml") || media.contains("html")) {
          ids[id] = href
        }
        search = index + gt + 1
      }
      None => break
    }
  }
  let spine : Array[String] = []
  let mut spine_search = 0
  while true {
    let tail = opf[spine_search:].to_owned()
    let at = tail.find("<itemref")
    match at {
      Some(relative) => {
        let index = spine_search + relative
        let rest = opf[index:].to_owned()
        let gt = match rest.find(">") {
          Some(value) => value
          None => break
        }
        let tag = rest[:gt].to_owned()
        let idref = epub_attr("<itemref" + tag, "itemref", "idref")
        match ids.get(idref) {
          Some(href) => spine.push(href)
          None => ()
        }
        spine_search = index + gt + 1
      }
      None => break
    }
  }
  let title = epub_tag_text(opf, "dc:title")
  let creator = epub_tag_text(opf, "dc:creator")
  let language = epub_tag_text(opf, "dc:language")
  (spine, title, creator, language)
}

///|
/// Convert the reflowable chapters of an EPUB publication into reader pages.
pub fn convert(
  data : Bytes,
  title~ : String = "",
) -> EpubResult raise EpubError {
  let package = @ooxml.open_ooxml(data) catch {
    @ooxml.InvalidOoxml(message) => raise EpubInvalid(message)
  }
  let container = try {
    @utf8.decode_lossy(package.read("META-INF/container.xml")[:], ignore_bom=true)
  } catch {
    _ => raise EpubInvalid("EPUB: the package has no container")
  }
  let rootfile = epub_attr(container, "rootfile", "full-path")
  if rootfile == "" {
    raise EpubInvalid("EPUB: the package document is missing")
  }
  let rootfile_parts = rootfile.split("/").to_array()
  let directory = if rootfile_parts.length() > 1 {
    let parts : Array[String] = []
    for i in 0..<(rootfile_parts.length() - 1) {
      parts.push(rootfile_parts[i].to_owned())
    }
    parts.join("/") + "/"
  } else {
    ""
  }
  let opf = try {
    @utf8.decode_lossy(package.read(rootfile)[:], ignore_bom=true)
  } catch {
    _ => raise EpubInvalid("EPUB: the package document is missing")
  }
  let (spine, opf_title, creator, language) = epub_opf_parts(opf)
  if spine.is_empty() {
    raise EpubInvalid("EPUB: the spine has no content documents")
  }
  let blocks : Array[@reader.ReaderBlock] = []
  let warnings : Array[String] = []
  for href in spine {
    let path = if href.has_prefix("/") {
      href[1:].to_owned()
    } else {
      directory + href
    }
    let chapter = package.read(path) catch {
      _ => {
        warnings.push("EPUB: a content document is missing: " + href)
        continue
      }
    }
    let document = @html.reader_document(chapter)
    for block in document.blocks {
      blocks.push(block)
    }
  }
  let document_title = if title != "" {
    title
  } else {
    opf_title
  }
  let reader : @reader.ReaderDocument = { title: document_title, blocks }
  let meta : Map[String, Json] = {
    "source": Json::string("epub"),
    "generator": Json::string("bdf-go/0.1"),
  }
  let dc : Map[String, Json] = Map([])
  if document_title != "" {
    dc["title"] = Json::string(document_title)
  }
  if creator != "" {
    dc["creator"] = Json::string(creator)
  }
  if language != "" {
    dc["language"] = Json::string(language)
  }
  if !dc.is_empty() {
    meta["dc"] = Json::object(dc)
  }
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
  let layout = @reader.render(reader, writer)
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
        _ => raise EpubInvalid("EPUB text index could not be stored")
      }
      view["textIndex"] = Json::string(hash)
    }
  }
  writer.add_view(Json::object(view))
  let bdf = writer.write_single() catch {
    _ => raise EpubInvalid("EPUB document could not be written")
  }
  let count = layout.pages.length()
  {
    bdf,
    pages: count,
    summary: "\{count} page(s) from \{spine.length()} content document(s)",
    warnings,
  }
}
