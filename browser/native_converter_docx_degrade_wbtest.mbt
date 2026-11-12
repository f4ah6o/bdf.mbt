///|
// The worker's DOCX path must surface the converter's public warnings: a
// drawing whose visual content is not drawn is skipped with one warning, and
// the rest of the document still converts. The capture helpers of the other
// DOCX worker tests are shared; this file adds only what reads `warnings`
// from the posted message.

///|
/// The posted messages, with the warnings the result carried and whether they
/// crossed the Worker boundary as a real JavaScript array.
extern "js" fn docx_degrade_capture_notes() -> String =
  #|() => JSON.stringify((globalThis.__docxPosted ?? []).map(m => ({ ok: m.ok, format: m.result?.format, warnings: m.result?.warnings, warningsArray: Array.isArray(m.result?.warnings), error: m.error })))

///|
/// A document with an anchored shape and a body paragraph after it: the
/// drawing degrades with a warning, the text survives.
fn docx_degrade_worker_package() -> Bytes raise {
  let content_types =
    #|<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>
  let rels =
    #|<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>
  let document =
    #|<?xml version="1.0" encoding="UTF-8"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape"><w:body><w:p><w:r><w:drawing><wp:anchor distT="0" distB="0" distL="0" distR="0" behindDoc="0" relativeHeight="1"><wp:simplePos x="0" y="0"/><wp:positionH relativeFrom="column"><wp:posOffset>0</wp:posOffset></wp:positionH><wp:positionV relativeFrom="paragraph"><wp:posOffset>0</wp:posOffset></wp:positionV><wp:docPr id="1" name="Panel" descr="A red rectangle"/><wp:extent cx="914400" cy="914400"/><a:graphic><a:graphicData uri="http://schemas.microsoft.com/office/word/2010/wordprocessingShape"><wps:wsp><wps:spPr><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></wps:spPr></wps:wsp></a:graphicData></a:graphic></wp:anchor></w:drawing></w:r></w:p><w:p><w:r><w:t>Adjacent body text</w:t></w:r></w:p><w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr></w:body></w:document>
  @ooxml.stored_zip([
    ("[Content_Types].xml", @utf8.encode(content_types)),
    ("_rels/.rels", @utf8.encode(rels)),
    ("word/document.xml", @utf8.encode(document)),
  ])
}

///|
test "the worker posts the drawing degrade warning with the document" {
  docx_test_capture_start()
  native_convert_docx(
    docx_test_state(),
    docx_test_request(""),
    docx_degrade_worker_package(),
    false,
  )
  let posted = docx_degrade_capture_notes()
  let text = docx_test_page_text(docx_test_capture_bdf())
  docx_test_capture_stop()
  assert_true(posted.contains("\"ok\":true"), msg=posted)
  assert_true(
    posted.contains("a drawing without an embedded image or text box"),
    msg=posted,
  )
  assert_true(posted.contains("\"warningsArray\":true"), msg=posted)
  assert_true(text.contains("Adjacent body text"), msg=text)
}
