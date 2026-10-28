///|
test "EXIF text uses UTF-8 or Latin-1 and stops at NUL" {
  assert_eq(metadata_text(b" \xc2\xa9 Ann\x00hidden"), "© Ann")
  assert_eq(metadata_text(b"\xe9"), "é")
  assert_eq(metadata_utf16(b"A\x00\x3d\xd8\x00\xde\x00\x00", true), "A😀")
  assert_eq(metadata_utf16(b"\xd8\x00\x00\x41", false), "�A")
}

///|
test "EXIF dates use a timezone only when absent" {
  assert_eq(
    metadata_exif_date("2026:09:01 10:20:30", "+09:00"),
    "2026-09-01T10:20:30+09:00",
  )
  assert_eq(
    metadata_exif_date("2026:09:01 10:20:30Z", "+09:00"),
    "2026-09-01T10:20:30Z",
  )
  assert_eq(metadata_exif_date("0000:00:00 00:00:00", "+09:00"), "")
}

///|
test "invalid UTF-8 is removed without removing encoded replacement characters" {
  assert_eq(metadata_valid_utf8(b"A\xff\xef\xbf\xbd\xc3B"), "A�B")
}
