///|
test "EPUB OPF accepts namespace prefixes and single-quoted attributes" {
  let opf = "<?xml version='1.0'?><opf:package xmlns:opf='http://www.idpf.org/2007/opf'><opf:manifest><opf:item id='c1' href='Text/ch1.xhtml' media-type='application/xhtml+xml'/></opf:manifest><opf:spine><opf:itemref idref='c1'/></opf:spine></opf:package>"
  let (spine, _, _, _) = epub_opf_parts(opf)
  assert_eq(spine.length(), 1)
  assert_eq(spine[0], "Text/ch1.xhtml")
}

///|
test "EPUB spine is converted to reader pages" {
  let data = @gzip.decompress(
    @base64.decode(epub_basic_fixture[:], ignore_whitespace=true)[:],
  ) catch { _ => b"" }
  assert_eq(detect(data), true)
  let result = convert(data)
  assert_eq(result.pages > 0, true)
  let doc = @core.open_single(result.bdf)
  assert_eq(doc.manifest.views[0].pages[0].width, 419.5, msg="EPUB A5 width")
  let index = @core.decode_text_index(doc.part(doc.manifest.views[0].text_index.unwrap()))
  let mut text = ""
  for run in index {
    text += run.text
  }
  assert_eq(text.length() > 20, true)
}

///|
fn epub_test_skip_varuint(ops : Bytes, from : Int32) -> Int32 {
  let mut at = from
  while at < ops.length() {
    let byte = ops[at]
    at += 1
    if (byte & 0x80) == 0 {
      break
    }
  }
  at
}

///|
fn epub_test_f32(ops : Bytes, at : Int32) -> Double {
  let bits = ops[at].to_int() |
    (ops[at + 1].to_int() << 8) |
    (ops[at + 2].to_int() << 16) |
    (ops[at + 3].to_int() << 24)
  Float::reinterpret_from_int(bits).to_double()
}

///|
fn epub_test_image_rects(ops : Bytes) -> Array[(Double, Double, Double, Double)] {
  let rects : Array[(Double, Double, Double, Double)] = []
  let mut at = 0
  while at < ops.length() {
    let opcode = ops[at]
    at += 1
    if opcode == 0x40 {
      at = epub_test_skip_varuint(ops, at)
      if at + 16 > ops.length() {
        break
      }
      rects.push(
        (epub_test_f32(ops, at), epub_test_f32(ops, at + 4), epub_test_f32(ops, at + 8), epub_test_f32(ops, at + 12)),
      )
      at += 16
    } else if opcode == 0x71 {
      if at >= ops.length() {
        break
      }
      at += 1
      at = epub_test_skip_varuint(ops, at)
    } else {
      break
    }
  }
  rects
}

