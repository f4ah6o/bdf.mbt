///|
test "PDF CMap codes and Unicode" {
  let cm = pdf_parse_cmap(
    b"1 begincodespacerange <0000> <FFFF> endcodespacerange 2 beginbfchar <0003> <0041> <0004> <00660069> endbfchar 2 beginbfrange <0010> <0012> <0061> <0020> <0021> [<0078> <0079>] endbfrange",
    None,
  )
  assert_eq(cm.to_unicode(3L), "A")
  assert_eq(cm.to_unicode(4L), "fi")
  assert_eq(cm.to_unicode(17L), "b")
  assert_eq(cm.to_unicode(33L), "y")
  assert_eq(cm.decode(b"\x00\x03\x00\x11"), [
    { code: 3L, size: 2, cid: 0L, },
    { code: 17L, size: 2, cid: 0L, },
  ])
}

///|
test "PDF CMap CID ranges and identity parent" {
  let cm = pdf_parse_cmap(
    b"1 begincodespacerange <00> <80> <8140> <9ffc> endcodespacerange 1 begincidrange <8140> <8150> 633 endcidrange",
    None,
  )
  assert_eq(cm.decode(b"\x41\x81\x42"), [
    { code: 65L, size: 1, cid: 0L, },
    { code: 33090L, size: 2, cid: 635L, },
  ])
  let identity = pdf_parse_cmap(b"/Identity-V usecmap", None)
  assert_true(identity.vertical)
  assert_eq(identity.decode(b"\x81\x42"), [
    { code: 33090L, size: 2, cid: 33090L, },
  ])
  let unknown = pdf_parse_cmap(b"/Definitely-Missing-H usecmap", None)
  assert_true(unknown.unresolved_parent)
}
