///|
fn pdf_test_pad_offset(offset : Int32) -> String {
  let text = offset.to_string()
  let mut padding = 10 - text.length()
  let out = StringBuilder()
  while padding > 0 {
    out.write_string("0")
    padding -= 1
  }
  out.write_string(text)
  out.to_string()
}

///|
fn pdf_test_stream(extra : String, data : Bytes) -> Bytes {
  let out = @buffer.Buffer()
  out.write_string_utf8("<< ")
  out.write_string_utf8(extra)
  out.write_string_utf8(" /Length ")
  out.write_string_utf8(data.length().to_string())
  out.write_string_utf8(" >>\nstream\n")
  out.write_bytesview(data[:])
  out.write_string_utf8("\nendstream")
  out.to_bytes()
}

///|
fn pdf_test_pdf(objects : Array[Bytes]) -> Bytes {
  let out = @buffer.Buffer()
  out.write_string_utf8("%PDF-1.7\n")
  let offsets : Array[Int32] = []
  for i, body in objects {
    offsets.push(out.length())
    out.write_string_utf8("\{i + 1} 0 obj\n")
    out.write_bytesview(body[:])
    out.write_string_utf8("\nendobj\n")
  }
  let xref = out.length()
  out.write_string_utf8("xref\n0 \{objects.length() + 1}\n")
  out.write_string_utf8("0000000000 65535 f \n")
  for offset in offsets {
    out.write_string_utf8(pdf_test_pad_offset(offset) + " 00000 n \n")
  }
  out.write_string_utf8(
    "trailer\n<< /Size \{objects.length() + 1} /Root 1 0 R >>\nstartxref\n\{xref}\n%%EOF\n",
  )
  out.to_bytes()
}

///|
fn pdf_xobject_test_document(
  content : Bytes,
  xobject_dict : String,
  xobject_data : Bytes,
) -> Bytes {
  pdf_test_pdf([
    b"<< /Type /Catalog /Pages 2 0 R >>",
    b"<< /Type /Pages /Kids [3 0 R] /Count 1 /MediaBox [0 0 200 200] >>",
    b"<< /Type /Page /Parent 2 0 R /Resources << /XObject << /Im1 5 0 R >> >> /Contents 4 0 R >>",
    pdf_test_stream("", content),
    pdf_test_stream(xobject_dict, xobject_data),
  ])
}

///|
fn pdf_test_png_u32(png : Bytes, offset : Int32) -> Int32 {
  (png[offset].to_int() << 24) |
  (png[offset + 1].to_int() << 16) |
  (png[offset + 2].to_int() << 8) |
  png[offset + 3].to_int()
}

///|
fn pdf_test_png_idat(png : Bytes) -> Bytes raise {
  let out = @buffer.Buffer()
  let mut pos = 8
  while pos + 12 <= png.length() {
    let length = pdf_test_png_u32(png, pos)
    let kind = png[pos + 4:pos + 8]
    if kind == b"IDAT" {
      out.write_bytesview(png[pos + 8:pos + 8 + length])
    }
    pos += 12 + length
  }
  out.to_bytes()
}

///|
fn pdf_test_image_bytes(document : Bytes) -> Bytes raise {
  let split = @core.single_to_split(document)
  let manifest = @core.parse_manifest(@utf8.decode(split.manifest))
  for part in manifest.parts {
    if part.kind == "img" {
      return @core.open_single(document).part(part.hash)
    }
  }
  fail("PDF image part is missing")
}

///|
fn pdf_inline_content(dict : String, data : Bytes) -> Bytes {
  let out = @buffer.Buffer()
  out.write_string_utf8("q 100 0 0 100 10 20 cm BI\n")
  out.write_string_utf8(dict)
  out.write_string_utf8("\nID ")
  out.write_bytesview(data[:])
  out.write_string_utf8("\nEI Q")
  out.to_bytes()
}

