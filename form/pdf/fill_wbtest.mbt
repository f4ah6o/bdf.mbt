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

///|
test "fill_pdf adds a button appearance state" {
  let pdf = @base64.decode(
    "JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgL0Fjcm9Gb3JtIDw8IC9GaWVsZHMgWzQgMCBSXSA+PiA+PgplbmRvYmoKMiAwIG9iago8PCAvVHlwZSAvUGFnZXMgL0tpZHMgWzMgMCBSXSAvQ291bnQgMSA+PgplbmRvYmoKMyAwIG9iago8PCAvVHlwZSAvUGFnZSAvUGFyZW50IDIgMCBSIC9NZWRpYUJveCBbMCAwIDIwMCAxMDBdIC9Bbm5vdHMgWzQgMCBSXSA+PgplbmRvYmoKNCAwIG9iago8PCAvVHlwZSAvQW5ub3QgL1N1YnR5cGUgL1dpZGdldCAvRlQgL0J0biAvVCAoYWdyZWUpIC9WIC9PZmYgL1JlY3QgWzEwIDIwIDIwIDMwXSAvUCAzIDAgUiA+PgplbmRvYmoKeHJlZgowIDUKMDAwMDAwMDAwMCA2NTUzNSBmIAowMDAwMDAwMDA5IDAwMDAwIG4gCjAwMDAwMDAwOTAgMDAwMDAgbiAKMDAwMDAwMDE0NyAwMDAwMCBuIAowMDAwMDAwMjM0IDAwMDAwIG4gCnRyYWlsZXIKPDwgL1NpemUgNSAvUm9vdCAxIDAgUiA+PgpzdGFydHhyZWYKMzQyCiUlRU9GCg==",
  )
  let filled = fill_pdf(pdf, @utf8.encode("{\"agree\":true}"))
  let text = @utf8.decode_lossy(filled[:])
  assert_true(text.contains("/AS /Yes"), msg=text)
  let fields = read_fields(filled)
  assert_eq(fields.length(), 1)
  assert_eq(fields[0].value, "/Yes")
}

///|
test "fill_pdf selects a named button state" {
  let pdf = @base64.decode(
    "JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgL0Fjcm9Gb3JtIDw8IC9GaWVsZHMgWzQgMCBSXSA+PiA+PgplbmRvYmoKMiAwIG9iago8PCAvVHlwZSAvUGFnZXMgL0tpZHMgWzMgMCBSXSAvQ291bnQgMSA+PgplbmRvYmoKMyAwIG9iago8PCAvVHlwZSAvUGFnZSAvUGFyZW50IDIgMCBSIC9NZWRpYUJveCBbMCAwIDIwMCAxMDBdIC9Bbm5vdHMgWzQgMCBSXSA+PgplbmRvYmoKNCAwIG9iago8PCAvVHlwZSAvQW5ub3QgL1N1YnR5cGUgL1dpZGdldCAvRlQgL0J0biAvVCAoYWdyZWUpIC9WIC9PZmYgL1JlY3QgWzEwIDIwIDIwIDMwXSAvUCAzIDAgUiA+PgplbmRvYmoKeHJlZgowIDUKMDAwMDAwMDAwMCA2NTUzNSBmIAowMDAwMDAwMDA5IDAwMDAwIG4gCjAwMDAwMDAwOTAgMDAwMDAgbiAKMDAwMDAwMDE0NyAwMDAwMCBuIAowMDAwMDAwMjM0IDAwMDAwIG4gCnRyYWlsZXIKPDwgL1NpemUgNSAvUm9vdCAxIDAgUiA+PgpzdGFydHhyZWYKMzQyCiUlRU9GCg==",
  )
  let filled = fill_pdf(pdf, @utf8.encode("{\"agree\":\"Yes\"}"))
  let text = @utf8.decode_lossy(filled[:])
  assert_true(text.contains("/V /Yes"), msg=text)
}

