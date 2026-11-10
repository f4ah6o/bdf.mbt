///|
test "select_pages keeps only the requested pages" {
  let writer = DocumentWriter::new()
  writer.add_view(
    Json::object({
      "id": Json::string("view"),
      "kind": Json::string("fixed"),
      "pages": Json::array([
        Json::object({
          "w": Json::number(100.0),
          "h": Json::number(200.0),
          "layers": Json::array([]),
        }),
        Json::object({
          "w": Json::number(300.0),
          "h": Json::number(400.0),
          "layers": Json::array([]),
        }),
      ]),
    }),
  )
  let selected = select_pages(writer.write_single(), [2L])
  let document = open_single(selected)
  assert_eq(document.manifest.views.length(), 1)
  assert_eq(document.manifest.views[0].pages.length(), 1)
  assert_eq(document.manifest.views[0].pages[0].width, 300.0)
}

///|
/// A two-page fixed view whose text index is the given runs.
fn page_select_runs_document(runs : Array[IndexRun]) -> Bytes raise {
  let writer = DocumentWriter::new()
  let hash = writer.add_part("idx", encode_text_index(runs))
  writer.add_view(
    Json::object({
      "id": Json::string("view"),
      "kind": Json::string("fixed"),
      "textIndex": Json::string(hash),
      "pages": Json::array([
        Json::object({
          "w": Json::number(100.0),
          "h": Json::number(200.0),
          "layers": Json::array([]),
        }),
        Json::object({
          "w": Json::number(300.0),
          "h": Json::number(400.0),
          "layers": Json::array([]),
        }),
      ]),
    }),
  )
  writer.write_single()
}

///|
/// A two-page fixed view whose text index names each page.
fn page_select_indexed_document(text~ : String = "") -> Bytes raise {
  let second = if text == "" { "Second page" } else { text }
  page_select_runs_document([
    { a: 0, b: 0, ordinal: 0, separator: 2, text: "First page" },
    { a: 1, b: 0, ordinal: 0, separator: 2, text: second },
  ])
}

///|
/// The runs of the only view's text index.
fn page_select_runs(bdf : Bytes) -> Array[IndexRun] raise {
  let document = open_single(bdf)
  let hash = document.manifest.views[0].text_index.unwrap()
  decode_text_index(document.part(hash))
}

///|
/// The text of every text index part of a document, joined: what search can
/// read from the file.
fn page_select_index_text(bdf : Bytes) -> String raise {
  let document = open_single(bdf)
  let text = StringBuilder()
  for part in document.manifest.parts {
    if part.kind != "idx" {
      continue
    }
    text.write_string(@utf8.decode_lossy(document.part(part.hash)))
  }
  text.to_string()
}

///|
test "select_pages keeps the text index of the selected page" {
  let selected = select_pages(page_select_indexed_document(), [2L])
  let document = open_single(selected)
  assert_eq(document.manifest.views[0].pages.length(), 1)
  let hash = document.manifest.views[0].text_index.unwrap()
  let runs = decode_text_index(document.part(hash))
  assert_eq(runs.length(), 1)
  assert_eq(runs[0].a, 0)
  assert_eq(runs[0].text, "Second page")
}

///|
test "select_pages renumbers the text index of a later page" {
  let selected = select_pages(page_select_indexed_document(), [1L, 2L])
  let document = open_single(selected)
  let hash = document.manifest.views[0].text_index.unwrap()
  let runs = decode_text_index(document.part(hash))
  assert_eq(runs.length(), 2)
  assert_eq((runs[0].a, runs[0].text), (0, "First page"))
  assert_eq((runs[1].a, runs[1].text), (1, "Second page"))
}

///|
test "select_pages leaves an unchanged text index alone" {
  let data = page_select_indexed_document()
  let before = open_single(data)
  let selected = select_pages(data, [1L, 2L])
  let after = open_single(selected)
  assert_eq(
    after.manifest.views[0].text_index,
    before.manifest.views[0].text_index,
  )
  assert_eq(after.manifest.parts.length(), before.manifest.parts.length())
}

///|
test "select_pages reads a compressed text index" {
  // A part of 512 bytes or more is stored as raw DEFLATE, so the selection has
  // to inflate the index before it can drop the first page's run.
  let long = "Second page " + "x".repeat(600)
  let selected = select_pages(page_select_indexed_document(text=long), [2L])
  let document = open_single(selected)
  let hash = document.manifest.views[0].text_index.unwrap()
  let runs = decode_text_index(document.part(hash))
  assert_eq(runs.length(), 1)
  assert_eq(runs[0].a, 0)
  assert_eq(runs[0].text, long)
}

///|
test "select_pages keeps the layer and run coordinates of the selected page" {
  // `b` and `ordinal` name the layer and the run inside the page, so a page
  // selection must carry them through unchanged: a search hit is resolved to a
  // rectangle by (a, b, ordinal), and a shifted `b` would point at another
  // layer or at nothing.
  let selected = select_pages(
    page_select_runs_document([
      { a: 0, b: 0, ordinal: 0, separator: 2, text: "First page" },
      { a: 1, b: 2, ordinal: 7, separator: 1, text: "Second page" },
    ]),
    [2L],
  )
  let runs = page_select_runs(selected)
  assert_eq(runs.length(), 1)
  assert_eq((runs[0].a, runs[0].b, runs[0].ordinal), (0, 2, 7))
  assert_eq((runs[0].separator, runs[0].text), (1, "Second page"))
}

