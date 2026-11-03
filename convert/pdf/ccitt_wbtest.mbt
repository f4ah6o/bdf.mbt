///|
fn pdf_ccitt_pixels_rgb(
  pixels : Int32,
  red : Int32,
  green : Int32,
  blue : Int32,
) -> Bytes {
  let out = @buffer.Buffer(size_hint=pixels * 3)
  for _ in 0..<pixels {
    out.write_byte(red.to_byte())
    out.write_byte(green.to_byte())
    out.write_byte(blue.to_byte())
  }
  out.to_bytes()
}

///|
fn pdf_ccitt_pixels_rgba(
  pixels : Int32,
  red : Int32,
  green : Int32,
  blue : Int32,
  alpha : Int32,
) -> Bytes {
  let out = @buffer.Buffer(size_hint=pixels * 4)
  for _ in 0..<pixels {
    out.write_byte(red.to_byte())
    out.write_byte(green.to_byte())
    out.write_byte(blue.to_byte())
    out.write_byte(alpha.to_byte())
  }
  out.to_bytes()
}

///|
fn pdf_ccitt_scanline_rgb(
  pixels : Int32,
  red : Int32,
  green : Int32,
  blue : Int32,
) -> Bytes {
  let out = @buffer.Buffer(size_hint=1 + pixels * 3)
  out.write_byte(0)
  out.write_bytesview(pdf_ccitt_pixels_rgb(pixels, red, green, blue)[:])
  out.to_bytes()
}

///|
fn pdf_ccitt_params_for_test(
  k : Int32,
  rows : Int32,
  align : Bool,
) -> PdfCcittParams {
  let params = pdf_ccitt_default_params()
  params.k = k
  params.columns = 8
  params.rows = rows
  params.encoded_byte_align = align
  params
}

///|
test "PDF CCITT G4 white image decodes" {
  let params = pdf_ccitt_params_for_test(-1, 1, false)
  let bits = pdf_decode_ccitt(params, 8, 1, b"\xff")
  assert_eq(
    pdf_ccitt_rgb(8, 1, bits, false, false),
    pdf_ccitt_pixels_rgb(8, 255, 255, 255),
    msg="CCITT G4 white",
  )
}

///|
test "PDF CCITT G4 black image decodes" {
  let params = pdf_ccitt_params_for_test(-1, 1, false)
  let bits = pdf_decode_ccitt(params, 8, 1, b"\x26\xa2\x80")
  assert_eq(
    pdf_ccitt_rgb(8, 1, bits, false, false),
    pdf_ccitt_pixels_rgb(8, 0, 0, 0),
    msg="CCITT G4 black",
  )
}

///|
test "PDF CCITT G3 one-dimensional rows decode" {
  let params = pdf_ccitt_params_for_test(0, 1, false)
  let white = pdf_decode_ccitt(params, 8, 1, b"\x98")
  assert_eq(
    pdf_ccitt_rgb(8, 1, white, false, false),
    pdf_ccitt_pixels_rgb(8, 255, 255, 255),
    msg="CCITT G3 white",
  )
  let black = pdf_decode_ccitt(params, 8, 1, b"\x35\x14")
  assert_eq(
    pdf_ccitt_rgb(8, 1, black, false, false),
    pdf_ccitt_pixels_rgb(8, 0, 0, 0),
    msg="CCITT G3 black",
  )
}

///|
test "PDF CCITT mixed two-dimensional rows decode" {
  let params = pdf_ccitt_params_for_test(1, 2, false)
  let bits = pdf_decode_ccitt(params, 8, 2, b"\x00\x1c\xc0\x05")
  assert_eq(
    pdf_ccitt_rgb(8, 2, bits, false, false),
    pdf_ccitt_pixels_rgb(16, 255, 255, 255),
    msg="CCITT mixed rows",
  )
}

///|
test "PDF CCITT encoded byte alignment decodes" {
  let params = pdf_ccitt_params_for_test(0, 2, true)
  let bits = pdf_decode_ccitt(params, 8, 2, b"\x98\x98")
  assert_eq(
    pdf_ccitt_rgb(8, 2, bits, false, false),
    pdf_ccitt_pixels_rgb(16, 255, 255, 255),
    msg="CCITT byte aligned rows",
  )
}

///|
test "PDF CCITT mask paints black runs" {
  let params = pdf_ccitt_params_for_test(-1, 1, false)
  let bits = pdf_decode_ccitt(params, 8, 1, b"\x26\xa2\x80")
  assert_eq(
    pdf_ccitt_mask_rgba(8, 1, bits, false, false, 0xff0000ffU),
    pdf_ccitt_pixels_rgba(8, 255, 0, 0, 255),
    msg="CCITT mask ink",
  )
  assert_eq(
    pdf_ccitt_mask_rgba(8, 1, bits, false, true, 0xff0000ffU),
    pdf_ccitt_pixels_rgba(8, 0, 0, 0, 0),
    msg="CCITT mask decode inversion",
  )
}

///|
test "PDF CCITT damaged rows respect the tolerance" {
  let params = pdf_ccitt_params_for_test(-1, 1, false)
  params.damaged_rows_before_error = 1
  let bits = pdf_decode_ccitt(params, 8, 1, b"\x00")
  assert_eq(
    pdf_ccitt_rgb(8, 1, bits, false, false),
    pdf_ccitt_pixels_rgb(8, 255, 255, 255),
    msg="CCITT tolerated damage",
  )
  params.damaged_rows_before_error = 0
  let rejected = try {
    ignore(pdf_decode_ccitt(params, 8, 1, b"\x00"))
    false
  } catch {
    InvalidStream(message) => message.contains("damaged")
  }
  assert_true(rejected, msg="CCITT damage without tolerance")
}