///|
test "EPUB fixed layout converts pictures into fixed pages" {
  let data = @gzip.decompress(
    @base64.decode(epub_fixed_fixture[:], ignore_whitespace=true)[:],
  ) catch { _ => b"" }
  assert_eq(detect(data), true)
  let result = convert(data)
  assert_eq(result.pages, 6)
  let mut outside = 0
  for warning in result.warnings {
    if warning.contains("outside the reading order") {
      outside += 1
    }
  }
  assert_eq(outside, 1)
  assert_eq(result.warnings.length(), 1)
  let doc = @core.open_single(result.bdf)
  assert_eq(doc.manifest.views.length(), 1)
  let view = doc.manifest.views[0]
  assert_eq(view.id, "pages")
  assert_eq(view.kind, "fixed")
  assert_eq(view.direction, "rtl")
  assert_eq(view.title, "固定レイアウトのテスト")
  assert_true(view.text_index is None)
  assert_eq(view.pages.length(), 6)
  let mut figure = false
  for page in view.pages {
    assert_eq(page.width, 450.0)
    assert_eq(page.height, 600.0)
    assert_eq(page.layers.length(), 1)
    assert_eq(page.layers[0].role, "body")
    let object = @core.decode_object(doc.part(page.layers[0].object))
    assert_eq(object.images.length(), 1)
    for value in object.strings {
      if value == "The last page" {
        figure = true
      }
    }
    let rects = epub_test_image_rects(object.ops)
    assert_eq(rects.length(), 1)
    let (x, y, width, height) = rects[0]
    assert_eq(x, 0.0)
    assert_eq(y, 0.0)
    assert_eq(width, 450.0)
    assert_eq(height, 600.0)
  }
  assert_true(figure)
  // The cover's SVG wrapper is drawn as the PNG it holds; the page drawn in
  // SVG and the page whose picture is an SVG file are the two SVG images.
  let mut image_parts = 0
  let svg_parts : Array[Bytes] = []
  for part in doc.manifest.parts {
    if part.kind != "img" {
      continue
    }
    image_parts += 1
    let content = doc.part(part.hash)
    let head = @utf8.decode_lossy(
      content[:content.length().min(200)],
      ignore_bom=true,
    )
    if head.contains("<svg") {
      svg_parts.push(content)
    }
  }
  assert_eq(image_parts, 6)
  assert_eq(svg_parts.length(), 2)
  let mut svg_text = ""
  for part in svg_parts {
    svg_text += @utf8.decode_lossy(part[:], ignore_bom=true)
  }
  assert_true(svg_text.contains("<linearGradient id=\"sky\""))
  assert_true(svg_text.contains("fill=\"url(#sky)\""))
}

///|
test "EPUB fixed-layout parsing is bounded on malformed input" {
  let opf = "<package><metadata><meta property=\"rendition:layout\">pre-paginated</meta></metadata><manifest><item id=\"a\"/><item id=\"b\" href=\"b.xhtml\" media-type=\"application/xhtml+xml\"/></manifest><spine><itemref/><itemref idref=\"b\" linear=\"no\"/></spine></package>"
  assert_true(epub_is_pre_paginated(opf))
  assert_true(epub_spine_is_rtl(opf) == false)
  assert_eq(epub_manifest_items(opf).length(), 1)
  let refs = epub_spine_refs(opf)
  assert_eq(refs.length(), 1)
  assert_false(refs[0].linear)
  assert_true(
    epub_viewport("<meta name=\"viewport\" content=\"width=, height=\"/>") is None,
  )
  assert_true(epub_viewport("<meta name=\"viewport\" content=\"width=600, height=800\"/>") is Some(_))
  assert_true(epub_inline_svg("<svg width=\"1\">") is None)
  assert_true(epub_inline_svg("<svg viewBox=\"0 0 1 1\"><rect/></svg>") is Some(_))
  let (width, height) = epub_svg_size("<svg width='12pt' height='1in'/>")
  assert_eq(width, 16.0)
  assert_eq(height, 96.0)
  assert_eq(epub_css_pixels("600px"), 600.0)
  assert_eq(epub_image_format(b""), "")
  assert_eq(epub_image_format(b"\x89PNG"), "")
  assert_eq(epub_raster_size(b"", "png"), (0.0, 0.0))
  assert_eq(epub_raster_size(b"not an image", "jpeg"), (0.0, 0.0))
}

///|
fn epub_test_put_u16(bytes : Array[Byte], at : Int32, value : Int32) -> Unit {
  bytes[at] = (value & 0xff).to_byte()
  bytes[at + 1] = ((value >> 8) & 0xff).to_byte()
}

///|
fn epub_test_put_u32(bytes : Array[Byte], at : Int32, value : Int32) -> Unit {
  bytes[at] = (value & 0xff).to_byte()
  bytes[at + 1] = ((value >> 8) & 0xff).to_byte()
  bytes[at + 2] = ((value >> 16) & 0xff).to_byte()
  bytes[at + 3] = ((value >> 24) & 0xff).to_byte()
}

