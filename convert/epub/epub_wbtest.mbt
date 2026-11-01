///|
test "EPUB spine is converted to reader pages" {
  let data = @gzip.decompress(
    @base64.decode(epub_basic_fixture[:], ignore_whitespace=true)[:],
  ) catch { _ => b"" }
  assert_eq(detect(data), true)
  let result = convert(data)
  assert_eq(result.pages > 0, true)
  let doc = @core.open_single(result.bdf)
  let index = @core.decode_text_index(doc.part(doc.manifest.views[0].text_index.unwrap()))
  let mut text = ""
  for run in index {
    text += run.text
  }
  assert_eq(text.length() > 20, true)
}
