///|
test "IPTC extracts multiple creators, subjects and a timestamp" {
  let data = b"\x1c\x02\x05\x00\x04Name\x1c\x02\x50\x00\x03Ann\x1c\x02\x50\x00\x03Bob\x1c\x02\x19\x00\x03sky\x1c\x02\x37\x00\x0820260831\x1c\x02\x3c\x00\x0b184500+0900"
  let dc = iptc_metadata(data)
  assert_eq(dc.get("title"), Some(["Name"]))
  assert_eq(dc.get("creator"), Some(["Ann", "Bob"]))
  assert_eq(dc.get("subject"), Some(["sky"]))
  assert_eq(dc.get("created"), Some(["2026-08-31T18:45:00+09:00"]))
}