///|
test "select_pages rejects runs of pages the view does not hold" {
  // A run whose page is outside the view cannot be remapped, so it is dropped
  // rather than left pointing at a page the selection removed.
  let selected = select_pages(
    page_select_runs_document([
      { a: 0, b: 0, ordinal: 0, separator: 2, text: "First page" },
      { a: 1, b: 0, ordinal: 0, separator: 2, text: "Second page" },
      { a: 5, b: 0, ordinal: 0, separator: 2, text: "Stray page" },
    ]),
    [1L],
  )
  let runs = page_select_runs(selected)
  assert_eq(runs.map(fn(run) { (run.a, run.text) }), [(0, "First page")])
}

///|
test "select_pages drops the text index of the pages it removed" {
  // The selected page must not carry the other pages' text in its search
  // index: the superseded index part is left out of the manifest, so no index
  // part still describes the removed page.
  let selected = select_pages(page_select_indexed_document(), [2L])
  let text = page_select_index_text(selected)
  assert_false(text.contains("First page"), msg=text)
  assert_true(text.contains("Second page"), msg=text)
}

///|
test "select_pages drops a text index it cannot rewrite" {
  // A part that is not a text index cannot be narrowed. The view loses the
  // reference so a reader rebuilds the index from the selected page's objects
  // instead of reading the removed pages' text.
  let writer = DocumentWriter::new()
  let hash = writer.add_part("idx", b"not a text index")
  writer.add_view(
    Json::object({
      "id": Json::string("view"),
      "kind": Json::string("fixed"),
      "textIndex": Json::string(hash),
      "pages": Json::array([
        Json::object({
          "w": Json::number(100.0),
          "h": Json::number(200.0),
          "layers": Json::array([]),
        }),
        Json::object({
          "w": Json::number(300.0),
          "h": Json::number(400.0),
          "layers": Json::array([]),
        }),
      ]),
    }),
  )
  let selected = select_pages(writer.write_single(), [2L])
  let document = open_single(selected)
  assert_eq(document.manifest.views[0].text_index, None)
  assert_eq(document.manifest.parts.length(), 0)
}

///|
test "select_pages leaves a sheet text index alone" {
  // A sheet view indexes tiles, not pages: `a` and `b` are tile coordinates,
  // so a page selection must not drop its runs.
  let writer = DocumentWriter::new()
  let index = encode_text_index([
    { a: 0, b: 0, ordinal: 0, separator: 2, text: "A1" },
    { a: 1, b: 0, ordinal: 0, separator: 2, text: "B1" },
  ])
  let hash = writer.add_part("idx", index)
  writer.add_view(
    Json::object({
      "id": Json::string("sheet"),
      "kind": Json::string("sheet"),
      "textIndex": Json::string(hash),
      "tiles": Json::object({
        "0,0": Json::string("0123456789abcdef0123456789abcdef"),
        "1,0": Json::string("0123456789abcdef0123456789abcdef"),
      }),
    }),
  )
  let selected = select_pages(writer.write_single(), [1L])
  let document = open_single(selected)
  assert_eq(document.manifest.views[0].text_index, Some(hash))
  assert_eq(decode_text_index(document.part(hash)).length(), 2)
}

///|
/// A two-view document whose second view holds the first view's second page
/// alone. The second view's index is the first view's index with the first
/// page's run removed, so selecting the first view's second page and the whole
/// second view rewrites the first view's index to exactly the second view's
/// index and reuses its part.
fn page_select_collision_document(
  first_text : String,
  second_text : String,
  b : Int32,
  ordinal : Int32,
) -> (Bytes, String, String) raise {
  let first = encode_text_index([
    { a: 0, b: 0, ordinal: 0, separator: 2, text: first_text },
    { a: 1, b, ordinal, separator: 2, text: second_text },
  ])
  let second = encode_text_index([
    { a: 0, b, ordinal, separator: 2, text: second_text },
  ])
  let writer = DocumentWriter::new()
  let first_hash = writer.add_part("idx", first)
  let second_hash = writer.add_part("idx", second)
  writer.add_view(
    Json::object({
      "id": Json::string("first"),
      "kind": Json::string("fixed"),
      "textIndex": Json::string(first_hash),
      "pages": Json::array([
        Json::object({
          "w": Json::number(100.0),
          "h": Json::number(200.0),
          "layers": Json::array([]),
        }),
        Json::object({
          "w": Json::number(300.0),
          "h": Json::number(400.0),
          "layers": Json::array([]),
        }),
      ]),
    }),
  )
  writer.add_view(
    Json::object({
      "id": Json::string("second"),
      "kind": Json::string("fixed"),
      "textIndex": Json::string(second_hash),
      "pages": Json::array([
        Json::object({
          "w": Json::number(500.0),
          "h": Json::number(600.0),
          "layers": Json::array([]),
        }),
      ]),
    }),
  )
  (writer.write_single(), first_hash, second_hash)
}