///|
/// Build a ZIP archive of stored entries for package-level tests.
fn epub_test_zip(files : Array[(String, String)]) -> Bytes {
  let names : Array[Bytes] = []
  let bodies : Array[Bytes] = []
  let offsets : Array[Int32] = []
  let mut total = 22
  for (name, body) in files {
    let name_bytes = @utf8.encode(name)
    let body_bytes = @utf8.encode(body)
    names.push(name_bytes)
    bodies.push(body_bytes)
    total += 30 + 76 + name_bytes.length() * 2 + body_bytes.length()
  }
  let out = Bytes::make(total, 0).to_array()
  let mut at = 0
  for i, name_bytes in names {
    offsets.push(at)
    let body = bodies[i]
    epub_test_put_u32(out, at, 0x04034b50)
    epub_test_put_u16(out, at + 4, 20)
    epub_test_put_u32(out, at + 18, body.length())
    epub_test_put_u32(out, at + 22, body.length())
    epub_test_put_u16(out, at + 26, name_bytes.length())
    for j in 0..<name_bytes.length() {
      out[at + 30 + j] = name_bytes[j]
    }
    for j in 0..<body.length() {
      out[at + 30 + name_bytes.length() + j] = body[j]
    }
    at += 30 + name_bytes.length() + body.length()
  }
  let central_start = at
  for i, name_bytes in names {
    let body = bodies[i]
    epub_test_put_u32(out, at, 0x02014b50)
    epub_test_put_u16(out, at + 4, 20)
    epub_test_put_u16(out, at + 6, 20)
    epub_test_put_u32(out, at + 20, body.length())
    epub_test_put_u32(out, at + 24, body.length())
    epub_test_put_u16(out, at + 28, name_bytes.length())
    epub_test_put_u32(out, at + 42, offsets[i])
    for j in 0..<name_bytes.length() {
      out[at + 46 + j] = name_bytes[j]
    }
    at += 46 + name_bytes.length()
  }
  let central_size = at - central_start
  epub_test_put_u32(out, at, 0x06054b50)
  epub_test_put_u16(out, at + 8, names.length())
  epub_test_put_u16(out, at + 10, names.length())
  epub_test_put_u32(out, at + 12, central_size)
  epub_test_put_u32(out, at + 16, central_start)
  Bytes::from_array(out)
}

///|
test "EPUB pre-paginated book with text pages falls back to reflowable" {
  let opf = "<?xml version=\"1.0\"?><package xmlns=\"http://www.idpf.org/2007/opf\" version=\"3.0\"><metadata xmlns:dc=\"http://purl.org/dc/elements/1.1/\"><dc:title>Broken fixed</dc:title><dc:language>ja</dc:language><meta property=\"rendition:layout\">pre-paginated</meta></metadata><manifest><item id=\"c1\" href=\"a.xhtml\" media-type=\"application/xhtml+xml\"/></manifest><spine><itemref idref=\"c1\"/></spine></package>"
  let page = "<?xml version=\"1.0\"?><html xmlns=\"http://www.w3.org/1999/xhtml\"><head><title>Fixed</title><meta name=\"viewport\" content=\"width=600, height=800\"/></head><body><img src=\"one.png\" alt=\"\"/><img src=\"two.png\" alt=\"\"/></body></html>"
  let container = "<?xml version=\"1.0\"?><container version=\"1.0\" xmlns=\"urn:oasis:names:tc:opendocument:xmlns:container\"><rootfiles><rootfile full-path=\"OEBPS/content.opf\" media-type=\"application/oebps-package+xml\"/></rootfiles></container>"
  let data = epub_test_zip([
    ("mimetype", "application/epub+zip"),
    ("META-INF/container.xml", container),
    ("OEBPS/content.opf", opf),
    ("OEBPS/a.xhtml", page),
  ])
  assert_eq(detect(data), true)
  let result = convert(data)
  assert_true(result.pages > 0)
  let mut warned = false
  for warning in result.warnings {
    if warning.contains("reflowable text") {
      warned = true
    }
  }
  assert_true(warned)
  let doc = @core.open_single(result.bdf)
  assert_eq(doc.manifest.views.length(), 1)
  // The fixed-layout path is not taken for a page that holds two pictures.
  assert_true(doc.manifest.views[0].pages[0].width == 419.5)
}
