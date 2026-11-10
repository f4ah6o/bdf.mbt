///|
// Page selection: the page view keeps the pages a `pages` option names, in
// document order, and numbers them from one; the scroll view keeps the whole
// document. The documents are built as stored ZIP packages, so a test shows
// the WordprocessingML it uses.

///|
fn docx_pages_fixture() -> Bytes raise {
  let blocks = "<w:p><w:r><w:t>One</w:t></w:r></w:p>" +
    "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>" +
    "<w:p><w:r><w:t>Two</w:t></w:r></w:p>" +
    "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>" +
    "<w:p><w:r><w:t>Three</w:t></w:r></w:p>"
  docx_test_docx(blocks, DOCX_TEST_SECTION, [])
}

///|
fn docx_pages_manifest(result : DocxResult) -> @core.Manifest raise {
  let split = @core.single_to_split(result.bdf)
  @core.parse_manifest(@utf8.decode(split.manifest))
}

///|
fn docx_pages_view(result : DocxResult, view_id : String) -> @core.View raise {
  for view in docx_pages_manifest(result).views {
    if view.id == view_id {
      return view
    }
  }
  fail("no view " + view_id)
}

///|
fn docx_pages_texts(
  result : DocxResult,
  view_id : String,
) -> Array[String] raise {
  let texts : Array[String] = []
  for index, _ in docx_pages_view(result, view_id).pages {
    texts.push(
      docx_test_commands_text(
        docx_test_page_commands(result, view_id, index, "body"),
      ),
    )
  }
  texts
}

///|
fn docx_pages_numbers(
  result : DocxResult,
  view_id : String,
) -> Array[Int32] raise {
  let split = @core.single_to_split(result.bdf)
  let root = @json.parse(@utf8.decode(split.manifest))
  let numbers : Array[Int32] = []
  let views = match root.value("views") {
    Some(Json::Array(values)) => values
    _ => []
  }
  for view in views {
    let id = match view.value("id") {
      Some(Json::String(value)) => value
      _ => ""
    }
    if id != view_id {
      continue
    }
    let pages = match view.value("pages") {
      Some(Json::Array(values)) => values
      _ => []
    }
    for page in pages {
      numbers.push(
        match page.value("page") {
          Some(Json::Number(value, ..)) => value.to_int()
          _ => 0
        },
      )
    }
  }
  numbers
}

///|
fn docx_pages_links(
  result : DocxResult,
  view_id : String,
) -> Array[String] raise {
  let urls : Array[String] = []
  for index, _ in docx_pages_view(result, view_id).pages {
    for command in docx_test_page_commands(result, view_id, index, "body") {
      match command {
        @render.Link(_, _, _, _, url) => urls.push(url)
        _ => ()
      }
    }
  }
  urls
}

///|
test "DOCX page selection keeps the requested pages" {
  let data = docx_pages_fixture()
  let all = convert(data)
  assert_eq(all.pages, 3)
  assert_eq(docx_pages_texts(all, "pages"), ["One", "Two", "Three"])
  let one = convert(data, pages="2")
  assert_eq(one.pages, 1)
  assert_eq(docx_pages_texts(one, "pages"), ["Two"])
  assert_eq(docx_pages_numbers(one, "pages"), [1])
  assert_true(one.summary.has_prefix("1 page(s), "), msg=one.summary)
}

///|
test "DOCX page selection keeps document order" {
  // Upstream's page view keeps the selected pages in document order, each
  // once, however the selection names them.
  let result = convert(docx_pages_fixture(), pages="3,1,1")
  assert_eq(result.pages, 2)
  assert_eq(docx_pages_texts(result, "pages"), ["One", "Three"])
  assert_eq(docx_pages_numbers(result, "pages"), [1, 2])
}

///|
test "DOCX page selection accepts open ranges" {
  let result = convert(docx_pages_fixture(), pages="2-")
  assert_eq(result.pages, 2)
  assert_eq(docx_pages_texts(result, "pages"), ["Two", "Three"])
  let from_start = convert(docx_pages_fixture(), pages="-2")
  assert_eq(docx_pages_texts(from_start, "pages"), ["One", "Two"])
}

