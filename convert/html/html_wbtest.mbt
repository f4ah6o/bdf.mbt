///|
fn html_test_fixture(text : String) -> Bytes {
  @gzip.decompress(@base64.decode(text[:], ignore_whitespace=true)[:]) catch {
    _ => b""
  }
}

///|
test "HTML article becomes reader pages" {
  let data = html_test_fixture(html_article_fixture)
  assert_eq(detect(data), true)
  let result = convert(data)
  assert_eq(result.pages > 0, true)
  let doc = @core.open_single(result.bdf)
  let index = @core.decode_text_index(doc.part(doc.manifest.views[0].text_index.unwrap()))
  let mut text = ""
  for run in index {
    text += run.text
  }
  for want in ["How Canvas Documents Load Quickly", "Canvas", "Subscribe"] {
    assert_eq(text.contains(want), true)
  }
}
