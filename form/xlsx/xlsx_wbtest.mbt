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

///|
test "form xlsx renders a filled shared string" {
  let content_types =
    #|<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/></Types>
  let rels =
    #|<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>
  let workbook =
    #|<?xml version="1.0"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets></workbook>
  let workbook_rels =
    #|<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/></Relationships>
  let sheet =
    #|<?xml version="1.0"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row r="1"><c r="A1" t="s"><v>0</v></c></row></sheetData></worksheet>
  let strings =
    #|<?xml version="1.0"?><sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><si><t>{{name}}</t></si></sst>
  let zipped = @ooxml.stored_zip([
    ("[Content_Types].xml", @utf8.encode(content_types)),
    ("_rels/.rels", @utf8.encode(rels)),
    ("xl/workbook.xml", @utf8.encode(workbook)),
    ("xl/_rels/workbook.xml.rels", @utf8.encode(workbook_rels)),
    ("xl/worksheets/sheet1.xml", @utf8.encode(sheet)),
    ("xl/sharedStrings.xml", @utf8.encode(strings)),
  ])
  let filled = fill_bytes(zipped, @utf8.encode("{\"name\":\"Alice\"}"))
  let result = @xlsx.convert_plain_no_fonts(filled)
  let document = @core.open_single(result.bdf)
  let mut text = ""
  for view in document.manifest.views {
    match view.text_index {
      Some(hash) => {
        for run in @core.decode_text_index(document.part(hash)) {
          text = text + run.text
        }
      }
      None => ()
    }
  }
  assert_true(text.contains("Alice"), msg=text + " warnings=" + result.warnings.join(";"))
}