///|
/// The manifest part with the given hash.
fn page_select_part(bdf : Bytes, hash : String) -> Part raise {
  let document = open_single(bdf)
  for part in document.manifest.parts {
    if part.hash == hash {
      return part
    }
  }
  raise BadFormat("missing part")
}

///|
/// The search index of the given view.
fn page_select_view_search(bdf : Bytes, view : Int) -> TextSearch raise {
  let document = open_single(bdf)
  let hash = document.manifest.views[view].text_index.unwrap()
  TextSearch::new(decode_text_index(document.part(hash)))
}

///|
test "select_pages reuses a compressed part without corrupting it" {
  // The rewritten index of the first view is byte-identical to the second
  // view's index, so it names the second view's part. That part is stored as
  // raw DEFLATE: reusing its metadata while replacing its bytes with the
  // uncompressed index would make the selection unreadable.
  let long = "Second page " + "x".repeat(600)
  let (data, first_hash, second_hash) = page_select_collision_document(
    "First page", long, 2, 7,
  )
  let before = open_single(data)
  assert_eq(before.manifest.parts.length(), 2)
  for part in before.manifest.parts {
    assert_eq(part.encoding, "deflate-raw")
  }
  assert_true(first_hash != second_hash)
  let before_part = page_select_part(data, second_hash)
  assert_true(before_part.length < before_part.size)
  let selected = select_pages(data, [2L, 3L])
  let after = open_single(selected)
  assert_eq(after.manifest.views.length(), 2)
  assert_eq(after.manifest.views[0].pages.length(), 1)
  assert_eq(after.manifest.views[1].pages.length(), 1)
  assert_eq(after.manifest.views[0].pages[0].width, 300.0)
  assert_eq(after.manifest.views[0].pages[0].height, 400.0)
  assert_eq(after.manifest.views[1].pages[0].width, 500.0)
  assert_eq(after.manifest.views[1].pages[0].height, 600.0)
  // Both views name the reused part, and the superseded index is gone.
  assert_eq(after.manifest.views[0].text_index, Some(second_hash))
  assert_eq(after.manifest.views[1].text_index, Some(second_hash))
  assert_eq(after.manifest.parts.length(), 1)
  let after_part = page_select_part(selected, second_hash)
  assert_eq(after_part.encoding, before_part.encoding)
  assert_eq(after_part.length, before_part.length)
  assert_eq(after_part.size, before_part.size)
  // The reused part still decodes to the selected page's run, with its layer
  // and run coordinates preserved and its page renumbered.
  let runs = decode_text_index(after.part(second_hash))
  assert_eq(runs.length(), 1)
  assert_eq((runs[0].a, runs[0].b, runs[0].ordinal), (0, 2, 7))
  assert_eq(runs[0].text, long)
  // Search reads the selected page's text in both views and none of the
  // removed page's text.
  for view in 0..<2 {
    let search = page_select_view_search(selected, view)
    assert_eq(search.search("Second page").length(), 1)
    assert_eq(search.search("First page").length(), 0)
  }
  let text = page_select_index_text(selected)
  assert_false(text.contains("First page"), msg=text)
  assert_true(text.contains("Second page"), msg=text)
}

///|
test "select_pages reuses an identity part without corrupting it" {
  // The inverse of the compressed case: the reused part is stored as identity,
  // so its bytes and metadata must stay identity while the first view's longer
  // index is inflated and dropped.
  let long = "First page " + "y".repeat(600)
  let (data, first_hash, second_hash) = page_select_collision_document(
    long, "Second page", 2, 7,
  )
  let before = open_single(data)
  assert_eq(before.manifest.parts.length(), 2)
  assert_eq(page_select_part(data, first_hash).encoding, "deflate-raw")
  assert_eq(page_select_part(data, second_hash).encoding, "identity")
  let selected = select_pages(data, [2L, 3L])
  let after = open_single(selected)
  assert_eq(after.manifest.views.length(), 2)
  assert_eq(after.manifest.views[0].pages.length(), 1)
  assert_eq(after.manifest.views[1].pages.length(), 1)
  assert_eq(after.manifest.views[0].text_index, Some(second_hash))
  assert_eq(after.manifest.views[1].text_index, Some(second_hash))
  assert_eq(after.manifest.parts.length(), 1)
  let after_part = page_select_part(selected, second_hash)
  assert_eq(after_part.encoding, "identity")
  let runs = decode_text_index(after.part(second_hash))
  assert_eq(runs.length(), 1)
  assert_eq((runs[0].a, runs[0].b, runs[0].ordinal), (0, 2, 7))
  assert_eq(runs[0].text, "Second page")
  for view in 0..<2 {
    let search = page_select_view_search(selected, view)
    assert_eq(search.search("Second page").length(), 1)
    assert_eq(search.search("First page").length(), 0)
  }
  let text = page_select_index_text(selected)
  assert_false(text.contains("First page"), msg=text)
  assert_true(text.contains("Second page"), msg=text)
}