///|
test "fill_pdf updates a referenced AcroForm" {
  let pdf = @base64.decode(
    "JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgL0Fjcm9Gb3JtIDUgMCBSID4+CmVuZG9iagoyIDAgb2JqCjw8IC9UeXBlIC9QYWdlcyAvS2lkcyBbMyAwIFJdIC9Db3VudCAxID4+CmVuZG9iagozIDAgb2JqCjw8IC9UeXBlIC9QYWdlIC9QYXJlbnQgMiAwIFIgL01lZGlhQm94IFswIDAgMjAwIDEwMF0gL0Fubm90cyBbNCAwIFJdID4+CmVuZG9iago0IDAgb2JqCjw8IC9UeXBlIC9Bbm5vdCAvU3VidHlwZSAvV2lkZ2V0IC9GVCAvVHggL1QgKG5hbWUpIC9WIChPbGQpIC9SZWN0IFsxMCAyMCAxMDAgNDBdIC9QIDMgMCBSID4+CmVuZG9iago1IDAgb2JqCjw8IC9GaWVsZHMgWzQgMCBSXSA+PgplbmRvYmoKeHJlZgowIDYKMDAwMDAwMDAwMCA2NTUzNSBmIAowMDAwMDAwMDA5IDAwMDAwIG4gCjAwMDAwMDAwNzQgMDAwMDAgbiAKMDAwMDAwMDEzMSAwMDAwMCBuIAowMDAwMDAwMjE4IDAwMDAwIG4gCjAwMDAwMDAzMjYgMDAwMDAgbiAKdHJhaWxlcgo8PCAvU2l6ZSA2IC9Sb290IDEgMCBSID4+CnN0YXJ0eHJlZgozNjMKJSVFT0YK",
  )
  let filled = fill_pdf(pdf, @utf8.encode("{\"name\":\"Alice\"}"))
  let text = @utf8.decode_lossy(filled[:])
  assert_true(text.contains("/NeedAppearances true"), msg=text)
  let fields = read_fields(filled)
  assert_eq(fields.length(), 1)
  assert_eq(fields[0].value, "Alice")
}

///|
test "fill_pdf uses the appearance on state" {
  let pdf = @base64.decode(
    "JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgL0Fjcm9Gb3JtIDw8IC9GaWVsZHMgWzQgMCBSXSA+PiA+PgplbmRvYmoKMiAwIG9iago8PCAvVHlwZSAvUGFnZXMgL0tpZHMgWzMgMCBSXSAvQ291bnQgMSA+PgplbmRvYmoKMyAwIG9iago8PCAvVHlwZSAvUGFnZSAvUGFyZW50IDIgMCBSIC9NZWRpYUJveCBbMCAwIDIwMCAxMDBdIC9Bbm5vdHMgWzQgMCBSXSA+PgplbmRvYmoKNCAwIG9iago8PCAvVHlwZSAvQW5ub3QgL1N1YnR5cGUgL1dpZGdldCAvRlQgL0J0biAvVCAoYWdyZWUpIC9WIC9PZmYgL0FTIC9PZmYgL0FQIDw8IC9OIDw8IC9PbiA2IDAgUiAvT2ZmIDcgMCBSID4+ID4+IC9SZWN0IFsxMCAyMCAyMCAzMF0gL1AgMyAwIFIgPj4KZW5kb2JqCjUgMCBvYmoKPDwgPj4KZW5kb2JqCjYgMCBvYmoKPDwgPj4KZW5kb2JqCnhyZWYKMCA3CjAwMDAwMDAwMDAgNjU1MzUgZiAKMDAwMDAwMDAwOSAwMDAwMCBuIAowMDAwMDAwMDkwIDAwMDAwIG4gCjAwMDAwMDAxNDcgMDAwMDAgbiAKMDAwMDAwMDIzNCAwMDAwMCBuIAowMDAwMDAwMzkxIDAwMDAwIG4gCjAwMDAwMDA0MTIgMDAwMDAgbiAKdHJhaWxlcgo8PCAvU2l6ZSA3IC9Sb290IDEgMCBSID4+CnN0YXJ0eHJlZgo0MzMKJSVFT0YK",
  )
  let filled = fill_pdf(pdf, @utf8.encode("{\"agree\":true}"))
  let text = @utf8.decode_lossy(filled[:])
  assert_true(text.contains("/V /On"), msg=text)
  assert_true(text.contains("/AS /On"), msg=text)
}