///|
fn pdf_inline_test_document(content : Bytes) -> Bytes {
  pdf_test_pdf([
    b"<< /Type /Catalog /Pages 2 0 R >>",
    b"<< /Type /Pages /Kids [3 0 R] /Count 1 /MediaBox [0 0 200 200] >>",
    b"<< /Type /Page /Parent 2 0 R /Contents 4 0 R >>",
    pdf_test_stream("", content),
  ])
}

///|
fn pdf_inline_mask_content(dict : String, data : Bytes) -> Bytes {
  let out = @buffer.Buffer()
  out.write_string_utf8("q 1 0 0 rg 100 0 0 100 10 20 cm BI\n")
  out.write_string_utf8(dict)
  out.write_string_utf8("\nID ")
  out.write_bytesview(data[:])
  out.write_string_utf8("\nEI Q")
  out.to_bytes()
}

///|
fn pdf_test_red_mask_scanline(pixels : Int32) -> Bytes {
  let out = @buffer.Buffer()
  out.write_byte(0)
  for _ in 0..<pixels {
    out.write_byte(0xff)
    out.write_byte(0)
    out.write_byte(0)
    out.write_byte(0xff)
  }
  out.to_bytes()
}

///|
fn pdf_test_image_rgb(
  document : Bytes,
  width : Int32,
  height : Int32,
) -> Bytes raise {
  let png = pdf_test_image_bytes(document)
  assert_eq(png[:8], b"\x89PNG\r\n\x1a\n"[:], msg="PDF image PNG signature")
  assert_eq(pdf_test_png_u32(png, 16), width, msg="PDF image width")
  assert_eq(pdf_test_png_u32(png, 20), height, msg="PDF image height")
  @zlib.decompress(pdf_test_png_idat(png))
}

///|
fn pdf_test_image_rgba(
  document : Bytes,
  width : Int32,
  height : Int32,
) -> Bytes raise {
  let png = pdf_test_image_bytes(document)
  assert_eq(png[:8], b"\x89PNG\r\n\x1a\n"[:], msg="PDF image PNG signature")
  assert_eq(pdf_test_png_u32(png, 16), width, msg="PDF image width")
  assert_eq(pdf_test_png_u32(png, 20), height, msg="PDF image height")
  assert_eq(png[25].to_int(), 6, msg="PDF image colour type")
  @zlib.decompress(pdf_test_png_idat(png))
}

///|
test "PDF JPEG image XObject is stored unchanged" {
  let jpeg = b"\xff\xd8\xff\xe0\x00\x10\x4a\x46\x49\x46\x00\x01\x01\x01\x00\x48\x00\x48\x00\x00\xff\xdb\x00\x43\x00\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xdb\x00\x43\x01\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xc0\x00\x11\x08\x00\x01\x00\x01\x03\x01\x22\x00\x02\x11\x01\x03\x11\x01\xff\xc4\x00\x15\x00\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x05\xff\xc4\x00\x14\x10\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xda\x00\x0c\x03\x01\x00\x02\x10\x03\x10\x00\x00\x01\x7f\xff\xc4\x00\x14\x10\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xda\x00\x08\x01\x01\x00\x01\x05\x02\x7f\xff\xc4\x00\x14\x11\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xda\x00\x08\x01\x03\x01\x01\x3f\x01\x7f\xff\xc4\x00\x14\x11\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xda\x00\x08\x01\x02\x01\x01\x3f\x01\x7f\xff\xc4\x00\x14\x10\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xda\x00\x08\x01\x01\x00\x06\x3f\x02\x7f\xff\xc4\x00\x14\x10\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xda\x00\x08\x01\x01\x00\x01\x3f\x21\x7f\xff\xda\x00\x0c\x03\x01\x00\x02\x00\x03\x00\x00\x00\x10\xff\xc4\x00\x14\x11\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xda\x00\x08\x01\x03\x01\x01\x3f\x10\x7f\xff\xc4\x00\x14\x11\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xda\x00\x08\x01\x02\x01\x01\x3f\x10\x7f\xff\xc4\x00\x14\x10\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xda\x00\x08\x01\x01\x00\x01\x3f\x10\x7f\xff\xd9"
  let document = pdf_graphics_document(
    pdf_xobject_test_document(
      b"q 100 0 0 100 10 20 cm /Im1 Do Q", "/Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode",
      jpeg,
    ),
    no_text_index=true,
  )
  let split = @core.single_to_split(document)
  let manifest = @core.parse_manifest(@utf8.decode(split.manifest))
  let mut image_hash = ""
  for part in manifest.parts {
    if part.kind == "img" {
      image_hash = part.hash
    }
  }
  assert_true(image_hash != "", msg="PDF image part")
  let opened = @core.open_single(document)
  assert_eq(opened.part(image_hash), jpeg, msg="PDF image bytes")
  let body_hash = manifest.views[0].pages[0].layers[0].object
  let resources = @core.decode_object_resources(opened.part(body_hash))
  assert_eq(resources.object.images, [image_hash], msg="PDF image resource")
}

