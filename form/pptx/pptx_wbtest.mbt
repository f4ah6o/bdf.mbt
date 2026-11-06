///|
test "form pptx fills tags" {
  let slide =
    #|<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><p:cSld><p:spTree><p:sp><p:txBody><a:p><a:r><a:t>{{name}}</a:t></a:r></a:p></p:txBody></p:sp></p:spTree></p:cSld></p:sld>
  let zipped = @ooxml.stored_zip([
    ("ppt/slides/slide1.xml", @utf8.encode(slide)),
  ])
  let filled = fill_bytes(zipped, @utf8.encode("{\"name\":\"Alice\"}"))
  let archive = @zip.open_zip(filled)
  let mut text = ""
  for entry in archive.entries {
    if entry.name == "ppt/slides/slide1.xml" {
      text = @utf8.decode_lossy(archive.read(entry, 4096)[:])
    }
  }
  assert_true(text.contains("Alice"))
  assert_true(!text.contains("{{name}}"))
}
///|
test "form pptx fills speaker notes" {
  let notes =
    #|<p:notes xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><p:txBody><a:p><a:r><a:t>{{note}}</a:t></a:r></a:p></p:txBody></p:notes>
  let zipped = @ooxml.stored_zip([
    ("ppt/notesSlides/notesSlide1.xml", @utf8.encode(notes)),
  ])
  let filled = fill_bytes(zipped, @utf8.encode("{\"note\":\"Remember\"}"))
  let archive = @zip.open_zip(filled)
  let mut text = ""
  for entry in archive.entries {
    if entry.name == "ppt/notesSlides/notesSlide1.xml" {
      text = @utf8.decode_lossy(archive.read(entry, 4096)[:])
    }
  }
  assert_true(text.contains("Remember"), msg=text)
}

///|
test "form pptx renders a filled slide" {
  let content_types =
    #|<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/><Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/></Types>
  let rels =
    #|<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/></Relationships>
  let presentation =
    #|<?xml version="1.0"?><p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><p:sldIdLst><p:sldId id="256" r:id="rId1"/></p:sldIdLst><p:sldSz cx="12192000" cy="6858000"/></p:presentation>
  let presentation_rels =
    #|<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/></Relationships>
  let slide =
    #|<?xml version="1.0"?><p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><p:cSld><p:spTree><p:sp><p:txBody><a:p><a:r><a:t>{{name}}</a:t></a:r></a:p></p:txBody></p:sp></p:spTree></p:cSld></p:sld>
  let zipped = @ooxml.stored_zip([
    ("[Content_Types].xml", @utf8.encode(content_types)),
    ("_rels/.rels", @utf8.encode(rels)),
    ("ppt/presentation.xml", @utf8.encode(presentation)),
    ("ppt/_rels/presentation.xml.rels", @utf8.encode(presentation_rels)),
    ("ppt/slides/slide1.xml", @utf8.encode(slide)),
  ])
  let filled = fill_bytes(zipped, @utf8.encode("{\"name\":\"Alice\"}"))
  let result = @pptx.convert(filled)
  assert_eq(result.pages, 1)
  let document = @core.open_single(result.bdf)
  assert_eq(document.manifest.views.length(), 1)
  assert_eq(document.manifest.views[0].pages.length(), 1)
}

