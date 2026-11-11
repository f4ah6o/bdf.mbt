///|
// The worker's shared page-selection and stream contract: `native_select_pages`,
// `native_stream_multipage` and the `page`/`finish`/`close` dispatch of the
// native converter state.
//
// Every fixture is a synthetic two-page BDF built in memory with
// `DocumentWriter`, so the tests read no sample file and name no converter
// format.

///|
/// A request shaped like the one the worker receives.
extern "js" fn pages_test_request(
  kind : String,
  options_json : String,
  data : Bytes,
) -> ConverterRequest =
  #|(kind,json,data) => ({ id: 1, type: kind, data, options: JSON.parse(json) })

///|
/// A stream request: `finish`, `page` and `close` name the stream on the
/// request itself, not in the options.
extern "js" fn pages_test_stream_request(
  kind : String,
  stream : Int,
) -> ConverterRequest =
  #|(kind,stream) => ({ id: 1, type: kind, stream: Number(stream), options: {} })

///|
/// A stream page request: the stream and the page index are separate fields.
extern "js" fn pages_test_page_request(
  stream : Int,
  index : Int,
) -> ConverterRequest =
  #|(stream,index) => ({ id: 1, type: 'page', stream: Number(stream), index: Number(index), options: {} })

///|
/// Capture what the worker posts, in place of the real `self`.
extern "js" fn pages_test_capture_start() -> Unit =
  #|() => { globalThis.__pagesPosted = []; globalThis.self = { postMessage: (m) => { globalThis.__pagesPosted.push(m); } }; }

///|
/// The posted messages, without the converted bytes. `warningsArray` records
/// whether `warnings` crossed the Worker boundary as a real JavaScript array.
extern "js" fn pages_test_capture_take() -> String =
  #|() => JSON.stringify((globalThis.__pagesPosted ?? []).map(m => ({ ok: m.ok, format: m.result?.format, summary: m.result?.summary, pages: m.result?.pages, stream: m.result?.stream, warnings: m.result?.warnings, warningsArray: Array.isArray(m.result?.warnings), error: m.error, code: m.code })))

///|
/// The converted bytes of the first message the worker posted.
extern "js" fn pages_test_capture_bdf() -> Bytes =
  #|() => { const m = (globalThis.__pagesPosted ?? [])[0]; return m?.result?.bdf ?? new Uint8Array(0); }

///|
/// The converted bytes of the last message the worker posted.
extern "js" fn pages_test_capture_last_bdf() -> Bytes =
  #|() => { const m = (globalThis.__pagesPosted ?? []).at(-1); return m?.result?.bdf ?? new Uint8Array(0); }

///|
/// Whether the last message the worker posted carried a null result: the
/// `close` reply.
extern "js" fn pages_test_capture_null_result() -> Bool =
  #|() => { const m = (globalThis.__pagesPosted ?? []).at(-1); return m?.result === null }

///|
/// Forget the messages posted so far, so the next reply can be read alone.
extern "js" fn pages_test_capture_clear() -> Unit =
  #|() => { globalThis.__pagesPosted = []; }

///|
extern "js" fn pages_test_capture_stop() -> Unit =
  #|() => { delete globalThis.self; delete globalThis.__pagesPosted; }

///|
/// A two-page fixed view whose text index names each page.
fn pages_test_document() -> Bytes raise {
  let writer = @core.DocumentWriter::new()
  let hash = writer.add_part(
    "idx",
    @core.encode_text_index([
      { a: 0, b: 0, ordinal: 0, separator: 2, text: "First page" },
      { a: 1, b: 0, ordinal: 0, separator: 2, text: "Second page" },
    ]),
  )
  writer.add_view(
    Json::object({
      "id": Json::string("pages"),
      "kind": Json::string("fixed"),
      "textIndex": Json::string(hash),
      "pages": Json::array([
        Json::object({
          "w": Json::number(400.0),
          "h": Json::number(300.0),
          "layers": Json::array([]),
        }),
        Json::object({
          "w": Json::number(300.0),
          "h": Json::number(200.0),
          "layers": Json::array([]),
        }),
      ]),
    }),
  )
  writer.write_single()
}