///|
test "fill_pdf escapes literal parentheses" {
  let pdf = @base64.decode(
    "JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgL0Fjcm9Gb3JtIDw8IC9GaWVsZHMgWzQgMCBSXSA+PiA+PgplbmRvYmoKMiAwIG9iago8PCAvVHlwZSAvUGFnZXMgL0tpZHMgWzMgMCBSXSAvQ291bnQgMSA+PgplbmRvYmoKMyAwIG9iago8PCAvVHlwZSAvUGFnZSAvUGFyZW50IDIgMCBSIC9NZWRpYUJveCBbMCAwIDIwMCAxMDBdIC9Bbm5vdHMgWzQgMCBSXSA+PgplbmRvYmoKNCAwIG9iago8PCAvVHlwZSAvQW5ub3QgL1N1YnR5cGUgL1dpZGdldCAvRlQgL1R4IC9UIChuYW1lKSAvViAoT2xkKSAvUmVjdCBbMTAgMjAgMTAwIDQwXSAvUCAzIDAgUiA+PgplbmRvYmoKeHJlZgowIDUKMDAwMDAwMDAwMCA2NTUzNSBmIAowMDAwMDAwMDA5IDAwMDAwIG4gCjAwMDAwMDAwOTAgMDAwMDAgbiAKMDAwMDAwMDE0NyAwMDAwMCBuIAowMDAwMDAwMjM0IDAwMDAwIG4gCnRyYWlsZXIKPDwgL1NpemUgNSAvUm9vdCAxIDAgUiA+PgpzdGFydHhyZWYKMzQyCiUlRU9GCg==",
  )
  let value = "A(B)\\C"
  let filled = fill_pdf(pdf, @utf8.encode("{\"name\":\"A(B)\\\\C\"}"))
  let fields = read_fields(filled)
  assert_eq(fields.length(), 1)
  assert_eq(fields[0].value, value)
  let control = fill_pdf(pdf, @utf8.encode("{\"name\":\"A\\nB\\tC\"}"))
  assert_eq(read_fields(control)[0].value, "A\nB\tC")
}

///|
test "fill_pdf can skip read-only fields" {
  let pdf = @base64.decode(
    "JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgL0Fjcm9Gb3JtIDw8IC9GaWVsZHMgWzQgMCBSXSA+PiA+PgplbmRvYmoKMiAwIG9iago8PCAvVHlwZSAvUGFnZXMgL0tpZHMgWzMgMCBSXSAvQ291bnQgMSA+PgplbmRvYmoKMyAwIG9iago8PCAvVHlwZSAvUGFnZSAvUGFyZW50IDIgMCBSIC9NZWRpYUJveCBbMCAwIDIwMCAxMDBdIC9Bbm5vdHMgWzQgMCBSXSA+PgplbmRvYmoKNCAwIG9iago8PCAvVHlwZSAvQW5ub3QgL1N1YnR5cGUgL1dpZGdldCAvRlQgL1R4IC9UIChuYW1lKSAvViAoT2xkKSAvRmYgMSAvUmVjdCBbMTAgMjAgMTAwIDQwXSAvUCAzIDAgUiA+PgplbmRvYmoKeHJlZgowIDUKMDAwMDAwMDAwMCA2NTUzNSBmIAowMDAwMDAwMDA5IDAwMDAwIG4gCjAwMDAwMDAwOTAgMDAwMDAgbiAKMDAwMDAwMDE0NyAwMDAwMCBuIAowMDAwMDAwMjM0IDAwMDAwIG4gCnRyYWlsZXIKPDwgL1NpemUgNSAvUm9vdCAxIDAgUiA+PgpzdGFydHhyZWYKMzQ4CiUlRU9GCg==",
  )
  let skipped = fill_pdf(
    pdf,
    @utf8.encode("{\"name\":\"New\"}"),
    skip_read_only=true,
  )
  assert_eq(read_fields(skipped)[0].value, "Old")
  let filled = fill_pdf(pdf, @utf8.encode("{\"name\":\"New\"}"))
  assert_eq(read_fields(filled)[0].value, "New")
}

