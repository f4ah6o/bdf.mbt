///|
fn pdf_type3_test_document() -> Bytes {
  let out : Array[Byte] = []
  let offsets : Array[Int] = []
  pdf_jpx_test_append(out, "%PDF-1.7\n")
  offsets.push(out.length())
  pdf_jpx_test_append(
    out,
    "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n",
  )
  offsets.push(out.length())
  pdf_jpx_test_append(
    out,
    "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n",
  )
  offsets.push(out.length())
  pdf_jpx_test_append(
    out,
    "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>\nendobj\n",
  )
  offsets.push(out.length())
  pdf_jpx_test_append(
    out,
    "4 0 obj\n<< /Type /Font /Subtype /Type3 /FontBBox [0 0 1000 1000] /FontMatrix [0.001 0 0 0.001 0 0] /CharProcs << /square 6 0 R >> /Encoding << /Type /Encoding /Differences [65 /square] >> /FirstChar 65 /LastChar 65 /Widths [1000] /Resources << >> >>\nendobj\n",
  )
  let content = "BT /F1 20 Tf 20 20 Td (A) Tj ET"
  offsets.push(out.length())
  pdf_jpx_test_append(
    out,
    "5 0 obj\n<< /Length \{content.length()} >>\nstream\n\{content}\nendstream\nendobj\n",
  )
  let glyph = "0 0 1000 1000 re f"
  offsets.push(out.length())
  pdf_jpx_test_append(
    out,
    "6 0 obj\n<< /Length \{glyph.length()} >>\nstream\n\{glyph}\nendstream\nendobj\n",
  )
  let xref = out.length()
  pdf_jpx_test_append(out, "xref\n0 \{offsets.length() + 1}\n0000000000 65535 f \n")
  for offset in offsets {
    pdf_jpx_test_append(out, pdf_jpx_test_offset(offset) + " 00000 n \n")
  }
  pdf_jpx_test_append(
    out,
    "trailer\n<< /Size \{offsets.length() + 1} /Root 1 0 R >>\nstartxref\n\{xref}\n%%EOF\n",
  )
  Bytes::from_array(out)
}

///|
test "PDF Type3 font exposes glyph procedures" {
  let data = pdf_type3_test_document()
  let file = pdf_open_file(data)
  let font = file.simple_font(PdfRef(4L, 0L))
  assert_true(font.type3, msg="Type3 font flag")
  let (_, raw) = file.type3_glyph_stream(font, 65).unwrap()
  assert_eq(
    @utf8.decode_lossy(raw[:]),
    "0 0 1000 1000 re f",
    msg="Type3 glyph stream",
  )
}

///|
test "PDF Type3 glyph procedures render through the graphics document" {
  let document = pdf_graphics_document(
    pdf_type3_test_document(),
    no_text_index=true,
  )
  assert_true(document.length() > 0, msg="Type3 document bytes")
}