///|
test "PDF Flate RGB samples become PNG" {
  let document = pdf_graphics_document(
    pdf_xobject_test_document(
      b"q 100 0 0 100 10 20 cm /Im1 Do Q",
      "/Type /XObject /Subtype /Image /Width 2 /Height 1 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode",
      @zlib.compress(b"\xff\x00\x00\x00\xff\x00"[:]),
    ),
    no_text_index=true,
  )
  assert_eq(
    pdf_test_image_rgb(document, 2, 1),
    b"\x00\xff\x00\x00\x00\xff\x00",
    msg="PDF RGB scanline",
  )
}

///|
test "PDF Flate CMYK samples become RGB PNG" {
  let document = pdf_graphics_document(
    pdf_xobject_test_document(
      b"q 100 0 0 100 10 20 cm /Im1 Do Q",
      "/Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceCMYK /BitsPerComponent 8 /Filter /FlateDecode",
      @zlib.compress(b"\x00\x00\x00\x00"[:]),
    ),
    no_text_index=true,
  )
  assert_eq(
    pdf_test_image_rgb(document, 1, 1),
    b"\x00\xff\xff\xff",
    msg="PDF CMYK scanline",
  )
}

///|
test "PDF image bit depths other than 8 fail closed" {
  let rejected = try {
    ignore(
      pdf_graphics_document(
        pdf_xobject_test_document(
          b"q 100 0 0 100 10 20 cm /Im1 Do Q",
          "/Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceGray /BitsPerComponent 1 /Filter /FlateDecode",
          @zlib.compress(b"\x00"[:]),
        ),
        no_text_index=true,
      ),
    )
    false
  } catch {
    InvalidStream(message) => message.contains("bit depths")
    _ => false
  }
  assert_true(rejected)
}

///|
test "PDF inline JPEG image is stored unchanged" {
  let jpeg = b"\xff\xd8inline\xff\xd9"
  let document = pdf_graphics_document(
    pdf_inline_test_document(
      pdf_inline_content("/W 1 /H 1 /CS /RGB /BPC 8 /F /DCTDecode", jpeg),
    ),
    no_text_index=true,
  )
  assert_eq(pdf_test_image_bytes(document), jpeg, msg="PDF inline JPEG bytes")
}

///|
test "PDF inline Flate RGB samples become PNG" {
  let document = pdf_graphics_document(
    pdf_inline_test_document(
      pdf_inline_content(
        "/W 2 /H 1 /CS /RGB /BPC 8 /F /FlateDecode",
        @zlib.compress(b"\xff\x00\x00\x00\xff\x00"[:]),
      ),
    ),
    no_text_index=true,
  )
  assert_eq(
    pdf_test_image_rgb(document, 2, 1),
    b"\x00\xff\x00\x00\x00\xff\x00",
    msg="PDF inline RGB scanline",
  )
}

///|
test "PDF inline raw gray samples become PNG" {
  let document = pdf_graphics_document(
    pdf_inline_test_document(
      pdf_inline_content("/W 1 /H 1 /CS /G /BPC 8", b"\x80"),
    ),
    no_text_index=true,
  )
  assert_eq(
    pdf_test_image_rgb(document, 1, 1),
    b"\x00\x80\x80\x80",
    msg="PDF inline gray scanline",
  )
}

