///|
/// Return a single-file BDF containing only the selected 1-based pages.
/// Stored parts that are no longer referenced are left out of the manifest.
pub fn select_pages(data : Bytes, pages : Array[Int64]) -> Bytes raise {
  if pages.is_empty() {
    return data
  }
  let split = single_to_split(data)
  let root = @json.parse(
    @utf8.decode(split.manifest) catch {
      _ => raise BadFormat("invalid UTF-8 manifest")
    },
  )
  let selected : Map[Int64, Bool] = Map([])
  for page in pages {
    if page > 0L {
      selected[page] = true
    }
  }
  let filtered = match root {
    Object(fields) => {
      let views = match fields.get("views") {
        Some(Array(values)) => values
        _ => []
      }
      let kept_views : Array[Json] = []
      let mut page_index = 0
      for view in views {
        if view is Object(view_fields) {
          let source_pages = match view_fields.get("pages") {
            Some(Array(values)) => values
            _ => []
          }
          let kept_pages : Array[Json] = []
          for page in source_pages {
            page_index += 1
            if selected.contains(page_index.to_int64()) {
              kept_pages.push(page)
            }
          }
          view_fields["pages"] = Json::array(kept_pages)
          kept_views.push(Json::object(view_fields))
        }
      }
      fields["views"] = Json::array(kept_views)
      Json::object(fields)
    }
    _ => raise BadFormat("manifest root is not an object")
  }
  let manifest = @utf8.encode(filtered.stringify())
  let parts : Map[String, Bytes] = Map([])
  for part in split.parts {
    parts[part.hash] = part.data
  }
  split_to_single(manifest, (hash, _) => {
    match parts.get(hash) {
      Some(value) => value
      None => raise BadFormat("missing selected part")
    }
  })
}
