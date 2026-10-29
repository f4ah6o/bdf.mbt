///|
test "CSV BOM takes priority over a requested character encoding" {
  assert_eq(decode_text(b"\xef\xbb\xbfa,b", charset="cp932"), {
    text: "a,b",
    charset: "UTF-8",
    bom: true,
  })
  assert_eq(
    decode_text(b"\xff\xfe\x00\x00a\x00\x00\x00,\x00\x00\x00b\x00\x00\x00"),
    { text: "a,b", charset: "UTF-32LE", bom: true, },
  )
  assert_eq(
    decode_text(b"\x00\x00\xfe\xff\x00\x00\x00a\x00\x00\x00,\x00\x00\x00b"),
    { text: "a,b", charset: "UTF-32BE", bom: true, },
  )
}

///|
test "CSV UTF decoders match upstream malformed byte handling" {
  assert_eq(csv_decode_utf8(b"a\xff\xfe\x80b\xc3"), "a�b�")
  assert_eq(csv_decode_utf8(b"\xf0\x90\x80\x80\xff\xe3\x81"), "𐀀�")
  assert_eq(
    csv_decode_utf32(b"\x00\xd8\x00\x00\x00\x00\x11\x00x", true),
    "���",
  )
  assert_true(csv_mostly_utf8(@utf8.encode("名前,説明\n")))
  assert_false(csv_mostly_utf8(b"abc\xc3"))
}

///|
test "CSV named charset aliases are normalized" {
  assert_eq(csv_charset_name(" cp932 "), "Shift_JIS")
  assert_eq(csv_charset_name("eucjp"), "EUC-JP")
  assert_eq(csv_charset_name("gb2312"), "GBK")
  assert_eq(csv_charset_name("latin1"), "WINDOWS-1252")
  let error = try {
    ignore(csv_charset_name("klingon"))
    ""
  } catch {
    InvalidDialect(detail) => detail
    _ => "unexpected error"
  }
  assert_eq(error, "csv: unknown character encoding \"klingon\"")
}

///|
test "CSV Japanese decoders follow Go's invalid-byte consumption" {
  assert_eq(csv_decode_charset(b"\x82\x40", "Shift_JIS"), "�")
  assert_eq(csv_decode_charset(b"\x81\x20", "Shift_JIS"), "� ")
  assert_eq(csv_decode_charset(b"\xf0\x40", "Shift_JIS"), "�")
  assert_eq(csv_decode_charset(b"\x8e\x80", "EUC-JP"), "��")
  assert_eq(csv_decode_charset(b"\x8f\xa1\x20", "EUC-JP"), "� ")
  assert_eq(
    csv_decode_charset(b"\x81\x8d\x8f\x90\x9d", "WINDOWS-1252"),
    "�����",
  )
}
