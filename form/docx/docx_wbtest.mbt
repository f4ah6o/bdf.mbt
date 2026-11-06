///|
test "form docx fills tags" {
  let content_types =
    #|<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>
  let rels =
    #|<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>
  let document =
    #|<?xml version="1.0" encoding="UTF-8"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>Hello {{name}}</w:t></w:r></w:p></w:body></w:document>
  let zipped = @ooxml.stored_zip([
    ("[Content_Types].xml", @utf8.encode(content_types)),
    ("_rels/.rels", @utf8.encode(rels)),
    ("word/document.xml", @utf8.encode(document)),
  ])
  let result = fill(zipped, @utf8.encode("{\"name\":\"Alice\"}"), views="pages")
  assert_true(result.pages >= 1)
  assert_true(result.bdf.length() > 0)
  assert_true(result.warnings.length() <= 1, msg=result.warnings.join(";"))
}
///|
test "form docx fills header tags" {
  let document =
    #|<?xml version="1.0"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>{{body}}</w:t></w:r></w:p></w:body></w:document>
  let header =
    #|<?xml version="1.0"?><w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:r><w:t>{{title}}</w:t></w:r></w:p></w:hdr>
  let zipped = @ooxml.stored_zip([
    ("word/document.xml", @utf8.encode(document)),
    ("word/header1.xml", @utf8.encode(header)),
  ])
  let filled = fill_bytes(
    zipped,
    @utf8.encode("{\"body\":\"Hello\",\"title\":\"Report\"}"),
  )
  let archive = @zip.open_zip(filled) catch {
    _ => fail("the filled package cannot be opened")
  }
  let mut value = ""
  for entry in archive.entries {
    if entry.name == "word/header1.xml" {
      value = @utf8.decode_lossy(archive.read(entry, 4096)[:])
    }
  }
  assert_true(value.contains("Report"), msg=value)
}

