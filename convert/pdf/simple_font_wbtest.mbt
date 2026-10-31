///|
fn check_pdf_simple_font(
  variant : Int32,
  family : String,
  weight : Int32,
  style : Int32,
  widths : Array[Double],
) -> Unit raise {
  let file : PdfFile = {
    data: b"",
    entries: {},
    objects: {},
    loading: {},
    object_streams: {},
    trailers: [],
    trailer: PdfNull,
    font_cache: Map([]),
    default_font: None,
  }
  let fonts : Array[PdfObject] = [
    PdfDict([
      (b"Subtype", PdfName(b"Type1")),
      (b"BaseFont", PdfName(b"Helvetica")),
    ]),
    PdfDict([
      (b"Subtype", PdfName(b"TrueType")),
      (b"BaseFont", PdfName(b"Courier-BoldOblique")),
    ]),
    PdfDict([
      (b"Subtype", PdfName(b"Type1")),
      (b"BaseFont", PdfName(b"ABCDEF+Times-Roman")),
      (
        b"FontDescriptor",
        PdfDict([(b"FontWeight", PdfInt(480L)), (b"Flags", PdfInt(64L))]),
      ),
    ]),
    PdfDict([
      (b"Subtype", PdfName(b"Type1")),
      (b"BaseFont", PdfName(b"Helvetica")),
      (
        b"FontDescriptor",
        PdfDict([(b"Flags", PdfInt(2L)), (b"StemV", PdfInt(130L))]),
      ),
    ]),
    PdfDict([
      (b"Subtype", PdfName(b"Type1")),
      (b"BaseFont", PdfName(b"Symbol-Heavy")),
      (b"FontDescriptor", PdfDict([(b"Flags", PdfInt(1L))])),
    ]),
    PdfDict([
      (b"Subtype", PdfName(b"Type1")),
      (b"BaseFont", PdfName(b"A+BCDE+Times-Light")),
      (b"FontDescriptor", PdfDict([(b"ItalicAngle", PdfInt(-10L))])),
    ]),
    PdfDict([
      (b"Subtype", PdfName(b"Type1")),
      (b"BaseFont", PdfName(b"Arial")),
      (b"FirstChar", PdfInt(65L)),
      (b"Widths", PdfArray([PdfInt(400L), PdfInt(0L), PdfName(b"bad")])),
      (b"FontDescriptor", PdfDict([(b"MissingWidth", PdfInt(500L))])),
    ]),
  ]
  let font = file.simple_font(fonts[variant])
  assert_eq(font.family, family, msg="font \{variant} family")
  assert_eq(font.weight, weight, msg="font \{variant} weight")
  assert_eq(font.style, style, msg="font \{variant} style")
  for code in 0..<256 {
    assert_eq(
      font.width(code),
      widths[code],
      msg="font \{variant} code \{code}",
    )
  }
}

///|
test "embedded and unsupported composite PDF fonts fail closed" {
  let file : PdfFile = {
    data: b"",
    entries: {},
    objects: {
      1L: { value: PdfDict([]), stream: Some(b"data"), },
      2L: {
        value: PdfDict([(b"WMode", PdfInt(1L))]),
        stream: Some(b"/Identity-H usecmap"),
      },
    },
    loading: {},
    object_streams: {},
    trailers: [],
    trailer: PdfNull,
    font_cache: Map([]),
    default_font: None,
  }
  let embedded = PdfDict([
    (b"FontDescriptor", PdfDict([(b"FontFile2", PdfRef(1L, 0L))])),
  ])
  let composite_embedded = PdfDict([
    (b"Subtype", PdfName(b"Type0")),
    (b"Encoding", PdfName(b"Identity-H")),
    (
      b"DescendantFonts",
      PdfArray([
        PdfDict([(b"FontDescriptor", PdfDict([(b"FontFile2", PdfRef(1L, 0L))]))]),
      ]),
    ),
  ])
  assert_true(
    try {
      ignore(file.simple_font(composite_embedded))
      false
    } catch {
      _ => true
    },
  )
  let vertical_cmap = PdfDict([
    (b"Subtype", PdfName(b"Type0")),
    (b"Encoding", PdfRef(2L, 0L)),
  ])
  let vertical = file.simple_font(vertical_cmap)
  assert_true(
    match vertical.composite_map {
      Some(map) => map.vertical
      None => false
    },
  )
  let composite = PdfDict([
    (b"Subtype", PdfName(b"Type0")),
    (b"Encoding", PdfName(b"Identity-V")),
  ])
  assert_true(
    try {
      ignore(file.simple_font(embedded))
      false
    } catch {
      _ => true
    },
  )
  let vertical = file.simple_font(composite)
  assert_true(
    match vertical.composite_map {
      Some(map) => map.vertical
      None => false
    },
  )
}

///|
test "PDF simple font ToUnicode overrides its encoding" {
  let cmap = b"1 begincodespacerange <00> <ff> endcodespacerange 1 beginbfchar <41> <03a9> endbfchar"
  let file : PdfFile = {
    data: b"",
    entries: {},
    objects: { 1L: { value: PdfDict([]), stream: Some(cmap), } },
    loading: {},
    object_streams: {},
    trailers: [],
    trailer: PdfNull,
    font_cache: Map([]),
    default_font: None,
  }
  let dict = PdfDict([
    (b"Subtype", PdfName(b"Type1")),
    (b"BaseFont", PdfName(b"Helvetica")),
    (b"ToUnicode", PdfRef(1L, 0L)),
  ])
  let font = file.simple_font(dict)
  assert_eq(font.unicode(65), "Ω")
  assert_eq(font.unicode(66), "B")
}
