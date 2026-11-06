
///|
test "ooxml expands conditions" {
  let true_values = Json::object({ "ok": Json::boolean(true) })
  let (yes, yes_warnings) = expand_controls(
    "A{{#ok}}B{{/ok}}C{{^ok}}D{{/ok}}",
    true_values,
  )
  assert_eq(yes, "ABC")
  assert_eq(yes_warnings.length(), 0)
  let false_values = Json::object({ "ok": Json::boolean(false) })
  let (no, no_warnings) = expand_controls(
    "A{{#ok}}B{{/ok}}C{{^ok}}D{{/ok}}",
    false_values,
  )
  assert_eq(no, "ACD")
  assert_eq(no_warnings.length(), 0)
  let list_values = Json::object({
    "items": Json::array([
      Json::object({ "name": Json::string("A") }),
      Json::object({ "name": Json::string("B") }),
    ]),
  })
  let (list, list_warnings) = expand_controls(
    "{{#items}}<r>{{name}}</r>{{/items}}",
    list_values,
  )
  assert_eq(list, "<r>A</r><r>B</r>")
  assert_eq(list_warnings.length(), 0)
  let (missing, missing_warnings) = expand_controls("A{{#none}}B{{/none}}C", true_values)
  assert_eq(missing, "AC")
  assert_eq(missing_warnings.length(), 0)
}
///|
test "ooxml fills header parts" {
  let zipped = stored_zip([
    (
      "word/header1.xml",
      @utf8.encode(
        "<?xml version=\"1.0\"?><w:hdr xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:p><w:r><w:t>{{title}}</w:t></w:r></w:p></w:hdr>",
      ),
    ),
    ("word/document.xml", @utf8.encode("<w:document/>")),
  ])
  let (filled, warnings) = fill_zip(
    zipped,
    Json::object({ "title": Json::string("Report") }),
  )
  assert_eq(warnings.length(), 0)
  let archive = @zip.open_zip(filled) catch {
    _ => fail("the filled package cannot be opened")
  }
  let mut header = ""
  for entry in archive.entries {
    if entry.name == "word/header1.xml" {
      header = @utf8.decode_lossy(archive.read(entry, 1024)[:])
    }
  }
  assert_true(header.contains("Report"), msg=header)
}

