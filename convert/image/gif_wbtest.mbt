///|
test "GIF comment supplies alternative text and multiple frames warn" {
  let image = b"GIF89a\x07\x00\x05\x00\x00\x00\x00\x21\xfe\x03cat\x00\x2c\x00\x00\x00\x00\x07\x00\x05\x00\x00\x02\x00\x2c\x00\x00\x00\x00\x07\x00\x05\x00\x00\x02\x00\x3b"
  let result = convert(image, name="cat.gif")
  assert_eq((result.format, result.width, result.height), ("gif", 7.0, 5.0))
  assert_true(result.animated)
  assert_eq(result.warnings, ["animated image: the first frame is drawn"])
  let doc = @core.open_single(result.bdf)
  let page = doc.manifest.views[0].pages[0]
  assert_eq(@core.decode_object(doc.part(page.layers[0].object)).strings, [
    "cat", "",
  ])
  for n in 0..<=image.length() {
    ignore(Some(convert(image[:n].to_bytes())) catch { _ => None })
  }
}

///|
test "GIF sub-blocks keep truncated comment bytes and advance safely" {
  let (content, offset) = gif_blocks(b"\x05abc", 0, true)
  assert_eq(content, Some(b"abc"))
  assert_eq(offset, 6)
  let (discarded, next) = gif_blocks(b"\x02ab\x00", 0, false)
  assert_eq(discarded, None)
  assert_eq(next, 4)
}
