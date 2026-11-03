///|
test "EPUB OPF accepts namespace prefixes and single-quoted attributes" {
  let opf = "<?xml version='1.0'?><opf:package xmlns:opf='http://www.idpf.org/2007/opf'><opf:manifest><opf:item id='c1' href='Text/ch1.xhtml' media-type='application/xhtml+xml'/></opf:manifest><opf:spine><opf:itemref idref='c1'/></opf:spine></opf:package>"
  let (spine, _, _, _) = epub_opf_parts(opf)
  assert_eq(spine.length(), 1)
  assert_eq(spine[0], "Text/ch1.xhtml")
}

///|
test "EPUB spine is converted to reader pages" {
  let data = @gzip.decompress(
    @base64.decode(epub_basic_fixture[:], ignore_whitespace=true)[:],
  ) catch { _ => b"" }
  assert_eq(detect(data), true)
  let result = convert(data)
  assert_eq(result.pages > 0, true)
  let doc = @core.open_single(result.bdf)
  assert_eq(doc.manifest.views[0].pages[0].width, 419.5, msg="EPUB A5 width")
  let index = @core.decode_text_index(doc.part(doc.manifest.views[0].text_index.unwrap()))
  let mut text = ""
  for run in index {
    text += run.text
  }
  assert_eq(text.length() > 20, true)
}
