///|
test "ooxml fills tags" {
  let values = Json::object({
    "name": Json::string("Alice & Bob"),
    "customer": Json::object({ "city": Json::string("Tokyo") }),
    "n": Json::number(3.0),
  })
  let (filled, warnings) = fill_tags(
    "<w:t>{{name}}</w:t><w:t>{{customer.city}}/{{n}}</w:t>",
    values,
  )
  assert_eq(filled, "<w:t>Alice &amp; Bob</w:t><w:t>Tokyo/3</w:t>")
  assert_eq(warnings.length(), 0)
  let (control, control_warnings) = fill_tags("<w:t>{{#items}}</w:t>", values)
  assert_eq(control, "<w:t>{{#items}}</w:t>")
  assert_eq(control_warnings.length(), 1)
  let (split, split_warnings) = fill_tags(
    "<w:t>{{na</w:t><w:t>me}}</w:t>",
    values,
  )
  assert_eq(split, "<w:t>Alice &amp; Bob</w:t>")
  assert_eq(split_warnings.length(), 0)
}

///|
test "ooxml rebuilds a zip" {
  let entries : Array[(String, Bytes)] = [
    ("[Content_Types].xml", b"<Types/>"),
    ("word/document.xml", b"<document>{{name}}</document>"),
  ]
  let zipped = stored_zip(entries)
  let archive = @zip.open_zip(zipped)
  assert_eq(archive.entries.length(), 2)
  let mut found = false
  for entry in archive.entries {
    if entry.name == "word/document.xml" {
      let data = archive.read(entry, 1024)
      assert_eq(data, b"<document>{{name}}</document>")
      found = true
    }
  }
  assert_true(found)
  let (filled, warnings) = fill_zip(
    zipped,
    Json::object({ "name": Json::string("Alice") }),
  )
  let filled_archive = @zip.open_zip(filled)
  let mut text = ""
  for entry in filled_archive.entries {
    if entry.name == "word/document.xml" {
      text = @utf8.decode_lossy(filled_archive.read(entry, 1024)[:])
    }
  }
  assert_eq(text, "<document>Alice</document>")
  assert_eq(warnings.length(), 0)
}
