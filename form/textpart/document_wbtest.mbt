///|
test "textpart document part" {
  let image = sample_image()
  let writer = @core.DocumentWriter::new()
  let hash = image.add_to(writer)
  assert_true(hash.length() > 0, msg="the part hash")
  let bytes = writer.write_single()
  let document = @core.open_single(bytes)
  assert_eq(document.manifest.parts.length(), 1)
  assert_eq(document.manifest.parts[0].kind, "text")
  let back = from_document(bytes)
  assert_eq(back.version, image.version)
  assert_eq(back.columns, image.columns)
  assert_eq(back.pages.length(), image.pages.length())
  assert_eq(back.pages[0].lines[4].text, "e\u{301}x")
  let empty = @core.DocumentWriter::new().write_single()
  let none = try {
    ignore(from_document(empty))
    false
  } catch {
    TextPartNone => true
    _ => false
  }
  assert_true(none, msg="a document without a print image")
}
