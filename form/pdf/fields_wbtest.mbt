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
    #|2 0 obj << /T (name) /V () /FT /Tx /Ff 3 /TU (Full Name) /MaxLen 20 /Opt [(Red) (Green)] /Rect [10 20 100 40] /P 3 0 R >>
    #|3 0 obj << /T (agree) /V () /FT /Btn /Rect [110 20 130 40] /P 4 0 R >>
    #|%%EOF
  let bdf = fill_overlay(
    @utf8.encode(pdf),
    @utf8.encode("{\"name\":\"Alice\\nBob\",\"agree\":\"On\"}"),
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
  assert_true(text.contains("X"), msg=text)
}

///|
test "pdf reads a button field" {
  let pdf =
    #|%PDF-1.7
    #|1 0 obj << /Type /Page /MediaBox [0 0 200 100] >>
    #|2 0 obj << /T (name) /V () /FT /Tx /Ff 3 /TU (Full Name) /MaxLen 20 /Opt [(Red) (Green)] /Rect [10 20 100 40] /P 3 0 R >>
    #|3 0 obj << /T (agree) /V () /FT /Btn /Rect [110 20 130 40] /P 4 0 R >>
    #|%%EOF
  let fields = read_fields(@utf8.encode(pdf))
  assert_eq(fields.length(), 2)
  assert_eq(fields[1].name, "agree")
  assert_eq(fields[1].typ, "/Btn")
  assert_eq(fields[1].rect, Some((110.0, 20.0, 130.0, 40.0)))
  assert_eq(fields[0].page_object, Some(3))
  assert_eq(fields[0].flags, Some(3))
  assert_true(fields[0].read_only)
  assert_true(fields[0].required)
  assert_eq(fields[0].alternate_name, "Full Name")
  assert_eq(fields[0].max_len, Some(20))
  assert_eq(fields[0].options, ["Red", "Green"])
  assert_eq(fields[1].page_object, Some(4))
}

///|
test "pdf overlay uses a CropBox" {
  let pdf =
    #|%PDF-1.7
    #|1 0 obj << /Type /Page /CropBox [0 0 300 150] >>
    #|2 0 obj << /T (name) /V () /FT /Tx /Rect [10 20 100 40] >>
    #|%%EOF
  let bdf = fill_overlay(
    @utf8.encode(pdf),
    @utf8.encode("{\"name\":\"Alice\"}"),
    title="crop",
  )
  let document = @core.open_single(bdf)
  assert_eq(document.manifest.views[0].pages[0].width, 300.0)
  assert_eq(document.manifest.views[0].pages[0].height, 150.0)
}
///|
test "pdf overlay can skip read-only fields" {
  let pdf = @base64.decode(
    "JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgL0Fjcm9Gb3JtIDw8IC9GaWVsZHMgWzQgMCBSXSA+PiA+PgplbmRvYmoKMiAwIG9iago8PCAvVHlwZSAvUGFnZXMgL0tpZHMgWzMgMCBSXSAvQ291bnQgMSA+PgplbmRvYmoKMyAwIG9iago8PCAvVHlwZSAvUGFnZSAvUGFyZW50IDIgMCBSIC9NZWRpYUJveCBbMCAwIDIwMCAxMDBdIC9Bbm5vdHMgWzQgMCBSXSA+PgplbmRvYmoKNCAwIG9iago8PCAvVHlwZSAvQW5ub3QgL1N1YnR5cGUgL1dpZGdldCAvRlQgL1R4IC9UIChuYW1lKSAvViAoT2xkKSAvRmYgMSAvUmVjdCBbMTAgMjAgMTAwIDQwXSAvUCAzIDAgUiA+PgplbmRvYmoKeHJlZgowIDUKMDAwMDAwMDAwMCA2NTUzNSBmIAowMDAwMDAwMDA5IDAwMDAwIG4gCjAwMDAwMDAwOTAgMDAwMDAgbiAKMDAwMDAwMDE0NyAwMDAwMCBuIAowMDAwMDAwMjM0IDAwMDAwIG4gCnRyYWlsZXIKPDwgL1NpemUgNSAvUm9vdCAxIDAgUiA+PgpzdGFydHhyZWYKMzQ4CiUlRU9GCg==",
  )
  let skipped = fill_overlay(
    pdf,
    @utf8.encode("{\"name\":\"New\"}"),
    skip_read_only=true,
  )
  let document = @core.open_single(skipped)
  let resources = @core.decode_object_resources(
    document.part(document.manifest.parts[0].hash),
  )
  assert_true(!resources.object.strings.contains("New"))
  let filled = fill_overlay(pdf, @utf8.encode("{\"name\":\"New\"}"))
  let document2 = @core.open_single(filled)
  let resources2 = @core.decode_object_resources(
    document2.part(document2.manifest.parts[0].hash),
  )
  assert_true(resources2.object.strings.contains("New"))
}
