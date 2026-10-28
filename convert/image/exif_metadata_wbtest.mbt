///|
test "EXIF metadata decodes names, alternatives, rights and dates" {
  let fields : ExifFields = {
    little: true,
    orientation: 6,
    primary: {
      0x013b: b"Ann; Bob\x00",
      0x010e: b"OLYMPUS DIGITAL CAMERA\x00",
      0x9c9f: b"C\x00a\x00t\x00\x00\x00",
      0x8298: b"Ann\x00Bob\x00",
      0x0132: b"2026:09:02 08:00:00\x00",
    },
    exif: { 0x9003: b"2026:09:01 10:20:30\x00", 0x9011: b"+09:00\x00" },
  }
  let dc = exif_metadata(fields)
  assert_eq(dc.get("creator"), Some(["Ann", "Bob"]))
  assert_eq(dc.get("description"), Some(["Cat"]))
  assert_eq(dc.get("rights"), Some(["Ann", "Bob"]))
  assert_eq(dc.get("created"), Some(["2026-09-01T10:20:30+09:00"]))
  assert_eq(dc.get("modified"), Some(["2026-09-02T08:00:00"]))
}
