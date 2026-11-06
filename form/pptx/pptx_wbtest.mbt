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

