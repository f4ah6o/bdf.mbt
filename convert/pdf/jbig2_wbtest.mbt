///|
fn pdf_jbig2_test_append(out : Array[Byte], value : Int) -> Unit {
  out.push(value.to_byte())
}

///|
fn pdf_jbig2_test_u32(out : Array[Byte], value : Int) -> Unit {
  out.push(((value >> 24) & 0xff).to_byte())
  out.push(((value >> 16) & 0xff).to_byte())
  out.push(((value >> 8) & 0xff).to_byte())
  out.push((value & 0xff).to_byte())
}

///|
fn pdf_jbig2_test_stream() -> Bytes {
  let out : Array[Byte] = []
  // Page information segment: one white pixel.
  pdf_jbig2_test_u32(out, 0)
  pdf_jbig2_test_append(out, 0x30)
  pdf_jbig2_test_append(out, 0x00)
  pdf_jbig2_test_append(out, 1)
  pdf_jbig2_test_u32(out, 19)
  pdf_jbig2_test_u32(out, 1)
  pdf_jbig2_test_u32(out, 1)
  pdf_jbig2_test_u32(out, 0)
  pdf_jbig2_test_u32(out, 0)
  pdf_jbig2_test_append(out, 0)
  pdf_jbig2_test_append(out, 0)
  pdf_jbig2_test_append(out, 0)
  // Immediate generic region with MMR data for one black pixel.
  pdf_jbig2_test_u32(out, 1)
  pdf_jbig2_test_append(out, 0x24)
  pdf_jbig2_test_append(out, 0x00)
  pdf_jbig2_test_append(out, 1)
  pdf_jbig2_test_u32(out, 19)
  pdf_jbig2_test_u32(out, 1)
  pdf_jbig2_test_u32(out, 1)
  pdf_jbig2_test_u32(out, 0)
  pdf_jbig2_test_u32(out, 0)
  pdf_jbig2_test_append(out, 1)
  pdf_jbig2_test_append(out, 0x26)
  pdf_jbig2_test_append(out, 0xa8)
  Bytes::from_array(out)
}

///|
test "PDF JBIG2 MMR generic region decodes a black pixel" {
  let (width, height, bits) = pdf_jbig2_decode(pdf_jbig2_test_stream())
  assert_eq(width, 1, msg="JBIG2 width")
  assert_eq(height, 1, msg="JBIG2 height")
  assert_true((bits[0].to_int() & 0x80) != 0, msg="JBIG2 black pixel")
}

///|
test "PDF JBIG2 image renders through the graphics document" {
  let jbig2 = pdf_jbig2_test_stream()
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
    "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Resources << /XObject << /Im1 4 0 R >> >> /Contents 5 0 R >>\nendobj\n",
  )
  offsets.push(out.length())
  pdf_jpx_test_append(
    out,
    "4 0 obj\n<< /Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceGray /BitsPerComponent 1 /Filter /JBIG2Decode /Length \{jbig2.length()} >>\nstream\n",
  )
  out.append(jbig2.to_array())
  pdf_jpx_test_append(out, "\nendstream\nendobj\n")
  let content = "q 100 0 0 100 0 0 cm /Im1 Do Q"
  offsets.push(out.length())
  pdf_jpx_test_append(
    out,
    "5 0 obj\n<< /Length \{content.length()} >>\nstream\n\{content}\nendstream\nendobj\n",
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
  let document = pdf_graphics_document(Bytes::from_array(out), no_text_index=true)
  assert_true(document.length() > 0, msg="JBIG2 document bytes")
}
