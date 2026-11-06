///|
test "fill_pdf writes a field value" {
  let pdf = @base64.decode(
    "JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgL0Fjcm9Gb3JtIDw8IC9GaWVsZHMgWzQgMCBSXSA+PiA+PgplbmRvYmoKMiAwIG9iago8PCAvVHlwZSAvUGFnZXMgL0tpZHMgWzMgMCBSXSAvQ291bnQgMSA+PgplbmRvYmoKMyAwIG9iago8PCAvVHlwZSAvUGFnZSAvUGFyZW50IDIgMCBSIC9NZWRpYUJveCBbMCAwIDIwMCAxMDBdIC9Bbm5vdHMgWzQgMCBSXSA+PgplbmRvYmoKNCAwIG9iago8PCAvVHlwZSAvQW5ub3QgL1N1YnR5cGUgL1dpZGdldCAvRlQgL1R4IC9UIChuYW1lKSAvViAoT2xkKSAvUmVjdCBbMTAgMjAgMTAwIDQwXSAvUCAzIDAgUiA+PgplbmRvYmoKeHJlZgowIDUKMDAwMDAwMDAwMCA2NTUzNSBmIAowMDAwMDAwMDA5IDAwMDAwIG4gCjAwMDAwMDAwOTAgMDAwMDAgbiAKMDAwMDAwMDE0NyAwMDAwMCBuIAowMDAwMDAwMjM0IDAwMDAwIG4gCnRyYWlsZXIKPDwgL1NpemUgNSAvUm9vdCAxIDAgUiA+PgpzdGFydHhyZWYKMzQyCiUlRU9GCg==",
  )
  let text0 = @utf8.decode_lossy(pdf[:])
  assert_true(text0.contains("startxref"), msg="raw startxref")
  assert_true(pdf_startxref(text0) is Some(_), msg="startxref helper")
  let filled = fill_pdf(pdf, @utf8.encode("{\"name\":\"Alice\"}")) catch {
    PdfFillError(message) => fail(message)
  }
  let text = @utf8.decode_lossy(filled[:])
  assert_true(text.contains("/V (Alice)"), msg=text)
  assert_true(text.contains("/Prev 342"), msg=text)
  assert_true(text.contains("/NeedAppearances true"), msg=text)
  let fields = read_fields(filled)
  assert_eq(fields.length(), 1)
  assert_eq(fields[0].name, "name")
  assert_eq(fields[0].value, "Alice")
}
///|
test "fill_pdf inserts a missing V" {
  let pdf = @base64.decode(
    "JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgL0Fjcm9Gb3JtIDw8IC9GaWVsZHMgWzQgMCBSXSA+PiA+PgplbmRvYmoKMiAwIG9iago8PCAvVHlwZSAvUGFnZXMgL0tpZHMgWzMgMCBSXSAvQ291bnQgMSA+PgplbmRvYmoKMyAwIG9iago8PCAvVHlwZSAvUGFnZSAvUGFyZW50IDIgMCBSIC9NZWRpYUJveCBbMCAwIDIwMCAxMDBdIC9Bbm5vdHMgWzQgMCBSXSA+PgplbmRvYmoKNCAwIG9iago8PCAvVHlwZSAvQW5ub3QgL1N1YnR5cGUgL1dpZGdldCAvRlQgL1R4IC9UIChuYW1lKSAvUmVjdCBbMTAgMjAgMTAwIDQwXSAvUCAzIDAgUiA+PgplbmRvYmoKeHJlZgowIDUKMDAwMDAwMDAwMCA2NTUzNSBmIAowMDAwMDAwMDA5IDAwMDAwIG4gCjAwMDAwMDAwOTAgMDAwMDAgbiAKMDAwMDAwMDE0NyAwMDAwMCBuIAowMDAwMDAwMjM0IDAwMDAwIG4gCnRyYWlsZXIKPDwgL1NpemUgNSAvUm9vdCAxIDAgUiA+PgpzdGFydHhyZWYKMzMzCiUlRU9GCg==",
  )
  let filled = fill_pdf(pdf, @utf8.encode("{\"name\":\"Alice\"}"))
  let fields = read_fields(filled)
  assert_eq(fields.length(), 1)
  assert_eq(fields[0].value, "Alice")
}