///|
test "PDF image mask XObject becomes RGBA PNG" {
  let document = pdf_graphics_document(
    pdf_xobject_test_document(
      b"q 1 0 0 rg 100 0 0 100 10 20 cm /Im1 Do Q",
      "/Type /XObject /Subtype /Image /ImageMask true /Width 8 /Height 1 /BitsPerComponent 1 /Filter /FlateDecode",
      @zlib.compress(b"\x00"[:]),
    ),
    no_text_index=true,
  )
  assert_eq(
    pdf_test_image_rgba(document, 8, 1),
    pdf_test_red_mask_scanline(8),
    msg="PDF mask scanline",
  )
}

///|
test "PDF inline image mask becomes RGBA PNG" {
  let document = pdf_graphics_document(
    pdf_inline_test_document(
      pdf_inline_mask_content(
        "/W 8 /H 1 /IM true /BPC 1 /F /FlateDecode",
        @zlib.compress(b"\x00"[:]),
      ),
    ),
    no_text_index=true,
  )
  assert_eq(
    pdf_test_image_rgba(document, 8, 1),
    pdf_test_red_mask_scanline(8),
    msg="PDF inline mask scanline",
  )
}

///|
fn pdf_test_rgba_scanline(
  pixels : Array[(Int32, Int32, Int32, Int32)],
) -> Bytes {
  let out = @buffer.Buffer()
  out.write_byte(0)
  for pixel in pixels {
    let (red, green, blue, alpha) = pixel
    out.write_byte(red.to_byte())
    out.write_byte(green.to_byte())
    out.write_byte(blue.to_byte())
    out.write_byte(alpha.to_byte())
  }
  out.to_bytes()
}

///|
fn pdf_masked_image_test_document(
  width : Int32,
  height : Int32,
  image_extra : String,
  image_data : Bytes,
  mask_dict : String,
  mask_data : Bytes,
) -> Bytes {
  pdf_test_pdf([
    b"<< /Type /Catalog /Pages 2 0 R >>",
    b"<< /Type /Pages /Kids [3 0 R] /Count 1 /MediaBox [0 0 200 200] >>",
    b"<< /Type /Page /Parent 2 0 R /Resources << /XObject << /Im1 5 0 R >> >> /Contents 4 0 R >>",
    pdf_test_stream("", b"q 100 0 0 100 10 20 cm /Im1 Do Q"),
    pdf_test_stream(
      "/Type /XObject /Subtype /Image /Width \{width} /Height \{height} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode " +
      image_extra,
      image_data,
    ),
    pdf_test_stream(mask_dict, mask_data),
  ])
}

///|
test "PDF image soft mask supplies alpha" {
  let document = pdf_graphics_document(
    pdf_masked_image_test_document(
      2,
      1,
      "/SMask 6 0 R",
      @zlib.compress(b"\xff\x00\x00\x00\xff\x00"[:]),
      "/Type /XObject /Subtype /Image /Width 2 /Height 1 /ColorSpace /DeviceGray /BitsPerComponent 8 /Filter /FlateDecode",
      @zlib.compress(b"\x00\xff"[:]),
    ),
    no_text_index=true,
  )
  assert_eq(
    pdf_test_image_rgba(document, 2, 1),
    pdf_test_rgba_scanline([(255, 0, 0, 0), (0, 255, 0, 255)]),
    msg="PDF soft mask scanline",
  )
}

///|
test "PDF image stencil mask removes painted pixels" {
  let document = pdf_graphics_document(
    pdf_masked_image_test_document(
      1,
      1,
      "/Mask 6 0 R",
      @zlib.compress(b"\xff\x00\x00"[:]),
      "/Type /XObject /Subtype /Image /ImageMask true /Width 1 /Height 1 /BitsPerComponent 1 /Filter /FlateDecode",
      @zlib.compress(b"\x00"[:]),
    ),
    no_text_index=true,
  )
  assert_eq(
    pdf_test_image_rgba(document, 1, 1),
    pdf_test_rgba_scanline([(255, 0, 0, 0)]),
    msg="PDF stencil attachment scanline",
  )
}

