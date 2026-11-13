///|
fn encoding_fixture(header : String, value : Bytes) -> Bytes {
  let prefix = @utf8.encode(
    "0\nSECTION\n2\nHEADER\n" +
    header +
    "0\nENDSEC\n0\nSECTION\n2\nENTITIES\n0\nTEXT\n1\n",
  )
  prefix + value + b"\n0\nENDSEC\n0\nEOF\n"
}

///|
test "unlabelled and default-codepage Shift_JIS text uses upstream evidence" {
  let sjis = b"\x83\x65\x83\x58\x83\x67\x82\xcc\x95\xb6\x8e\x9a"
  for
    header in [
      "", "9\n$DWGCODEPAGE\n3\nANSI_1252\n", "9\n$DWGCODEPAGE\n3\nDOS932\n",
    ] {
    let tags = read_tags(encoding_fixture(header, sjis))
    assert_true(tags.any(t => t.code == 1 && t.s == "テストの文字"))
  }
}

///|
test "valid UTF8 overrides a legacy Shift_JIS declaration" {
  let text = "Größe 字"
  let tags = read_tags(
    encoding_fixture("9\n$DWGCODEPAGE\n3\nANSI_932\n", @utf8.encode(text)),
  )
  assert_true(tags.any(t => t.code == 1 && t.s == text))
}

///|
test "modern DXF does not infer Shift_JIS and entity tokens are not headers" {
  let sjis = b"\x83\x65\x83\x58"
  let modern = dxf_decode_text(
    encoding_fixture("9\n$ACADVER\n1\nAC1021\n", sjis),
  )
  assert_true(!modern.contains("テス"))
  assert_true(
    dxf_decode_text(encoding_fixture("", b"ANSI_932 \xe4\xf6\xdf")).contains(
      "�",
    ),
  )
}

///|
test "ambiguous halfwidth and invalid pairs do not trigger Japanese inference" {
  for value in [b"\xb6\xc0\xb6\xc5", b"\x83\x65\x83\x58\xff", b"\xe4\xf6\xdf"] {
    assert_eq(
      dxf_decode_text(encoding_fixture("", value)),
      @utf8.decode_lossy(encoding_fixture("", value)),
    )
  }
}

///|
test "explicit other codepages do not infer Japanese" {
  let data = encoding_fixture(
    "9\n$DWGCODEPAGE\n3\nANSI_1251\n", b"\x83\x65\x83\x58",
  )
  assert_eq(dxf_decode_text(data), @utf8.decode_lossy(data))
}

///|
test "codepage is read after a long header" {
  let header = "999\n" + "x".repeat(9000) + "\n9\n$DWGCODEPAGE\n3\nANSI_932\n"
  let tags = read_tags(encoding_fixture(header, b"\x83\x65"))
  assert_true(tags.any(t => t.code == 1 && t.s == "テ"))
}
