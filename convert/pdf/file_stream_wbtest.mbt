///|
// Build a one-page PDF whose content stream body is `body` and whose /Length
// entry is `declared`. `indirect` writes the length as a separate object and
// `eol` writes the line end before `endstream`; without it the declared length
// can run into the keyword itself.
fn pdf_stream_length_document(
  body : Bytes,
  declared : Int,
  indirect : Bool,
  eol : Bool,
) -> Bytes {
  let length = if indirect { "4 0 R" } else { declared.to_string() }
  let stream = @buffer.Buffer()
  stream.write_string_utf8("<< /Length " + length + " >>\nstream\n")
  stream.write_bytesview(body[:])
  if eol {
    stream.write_string_utf8("\n")
  }
  stream.write_string_utf8("endstream")
  pdf_test_pdf([
    b"<< /Type /Catalog /Pages 2 0 R >>",
    b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Resources << /Font << /F1 6 0 R >> >> /Contents 5 0 R >>",
    @utf8.encode(declared.to_string()),
    stream.to_bytes(),
    b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
  ])
}

///|
// The bytes the reader hands to the content interpreter for the first page.
fn pdf_stream_length_content(data : Bytes) -> Bytes raise {
  let file = pdf_open_file(data)
  let (pages, _) = file.page_leaves()
  file.page_content(pages[0].dict)
}

///|
test "PDF stream length matching the data keeps every byte" {
  let body = b"0 0 200 200 re f"
  let data = pdf_stream_length_document(body, body.length(), false, false)
  assert_eq(
    pdf_stream_length_content(data),
    body,
    msg="PDF stream length exact",
  )
}

///|
test "PDF stream length one past the data trims the endstream keyword" {
  // The reported file: a 38-byte stream declared as 39 with no line end before
  // the keyword, so the keyword's `e` used to become an operator.
  let body = b"BT /F1 12 Tf 20 100 Td (Hello) Tj"
  let data = pdf_stream_length_document(body, body.length() + 1, false, false)
  assert_eq(
    pdf_stream_length_content(data),
    body,
    msg="PDF stream length one past",
  )
}

///|
test "PDF stream length inside the endstream keyword trims every overlap" {
  let body = b"0 0 200 200 re f"
  for taken in 1..=8 {
    let data = pdf_stream_length_document(
      body,
      body.length() + taken,
      false,
      false,
    )
    assert_eq(
      pdf_stream_length_content(data),
      body,
      msg="PDF stream length overlap \{taken}",
    )
  }
}

///|
test "PDF stream length past the endstream keyword is not recovered" {
  // Recovery stops at the keyword: a length that swallows all of it is left
  // alone rather than guessed from a marker inside the data.
  let body = b"0 0 200 200 re f"
  let data = pdf_stream_length_document(body, body.length() + 9, false, false)
  assert_eq(
    pdf_stream_length_content(data).length(),
    body.length() + 9,
    msg="PDF stream length past the keyword",
  )
}

///|
test "PDF stream length one past the data keeps a line end" {
  // With a line end before the keyword the extra byte is that line end, not
  // part of `endstream`, so it stays in the data as upstream reads it.
  let body = b"0 0 200 200 re f"
  let data = pdf_stream_length_document(body, body.length() + 1, false, true)
  assert_eq(
    pdf_stream_length_content(data),
    body + b"\n",
    msg="PDF stream length line end",
  )
}

///|
test "PDF stream length short of the data keeps the declared bytes" {
  let body = b"0 0 200 200 re f"
  let data = pdf_stream_length_document(body, body.length() - 1, false, false)
  assert_eq(
    pdf_stream_length_content(data),
    body[:body.length() - 1].to_owned(),
    msg="PDF stream length short",
  )
}

///|
test "PDF stream length past the file is rejected" {
  let body = b"0 0 200 200 re f"
  let data = pdf_stream_length_document(
    body,
    body.length() + 1000,
    false,
    false,
  )
  let file = pdf_open_file(data)
  let rejected = try {
    ignore(file.load(5L, 0))
    false
  } catch {
    InvalidStream(message) => message.contains("exceeds file")
    _ => false
  }
  assert_true(rejected, msg="PDF stream length past the file")
}

///|
test "PDF stream length keeps a binary payload with a false marker" {
  // The payload contains the keyword itself; a correct length must not trim at
  // the false marker.
  let body = b"q 1 0 0 1 0 0 cm endstream Q"
  let data = pdf_stream_length_document(body, body.length(), false, false)
  assert_eq(
    pdf_stream_length_content(data),
    body,
    msg="PDF stream binary false marker",
  )
}

///|
test "PDF stream length one past a binary payload trims only the keyword" {
  let body = b"q 1 0 0 1 0 0 cm endstream Q"
  let data = pdf_stream_length_document(body, body.length() + 1, false, false)
  assert_eq(
    pdf_stream_length_content(data),
    body,
    msg="PDF stream binary false marker with a long length",
  )
}

///|
test "PDF stream length indirect one past the data trims the keyword" {
  let body = b"0 0 200 200 re f"
  let data = pdf_stream_length_document(body, body.length() + 1, true, false)
  assert_eq(
    pdf_stream_length_content(data),
    body,
    msg="PDF stream length indirect",
  )
}

///|
test "PDF stream length one past the data converts the page" {
  let body = b"BT /F1 12 Tf 20 100 Td (Hello) Tj"
  let data = pdf_stream_length_document(body, body.length() + 1, false, false)
  let result = convert(data)
  assert_eq(result.pages, 1, msg="PDF stream length page count")
}

///|
test "PDF cross-reference stream length inside endstream trims the keyword" {
  let body = b"0 0 200 200 re f"
  let out = @buffer.Buffer()
  out.write_string_utf8("5 0 obj\n<< /Length \{body.length() + 1} >>\nstream\n")
  out.write_bytesview(body[:])
  out.write_string_utf8("endstream\nendobj\n")
  let data = out.to_bytes()
  let file : PdfFile = {
    data,
    entries: Map([]),
    objects: Map([]),
    loading: Map([]),
    object_streams: Map([]),
    trailers: [],
    trailer: PdfNull,
    font_cache: Map([]),
    default_font: None,
    encryption: None,
  }
  let (_, stream) = file.read_direct_stream(0L)
  assert_eq(stream, body, msg="PDF cross-reference stream length")
}