///|
test "PDF colour key masks fail closed" {
  let rejected = try {
    ignore(
      pdf_graphics_document(
        pdf_masked_image_test_document(
          1,
          1,
          "/Mask [0 0 0 0 0 0]",
          @zlib.compress(b"\xff\x00\x00"[:]),
          "",
          b"",
        ),
        no_text_index=true,
      ),
    )
    false
  } catch {
    InvalidStream(message) => message.contains("colour key")
    _ => false
  }
  assert_true(rejected)
}

///|
test "PDF encoded images with masks fail closed" {
  let rejected = try {
    ignore(
      pdf_graphics_document(
        pdf_masked_image_test_document(
          1,
          1,
          "/Filter /DCTDecode /SMask 6 0 R",
          b"\xff\xd8inline\xff\xd9",
          "/Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceGray /BitsPerComponent 8 /Filter /FlateDecode",
          @zlib.compress(b"\xff"[:]),
        ),
        no_text_index=true,
      ),
    )
    false
  } catch {
    InvalidStream(message) => message.contains("encoded image data")
    _ => false
  }
  assert_true(rejected)
}

///|
fn pdf_form_image_test_document(group : Bool) -> Bytes {
  let form_extra = if group { " /Group << /S /Transparency >>" } else { "" }
  pdf_test_pdf([
    b"<< /Type /Catalog /Pages 2 0 R >>",
    b"<< /Type /Pages /Kids [3 0 R] /Count 1 /MediaBox [0 0 200 200] >>",
    b"<< /Type /Page /Parent 2 0 R /Resources << /XObject << /Fm1 5 0 R >> >> /Contents 4 0 R >>",
    pdf_test_stream("", b"q /Fm1 Do Q"),
    pdf_test_stream(
      "/Type /XObject /Subtype /Form /BBox [0 0 100 100] /Resources << /XObject << /Im1 6 0 R >> >>" +
      form_extra,
      b"q 100 0 0 100 0 0 cm /Im1 Do Q",
    ),
    pdf_test_stream(
      "/Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode",
      b"\xff\xd8form\xff\xd9",
    ),
  ])
}

///|
test "PDF form XObject inherits its own resources" {
  let document = pdf_graphics_document(
    pdf_form_image_test_document(false),
    no_text_index=true,
  )
  assert_eq(
    pdf_test_image_bytes(document),
    b"\xff\xd8form\xff\xd9",
    msg="PDF form image bytes",
  )
}

///|
test "PDF form transparency groups fail closed" {
  let rejected = try {
    ignore(
      pdf_graphics_document(
        pdf_form_image_test_document(true),
        no_text_index=true,
      ),
    )
    false
  } catch {
    InvalidStream(message) => message.contains("transparency groups")
    _ => false
  }
  assert_true(rejected)
}

///|
fn pdf_shading_test_document(shading : String) -> Bytes {
  pdf_test_pdf([
    b"<< /Type /Catalog /Pages 2 0 R >>",
    b"<< /Type /Pages /Kids [3 0 R] /Count 1 /MediaBox [0 0 200 200] >>",
    b"<< /Type /Page /Parent 2 0 R /Resources << /Shading << /Sh1 5 0 R >> >> /Contents 4 0 R >>",
    pdf_test_stream("", b"/Sh1 sh"),
    @utf8.encode(shading),
  ])
}

///|
fn pdf_test_body_paints(document : Bytes) -> Array[@core.Paint] raise {
  let split = @core.single_to_split(document)
  let manifest = @core.parse_manifest(@utf8.decode(split.manifest))
  let body_hash = manifest.views[0].pages[0].layers[0].object
  @core.decode_object_resources(@core.open_single(document).part(body_hash)).paints
}

