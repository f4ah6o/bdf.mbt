///|
fn check_pdf_pages(
  name : String,
  chunks : Array[String],
  left : Int32,
  expected : Array[
    (
      Int64?,
      (Double, Double, Double, Double)?,
      (Double, Double, Double, Double)?,
      Int32,
      Bool,
      String?,
      Int32,
      UInt64,
    ),
  ],
) -> Unit raise {
  let joined = StringBuilder()
  for chunk in chunks {
    joined.write_string(chunk)
  }
  let compressed = @base64.decode(joined.to_string()[:])
  let input = @gzip.decompress(compressed[:])
  let file = pdf_open_file(input)
  let (pages, actual_left) = file.page_leaves()
  assert_eq(actual_left, left, msg=name)
  assert_eq(pages.length(), expected.length(), msg=name)
  for i in 0..<expected.length() {
    let (id, media, crop, rotate, resources, error, length, digest) = expected[i]
    let page = pages[i]
    let actual_id = match page.reference {
      Some(PdfRef(number, _)) => Some(number)
      _ => None
    }
    assert_eq(actual_id, id, msg="\{name} page \{i} reference")
    assert_eq(page.attrs.media, media, msg="\{name} page \{i} media")
    assert_eq(page.attrs.crop, crop, msg="\{name} page \{i} crop")
    assert_eq(page.attrs.rotate, rotate, msg="\{name} page \{i} rotate")
    assert_eq(
      page.attrs.resources is Some(_),
      resources,
      msg="\{name} page \{i} resources",
    )
    assert_eq(page.error, error, msg="\{name} page \{i} error")
    let content = file.page_content(page.dict)
    assert_eq(content.length(), length, msg="\{name} page \{i} content length")
    let mut hash = 14695981039346656037UL
    for byte in content {
      hash = (hash ^ byte.to_uint64()) * 1099511628211UL
    }
    assert_eq(hash, digest, msg="\{name} page \{i} content bytes")
  }
}

///|
test "PDF page tree inheritance, repeated pages and cycles" {
  let kids : Array[PdfObject] = [PdfRef(3L, 0L), PdfRef(4L, 0L)]
  for _ in 0..<18 {
    kids.push(PdfRef(3L, 0L))
  }
  let catalog = PdfDict([(b"Pages", PdfRef(2L, 0L))])
  let tree = PdfDict([
    (b"Type", PdfName(b"Pages")),
    (b"Kids", PdfArray(kids)),
    (
      b"MediaBox",
      PdfArray([PdfInt(0L), PdfInt(0L), PdfInt(600L), PdfInt(800L)]),
    ),
    (b"Rotate", PdfReal(-1.5)),
    (b"Resources", PdfDict([])),
  ])
  let first = PdfDict([
    (b"Type", PdfName(b"Page")),
    (
      b"CropBox",
      PdfArray([PdfInt(10L), PdfInt(20L), PdfInt(500L), PdfInt(700L)]),
    ),
  ])
  let nested = PdfDict([
    (b"Type", PdfName(b"Pages")),
    (b"Kids", PdfArray([PdfRef(2L, 0L), PdfRef(5L, 0L)])),
    (b"MediaBox", PdfName(b"bad")),
    (b"Rotate", PdfInt(90L)),
  ])
  let second = PdfDict([
    (b"Type", PdfName(b"Page")),
    (b"Rotate", PdfInt(180L)),
    (b"Resources", PdfNull),
  ])
  let file : PdfFile = {
    data: b"",
    entries: {},
    objects: {
      1L: { value: catalog, stream: None, },
      2L: { value: tree, stream: None, },
      3L: { value: first, stream: None, },
      4L: { value: nested, stream: None, },
      5L: { value: second, stream: None, },
    },
    loading: {},
    object_streams: {},
    trailers: [PdfDict([(b"Root", PdfRef(1L, 0L))])],
    trailer: PdfNull,
  }
  let (pages, left) = file.page_leaves()
  assert_eq(pages.length(), 18)
  assert_eq(left, 2)
  assert_eq(pages[0].attrs.media, Some((0.0, 0.0, 600.0, 800.0)))
  assert_eq(pages[0].attrs.crop, Some((10.0, 20.0, 500.0, 700.0)))
  assert_eq(pages[0].attrs.rotate, -2)
  assert_true(pages[0].attrs.resources is Some(_))
  assert_eq(pages[1].error, Some("/MediaBox is not a rectangle"))
  assert_eq(pages[1].attrs.rotate, 180)
  assert_true(pages[1].attrs.resources is None)
}

///|
test "PDF page content combines decoded streams and skips null references" {
  let first = PdfDict([(b"Filter", PdfName(b"ASCIIHexDecode"))])
  let second = PdfDict([])
  let file : PdfFile = {
    data: b"",
    entries: {},
    objects: {
      1L: { value: first, stream: Some(b"343220>"), },
      2L: { value: second, stream: Some(b"0 0 m"), },
    },
    loading: {},
    object_streams: {},
    trailers: [],
    trailer: PdfNull,
  }
  let page = PdfDict([
    (b"Contents", PdfArray([PdfRef(1L, 0L), PdfNull, PdfRef(2L, 0L)])),
  ])
  assert_eq(file.page_content(page), b"42 0 0 m")
  let bad = PdfDict([(b"Contents", PdfArray([PdfInt(1L)]))])
  let rejected = try {
    ignore(file.page_content(bad))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "PDF page stream accepts indirect filter names and parameters" {
  let dict = PdfDict([
    (b"Filter", PdfRef(2L, 0L)),
    (b"DecodeParms", PdfRef(3L, 0L)),
  ])
  let file : PdfFile = {
    data: b"",
    entries: {},
    objects: {
      1L: { value: dict, stream: Some(b"3432>"), },
      2L: { value: PdfName(b"ASCIIHexDecode"), stream: None, },
      3L: { value: PdfDict([]), stream: None, },
    },
    loading: {},
    object_streams: {},
    trailers: [],
    trailer: PdfNull,
  }
  assert_eq(file.page_content(PdfDict([(b"Contents", PdfRef(1L, 0L))])), b"42")
}
