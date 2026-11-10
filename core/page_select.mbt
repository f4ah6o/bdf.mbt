///|
/// The stored form of a manifest part, as the JSON manifest describes it.
priv struct PageSelectPart {
  kind : String
  encoding : String
  size : Int32
}

///|
/// A text index rewritten for the selected pages, and the part that stores it.
priv struct PageSelectIndex {
  old : String
  hash : String
  data : Bytes
}

///|
/// What a page selection does to a view's text index.
priv enum PageSelectTextIndex {
  /// The selection kept every page, so the index still describes the view.
  Unchanged
  /// The index was rewritten for the selected pages.
  Rewritten(PageSelectIndex)
  /// The index of the named part cannot be rewritten. The view must not keep
  /// it: a reader rebuilds a missing index from the page objects, and those
  /// objects belong to the selected pages alone.
  Unreadable(String)
}

///|
/// Read the stored metadata of each manifest part. The JSON is read directly
/// rather than through `parse_manifest` so an encrypted outer manifest, which
/// has no views, still copies through.
fn page_select_parts(root : Json) -> Map[String, PageSelectPart] {
  let parts : Map[String, PageSelectPart] = Map([])
  if root is Object(fields) {
    match fields.get("parts") {
      Some(Array(entries)) =>
        for entry in entries {
          if entry is Object(entry_fields) {
            let hash = match entry_fields.get("h") {
              Some(String(value)) => value
              _ => ""
            }
            if hash != "" {
              parts[hash] = {
                kind: match entry_fields.get("t") {
                  Some(String(value)) => value
                  _ => ""
                },
                encoding: match entry_fields.get("enc") {
                  Some(String(value)) => value
                  _ => "identity"
                },
                size: match entry_fields.get("size") {
                  Some(Number(value, ..)) => value.to_int()
                  _ => -1
                },
              }
            }
          }
        }
      _ => ()
    }
  }
  parts
}

///|
/// Keep the text index runs of the selected pages and renumber them.
///
/// A run's `a` is the page index within its view, so a selection that drops
/// pages must drop their runs and shift the rest. Otherwise the page would
/// carry the text of pages it no longer holds. `b` and `ordinal` name the layer
/// and the run inside that page, so they stay valid as they are. Sheet views
/// index tiles, not pages, and are left alone by the caller.
fn page_select_text_index(
  view : Map[String, Json],
  remap : Map[Int64, Int64],
  dropped : Bool,
  parts : Map[String, PageSelectPart],
  stored : Map[String, Bytes],
) -> PageSelectTextIndex {
  if !dropped {
    return Unchanged
  }
  let hash = match view.get("textIndex") {
    Some(String(value)) => value
    _ => return Unchanged
  }
  let part = match parts.get(hash) {
    Some(value) => value
    None => return Unreadable(hash)
  }
  if part.kind == "sealed" {
    return Unreadable(hash)
  }
  let data = match stored.get(hash) {
    Some(value) => value
    None => return Unreadable(hash)
  }
  let decoded = if part.encoding == "identity" {
    data
  } else if part.encoding == "deflate-raw" && part.size >= 0 {
    inflate_bounded(data, part.size) catch { _ => return Unreadable(hash) }
  } else {
    return Unreadable(hash)
  }
  let runs = decode_text_index(decoded) catch { _ => return Unreadable(hash) }
  let kept : Array[IndexRun] = []
  let mut changed = false
  for run in runs {
    match remap.get(run.a.to_int64()) {
      Some(index) => {
        if index != run.a.to_int64() {
          changed = true
        }
        kept.push({
          a: index.to_int(),
          b: run.b,
          ordinal: run.ordinal,
          separator: run.separator,
          text: run.text,
        })
      }
      None => changed = true
    }
  }
  if !changed {
    return Unchanged
  }
  let encoded = encode_text_index(kept) catch { _ => return Unreadable(hash) }
  Rewritten({
    old: hash,
    hash: sha256(encoded).unsafe_substring(start=0, end=32),
    data: encoded,
  })
}

