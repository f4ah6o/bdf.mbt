///|
test "form xlsx fills tags" {
  let sheet =
    #|<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row r="1"><c r="A1" t="inlineStr"><is><t>{{name}}</t></is></c></row></sheetData></worksheet>
  let zipped = @ooxml.stored_zip([
    ("xl/worksheets/sheet1.xml", @utf8.encode(sheet)),
  ])
  let filled = fill_bytes(zipped, @utf8.encode("{\"name\":\"Alice\"}"))
  let archive = @zip.open_zip(filled)
  let mut text = ""
  for entry in archive.entries {
    if entry.name == "xl/worksheets/sheet1.xml" {
      text = @utf8.decode_lossy(archive.read(entry, 4096)[:])
    }
  }
  assert_true(text.contains("Alice"))
  assert_true(!text.contains("{{name}}"))
}
///|
test "form xlsx fills shared strings" {
  let strings =
    #|<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><si><t>{{name}}</t></si></sst>
  let zipped = @ooxml.stored_zip([
    ("xl/sharedStrings.xml", @utf8.encode(strings)),
  ])
  let filled = fill_bytes(zipped, @utf8.encode("{\"name\":\"Alice\"}"))
  let archive = @zip.open_zip(filled)
  let mut text = ""
  for entry in archive.entries {
    if entry.name == "xl/sharedStrings.xml" {
      text = @utf8.decode_lossy(archive.read(entry, 4096)[:])
    }
  }
  assert_true(text.contains("Alice"), msg=text)
}

