///|
test "JPEG XMP metadata sets the figure description before a title override" {
  let packet = @utf8.encode(
    "<rdf:RDF xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'><rdf:Description xmlns:dc='http://purl.org/dc/elements/1.1/'><dc:title>Original</dc:title><dc:description>A landscape</dc:description></rdf:Description></rdf:RDF>",
  )
  let segment = @buffer.Buffer()
  segment.write_bytes(b"http://ns.adobe.com/xap/1.0/\x00")
  segment.write_bytes(packet)
  let file = @buffer.Buffer()
  file.write_bytes(b"\xff\xd8\xff\xe1")
  file.write_uint16_be((segment.length() + 2).to_uint16())
  file.write_bytes(segment.to_bytes())
  file.write_bytes(b"\xff\xc0\x00\x07\x08\x00\x05\x00\x07\xff\xd9")
  let result = convert(file.to_bytes(), title="Override", name="photo.jpg")
  let doc = @core.open_single(result.bdf)
  assert_eq(doc.manifest.views[0].title, "Override")
  let page = doc.manifest.views[0].pages[0]
  let object = @core.decode_object(doc.part(page.layers[0].object))
  assert_eq(object.strings, ["A landscape", ""])
}
