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
  // Immediate generic region with MMR data for one black pixel: the region
  // segment information field (width, height, x, y, combination operator)
  // followed by the region flags and the MMR data.
  pdf_jbig2_test_u32(out, 1)
  pdf_jbig2_test_append(out, 0x26)
  pdf_jbig2_test_append(out, 0x00)
  pdf_jbig2_test_append(out, 1)
  pdf_jbig2_test_u32(out, 20)
  pdf_jbig2_test_u32(out, 1)
  pdf_jbig2_test_u32(out, 1)
  pdf_jbig2_test_u32(out, 0)
  pdf_jbig2_test_u32(out, 0)
  pdf_jbig2_test_append(out, 0)
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
// The two JBIG2 image streams of upstream images-jpx-jbig2.pdf: a halftone
// region over a pattern dictionary, and a text region over a symbol
// dictionary in the globals stream.

let pdf_jbig2_images_jpx_img1 : Array[Byte] = [
  0, 0, 0, 0, 48, 0, 1, 0, 0, 0, 19, 0, 0, 0, 230, 0, 0, 0, 190, 0, 0, 0, 0, 0,
  0, 0, 0, 32, 0, 0, 0, 0, 0, 1, 16, 0, 1, 0, 0, 0, 62, 0, 6, 6, 0, 0, 0, 15,
  136, 53, 118, 13, 148, 25, 2, 140, 15, 208, 186, 185, 73, 37, 69, 8, 72, 27, 151, 109, 34, 246, 26, 48,
  114, 191, 93, 67, 93, 20, 249, 77, 101, 110, 254, 230, 110, 226, 106, 254, 236, 114, 146, 111, 229, 163, 112, 101,
  228, 115, 43, 253, 206, 255, 172, 0, 0, 0, 2, 22, 32, 1, 1, 0, 0, 1, 120, 0, 0, 0, 220, 0,
  0, 0, 180, 0, 0, 0, 5, 0, 0, 0, 5, 0, 8, 0, 0, 0, 48, 0, 0, 0, 40, 255, 255, 253,
  0, 0, 0, 2, 0, 5, 0, 1, 0, 130, 239, 193, 24, 37, 124, 225, 116, 60, 238, 194, 63, 31, 139, 113,
  3, 54, 100, 245, 146, 36, 142, 134, 147, 114, 195, 195, 77, 64, 186, 162, 114, 235, 27, 30, 21, 137, 9, 84,
  27, 88, 249, 60, 96, 201, 69, 47, 235, 106, 63, 200, 91, 54, 191, 215, 168, 131, 107, 224, 83, 159, 46, 154,
  73, 173, 34, 130, 163, 107, 88, 127, 207, 33, 119, 106, 208, 112, 25, 245, 142, 156, 71, 170, 156, 36, 237, 203,
  75, 246, 178, 52, 28, 60, 80, 195, 139, 101, 233, 26, 98, 217, 91, 112, 133, 133, 14, 196, 68, 77, 200, 137,
  191, 102, 224, 63, 34, 7, 115, 236, 159, 122, 255, 128, 183, 207, 5, 186, 206, 148, 233, 141, 38, 114, 120, 52,
  169, 3, 108, 197, 205, 77, 185, 157, 153, 87, 218, 201, 33, 70, 73, 65, 196, 142, 231, 87, 10, 140, 147, 179,
  44, 60, 245, 9, 40, 140, 58, 114, 35, 231, 150, 99, 35, 21, 244, 92, 13, 28, 213, 87, 42, 9, 31, 232,
  212, 234, 110, 211, 82, 232, 239, 191, 172, 208, 223, 20, 213, 219, 48, 64, 153, 171, 214, 17, 17, 4, 255, 43,
  146, 102, 36, 198, 65, 52, 40, 36, 231, 15, 243, 167, 181, 182, 112, 202, 239, 178, 145, 84, 245, 245, 248, 230,
  117, 114, 189, 124, 251, 182, 27, 78, 58, 8, 20, 0, 254, 183, 46, 182, 138, 132, 118, 201, 149, 201, 24, 165,
  95, 150, 173, 15, 243, 237, 62, 220, 72, 158, 75, 162, 16, 72, 235, 226, 179, 201, 0, 89, 185, 224, 240, 243,
  207, 123, 8, 88, 21, 104, 173, 88, 113, 207, 237, 252, 181, 221, 192, 22, 148, 4, 12, 192, 48, 70, 19, 250,
  142, 110, 235, 54, 155, 198, 15, 68, 47, 245, 4, 1, 7, 160, 227, 17, 14, 217, 132, 47, 11, 98, 144, 98,
  121, 107, 85, 135, 96, 150, 95, 11, 143, 255, 172, 0, 0, 0, 3, 16, 0, 1, 0, 0, 0, 21, 2, 4,
  4, 0, 0, 0, 5, 87, 48, 154, 154, 205, 40, 120, 82, 4, 230, 255, 127, 255, 172, 0, 0, 0, 4, 23,
  32, 3, 1, 0, 0, 0, 81, 0, 0, 0, 55, 0, 0, 0, 45, 0, 0, 0, 0, 0, 0, 0, 140, 2,
  34, 0, 0, 0, 12, 0, 0, 0, 10, 0, 0, 0, 128, 255, 255, 255, 128, 3, 192, 0, 128, 87, 24, 76,
  145, 166, 15, 226, 237, 83, 97, 3, 50, 114, 117, 9, 12, 46, 81, 231, 234, 230, 121, 222, 32, 124, 166, 59,
  67, 131, 130, 97, 140, 136, 119, 9, 25, 43, 7, 148, 80, 89, 255, 172, 0, 0, 0, 5, 16, 0, 1, 0,
  0, 0, 28, 4, 5, 5, 0, 0, 0, 6, 116, 194, 39, 41, 38, 231, 39, 193, 215, 129, 241, 15, 100, 216,
  156, 169, 255, 57, 127, 255, 172, 0, 0, 0, 6, 23, 32, 5, 1, 0, 0, 0, 83, 0, 0, 0, 55, 0,
  0, 0, 45, 0, 0, 0, 60, 0, 0, 0, 140, 2, 36, 0, 0, 0, 12, 0, 0, 0, 10, 0, 0, 0,
  128, 255, 255, 255, 128, 3, 192, 0, 128, 64, 160, 213, 18, 209, 43, 89, 89, 67, 52, 249, 222, 40, 142, 173,
  66, 38, 122, 40, 29, 87, 194, 29, 9, 128, 103, 186, 196, 184, 209, 72, 108, 240, 123, 223, 208, 160, 134, 29,
  29, 253, 244, 191, 255, 172, 0, 0, 0, 7, 16, 0, 1, 0, 0, 0, 35, 6, 6, 6, 0, 0, 0, 7,
  141, 137, 239, 147, 44, 39, 116, 151, 104, 89, 195, 40, 235, 86, 60, 204, 130, 105, 201, 103, 224, 197, 177, 9,
  217, 183, 255, 172, 0, 0, 0, 8, 23, 32, 7, 1, 0, 0, 0, 83, 0, 0, 0, 55, 0, 0, 0, 45,
  0, 0, 0, 120, 0, 0, 0, 140, 2, 38, 0, 0, 0, 12, 0, 0, 0, 10, 0, 0, 0, 128, 255, 255,
  255, 128, 3, 192, 0, 128, 52, 49, 245, 160, 165, 60, 96, 115, 245, 208, 138, 153, 249, 192, 43, 89, 221, 222,
  249, 252, 224, 128, 231, 148, 85, 62, 229, 71, 122, 19, 225, 54, 142, 19, 67, 63, 31, 55, 209, 165, 230, 25,
  207, 255, 172, 0, 0, 0, 9, 49, 0, 1, 0, 0, 0, 0,
]