///|
test "DOCX page selection skips pages past the end" {
  let result = convert(docx_pages_fixture(), pages="1,9")
  assert_eq(result.pages, 1)
  assert_eq(docx_pages_texts(result, "pages"), ["One"])
  let none = convert(docx_pages_fixture(), pages="9")
  assert_eq(none.pages, 0)
  assert_eq(docx_pages_texts(none, "pages"), [])
  assert_true(none.summary.has_prefix("0 page(s), "), msg=none.summary)
}

///|
test "DOCX page selection rejects invalid specs" {
  let data = docx_pages_fixture()
  for
    (spec, message) in [
      ("0", "bad page \"0\" in \"0\": pages are numbered from 1"),
      ("1-x", "bad page \"x\" in \"1-x\": pages are numbered from 1"),
      ("5-3", "bad page range \"5-3\": it ends before it starts"),
    ] {
    let actual = try {
      ignore(convert(data, pages=spec))
      ""
    } catch {
      DocxInvalid(detail) => detail
      _ => "unexpected error"
    }
    assert_eq(actual, message)
  }
}

///|
test "DOCX page selection leaves the scroll view whole" {
  let data = docx_pages_fixture()
  let all = docx_pages_view(convert(data), "scroll")
  let selected = convert(data, pages="2")
  let manifest = docx_pages_manifest(selected)
  assert_eq(manifest.views.length(), 2)
  assert_eq(manifest.views[0].pages.length(), 1)
  assert_eq(manifest.views[1].pages.length(), all.pages.length())
  let scroll_only = convert(data, pages="2", views="scroll")
  assert_eq(scroll_only.pages, 0)
  assert_eq(docx_pages_manifest(scroll_only).views.length(), 1)
  assert_eq(
    docx_pages_manifest(scroll_only).views[0].pages.length(),
    all.pages.length(),
  )
}

///|
test "DOCX page selection renumbers bookmark links" {
  let blocks = "<w:p><w:hyperlink w:anchor=\"Target\"><w:r><w:t>GO</w:t></w:r></w:hyperlink></w:p>" +
    "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>" +
    "<w:p><w:r><w:t>Two</w:t></w:r></w:p>" +
    "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>" +
    "<w:p><w:bookmarkStart w:id=\"0\" w:name=\"Target\"/><w:r><w:t>Three</w:t></w:r>" +
    "<w:bookmarkEnd w:id=\"0\"/></w:p>"
  let data = docx_test_docx(blocks, DOCX_TEST_SECTION, [])
  assert_eq(docx_pages_links(convert(data), "pages"), ["#page=3"])
  assert_eq(docx_pages_links(convert(data, pages="1,3"), "pages"), ["#page=2"])
  // The page the bookmark is on is left out, so the link has no target.
  assert_eq(docx_pages_links(convert(data, pages="1"), "pages"), [])
}

///|
test "DOCX page selection resolves links by place, not by page number" {
  // A section that starts its numbering at 5: the bookmark on the third page
  // shows page 7, but a link to it names the third page of the view.
  let section = "<w:sectPr><w:pgSz w:w=\"12240\" w:h=\"15840\"/>" +
    "<w:pgMar w:top=\"1440\" w:right=\"1440\" w:bottom=\"1440\" w:left=\"1440\"/>" +
    "<w:pgNumType w:start=\"5\"/></w:sectPr>"
  let blocks = "<w:p><w:hyperlink w:anchor=\"Target\"><w:r><w:t>GO</w:t></w:r></w:hyperlink></w:p>" +
    "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>" +
    "<w:p><w:r><w:t>Two</w:t></w:r></w:p>" +
    "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>" +
    "<w:p><w:bookmarkStart w:id=\"0\" w:name=\"Target\"/><w:r><w:t>Three</w:t></w:r>" +
    "<w:bookmarkEnd w:id=\"0\"/></w:p>"
  let data = docx_test_docx(blocks, section, [])
  assert_eq(docx_pages_links(convert(data), "pages"), ["#page=3"])
  assert_eq(docx_pages_links(convert(data, pages="1,3"), "pages"), ["#page=2"])
}

