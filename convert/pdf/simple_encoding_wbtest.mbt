///|
fn check_pdf_simple_encoding(
  variant : Int32,
  expected : Array[(String, String)],
) -> Unit raise {
  let file : PdfFile = {
    data: b"",
    entries: {},
    objects: {},
    loading: {},
    object_streams: {},
    trailers: [],
    trailer: PdfNull,
  }
  let source : PdfObject? = match variant {
    0 => None
    1 => Some(PdfName(b"WinAnsiEncoding"))
    2 => Some(PdfName(b"MacRomanEncoding"))
    3 => Some(PdfName(b"MacExpertEncoding"))
    4 =>
      Some(
        PdfDict([
          (b"BaseEncoding", PdfName(b"WinAnsiEncoding")),
          (
            b"Differences",
            PdfArray([
              PdfInt(32L),
              PdfName(b"uni00A9"),
              PdfName(b"foo.alt"),
              PdfInt(65L),
              PdfName(b"zero"),
              PdfName(b"u1F600"),
              PdfInt(255L),
              PdfName(b"A"),
              PdfName(b"B"),
            ]),
          ),
        ]),
      )
    _ => Some(PdfName(b"Unknown"))
  }
  let encoding = file.simple_encoding(source)
  assert_eq(expected.length(), 256)
  for code in 0..<256 {
    let (name, unicode) = expected[code]
    assert_eq(
      encoding.name(code),
      name,
      msg="variant \{variant} code \{code} name",
    )
    assert_eq(
      encoding.unicode(code),
      unicode,
      msg="variant \{variant} code \{code} unicode",
    )
  }
}