///|
test "PDF CCITT rejects mismatched dimensions" {
  let params = pdf_ccitt_params_for_test(-1, 1, false)
  params.columns = 9
  let rejected = try {
    ignore(pdf_decode_ccitt(params, 8, 1, b"\xff"))
    false
  } catch {
    InvalidStream(message) => message.contains("Columns")
  }
  assert_true(rejected, msg="CCITT columns mismatch")
}

///|
test "PDF CCITT G4 image XObject becomes RGB PNG" {
  let document = pdf_graphics_document(
    pdf_xobject_test_document(
      b"q 100 0 0 100 10 20 cm /Im1 Do Q",
      "/Type /XObject /Subtype /Image /Width 8 /Height 1 /ColorSpace /DeviceGray /BitsPerComponent 1 /Filter /CCITTFaxDecode /DecodeParms << /K -1 /Columns 8 /Rows 1 >>",
      b"\x26\xa2\x80",
    ),
    no_text_index=true,
  )
  assert_eq(
    pdf_test_image_rgb(document, 8, 1),
    pdf_ccitt_scanline_rgb(8, 0, 0, 0),
    msg="PDF CCITT XObject",
  )
}

///|
test "PDF CCITT image mask XObject paints the fill colour" {
  let document = pdf_graphics_document(
    pdf_xobject_test_document(
      b"q 1 0 0 rg 100 0 0 100 10 20 cm /Im1 Do Q",
      "/Type /XObject /Subtype /Image /ImageMask true /Width 8 /Height 1 /BitsPerComponent 1 /Filter /CCITTFaxDecode /DecodeParms << /K -1 /Columns 8 /Rows 1 >>",
      b"\x26\xa2\x80",
    ),
    no_text_index=true,
  )
  assert_eq(
    pdf_test_image_rgba(document, 8, 1),
    pdf_test_red_mask_scanline(8),
    msg="PDF CCITT mask XObject",
  )
}

///|
test "PDF CCITT inline image decodes" {
  let document = pdf_graphics_document(
    pdf_inline_test_document(
      pdf_inline_content(
        "/W 8 /H 1 /CS /G /BPC 1 /F /CCF /DP << /K -1 /Columns 8 /Rows 1 >>",
        b"\x26\xa2\x80",
      ),
    ),
    no_text_index=true,
  )
  assert_eq(
    pdf_test_image_rgb(document, 8, 1),
    pdf_ccitt_scanline_rgb(8, 0, 0, 0),
    msg="PDF CCITT inline image",
  )
}

///|
test "PDF invalid JPX image reports a codec error" {
  let rejected = try {
    ignore(
      pdf_graphics_document(
        pdf_xobject_test_document(
          b"q 100 0 0 100 10 20 cm /Im1 Do Q",
          "/Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceGray /BitsPerComponent 8 /Filter /JPXDecode",
          b"\x00",
        ),
        no_text_index=true,
      ),
    )
    false
  } catch {
    InvalidStream(message) => message.contains("JPX")
  }
  assert_true(rejected, msg="PDF JPX error")
}

///|
test "PDF CCITT Decode array inverts image samples" {
  let document = pdf_graphics_document(
    pdf_xobject_test_document(
      b"q 100 0 0 100 10 20 cm /Im1 Do Q",
      "/Type /XObject /Subtype /Image /Width 8 /Height 1 /ColorSpace /DeviceGray /BitsPerComponent 1 /Filter /CCITTFaxDecode /Decode [1 0] /DecodeParms << /K -1 /Columns 8 /Rows 1 >>",
      b"\x26\xa2\x80",
    ),
    no_text_index=true,
  )
  assert_eq(
    pdf_test_image_rgb(document, 8, 1),
    pdf_ccitt_scanline_rgb(8, 255, 255, 255),
    msg="PDF CCITT Decode inversion",
  )
}

///|
test "PDF CCITT behind Flate decodes with indexed parameters" {
  let document = pdf_graphics_document(
    pdf_xobject_test_document(
      b"q 100 0 0 100 10 20 cm /Im1 Do Q",
      "/Type /XObject /Subtype /Image /Width 8 /Height 1 /ColorSpace /DeviceGray /BitsPerComponent 1 /Filter [/FlateDecode /CCITTFaxDecode] /DecodeParms [null << /K -1 /Columns 8 /Rows 1 >>]",
      @zlib.compress(b"\x26\xa2\x80"),
    ),
    no_text_index=true,
  )
  assert_eq(
    pdf_test_image_rgb(document, 8, 1),
    pdf_ccitt_scanline_rgb(8, 0, 0, 0),
    msg="PDF CCITT filter pipeline",
  )
}

///|
test "PDF CCITT infers one bit per component" {
  let document = pdf_graphics_document(
    pdf_xobject_test_document(
      b"q 100 0 0 100 10 20 cm /Im1 Do Q",
      "/Type /XObject /Subtype /Image /Width 8 /Height 1 /ColorSpace /DeviceGray /Filter /CCITTFaxDecode /DecodeParms << /K -1 /Columns 8 /Rows 1 >>",
      b"\x26\xa2\x80",
    ),
    no_text_index=true,
  )
  assert_eq(
    pdf_test_image_rgb(document, 8, 1),
    pdf_ccitt_scanline_rgb(8, 0, 0, 0),
    msg="PDF CCITT inferred bit depth",
  )
}