///|
test "fill_pdf updates files with xref streams" {
  let pdf = @base64.decode(
    "JVBERi0xLjUKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgL0Fjcm9Gb3JtIDw8IC9GaWVsZHMgWzQgMCBSXSA+PiA+PgplbmRvYmoKMiAwIG9iago8PCAvVHlwZSAvUGFnZXMgL0tpZHMgWzMgMCBSXSAvQ291bnQgMSA+PgplbmRvYmoKMyAwIG9iago8PCAvVHlwZSAvUGFnZSAvUGFyZW50IDIgMCBSIC9NZWRpYUJveCBbMCAwIDIwMCAxMDBdIC9Bbm5vdHMgWzQgMCBSXSA+PgplbmRvYmoKNCAwIG9iago8PCAvVHlwZSAvQW5ub3QgL1N1YnR5cGUgL1dpZGdldCAvRlQgL1R4IC9UIChuYW1lKSAvViAoT2xkKSAvUmVjdCBbMTAgMjAgMTAwIDQwXSAvUCAzIDAgUiA+PgplbmRvYmoKNSAwIG9iago8PCAvVHlwZSAvWFJlZiAvU2l6ZSA2IC9Sb290IDEgMCBSIC9XIFsxIDIgMV0gL0luZGV4IFswIDZdIC9MZW5ndGggMjQgPj4Kc3RyZWFtCgAAAAABAAkAAQBaAAEAkwABAOoAAQFWAAplbmRzdHJlYW0KZW5kb2JqCnN0YXJ0eHJlZgozNDIKJSVFT0YK",
  )
  let filled = fill_pdf(pdf, @utf8.encode("{\"name\":\"Alice\"}"))
  assert_eq(read_fields(filled)[0].value, "Alice")
  assert_true(@utf8.decode_lossy(filled[:]).contains("/Prev 342"))
}

///|
test "fill_pdf reads hexadecimal field names" {
  let pdf = @base64.decode(
    "JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgL0Fjcm9Gb3JtIDw8IC9GaWVsZHMgWzQgMCBSXSA+PiA+PgplbmRvYmoKMiAwIG9iago8PCAvVHlwZSAvUGFnZXMgL0tpZHMgWzMgMCBSXSAvQ291bnQgMSA+PgplbmRvYmoKMyAwIG9iago8PCAvVHlwZSAvUGFnZSAvUGFyZW50IDIgMCBSIC9NZWRpYUJveCBbMCAwIDIwMCAxMDBdIC9Bbm5vdHMgWzQgMCBSXSA+PgplbmRvYmoKNCAwIG9iago8PCAvVHlwZSAvQW5ub3QgL1N1YnR5cGUgL1dpZGdldCAvRlQgL1R4IC9UIDxGRUZGMzA0Mj4gL1JlY3QgWzEwIDIwIDEwMCA0MF0gL1AgMyAwIFIgPj4KZW5kb2JqCnhyZWYKMCA1CjAwMDAwMDAwMDAgNjU1MzUgZiAKMDAwMDAwMDAwOSAwMDAwMCBuIAowMDAwMDAwMDkwIDAwMDAwIG4gCjAwMDAwMDAxNDcgMDAwMDAgbiAKMDAwMDAwMDIzNCAwMDAwMCBuIAp0cmFpbGVyCjw8IC9TaXplIDUgL1Jvb3QgMSAwIFIgPj4Kc3RhcnR4cmVmCjMzNwolJUVPRgo=",
  )
  let fields = read_fields(pdf)
  assert_eq(fields.length(), 1)
  assert_eq(fields[0].name, "あ")
  let filled = fill_pdf(pdf, @utf8.encode("{\"あ\":\"Alice\"}"))
  let fields2 = read_fields(filled)
  assert_eq(fields2[0].value, "Alice")
  assert_true(@utf8.decode_lossy(filled[:]).contains("/V (Alice)"))
  let emoji = fill_pdf(pdf, @utf8.encode("{\"あ\":\"😀\"}"))
  assert_eq(read_fields(emoji)[0].value, "😀")
}

