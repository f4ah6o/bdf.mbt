///|
fn markdown_test_fixture(text : String) -> Bytes {
  @gzip.decompress(@base64.decode(text[:], ignore_whitespace=true)[:]) catch {
    _ => b""
  }
}

///|
test "Markdown reader pages and metadata" {
  let data = markdown_test_fixture(markdown_basic_fixture)
  let result = convert(data)
  assert_eq(result.pages > 0, true)
  let doc = @core.open_single(result.bdf)
  let view = doc.manifest.views[0]
  assert_eq(view.kind, "fixed")
  assert_eq(view.pages.length(), result.pages)
  assert_eq(view.text_index.is_empty(), false)
}

///|
test "Markdown headings, code, lists and text" {
  let data = markdown_test_fixture(markdown_basic_fixture)
  let result = convert(data)
  let doc = @core.open_single(result.bdf)
  let index = @core.decode_text_index(doc.part(doc.manifest.views[0].text_index.unwrap()))
  let mut text = ""
  for run in index {
    text += run.text
  }
  for want in ["Markdown のテスト文書", "見出し", "func main()", "完了したタスク", "リンク"] {
    assert_eq(text.contains(want), true)
  }
}