///|
/// The manifest part entries of the selection, and the rewritten indexes whose
/// bytes the selection must store.
///
/// A text index the selection replaced or dropped is left out unless a kept
/// view still names it, so the selected pages do not carry the text of the
/// pages they no longer hold. A rewritten index whose hash already names a
/// kept part is not appended again: that part's stored bytes and metadata
/// already describe the same content, and replacing the bytes would leave the
/// metadata describing the wrong encoding.
fn page_select_entries(
  entries : Array[Json],
  views : Array[Json],
  rewrites : Array[PageSelectIndex],
  touched : Map[String, Bool],
) -> (Array[Json], Array[PageSelectIndex]) {
  let referenced : Map[String, Bool] = Map([])
  for view in views {
    if view is Object(fields) {
      match fields.get("textIndex") {
        Some(String(hash)) => referenced[hash] = true
        _ => ()
      }
    }
  }
  let kept : Array[Json] = []
  let present : Map[String, Bool] = Map([])
  for entry in entries {
    let hash = match entry {
      Object(fields) =>
        match fields.get("h") {
          Some(String(value)) => value
          _ => ""
        }
      _ => ""
    }
    if hash != "" && touched.contains(hash) && !referenced.contains(hash) {
      continue
    }
    if hash != "" {
      present[hash] = true
    }
    kept.push(entry)
  }
  let added : Array[PageSelectIndex] = []
  for index in rewrites {
    if present.contains(index.hash) {
      continue
    }
    present[index.hash] = true
    added.push(index)
    kept.push(
      Json::object({
        "h": Json::string(index.hash),
        "t": Json::string("idx"),
        "enc": Json::string("identity"),
        "len": Json::number(index.data.length().to_double()),
        "size": Json::number(index.data.length().to_double()),
        "off": Json::number(0.0),
      }),
    )
  }
  (kept, added)
}

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
  let stored : Map[String, Bytes] = Map([])
  for part in split.parts {
    stored[part.hash] = part.data
  }
  let parts = page_select_parts(root)
  let rewrites : Array[PageSelectIndex] = []
  let touched : Map[String, Bool] = Map([])
  let (filtered, added) = match root {
    Object(fields) => {
      let views = match fields.get("views") {
        Some(Array(values)) => values
        _ => []
      }
      let entries = match fields.get("parts") {
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
          let remap : Map[Int64, Int64] = Map([])
          let mut local_index = 0
          for page in source_pages {
            page_index += 1
            if selected.contains(page_index.to_int64()) {
              remap[local_index.to_int64()] = kept_pages.length().to_int64()
              kept_pages.push(page)
            }
            local_index += 1
          }
          view_fields["pages"] = Json::array(kept_pages)
          if !source_pages.is_empty() {
            let dropped = kept_pages.length() != source_pages.length()
            match page_select_text_index(view_fields, remap, dropped, parts, stored) {
              Rewritten(index) => {
                touched[index.old] = true
                rewrites.push(index)
                view_fields["textIndex"] = Json::string(index.hash)
              }
              Unreadable(hash) => {
                touched[hash] = true
                view_fields.remove("textIndex")
              }
              Unchanged => ()
            }
          }
          kept_views.push(Json::object(view_fields))
        }
      }
      fields["views"] = Json::array(kept_views)
      let (kept_entries, stored_rewrites) = page_select_entries(
        entries, kept_views, rewrites, touched,
      )
      fields["parts"] = Json::array(kept_entries)
      (Json::object(fields), stored_rewrites)
    }
    _ => raise BadFormat("manifest root is not an object")
  }
  for index in added {
    stored[index.hash] = index.data
  }
  let manifest = @utf8.encode(filtered.stringify())
  split_to_single(manifest, (hash, _) => {
    match stored.get(hash) {
      Some(value) => value
      None => raise BadFormat("missing selected part")
    }
  })
}