///|
let pdf_jbig2_images_jpx_img2 : Array[Byte] = [
  0, 0, 0, 2, 48, 0, 1, 0, 0, 0, 19, 0, 0, 0, 200, 0, 0, 0, 120, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 6, 64, 1, 0, 1, 0, 0, 0, 119, 0, 0, 0, 190, 0,
  0, 0, 110, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 17, 0, 11, 0, 0, 0, 60, 0, 3, 18, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 48, 4, 144, 185, 172, 0, 88, 153, 204, 152, 217, 77,
  118, 7, 226, 67, 57, 114, 198, 196, 224, 129, 209, 106, 247, 32, 65, 217, 185, 157, 144, 178, 95, 49, 179, 108,
  135, 68, 77, 10, 50, 111, 114, 7, 182, 108, 244, 244, 112, 79, 177, 206, 243, 57, 5, 123, 62, 121, 183, 111,
  113, 245, 148, 28, 231, 228, 217, 99, 59, 41, 236, 177, 181, 26, 154, 157, 157, 64, 0, 0, 0, 4, 49, 0,
  1, 0, 0, 0, 0,
]

///|
let pdf_jbig2_images_jpx_globals : Array[Byte] = [
  0, 0, 0, 0, 53, 0, 0, 0, 0, 0, 13, 36, 255, 255, 255, 192, 0, 0, 0, 64, 85, 85, 93, 144,
  0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 162, 0, 1, 0, 0, 0, 18, 0, 0, 0, 18, 240, 60, 241,
  113, 112, 126, 0, 0, 0, 0, 48, 0, 0, 0, 0, 0, 16, 96, 0, 0, 16, 3, 1, 184, 96, 0, 0,
  0, 0, 63, 96, 0, 0, 48, 65, 243, 240, 96, 112, 0, 0, 7, 255, 48, 0, 0, 48, 241, 241, 252, 112,
  252, 0, 96, 7, 252, 29, 224, 0, 120, 249, 241, 252, 248, 255, 224, 240, 14, 12, 31, 248, 0, 249, 153, 153,
  152, 140, 127, 224, 251, 128, 8, 12, 12, 0, 201, 153, 153, 153, 142, 112, 224, 127, 128, 28, 8, 4, 0, 249,
  153, 153, 156, 140, 112, 0, 31, 128, 12, 12, 12, 0, 125, 240, 241, 252, 248, 112, 0, 31, 0, 4, 7, 248,
  0, 121, 240, 224, 120, 112, 112, 0, 30, 0, 0, 7, 224, 0, 120, 0, 192, 0, 0, 0, 0, 0, 0, 0,
  1, 128, 0, 12, 0, 192, 0, 0, 0, 0, 0, 0, 0, 0, 192, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 220, 248, 75, 132, 223, 128, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 252, 0, 0, 0, 0, 0, 0, 0,
  1, 128, 0, 0, 0, 49, 248, 0, 0, 0, 0, 0, 0, 0, 3, 128, 0, 7, 0, 48, 24, 60, 60, 1,
  192, 30, 0, 124, 1, 248, 0, 255, 0, 48, 24, 126, 124, 131, 96, 127, 225, 238, 1, 220, 3, 222, 0, 113,
  152, 102, 121, 134, 48, 64, 241, 131, 3, 7, 134, 3, 0, 115, 240, 66, 48, 4, 16, 192, 225, 1, 2, 3,
  132, 1, 0, 113, 240, 66, 48, 28, 16, 192, 193, 1, 2, 2, 4, 1, 0, 96, 240, 102, 48, 6, 60, 64,
  225, 131, 3, 6, 6, 3, 0, 96, 120, 255, 48, 7, 112, 127, 224, 238, 1, 220, 3, 222, 0, 112, 48, 255,
  32, 1, 248, 62, 0, 124, 1, 248, 0, 248, 0, 112, 1, 248, 32, 0, 56, 0, 0, 15, 1, 184, 0, 224,
  0, 48, 1, 224, 96, 0, 24, 0, 0, 63, 225, 152, 1, 192, 0, 0, 0, 192, 0, 0, 0, 0, 0, 63,
  225, 156, 3, 192, 0, 0, 0, 0, 0, 0, 0, 0, 0, 63, 193, 136, 3, 128, 0, 4, 4,
]