///|
test "fill_pdf maps choice display values" {
  let pdf = @base64.decode(
    "JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgL0Fjcm9Gb3JtIDw8IC9GaWVsZHMgWzQgMCBSXSA+PiA+PgplbmRvYmoKMiAwIG9iago8PCAvVHlwZSAvUGFnZXMgL0tpZHMgWzMgMCBSXSAvQ291bnQgMSA+PgplbmRvYmoKMyAwIG9iago8PCAvVHlwZSAvUGFnZSAvUGFyZW50IDIgMCBSIC9NZWRpYUJveCBbMCAwIDIwMCAxMDBdIC9Bbm5vdHMgWzQgMCBSXSA+PgplbmRvYmoKNCAwIG9iago8PCAvVHlwZSAvQW5ub3QgL1N1YnR5cGUgL1dpZGdldCAvRlQgL0NoIC9UIChjb2xvcikgL09wdCBbWyhSZWQpIChSKV0gWyhHcmVlbikgKEcpXV0gL1JlY3QgWzEwIDIwIDEwMCA0MF0gL1AgMyAwIFIgPj4KZW5kb2JqCnhyZWYKMCA1CjAwMDAwMDAwMDAgNjU1MzUgZiAKMDAwMDAwMDAwOSAwMDAwMCBuIAowMDAwMDAwMDkwIDAwMDAwIG4gCjAwMDAwMDAxNDcgMDAwMDAgbiAKMDAwMDAwMDIzNCAwMDAwMCBuIAp0cmFpbGVyCjw8IC9TaXplIDUgL1Jvb3QgMSAwIFIgPj4Kc3RhcnR4cmVmCjM2NwolJUVPRgo=",
  )
  let filled = fill_pdf(pdf, @utf8.encode("{\"color\":\"Red\"}"))
  let fields = read_fields(filled)
  assert_eq(fields[0].value, "R")
  let multi = fill_pdf(pdf, @utf8.encode("{\"color\":[\"Red\",\"Green\"]}"))
  assert_true(@utf8.decode_lossy(multi[:]).contains("[(R) (G)]"))
  assert_eq(read_fields(multi)[0].values, ["R", "G"])
}

///|
test "fill_pdf enforces maximum lengths" {
  let pdf = @base64.decode(
    "JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgL0Fjcm9Gb3JtIDw8IC9GaWVsZHMgWzQgMCBSXSA+PiA+PgplbmRvYmoKMiAwIG9iago8PCAvVHlwZSAvUGFnZXMgL0tpZHMgWzMgMCBSXSAvQ291bnQgMSA+PgplbmRvYmoKMyAwIG9iago8PCAvVHlwZSAvUGFnZSAvUGFyZW50IDIgMCBSIC9NZWRpYUJveCBbMCAwIDIwMCAxMDBdIC9Bbm5vdHMgWzQgMCBSXSA+PgplbmRvYmoKNCAwIG9iago8PCAvVHlwZSAvQW5ub3QgL1N1YnR5cGUgL1dpZGdldCAvRlQgL1R4IC9UIChuYW1lKSAvViAoT2xkKSAvTWF4TGVuIDMgL1JlY3QgWzEwIDIwIDEwMCA0MF0gL1AgMyAwIFIgPj4KZW5kb2JqCnhyZWYKMCA1CjAwMDAwMDAwMDAgNjU1MzUgZiAKMDAwMDAwMDAwOSAwMDAwMCBuIAowMDAwMDAwMDkwIDAwMDAwIG4gCjAwMDAwMDAxNDcgMDAwMDAgbiAKMDAwMDAwMDIzNCAwMDAwMCBuIAp0cmFpbGVyCjw8IC9TaXplIDUgL1Jvb3QgMSAwIFIgPj4Kc3RhcnR4cmVmCjM1MgolJUVPRgo=",
  )
  let filled = fill_pdf(pdf, @utf8.encode("{\"name\":\"Alice\"}"))
  assert_eq(read_fields(filled)[0].value, "Ali")
}

