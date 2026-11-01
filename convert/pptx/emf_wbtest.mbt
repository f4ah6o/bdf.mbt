///|
test "PPTX pictures stored as EMF are replayed" {
  let data = @gzip.decompress(
    @base64.decode(pptx_emf_fixture[:], ignore_whitespace=true)[:],
  )
  let result = convert(data)
  assert_eq(result.pages, 1)
  let doc = @core.open_single(result.bdf)
  let mut found = false
  for page in doc.manifest.views[0].pages {
    let object = @core.decode_object(doc.part(page.layers[0].object))
    if object.strings.contains("EMF テキスト") {
      found = true
      assert_eq(object.images.length(), 1)
    }
  }
  assert_eq(found, true)
}