///|
test "PDF axial shading becomes a linear gradient" {
  let document = pdf_graphics_document(
    pdf_shading_test_document(
      "<< /ShadingType 2 /ColorSpace /DeviceRGB /Coords [0 0 200 0] /Function << /FunctionType 2 /Domain [0 1] /C0 [1 0 0] /C1 [0 0 1] /N 1 >> >>",
    ),
    no_text_index=true,
  )
  let paints = pdf_test_body_paints(document)
  guard paints.length() == 1 else { fail("PDF axial shading paint count") }
  guard paints[0] is @core.Gradient(0, coords, stops) else {
    fail("PDF axial shading paint kind")
  }
  assert_eq(coords, [0.0, 0.0, 200.0, 0.0], msg="PDF axial shading coords")
  assert_eq(stops.length(), 2, msg="PDF axial shading stops")
  assert_eq(stops[0].offset, 0.0)
  assert_eq(stops[1].offset, 1.0)
  assert_eq(stops[0].color, 0xff0000ffU.reinterpret_as_int())
  assert_eq(stops[1].color, 0x0000ffffU.reinterpret_as_int())
}

///|
test "PDF radial shading becomes a radial gradient" {
  let document = pdf_graphics_document(
    pdf_shading_test_document(
      "<< /ShadingType 3 /ColorSpace /DeviceRGB /Coords [100 100 0 100 100 100] /Function << /FunctionType 2 /Domain [0 1] /C0 [1 1 1] /C1 [0 0 0] /N 1 >> >>",
    ),
    no_text_index=true,
  )
  let paints = pdf_test_body_paints(document)
  guard paints.length() == 1 else { fail("PDF radial shading paint count") }
  guard paints[0] is @core.Gradient(1, coords, stops) else {
    fail("PDF radial shading paint kind")
  }
  assert_eq(
    coords,
    [100.0, 100.0, 0.0, 100.0, 100.0, 100.0],
    msg="PDF radial shading coords",
  )
  assert_eq(stops.length(), 2, msg="PDF radial shading stops")
  assert_eq(stops[0].color, 0xffffffffU.reinterpret_as_int())
  assert_eq(stops[1].color, 0x000000ffU.reinterpret_as_int())
}

///|
test "PDF stitching shading samples its functions" {
  let document = pdf_graphics_document(
    pdf_shading_test_document(
      "<< /ShadingType 2 /ColorSpace /DeviceRGB /Coords [0 0 200 0] /Function << /FunctionType 3 /Domain [0 1] /Functions [<< /FunctionType 2 /Domain [0 1] /C0 [1 0 0] /C1 [0 1 0] /N 1 >> << /FunctionType 2 /Domain [0 1] /C0 [0 1 0] /C1 [0 0 1] /N 1 >>] /Bounds [0.5] /Encode [0 1 0 1] >> >>",
    ),
    no_text_index=true,
  )
  let paints = pdf_test_body_paints(document)
  guard paints.length() == 1 else { fail("PDF stitching paint count") }
  guard paints[0] is @core.Gradient(0, _, stops) else {
    fail("PDF stitching paint kind")
  }
  assert_eq(stops.length(), 33, msg="PDF stitching stops")
}

///|
test "PDF function shading falls back to a flat colour" {
  let document = pdf_graphics_document(
    pdf_shading_test_document(
      "<< /ShadingType 1 /ColorSpace /DeviceRGB /Domain [0 1 0 1] /Function << /FunctionType 2 /Domain [0 1] /C0 [1 0 0] /C1 [1 0 0] /N 1 >> >>",
    ),
    no_text_index=true,
  )
  assert_eq(pdf_test_body_paints(document).length(), 0)
}

///|
fn pdf_pattern_test_document(pattern : String, content : Bytes) -> Bytes {
  pdf_test_pdf([
    b"<< /Type /Catalog /Pages 2 0 R >>",
    b"<< /Type /Pages /Kids [3 0 R] /Count 1 /MediaBox [0 0 200 200] >>",
    b"<< /Type /Page /Parent 2 0 R /Resources << /Pattern << /P1 5 0 R >> >> /Contents 4 0 R >>",
    pdf_test_stream("", content),
    @utf8.encode(pattern),
    @utf8.encode(
      "<< /ShadingType 2 /ColorSpace /DeviceRGB /Coords [0 0 100 0] /Function << /FunctionType 2 /Domain [0 1] /C0 [1 0 0] /C1 [0 0 1] /N 1 >> >>",
    ),
  ])
}