///|
test "DOCX page selection keeps PAGEREF numbers" {
  let blocks = "<w:p><w:r><w:fldChar w:fldCharType=\"begin\"/></w:r>" +
    "<w:r><w:instrText xml:space=\"preserve\"> PAGEREF Target </w:instrText></w:r>" +
    "<w:r><w:fldChar w:fldCharType=\"separate\"/></w:r>" +
    "<w:r><w:t>9</w:t></w:r>" +
    "<w:r><w:fldChar w:fldCharType=\"end\"/></w:r></w:p>" +
    "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>" +
    "<w:p><w:r><w:t>Two</w:t></w:r></w:p>" +
    "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>" +
    "<w:p><w:bookmarkStart w:id=\"0\" w:name=\"Target\"/><w:r><w:t>Three</w:t></w:r>" +
    "<w:bookmarkEnd w:id=\"0\"/></w:p>"
  let data = docx_test_docx(blocks, DOCX_TEST_SECTION, [])
  // PAGEREF prints the page number the document shows, not the page's place
  // in the selected view.
  assert_eq(docx_pages_texts(convert(data, pages="1,3"), "pages")[0], "3")
  assert_eq(docx_pages_texts(convert(data), "pages")[0], "3")
}

///|
test "DOCX page selection renumbers the text index" {
  let data = docx_pages_fixture()
  let result = convert(data, pages="3,1")
  let document = @core.open_single(result.bdf)
  let view = document.manifest.views[0]
  let hash = match view.text_index {
    Some(value) => value
    None => ""
  }
  assert_true(hash != "", msg="DOCX text index")
  let runs = @core.decode_text_index(document.part(hash))
  let mut first = ""
  let mut second = ""
  for run in runs {
    if run.a == 0 {
      first += run.text
    } else if run.a == 1 {
      second += run.text
    }
  }
  assert_eq(first, "One")
  assert_eq(second, "Three")
}

///|
test "DOCX page selection defaults to every page" {
  let data = docx_pages_fixture()
  let plain = convert(data)
  let empty = convert(data, pages="")
  assert_eq(empty.pages, plain.pages)
  assert_eq(docx_pages_texts(empty, "pages"), docx_pages_texts(plain, "pages"))
  assert_eq(docx_pages_numbers(empty, "pages"), [1, 2, 3])
}

///|
test "DOCX page selection keeps the page fields of the document" {
  let header = docx_test_header(
    "<w:p><w:r><w:t>Page </w:t></w:r>" +
    "<w:r><w:fldChar w:fldCharType=\"begin\"/></w:r>" +
    "<w:r><w:instrText> PAGE </w:instrText></w:r>" +
    "<w:r><w:fldChar w:fldCharType=\"separate\"/></w:r>" +
    "<w:r><w:t>9</w:t></w:r>" +
    "<w:r><w:fldChar w:fldCharType=\"end\"/></w:r>" +
    "<w:r><w:t> of </w:t></w:r>" +
    "<w:fldSimple w:instr=\" NUMPAGES \"><w:r><w:t>9</w:t></w:r></w:fldSimple></w:p>",
  )
  let body = "<w:p><w:r><w:t>One</w:t></w:r></w:p>" +
    "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>" +
    "<w:p><w:r><w:t>Two</w:t></w:r></w:p>" +
    "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>" +
    "<w:p><w:r><w:t>Three</w:t></w:r></w:p>"
  let result = convert(docx_test_header_document(header, body, []), pages="2")
  assert_eq(result.pages, 1)
  // PAGE and NUMPAGES keep the document's numbering, not the view's.
  assert_eq(
    docx_test_commands_text(
      docx_test_page_commands(result, "pages", 0, "header"),
    ),
    "Page 2 of 3",
  )
}

///|
test "DOCX page selection works with the page view alone" {
  let result = convert(docx_pages_fixture(), pages="3", views="pages")
  assert_eq(result.pages, 1)
  let manifest = docx_pages_manifest(result)
  assert_eq(manifest.views.length(), 1)
  assert_eq(manifest.views[0].id, "pages")
  assert_eq(docx_pages_texts(result, "pages"), ["Three"])
}