///|
/// The page sizes of the page view, in points.
fn pages_test_page_sizes(bdf : Bytes) -> Array[(Int, Int)] raise {
  let document = @core.open_single(bdf)
  let sizes : Array[(Int, Int)] = []
  for view in document.manifest.views {
    if view.id != "pages" {
      continue
    }
    for page in view.pages {
      sizes.push((page.width.round().to_int(), page.height.round().to_int()))
    }
  }
  sizes
}

///|
/// The text the page view of a document holds.
fn pages_test_page_text(bdf : Bytes) -> String raise {
  let document = @core.open_single(bdf)
  let mut text = ""
  for view in document.manifest.views {
    if view.id != "pages" {
      continue
    }
    match view.text_index {
      Some(hash) => {
        for run in @core.decode_text_index(document.part(hash)) {
          text = text + run.text
        }
      }
      None => ()
    }
  }
  text
}

///|
/// The text of every text index part of a document, joined: what search can
/// read from the file.
fn pages_test_index_text(bdf : Bytes) -> String raise {
  let document = @core.open_single(bdf)
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
fn pages_test_state() -> NativeConverterState {
  { ready: true, streams: Map([]), next_stream: 0 }
}

///|
/// Open a stream over `bdf` the way a converter does after selecting pages.
fn pages_test_open(
  state : NativeConverterState,
  bdf : Bytes,
  pages : Int32,
  warnings : Array[String],
) -> Unit {
  native_stream_multipage(
    state,
    pages_test_request("open", "{}", b""),
    bdf,
    "synthetic",
    "2 page(s), " + warnings.length().to_string() + " warning(s)",
    warnings,
    pages,
    true,
  )
}

///|
test "native_selected_page_count counts distinct in-range pages" {
  assert_eq(native_selected_page_count([1L, 1L, 2L, 2L], 2), 2)
  assert_eq(native_selected_page_count([1L, 2L, 3L], 2), 2)
  assert_eq(native_selected_page_count([3L], 2), 0)
  assert_eq(native_selected_page_count([], 2), 0)
  assert_eq(native_selected_page_count([1L], 0), 0)
}

///|
test "native_select_pages keeps the selected page and reports its count" {
  let (bdf, pages) = native_select_pages(
    pages_test_request("convert", "{\"pages\":\"2\"}", b""),
    pages_test_document(),
    2,
  )
  assert_eq(pages, 1)
  assert_eq(pages_test_page_sizes(bdf), [(300, 200)])
  assert_eq(pages_test_page_text(bdf), "Second page")
  assert_false(pages_test_index_text(bdf).contains("First page"))
}

///|
test "native_select_pages reports the deduplicated page count" {
  let (bdf, pages) = native_select_pages(
    pages_test_request("convert", "{\"pages\":\"1,1,2,2\"}", b""),
    pages_test_document(),
    2,
  )
  assert_eq(pages, 2)
  assert_eq(pages_test_page_sizes(bdf), [(400, 300), (300, 200)])
  assert_eq(pages_test_page_text(bdf), "First pageSecond page")
}

///|
test "native_select_pages keeps document order for a reversed selection" {
  let (bdf, pages) = native_select_pages(
    pages_test_request("convert", "{\"pages\":\"2,1\"}", b""),
    pages_test_document(),
    2,
  )
  assert_eq(pages, 2)
  assert_eq(pages_test_page_sizes(bdf), [(400, 300), (300, 200)])
  assert_eq(pages_test_page_text(bdf), "First pageSecond page")
}

///|
test "native_select_pages reports an out-of-range selection as zero pages" {
  let (bdf, pages) = native_select_pages(
    pages_test_request("convert", "{\"pages\":\"5\"}", b""),
    pages_test_document(),
    2,
  )
  assert_eq(pages, 0)
  assert_eq(pages_test_page_sizes(bdf), [])
  assert_eq(pages_test_page_text(bdf), "")
  let index = pages_test_index_text(bdf)
  assert_false(index.contains("First page"), msg=index)
  assert_false(index.contains("Second page"), msg=index)
}

///|
test "native_select_pages leaves the document alone without a selection" {
  let data = pages_test_document()
  let (bdf, pages) = native_select_pages(
    pages_test_request("convert", "{}", b""),
    data,
    2,
  )
  assert_eq(pages, 2)
  assert_eq(bdf.length(), data.length())
  assert_eq(pages_test_page_sizes(bdf), [(400, 300), (300, 200)])
}

///|
test "native_select_pages leaves the document alone for an invalid selection" {
  let data = pages_test_document()
  let (bdf, pages) = native_select_pages(
    pages_test_request("convert", "{\"pages\":\"bogus\"}", b""),
    data,
    2,
  )
  assert_eq(pages, 2)
  assert_eq(bdf.length(), data.length())
}

///|
test "native_select_pages counts only the pages that exist" {
  let (bdf, pages) = native_select_pages(
    pages_test_request("convert", "{\"pages\":\"1-5\"}", b""),
    pages_test_document(),
    2,
  )
  assert_eq(pages, 2)
  assert_eq(pages_test_page_sizes(bdf), [(400, 300), (300, 200)])
}

///|
test "native_select_pages leaves a zero-page input alone" {
  let data = pages_test_document()
  let (bdf, pages) = native_select_pages(
    pages_test_request("convert", "{\"pages\":\"1\"}", b""),
    data,
    0,
  )
  assert_eq(pages, 0)
  assert_eq(bdf.length(), data.length())
}

///|
test "native_stream_multipage opens a stream for the selected document" {
  let state = pages_test_state()
  let (bdf, pages) = native_select_pages(
    pages_test_request("open", "{\"pages\":\"2\"}", b""),
    pages_test_document(),
    2,
  )
  pages_test_capture_start()
  native_stream_multipage(
    state,
    pages_test_request("open", "{\"pages\":\"2\"}", b""),
    bdf,
    "synthetic",
    "1 page(s), 1 warning(s)",
    ["first warning"],
    pages,
    true,
  )
  let posted = pages_test_capture_take()
  let opened = pages_test_capture_bdf()
  pages_test_capture_stop()
  assert_true(posted.contains("\"ok\":true"), msg=posted)
  assert_true(posted.contains("\"pages\":1"), msg=posted)
  assert_true(posted.contains("\"stream\":0"), msg=posted)
  assert_true(posted.contains("\"warnings\":[\"first warning\"]"), msg=posted)
  assert_true(posted.contains("\"warningsArray\":true"), msg=posted)
  assert_eq(state.next_stream, 1)
  assert_eq(state.streams.length(), 1)
  assert_eq(pages_test_page_sizes(opened), [(300, 200)])
  assert_eq(pages_test_page_text(opened), "Second page")
}

///|
test "native_stream_multipage reports an empty selection as zero pages and no stream" {
  let state = pages_test_state()
  let (bdf, pages) = native_select_pages(
    pages_test_request("open", "{\"pages\":\"5\"}", b""),
    pages_test_document(),
    2,
  )
  pages_test_capture_start()
  native_stream_multipage(
    state,
    pages_test_request("open", "{\"pages\":\"5\"}", b""),
    bdf,
    "synthetic",
    "0 page(s), 0 warning(s)",
    [],
    pages,
    true,
  )
  let posted = pages_test_capture_take()
  pages_test_capture_stop()
  assert_true(posted.contains("\"ok\":true"), msg=posted)
  assert_true(posted.contains("\"pages\":0"), msg=posted)
  assert_false(posted.contains("\"stream\":"), msg=posted)
  assert_eq(state.next_stream, 0)
  assert_eq(state.streams.length(), 0)
}

///|
test "native_stream_multipage replies without a stream when not opened" {
  let state = pages_test_state()
  pages_test_capture_start()
  native_stream_multipage(
    state,
    pages_test_request("convert", "{}", b""),
    pages_test_document(),
    "synthetic",
    "2 page(s), 0 warning(s)",
    [],
    2,
    false,
  )
  let posted = pages_test_capture_take()
  pages_test_capture_stop()
  assert_true(posted.contains("\"ok\":true"), msg=posted)
  assert_false(posted.contains("\"pages\":"), msg=posted)
  assert_false(posted.contains("\"stream\":"), msg=posted)
  assert_eq(state.next_stream, 0)
  assert_eq(state.streams.length(), 0)
}

///|
test "native_stream_multipage allocates a new stream for each open" {
  let state = pages_test_state()
  let data = pages_test_document()
  pages_test_capture_start()
  pages_test_open(state, data, 2, [])
  pages_test_open(state, data, 2, [])
  let posted = pages_test_capture_take()
  pages_test_capture_stop()
  assert_true(posted.contains("\"stream\":0"), msg=posted)
  assert_true(posted.contains("\"stream\":1"), msg=posted)
  assert_eq(state.next_stream, 2)
  assert_eq(state.streams.length(), 2)
}

///|
async test "the worker streams one page at a time with its own index" {
  let state = pages_test_state()
  pages_test_capture_start()
  pages_test_open(state, pages_test_document(), 2, [])
  pages_test_capture_clear()
  state.dispatch(pages_test_page_request(0, 0))
  let firstSizes = pages_test_page_sizes(pages_test_capture_last_bdf())
  let firstText = pages_test_page_text(pages_test_capture_last_bdf())
  let firstIndex = pages_test_index_text(pages_test_capture_last_bdf())
  pages_test_capture_clear()
  state.dispatch(pages_test_page_request(0, 1))
  let secondSizes = pages_test_page_sizes(pages_test_capture_last_bdf())
  let secondText = pages_test_page_text(pages_test_capture_last_bdf())
  let secondIndex = pages_test_index_text(pages_test_capture_last_bdf())
  pages_test_capture_stop()
  assert_eq(firstSizes, [(400, 300)])
  assert_eq(firstText, "First page")
  assert_false(firstIndex.contains("Second page"), msg=firstIndex)
  assert_eq(secondSizes, [(300, 200)])
  assert_eq(secondText, "Second page")
  assert_false(secondIndex.contains("First page"), msg=secondIndex)
}

///|
async test "the worker reports the selected page count on open" {
  let state = pages_test_state()
  let (bdf, pages) = native_select_pages(
    pages_test_request("open", "{\"pages\":\"2\"}", b""),
    pages_test_document(),
    2,
  )
  pages_test_capture_start()
  native_stream_multipage(
    state,
    pages_test_request("open", "{\"pages\":\"2\"}", b""),
    bdf,
    "synthetic",
    "1 page(s), 0 warning(s)",
    [],
    pages,
    true,
  )
  let opened = pages_test_capture_take()
  let openedSizes = pages_test_page_sizes(pages_test_capture_bdf())
  pages_test_capture_clear()
  state.dispatch(pages_test_page_request(0, 0))
  let pageSizes = pages_test_page_sizes(pages_test_capture_last_bdf())
  let pageText = pages_test_page_text(pages_test_capture_last_bdf())
  pages_test_capture_stop()
  assert_true(opened.contains("\"pages\":1"), msg=opened)
  assert_true(opened.contains("\"stream\":0"), msg=opened)
  assert_eq(openedSizes, [(300, 200)])
  assert_eq(pageSizes, [(300, 200)])
  assert_eq(pageText, "Second page")
}

///|
async test "the worker reports an out-of-range selection as zero pages and no stream" {
  let state = pages_test_state()
  let (bdf, pages) = native_select_pages(
    pages_test_request("open", "{\"pages\":\"5\"}", b""),
    pages_test_document(),
    2,
  )
  pages_test_capture_start()
  native_stream_multipage(
    state,
    pages_test_request("open", "{\"pages\":\"5\"}", b""),
    bdf,
    "synthetic",
    "0 page(s), 0 warning(s)",
    [],
    pages,
    true,
  )
  let opened = pages_test_capture_take()
  let sizes = pages_test_page_sizes(pages_test_capture_bdf())
  pages_test_capture_stop()
  assert_true(opened.contains("\"ok\":true"), msg=opened)
  assert_true(opened.contains("\"pages\":0"), msg=opened)
  assert_false(opened.contains("\"stream\":"), msg=opened)
  assert_eq(sizes, [])
  assert_eq(state.streams.length(), 0)
}

///|
async test "the worker finishes a stream repeatedly" {
  let state = pages_test_state()
  pages_test_capture_start()
  pages_test_open(state, pages_test_document(), 2, ["first warning"])
  pages_test_capture_clear()
  state.dispatch(pages_test_stream_request("finish", 0))
  let first = pages_test_capture_take()
  let firstSizes = pages_test_page_sizes(pages_test_capture_last_bdf())
  pages_test_capture_clear()
  state.dispatch(pages_test_stream_request("finish", 0))
  let second = pages_test_capture_take()
  let secondSizes = pages_test_page_sizes(pages_test_capture_last_bdf())
  pages_test_capture_stop()
  assert_true(first.contains("\"ok\":true"), msg=first)
  assert_true(first.contains("\"format\":\"synthetic\""), msg=first)
  assert_true(first.contains("\"summary\":\"2 page(s), 1 warning(s)\""), msg=first)
  assert_true(first.contains("\"warnings\":[\"first warning\"]"), msg=first)
  assert_eq(firstSizes, [(400, 300), (300, 200)])
  assert_true(second.contains("\"ok\":true"), msg=second)
  assert_eq(secondSizes, [(400, 300), (300, 200)])
  assert_eq(state.streams.length(), 1)
}

///|
async test "the worker releases a stream on close" {
  let state = pages_test_state()
  pages_test_capture_start()
  pages_test_open(state, pages_test_document(), 2, [])
  pages_test_capture_clear()
  state.dispatch(pages_test_stream_request("close", 0))
  let closed = pages_test_capture_take()
  let closedNull = pages_test_capture_null_result()
  pages_test_capture_clear()
  state.dispatch(pages_test_stream_request("finish", 0))
  let finished = pages_test_capture_take()
  pages_test_capture_clear()
  state.dispatch(pages_test_page_request(0, 0))
  let paged = pages_test_capture_take()
  pages_test_capture_stop()
  assert_true(closed.contains("\"ok\":true"), msg=closed)
  assert_true(closedNull, msg=closed)
  assert_true(finished.contains("\"ok\":false"), msg=finished)
  assert_true(finished.contains("no conversion 0"), msg=finished)
  assert_true(paged.contains("\"ok\":false"), msg=paged)
  assert_true(paged.contains("no conversion 0"), msg=paged)
  assert_eq(state.streams.length(), 0)
}

///|
async test "the worker reopens a stream after close with a new id" {
  let state = pages_test_state()
  let data = pages_test_document()
  pages_test_capture_start()
  pages_test_open(state, data, 2, [])
  pages_test_capture_clear()
  state.dispatch(pages_test_stream_request("close", 0))
  pages_test_capture_clear()
  let (selected, pages) = native_select_pages(
    pages_test_request("open", "{\"pages\":\"2\"}", b""),
    data,
    2,
  )
  native_stream_multipage(
    state,
    pages_test_request("open", "{\"pages\":\"2\"}", b""),
    selected,
    "synthetic",
    "1 page(s), 0 warning(s)",
    [],
    pages,
    true,
  )
  let reopened = pages_test_capture_take()
  let reopenedSizes = pages_test_page_sizes(pages_test_capture_bdf())
  pages_test_capture_clear()
  state.dispatch(pages_test_page_request(1, 0))
  let pageSizes = pages_test_page_sizes(pages_test_capture_last_bdf())
  pages_test_capture_clear()
  state.dispatch(pages_test_stream_request("finish", 0))
  let oldFinish = pages_test_capture_take()
  pages_test_capture_clear()
  state.dispatch(pages_test_stream_request("finish", 1))
  let newFinish = pages_test_capture_take()
  pages_test_capture_stop()
  assert_true(reopened.contains("\"stream\":1"), msg=reopened)
  assert_true(reopened.contains("\"pages\":1"), msg=reopened)
  assert_eq(reopenedSizes, [(300, 200)])
  assert_eq(pageSizes, [(300, 200)])
  assert_true(oldFinish.contains("no conversion 0"), msg=oldFinish)
  assert_true(newFinish.contains("\"ok\":true"), msg=newFinish)
}

///|
async test "the worker serializes warnings as a JavaScript array" {
  let state = pages_test_state()
  pages_test_capture_start()
  pages_test_open(state, pages_test_document(), 2, [
    "first warning", "second warning",
  ])
  let opened = pages_test_capture_take()
  pages_test_capture_clear()
  state.dispatch(pages_test_stream_request("finish", 0))
  let finished = pages_test_capture_take()
  pages_test_capture_clear()
  state.dispatch(pages_test_page_request(0, 0))
  let paged = pages_test_capture_take()
  pages_test_capture_stop()
  assert_true(
    opened.contains("\"warnings\":[\"first warning\",\"second warning\"]"),
    msg=opened,
  )
  assert_true(opened.contains("\"warningsArray\":true"), msg=opened)
  assert_true(
    finished.contains("\"warnings\":[\"first warning\",\"second warning\"]"),
    msg=finished,
  )
  assert_true(finished.contains("\"warningsArray\":true"), msg=finished)
  assert_true(paged.contains("\"warnings\":[]"), msg=paged)
  assert_true(paged.contains("\"warningsArray\":true"), msg=paged)
}

///|
async test "the worker closes an unknown stream without allocating one" {
  let state = pages_test_state()
  pages_test_capture_start()
  state.dispatch(pages_test_stream_request("close", 7))
  let closed = pages_test_capture_take()
  let closedNull = pages_test_capture_null_result()
  pages_test_capture_stop()
  assert_true(closed.contains("\"ok\":true"), msg=closed)
  assert_true(closedNull, msg=closed)
  assert_eq(state.next_stream, 0)
  assert_eq(state.streams.length(), 0)
}

///|
/// The number a page token names.
fn pages_test_number(text : String) -> Int64 {
  @string.parse_int64(text) catch { _ => 0L }
}

///|
/// The pages a token names, before the input's page count is applied.
fn pages_test_expand(token : String, count : Int32) -> Array[Int64] {
  let parts = token.split("-").map(fn(part) { part.to_owned() }).to_array()
  let from = if parts[0] == "" { 1L } else { pages_test_number(parts[0]) }
  let to = if parts.length() == 1 {
    from
  } else if parts[1] == "" {
    count.to_int64()
  } else {
    pages_test_number(parts[1])
  }
  let numbers : Array[Int64] = []
  let mut n = from
  while n <= to {
    numbers.push(n)
    n += 1L
  }
  numbers
}

///|
/// The pages a selection names, in document order: the reference model the
/// property loop compares `native_select_pages` against.
fn pages_test_expected(spec : String, count : Int32) -> Array[Int64] {
  let named : Map[Int64, Bool] = Map([])
  for segment in spec.split(",") {
    let token = segment.to_owned()
    if token == "" {
      continue
    }
    for page in pages_test_expand(token, count) {
      if page >= 1L && page <= count.to_int64() {
        named[page] = true
      }
    }
  }
  let expected : Array[Int64] = []
  for page = 1L; page <= count.to_int64(); page = page + 1L {
    if named.contains(page) {
      expected.push(page)
    }
  }
  expected
}

///|
test "native_select_pages keeps exactly the pages a selection names" {
  let data = pages_test_document()
  let tokens = ["1", "2", "3", "1-2", "2-3", "1-3", "1-", "-2", "2-2"]
  let specs : Array[String] = []
  for token in tokens {
    specs.push(token)
  }
  for first in tokens {
    for second in tokens {
      specs.push(first + "," + second)
    }
  }
  for spec in specs {
    let expected = pages_test_expected(spec, 2)
    let (bdf, pages) = native_select_pages(
      pages_test_request("convert", "{\"pages\":\"" + spec + "\"}", b""),
      data,
      2,
    )
    assert_eq(pages.to_int64(), expected.length().to_int64(), msg=spec)
    let sizes = pages_test_page_sizes(bdf)
    assert_eq(sizes.length(), expected.length(), msg=spec)
    let text = pages_test_page_text(bdf)
    let index = pages_test_index_text(bdf)
    for page in expected {
      let label = if page == 1L { "First page" } else { "Second page" }
      assert_true(text.contains(label), msg=spec + " " + label)
      assert_true(index.contains(label), msg=spec + " " + label)
    }
    for page in [1L, 2L] {
      if !expected.contains(page) {
        let label = if page == 1L { "First page" } else { "Second page" }
        assert_false(text.contains(label), msg=spec + " " + label)
        assert_false(index.contains(label), msg=spec + " " + label)
      }
    }
  }
}
