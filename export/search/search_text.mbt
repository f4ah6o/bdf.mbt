///|
/// The text of a document for a search index, as the upstream BDF
/// SearchText record: metadata and the text of each view, page by page.
pub(all) struct SearchTextResult {
  json : String
  plain : String
  views : Int32
  pages : Int32
}

///|
fn object_resolver(
  document : @core.Document,
) -> (String) -> @core.ObjectResources? raise {
  fn(hash) {
    let bytes = document.part(hash) catch { _ => return None }
    Some(@core.decode_object_resources(bytes)) catch {
      _ => None
    }
  }
}

///|
fn read_part(document : @core.Document, hash : String) -> Bytes raise {
  document.part(hash)
}

///|
fn page_text(runs : Array[@core.IndexRun]) -> String {
  @core.index_plain_text(runs).trim().to_string()
}

///|
fn view_pages(
  view : @core.View,
  runs : Array[@core.IndexRun],
) -> (Array[Json], Int32) {
  let pages : Array[Json] = []
  if view.kind == "sheet" {
    let text = page_text(runs)
    if text != "" {
      pages.push(Json::object({ "text": Json::string(text) }))
    }
    return (pages, if pages.length() > 0 { 1 } else { 0 })
  }
  let by_page : Map[Int32, Array[@core.IndexRun]] = Map([])
  let numbers : Array[Int32] = []
  for run in runs {
    match by_page.get(run.a) {
      Some(list) => list.push(run)
      None => {
        by_page[run.a] = [run]
        numbers.push(run.a)
      }
    }
  }
  numbers.sort()
  for number in numbers {
    let text = match by_page.get(number) {
      Some(list) => page_text(list)
      None => ""
    }
    if text != "" {
      pages.push(
        Json::object({
          "page": Json::number((number + 1).to_double()),
          "text": Json::string(text),
        }),
      )
    }
  }
  (pages, pages.length())
}

///|
fn view_json(view : @core.View, pages : Array[Json]) -> Json {
  let fields : Map[String, Json] = {
    "id": Json::string(view.id),
    "kind": Json::string(view.kind),
    "pages": Json::array(pages),
  }
  if view.title != "" {
    fields["title"] = Json::string(view.title)
  }
  Json::object(fields)
}

///|
fn plain_text(view : @core.View, pages : Array[Json]) -> String {
  let out = StringBuilder()
  let title = if view.title == "" { view.id } else { view.title }
  out.write_string("# ")
  out.write_string(title)
  out.write_string("\n\n")
  for page in pages {
    let number = match page.value("page") {
      Some(Json::Number(value, ..)) => value.to_int()
      _ => 0
    }
    if number > 0 {
      out.write_string("## Page ")
      out.write_string(number.to_string())
      out.write_string("\n\n")
    }
    match page.value("text") {
      Some(Json::String(text)) => {
        out.write_string(text)
        out.write_string("\n\n")
      }
      _ => ()
    }
  }
  out.to_string()
}

///|
/// Build the search text of an opened BDF document.
pub fn search_text(document : @core.Document) -> SearchTextResult raise {
  let has_flow = document.manifest.views.any(view => view.kind == "flow")
  let resolve = object_resolver(document)
  let views : Array[Json] = []
  let plain = StringBuilder()
  let mut page_count = 0
  for view in document.manifest.views {
    if view.kind == "scroll" && has_flow {
      continue
    }
    let runs = @render.view_text_index(
      view,
      hash => read_part(document, hash),
      resolve,
    )
    let (pages, count) = view_pages(view, runs)
    page_count += count
    views.push(view_json(view, pages))
    plain.write_string(plain_text(view, pages))
  }
  let meta = match @core.manifest_json(document.data).value("meta") {
    Some(value) => value
    None => Json::empty_object()
  }
  let root = Json::object({ "meta": meta, "views": Json::array(views) })
  {
    json: root.stringify(),
    plain: plain.to_string(),
    views: views.length(),
    pages: page_count,
  }
}

///|
/// Build the search text of a single-file BDF. Encrypted documents must be
/// opened and decrypted by the caller first.
pub fn search_text_bytes(data : Bytes) -> SearchTextResult raise {
  search_text(@core.open_single(data))
}
