///|
test "DOCX pictures stored as EMF are replayed" {
  let data = @gzip.decompress(
    @base64.decode(docx_emf_fixture[:], ignore_whitespace=true)[:],
  )
  let result = convert(data)
  assert_eq(result.pages, 1)
  let doc = @core.open_single(result.bdf)
  let page = doc.manifest.views[0].pages[0]
  let object = @core.decode_object(doc.part(page.layers[0].object))
  assert_eq(object.strings.contains("EMF テキスト"), true)
  assert_eq(object.images.length(), 1)
  assert_eq(
    result.warnings.contains("DOCX: an EMF/WMF drawing could not be replayed"),
    false,
  )
}