///|
test "PDF shading pattern fills a path" {
  let document = pdf_graphics_document(
    pdf_pattern_test_document(
      "<< /Type /Pattern /PatternType 2 /Shading 6 0 R /Matrix [1 0 0 1 0 0] >>",
      b"q /Pattern cs /P1 scn 0 0 100 100 re f Q",
    ),
    no_text_index=true,
  )
  let paints = pdf_test_body_paints(document)
  guard paints.length() == 1 else { fail("PDF pattern paint count") }
  guard paints[0] is @core.Gradient(0, coords, stops) else {
    fail("PDF pattern paint kind")
  }
  assert_eq(coords, [0.0, 0.0, 100.0, 0.0], msg="PDF pattern coords")
  assert_eq(stops.length(), 2, msg="PDF pattern stops")
  assert_eq(stops[0].color, 0xff0000ffU.reinterpret_as_int())
  assert_eq(stops[1].color, 0x0000ffffU.reinterpret_as_int())
}

///|
test "PDF tiling patterns fail closed" {
  let rejected = try {
    ignore(
      pdf_graphics_document(
        pdf_pattern_test_document(
          "<< /Type /Pattern /PatternType 1 /XStep 10 /YStep 10 /BBox [0 0 10 10] >>",
          b"q /Pattern cs /P1 scn 0 0 100 100 re f Q",
        ),
        no_text_index=true,
      ),
    )
    false
  } catch {
    InvalidStream(message) => message.contains("tiling patterns")
    _ => false
  }
  assert_true(rejected)
}

///|
test "PDF pattern outside a Pattern colour space fails closed" {
  let rejected = try {
    ignore(
      pdf_graphics_document(
        pdf_pattern_test_document(
          "<< /Type /Pattern /PatternType 2 /Shading 6 0 R >>", b"q /P1 scn 0 0 100 100 re f Q",
        ),
        no_text_index=true,
      ),
    )
    false
  } catch {
    InvalidStream(message) => message.contains("Pattern colour space")
    _ => false
  }
  assert_true(rejected)
}

///|
fn pdf_embedded_font_test_document(font_data : Bytes, filter : String) -> Bytes {
  pdf_test_pdf([
    b"<< /Type /Catalog /Pages 2 0 R >>",
    b"<< /Type /Pages /Kids [3 0 R] /Count 1 /MediaBox [0 0 200 200] >>",
    b"<< /Type /Page /Parent 2 0 R /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
    pdf_test_stream("", b"BT /F1 12 Tf 10 10 Td (A) Tj ET"),
    @utf8.encode(
      "<< /Type /Font /Subtype /TrueType /BaseFont /Embedded /FirstChar 32 /LastChar 32 /Widths [600] /FontDescriptor 6 0 R /Encoding /WinAnsiEncoding >>",
    ),
    @utf8.encode(
      "<< /Type /FontDescriptor /FontName /Embedded /Flags 32 /FontBBox [0 0 1000 1000] /ItalicAngle 0 /Ascent 800 /Descent -200 /CapHeight 700 /StemV 80 /FontFile2 7 0 R >>",
    ),
    pdf_test_stream(filter, font_data),
  ])
}

///|
fn pdf_test_font_part(document : Bytes) -> (String, Bytes) raise {
  let split = @core.single_to_split(document)
  let manifest = @core.parse_manifest(@utf8.decode(split.manifest))
  for part in manifest.parts {
    if part.kind == "font" {
      return (part.hash, @core.open_single(document).part(part.hash))
    }
  }
  fail("PDF font part is missing")
}

