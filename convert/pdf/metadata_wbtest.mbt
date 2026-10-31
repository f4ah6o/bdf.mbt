///|
fn check_pdf_metadata(
  name : String,
  chunks : Array[String],
  title : String,
  creator : String,
  description : String,
  subjects : Array[String],
  created : String,
  modified : String,
) -> Unit raise {
  let joined = StringBuilder()
  for chunk in chunks {
    joined.write_string(chunk)
  }
  let compressed = @base64.decode(joined.to_string()[:])
  let input = @gzip.decompress(compressed[:])
  let file = pdf_open_file(input)
  assert_eq(
    file.metadata(),
    { title, creator, description, subjects, created, modified, },
    msg=name,
  )
}

///|
test "PDF metadata decodes text and separates keywords" {
  let info = PdfDict([
    (b"Title", PdfHex(b"\xfe\xff\x00\x20\x00\x54\x00\x20")),
    (b"Author", PdfString(b" Alice ")),
    (b"Subject", PdfString(b" Example ")),
    (b"Keywords", PdfString(b" one, two ; three ")),
    (b"CreationDate", PdfString(b"D:20241015123000+09'00'")),
  ])
  let file : PdfFile = {
    data: b"",
    entries: {},
    objects: { 1L: { value: info, stream: None, } },
    loading: {},
    object_streams: {},
    trailers: [PdfDict([(b"Info", PdfRef(1L, 0L))])],
    trailer: PdfNull,
    font_cache: Map([]),
    default_font: None,
  }
  assert_eq(file.metadata(), {
    title: "T",
    creator: "Alice",
    description: "Example",
    subjects: ["one", "two", "three"],
    created: "2024-10-15T12:30:00+09:00",
    modified: "",
  })
  assert_eq(pdf_metadata_keywords(" pdf， bdf ；canvas、検索; "), [
    "pdf", "bdf", "canvas", "検索",
  ])
}