///|
test "pdf reports missing required fields" {
  let pdf = @base64.decode(
    "JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgL0Fjcm9Gb3JtIDw8IC9GaWVsZHMgWzQgMCBSXSA+PiA+PgplbmRvYmoKMiAwIG9iago8PCAvVHlwZSAvUGFnZXMgL0tpZHMgWzMgMCBSXSAvQ291bnQgMSA+PgplbmRvYmoKMyAwIG9iago8PCAvVHlwZSAvUGFnZSAvUGFyZW50IDIgMCBSIC9NZWRpYUJveCBbMCAwIDIwMCAxMDBdIC9Bbm5vdHMgWzQgMCBSXSA+PgplbmRvYmoKNCAwIG9iago8PCAvVHlwZSAvQW5ub3QgL1N1YnR5cGUgL1dpZGdldCAvRlQgL1R4IC9UIChub3RlKSAvRmYgMiAvUmVjdCBbMTAgMjAgMTAwIDQwXSAvUCAzIDAgUiA+PgplbmRvYmoKeHJlZgowIDUKMDAwMDAwMDAwMCA2NTUzNSBmIAowMDAwMDAwMDA5IDAwMDAwIG4gCjAwMDAwMDAwOTAgMDAwMDAgbiAKMDAwMDAwMDE0NyAwMDAwMCBuIAowMDAwMDAwMjM0IDAwMDAwIG4gCnRyYWlsZXIKPDwgL1NpemUgNSAvUm9vdCAxIDAgUiA+PgpzdGFydHhyZWYKMzM5CiUlRU9GCg==",
  )
  assert_eq(missing_required(pdf, @utf8.encode("{}")), ["note"])
  assert_eq(
    missing_required(pdf, @utf8.encode("{\"note\":\"Hello\"}")),
    [],
  )
  assert_eq(
    missing_required(pdf, @utf8.encode("{\"note\":[\"Hello\"]}")),
    [],
  )
}

///|
test "fill_pdf resolves appearance streams" {
  let pdf = @base64.decode(
    "JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgL0Fjcm9Gb3JtIDw8IC9GaWVsZHMgWzQgMCBSXSA+PiA+PgplbmRvYmoKMiAwIG9iago8PCAvVHlwZSAvUGFnZXMgL0tpZHMgWzMgMCBSXSAvQ291bnQgMSA+PgplbmRvYmoKMyAwIG9iago8PCAvVHlwZSAvUGFnZSAvUGFyZW50IDIgMCBSIC9NZWRpYUJveCBbMCAwIDIwMCAxMDBdIC9Bbm5vdHMgWzQgMCBSXSA+PgplbmRvYmoKNCAwIG9iago8PCAvVHlwZSAvQW5ub3QgL1N1YnR5cGUgL1dpZGdldCAvRlQgL0J0biAvVCAoYWdyZWUpIC9WIC9PZmYgL0FTIC9PZmYgL0FQIDw8IC9OIDUgMCBSID4+IC9SZWN0IFsxMCAyMCAyMCAzMF0gL1AgMyAwIFIgPj4KZW5kb2JqCjUgMCBvYmoKPDwgL09uIDYgMCBSIC9PZmYgNyAwIFIgPj4KZW5kb2JqCjYgMCBvYmoKPDwgL0xlbmd0aCAwID4+CnN0cmVhbQoKZW5kc3RyZWFtCmVuZG9iago3IDAgb2JqCjw8IC9MZW5ndGggMCA+PgpzdHJlYW0KCmVuZHN0cmVhbQplbmRvYmoKeHJlZgowIDgKMDAwMDAwMDAwMCA2NTUzNSBmIAowMDAwMDAwMDA5IDAwMDAwIG4gCjAwMDAwMDAwOTAgMDAwMDAgbiAKMDAwMDAwMDE0NyAwMDAwMCBuIAowMDAwMDAwMjM0IDAwMDAwIG4gCjAwMDAwMDAzNzAgMDAwMDAgbiAKMDAwMDAwMDQxMiAwMDAwMCBuIAowMDAwMDAwNDYxIDAwMDAwIG4gCnRyYWlsZXIKPDwgL1NpemUgOCAvUm9vdCAxIDAgUiA+PgpzdGFydHhyZWYKNTEwCiUlRU9GCg==",
  )
  let filled = fill_pdf(pdf, @utf8.encode("{\"agree\":true}"))
  let text = @utf8.decode_lossy(filled[:])
  assert_true(text.contains("/V /On"), msg=text)
  assert_true(text.contains("/AS /On"), msg=text)
}

