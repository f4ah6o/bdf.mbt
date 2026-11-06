///|
test "pdf reads AcroForm fields" {
  let pdf =
    #|%PDF-1.7
    #|1 0 obj << /T (name) /V (Alice) /FT /Tx /Rect [10 20 100 40] >>
    #|2 0 obj << /T (note) /V (A\(B\)) /FT /Tx >>
    #|%%EOF
  let fields = read_fields(@utf8.encode(pdf))
  assert_eq(fields.length(), 2)
  assert_eq(fields[0].name, "name")
  assert_eq(fields[0].value, "Alice")
  assert_eq(fields[0].typ, "/Tx")
  assert_eq(fields[0].rect, Some((10.0, 20.0, 100.0, 40.0)))
  assert_eq(fields[1].name, "note")
  assert_eq(fields[1].value, "A(B)")
}
///|
test "pdf reads hex and name values" {
  let pdf =
    #|%PDF-1.7
    #|1 0 obj << /T (unicode) /V <FEFF0041006C006900630065> /FT /Tx >>
    #|2 0 obj << /T (ascii) /V <414243> /FT /Tx >>
    #|3 0 obj << /T (check) /V /Yes /FT /Btn >>
    #|%%EOF
  let fields = read_fields(@utf8.encode(pdf))
  assert_eq(fields.length(), 3)
  assert_eq(fields[0].value, "Alice")
  assert_eq(fields[1].value, "ABC")
  assert_eq(fields[2].value, "/Yes")
  assert_eq(fields[2].typ, "/Btn")
}

///|
test "pdf overlay draws form values" {
  let pdf =
    #|%PDF-1.7
    #|1 0 obj << /Type /Page /MediaBox [0 0 200 100] >>
    #|2 0 obj << /T (name) /V () /FT /Tx /Rect [10 20 100 40] >>
    #|%%EOF
  let bdf = fill_overlay(
    @utf8.encode(pdf),
    @utf8.encode("{\"name\":\"Alice\\nBob\"}"),
    title="overlay",
  )
  let document = @core.open_single(bdf)
  assert_eq(document.manifest.views[0].pages[0].width, 200.0)
  assert_eq(document.manifest.views[0].pages[0].height, 100.0)
  let mut text = ""
  for part in document.manifest.parts {
    if part.kind == "obj" {
      let resources = @core.decode_object_resources(document.part(part.hash))
      for value in resources.object.strings {
        text = text + value + "\n"
      }
    }
  }
  assert_true(text.contains("Alice"), msg=text)
  assert_true(text.contains("Bob"), msg=text)
}