///|
test "PDF embedded TrueType font is stored unchanged" {
  let font_data = b"\x00\x01\x00\x00embedded-true-type"
  let document = pdf_graphics_document(
    pdf_embedded_font_test_document(font_data, ""),
    no_text_index=true,
  )
  let (hash, data) = pdf_test_font_part(document)
  assert_eq(data, font_data, msg="PDF embedded font bytes")
  let split = @core.single_to_split(document)
  let manifest = @core.parse_manifest(@utf8.decode(split.manifest))
  let body_hash = manifest.views[0].pages[0].layers[0].object
  let resources = @core.decode_object_resources(
    @core.open_single(document).part(body_hash),
  )
  assert_eq(resources.fonts[0].hash, Some(hash), msg="PDF font resource hash")
}

///|
test "PDF embedded Flate font stream is decoded" {
  let font_data = b"\x00\x01\x00\x00flate-font"
  let document = pdf_graphics_document(
    pdf_embedded_font_test_document(
      @zlib.compress(font_data[:]),
      "/Filter /FlateDecode",
    ),
    no_text_index=true,
  )
  let (_, data) = pdf_test_font_part(document)
  assert_eq(data, font_data, msg="PDF embedded Flate font bytes")
}

///|
test "PDF Type1 font programs fail closed" {
  let rejected = try {
    ignore(
      pdf_graphics_document(
        pdf_test_pdf([
          b"<< /Type /Catalog /Pages 2 0 R >>",
          b"<< /Type /Pages /Kids [3 0 R] /Count 1 /MediaBox [0 0 200 200] >>",
          b"<< /Type /Page /Parent 2 0 R /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
          pdf_test_stream("", b"BT /F1 12 Tf 10 10 Td (A) Tj ET"),
          @utf8.encode(
            "<< /Type /Font /Subtype /Type1 /BaseFont /Embedded /FirstChar 32 /LastChar 32 /Widths [600] /FontDescriptor 6 0 R /Encoding /WinAnsiEncoding >>",
          ),
          @utf8.encode(
            "<< /Type /FontDescriptor /FontName /Embedded /Flags 32 /FontBBox [0 0 1000 1000] /ItalicAngle 0 /Ascent 800 /Descent -200 /CapHeight 700 /StemV 80 /FontFile 7 0 R >>",
          ),
          pdf_test_stream("", b"%!PS-AdobeFont-1.0"),
        ]),
        no_text_index=true,
      ),
    )
    false
  } catch {
    InvalidStream(message) => message.contains("unsupported embedded PDF font")
    _ => false
  }
  assert_true(rejected)
}

///|
test "PDF link annotations become link commands" {
  let document = pdf_graphics_document(
    pdf_test_pdf([
      b"<< /Type /Catalog /Pages 2 0 R >>",
      b"<< /Type /Pages /Kids [3 0 R] /Count 1 /MediaBox [0 0 200 200] >>",
      b"<< /Type /Page /Parent 2 0 R /Contents 4 0 R /Annots [5 0 R] >>",
      pdf_test_stream("", b""),
      @utf8.encode(
        "<< /Type /Annot /Subtype /Link /Rect [10 20 30 40] /A << /S /URI /URI (https://example.org/) >> >>",
      ),
    ]),
    no_text_index=true,
  )
  let split = @core.single_to_split(document)
  let manifest = @core.parse_manifest(@utf8.decode(split.manifest))
  let body_hash = manifest.views[0].pages[0].layers[0].object
  let resources = @core.decode_object_resources(
    @core.open_single(document).part(body_hash),
  )
  let commands = @render.compile_object(resources.object)
  let mut found : (Double, Double, Double, Double, String)? = None
  for command in commands {
    match command {
      @render.Link(x, y, width, height, url) =>
        found = Some((x, y, width, height, url))
      _ => ()
    }
  }
  match found {
    Some((x, y, width, height, url)) => {
      assert_eq((x, y, width, height), (10.0, 20.0, 20.0, 20.0))
      assert_eq(url, "https://example.org/")
    }
    None => fail("PDF link annotation is missing")
  }
}