///|
test "fill_pdf writes Japanese text as UTF-16" {
  let pdf = @base64.decode(
    "JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgL0Fjcm9Gb3JtIDw8IC9GaWVsZHMgWzQgMCBSXSA+PiA+PgplbmRvYmoKMiAwIG9iago8PCAvVHlwZSAvUGFnZXMgL0tpZHMgWzMgMCBSXSAvQ291bnQgMSA+PgplbmRvYmoKMyAwIG9iago8PCAvVHlwZSAvUGFnZSAvUGFyZW50IDIgMCBSIC9NZWRpYUJveCBbMCAwIDIwMCAxMDBdIC9Bbm5vdHMgWzQgMCBSXSA+PgplbmRvYmoKNCAwIG9iago8PCAvVHlwZSAvQW5ub3QgL1N1YnR5cGUgL1dpZGdldCAvRlQgL1R4IC9UIChuYW1lKSAvViAoT2xkKSAvUmVjdCBbMTAgMjAgMTAwIDQwXSAvUCAzIDAgUiA+PgplbmRvYmoKeHJlZgowIDUKMDAwMDAwMDAwMCA2NTUzNSBmIAowMDAwMDAwMDA5IDAwMDAwIG4gCjAwMDAwMDAwOTAgMDAwMDAgbiAKMDAwMDAwMDE0NyAwMDAwMCBuIAowMDAwMDAwMjM0IDAwMDAwIG4gCnRyYWlsZXIKPDwgL1NpemUgNSAvUm9vdCAxIDAgUiA+PgpzdGFydHhyZWYKMzQyCiUlRU9GCg==",
  )
  let filled = fill_pdf(pdf, @utf8.encode("{\"name\":\"日本語\"}"))
  let text = @utf8.decode_lossy(filled[:])
  assert_true(text.contains("<FEFF65E5672C8A9E>"), msg=text)
  let fields = read_fields(filled)
  assert_eq(fields.length(), 1)
  assert_eq(fields[0].value, "日本語")
}

///|
test "fill_pdf checks a button" {
  let pdf = @base64.decode(
    "JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgL0Fjcm9Gb3JtIDw8IC9GaWVsZHMgWzQgMCBSXSA+PiA+PgplbmRvYmoKMiAwIG9iago8PCAvVHlwZSAvUGFnZXMgL0tpZHMgWzMgMCBSXSAvQ291bnQgMSA+PgplbmRvYmoKMyAwIG9iago8PCAvVHlwZSAvUGFnZSAvUGFyZW50IDIgMCBSIC9NZWRpYUJveCBbMCAwIDIwMCAxMDBdIC9Bbm5vdHMgWzQgMCBSXSA+PgplbmRvYmoKNCAwIG9iago8PCAvVHlwZSAvQW5ub3QgL1N1YnR5cGUgL1dpZGdldCAvRlQgL0J0biAvVCAoYWdyZWUpIC9WIC9PZmYgL0FTIC9PZmYgL1JlY3QgWzEwIDIwIDIwIDMwXSAvUCAzIDAgUiA+PgplbmRvYmoKeHJlZgowIDUKMDAwMDAwMDAwMCA2NTUzNSBmIAowMDAwMDAwMDA5IDAwMDAwIG4gCjAwMDAwMDAwOTAgMDAwMDAgbiAKMDAwMDAwMDE0NyAwMDAwMCBuIAowMDAwMDAwMjM0IDAwMDAwIG4gCnRyYWlsZXIKPDwgL1NpemUgNSAvUm9vdCAxIDAgUiA+PgpzdGFydHhyZWYKMzUxCiUlRU9GCg==",
  )
  let filled = fill_pdf(pdf, @utf8.encode("{\"agree\":true}"))
  let text = @utf8.decode_lossy(filled[:])
  assert_true(text.contains("/V /Yes"), msg=text)
  assert_true(text.contains("/AS /Yes"), msg=text)
  let fields = read_fields(filled)
  assert_eq(fields.length(), 1)
  assert_eq(fields[0].value, "/Yes")
}

