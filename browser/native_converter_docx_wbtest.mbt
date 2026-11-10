///|
// The worker's DOCX path passes its `pages` option to the converter, so the
// summary and the page count describe the selected pages.

///|
/// A request shaped like the one the worker receives.
extern "js" fn docx_test_request(pages : String) -> ConverterRequest =
  #|(pages) => ({ id: 1, type: "convert", options: { pages } })

///|
/// Capture what the worker posts, in place of the real `self`.
extern "js" fn docx_test_capture_start() -> Unit =
  #|() => { globalThis.__docxPosted = []; globalThis.self = { postMessage: (m) => { globalThis.__docxPosted.push(m); } }; }

///|
/// The posted messages, without the converted bytes.
extern "js" fn docx_test_capture_take() -> String =
  #|() => JSON.stringify((globalThis.__docxPosted ?? []).map(m => ({ ok: m.ok, format: m.result?.format, summary: m.result?.summary, bytes: m.result?.bdf?.length ?? 0, error: m.error })))

///|
/// The converted bytes the worker posted.
extern "js" fn docx_test_capture_bdf() -> Bytes =
  #|() => { const m = (globalThis.__docxPosted ?? [])[0]; return m?.result?.bdf ?? new Uint8Array(0); }

///|
extern "js" fn docx_test_capture_stop() -> Unit =
  #|() => { delete globalThis.self; delete globalThis.__docxPosted; }

///|
/// The text the page view of a converted document holds.
fn docx_test_page_text(bdf : Bytes) -> String raise {
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
/// A two-page document whose pages hold different text.
fn docx_test_package() -> Bytes raise {
  let content_types =
    #|<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>
  let rels =
    #|<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>
  let document =
    #|<?xml version="1.0" encoding="UTF-8"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>One</w:t></w:r></w:p><w:p><w:r><w:br w:type="page"/></w:r></w:p><w:p><w:r><w:t>Two</w:t></w:r></w:p></w:body></w:document>
  @ooxml.stored_zip([
    ("[Content_Types].xml", @utf8.encode(content_types)),
    ("_rels/.rels", @utf8.encode(rels)),
    ("word/document.xml", @utf8.encode(document)),
  ])
}

///|
fn docx_test_state() -> NativeConverterState {
  { ready: true, streams: Map([]), next_stream: 0 }
}

///|
test "the worker converts every DOCX page by default" {
  let data = docx_test_package()
  docx_test_capture_start()
  native_convert_docx(docx_test_state(), docx_test_request(""), data, false)
  let posted = docx_test_capture_take()
  let text = docx_test_page_text(docx_test_capture_bdf())
  docx_test_capture_stop()
  assert_true(posted.contains("\"format\":\"docx\""), msg=posted)
  assert_true(posted.contains("\"summary\":\"2 pages, "), msg=posted)
  assert_true(text.contains("One"), msg=text)
  assert_true(text.contains("Two"), msg=text)
}

///|
test "the worker keeps the selected DOCX pages" {
  let data = docx_test_package()
  docx_test_capture_start()
  native_convert_docx(docx_test_state(), docx_test_request("2"), data, false)
  let posted = docx_test_capture_take()
  let text = docx_test_page_text(docx_test_capture_bdf())
  docx_test_capture_stop()
  assert_true(posted.contains("\"format\":\"docx\""), msg=posted)
  assert_true(posted.contains("\"summary\":\"1 page, "), msg=posted)
  assert_true(!posted.contains("\"summary\":\"2 pages, "), msg=posted)
  // The posted bytes hold the selected page alone, so the worker did not
  // select the pages a second time.
  assert_true(text.contains("Two"), msg=text)
  assert_true(!text.contains("One"), msg=text)
}
