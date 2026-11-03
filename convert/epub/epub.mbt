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
fn epub_is_space(c : UInt16) -> Bool {
  c == 0x20 || c == 0x09 || c == 0x0d || c == 0x0a
}

///|
fn epub_local_name(name : String) -> String {
  match name.find(":") {
    Some(index) => name[index + 1:].to_owned()
    None => name
  }
}

///|
fn epub_tag_end(text : String, from : Int32) -> Int32? {
  let mut quote : UInt16 = 0
  let mut i = from
  while i < text.length() {
    let c = text[i]
    if quote != 0 {
      if c == quote {
        quote = 0
      }
    } else if c == 0x22 || c == 0x27 {
      quote = c
    } else if c == 0x3e {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn epub_find_tag(
  text : String,
  from : Int32,
  tag : String,
) -> (Int32, Int32)? {
  let mut pos = from
  while pos < text.length() {
    let tail = text[pos:].to_owned()
    let relative = match tail.find("<") {
      Some(value) => value
      None => return None
    }
    let start = pos + relative
    if start + 4 <= text.length() && text[start:start + 4] == "<!--" {
      let rest = text[start + 4:].to_owned()
      pos = match rest.find("-->") {
        Some(value) => start + 4 + value + 3
        None => return None
      }
      continue
    }
    if start + 9 <= text.length() && text[start:start + 9] == "<![CDATA[" {
      let rest = text[start + 9:].to_owned()
      pos = match rest.find("]]>") {
        Some(value) => start + 9 + value + 3
        None => return None
      }
      continue
    }
    if start + 2 <= text.length() && text[start:start + 2] == "<?" {
      let rest = text[start + 2:].to_owned()
      pos = match rest.find("?>") {
        Some(value) => start + 2 + value + 2
        None => return None
      }
      continue
    }
    if start + 2 <= text.length() && text[start:start + 2] == "<!" {
      let end = match epub_tag_end(text, start + 2) {
        Some(value) => value
        None => return None
      }
      pos = end + 1
      continue
    }
    let mut i = start + 1
    let closing = i < text.length() && text[i] == 0x2f
    while i < text.length() && (text[i] == 0x2f || epub_is_space(text[i])) {
      i += 1
    }
    if i >= text.length() {
      return None
    }
    let name_start = i
    while i < text.length() &&
          !epub_is_space(text[i]) &&
          text[i] != 0x2f &&
          text[i] != 0x3e {
      i += 1
    }
    let local = epub_local_name(text[name_start:i].to_owned())
    if local == tag && !closing {
      let end = match epub_tag_end(text, i) {
        Some(value) => value
        None => return None
      }
      return Some((start, end))
    }
    pos = start + 1
  }
  None
}

///|
fn epub_decode_entities(value : String) -> String {
  value
    .replace(old="&amp;", new="&")
    .replace(old="&quot;", new="\"")
    .replace(old="&apos;", new="'")
    .replace(old="&lt;", new="<")
    .replace(old="&gt;", new=">")
}

///|
fn epub_attr_in_tag(tag : String, name : String) -> String {
  let mut pos = 1
  while pos < tag.length() &&
        !epub_is_space(tag[pos]) &&
        tag[pos] != 0x2f &&
        tag[pos] != 0x3e {
    pos += 1
  }
  while pos < tag.length() {
    while pos < tag.length() &&
          (epub_is_space(tag[pos]) || tag[pos] == 0x2f) {
      pos += 1
    }
    if pos >= tag.length() || tag[pos] == 0x3e {
      break
    }
    let key_start = pos
    while pos < tag.length() &&
          !epub_is_space(tag[pos]) &&
          tag[pos] != 0x3d &&
          tag[pos] != 0x2f &&
          tag[pos] != 0x3e {
      pos += 1
    }
    let key = tag[key_start:pos].to_owned()
    while pos < tag.length() && epub_is_space(tag[pos]) {
      pos += 1
    }
    if pos < tag.length() && tag[pos] == 0x3d {
      pos += 1
      while pos < tag.length() && epub_is_space(tag[pos]) {
        pos += 1
      }
      let value = if pos < tag.length() &&
        (tag[pos] == 0x22 || tag[pos] == 0x27) {
        let quote = tag[pos]
        pos += 1
        let value_start = pos
        while pos < tag.length() && tag[pos] != quote {
          pos += 1
        }
        let value = tag[value_start:pos].to_owned()
        if pos < tag.length() {
          pos += 1
        }
        value
      } else {
        let value_start = pos
        while pos < tag.length() &&
              !epub_is_space(tag[pos]) &&
              tag[pos] != 0x3e {
          pos += 1
        }
        tag[value_start:pos].to_owned()
      }
      if key == name {
        return epub_decode_entities(value)
      }
    }
  }
  ""
}

///|
fn epub_attr(text : String, tag : String, name : String) -> String {
  match epub_find_tag(text, 0, tag) {
    Some((start, end)) => epub_attr_in_tag(text[start:end + 1].to_owned(), name)
    None => ""
  }
}

///|
fn epub_tag_text(text : String, tag : String) -> String {
  match epub_find_tag(text, 0, tag) {
    Some((_, end)) => {
      let after = text[end + 1:].to_owned()
      let close = match after.find("</") {
        Some(value) => value
        None => return ""
      }
      after[:close].to_owned().trim().to_string()
    }
    None => ""
  }
}

///|
fn epub_item_is_content(href : String, media : String) -> Bool {
  if media != "" {
    return media.contains("html") || media.contains("xhtml")
  }
  let lower = href.to_lower()
  lower.has_suffix(".xhtml") ||
  lower.has_suffix(".html") ||
  lower.has_suffix(".htm")
}

///|
fn epub_opf_parts(opf : String) -> (Array[String], String, String, String) {
  let manifest : Array[(String, String)] = []
  let ids : Map[String, String] = Map([])
  let mut pos = 0
  while true {
    match epub_find_tag(opf, pos, "item") {
      Some((start, end)) => {
        let tag = opf[start:end + 1].to_owned()
        let id = epub_attr_in_tag(tag, "id")
        let href = epub_attr_in_tag(tag, "href")
        let media = epub_attr_in_tag(tag, "media-type")
        if id != "" && href != "" && epub_item_is_content(href, media) {
          manifest.push((id, href))
          ids[id] = href
        }
        pos = end + 1
      }
      None => break
    }
  }
  let spine : Array[String] = []
  let mut spine_search = 0
  while true {
    match epub_find_tag(opf, spine_search, "itemref") {
      Some((start, end)) => {
        let tag = opf[start:end + 1].to_owned()
        let idref = epub_attr_in_tag(tag, "idref")
        match ids.get(idref) {
          Some(href) => spine.push(href)
          None => ()
        }
        spine_search = end + 1
      }
      None => break
    }
  }
  if spine.is_empty() {
    for entry in manifest {
      spine.push(entry.1)
    }
  }
  let title = epub_tag_text(opf, "title")
  let creator = epub_tag_text(opf, "creator")
  let language = epub_tag_text(opf, "language")
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
  let options = @reader.ReaderOptions::new(
    width=419.5,
    height=595.3,
    margin=41.95,
    font_size=12.0,
  )
  let layout = @reader.render(reader, writer, options~)
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