///|
test "PDF JBIG2 fixture images decode like upstream" {
  let (w1, h1, bits1) = pdf_jbig2_decode(Bytes::from_array(pdf_jbig2_images_jpx_img1))
  assert_eq(w1, 230, msg="JBIG2 halftone width")
  assert_eq(h1, 190, msg="JBIG2 halftone height")
  assert_eq(
    pdf_jbig2_fixture_black(bits1, w1, h1),
    28529,
    msg="JBIG2 halftone black pixels",
  )
  assert_eq(
    pdf_jbig2_fixture_fnv(bits1.to_array()),
    17763461201924439071UL,
    msg="JBIG2 halftone page bytes",
  )
  let (w2, h2, bits2) = pdf_jbig2_decode_with_globals(
    Bytes::from_array(pdf_jbig2_images_jpx_img2),
    Bytes::from_array(pdf_jbig2_images_jpx_globals),
  )
  assert_eq(w2, 200, msg="JBIG2 text width")
  assert_eq(h2, 120, msg="JBIG2 text height")
  assert_eq(
    pdf_jbig2_fixture_black(bits2, w2, h2),
    2698,
    msg="JBIG2 text black pixels",
  )
  assert_eq(
    pdf_jbig2_fixture_fnv(bits2.to_array()),
    14896466107680124503UL,
    msg="JBIG2 text page bytes",
  )
}

///|
test "PDF JBIG2 globals stream renders through the graphics document" {
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
    "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 120] /Resources << /XObject << /Im1 4 0 R >> >> /Contents 5 0 R >>\nendobj\n",
  )
  offsets.push(out.length())
  pdf_jpx_test_append(
    out,
    "4 0 obj\n<< /Type /XObject /Subtype /Image /Width 200 /Height 120 /ImageMask true /Filter /JBIG2Decode /DecodeParms << /JBIG2Globals 6 0 R >> /Length \{pdf_jbig2_images_jpx_img2.length()} >>\nstream\n",
  )
  for byte in pdf_jbig2_images_jpx_img2 {
    out.push(byte)
  }
  pdf_jpx_test_append(out, "\nendstream\nendobj\n")
  let content = "q 200 0 0 120 0 0 cm /Im1 Do Q"
  offsets.push(out.length())
  pdf_jpx_test_append(
    out,
    "5 0 obj\n<< /Length \{content.length()} >>\nstream\n\{content}\nendstream\nendobj\n",
  )
  offsets.push(out.length())
  pdf_jpx_test_append(
    out,
    "6 0 obj\n<< /Length \{pdf_jbig2_images_jpx_globals.length()} >>\nstream\n",
  )
  for byte in pdf_jbig2_images_jpx_globals {
    out.push(byte)
  }
  pdf_jpx_test_append(out, "\nendstream\nendobj\n")
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
  assert_true(document.length() > 0, msg="JBIG2 globals document bytes")
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
