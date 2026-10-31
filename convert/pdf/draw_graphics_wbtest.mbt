///|
fn check_pdf_graphics(content : Bytes, expected : Bytes) -> Unit raise {
  let graphics = PdfGraphics::new(
    612.0,
    792.0,
    (1.0, 0.0, 0.0, -1.0, 0.0, 792.0),
  )
  graphics.run(content)
  let actual = graphics.object.encode()
  if actual != expected {
    let mut i = 0
    while i < actual.length() &&
          i < expected.length() &&
          actual[i] == expected[i] {
      i += 1
    }
    let a = if i < actual.length() { actual[i].to_int() } else { -1 }
    let e = if i < expected.length() { expected[i].to_int() } else { -1 }
    fail(
      "PDF graphics mismatch at \{i}: got \{a}, expected \{e}; content \{content}",
    )
  }
}

///|
test "unsupported PDF graphics commands fail closed" {
  let graphics = PdfGraphics::new(10.0, 10.0, (1.0, 0.0, 0.0, 1.0, 0.0, 0.0))
  let rejected = try {
    graphics.run(b"BI")
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
fn check_pdf_graphics_page(
  data : Bytes,
  width : Double,
  height : Double,
  expected : Bytes,
) -> Unit raise {
  let file = pdf_open_file(data)
  let (pages, _) = file.page_leaves()
  assert_eq(pages.length(), 1)
  let (geometry, object) = file.graphics_page(pages[0], "crop")
  assert_eq(geometry.width, width)
  assert_eq(geometry.height, height)
  if object != expected {
    let mut i = 0
    while i < object.length() &&
          i < expected.length() &&
          object[i] == expected[i] {
      i += 1
    }
    let a = if i < object.length() { object[i].to_int() } else { -1 }
    let e = if i < expected.length() { expected[i].to_int() } else { -1 }
    fail(
      "page object mismatch at \{i}: got \{a}, expected \{e}; geometry \{geometry.matrix}",
    )
  }
}

///|
test "unsupported PDF soft masks fail closed" {
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
  let resources = PdfDict([
    (b"ExtGState", PdfDict([(b"GS1", PdfDict([(b"SMask", PdfDict([]))]))])),
  ])
  let graphics = PdfGraphics::new(
    10.0,
    10.0,
    (1.0, 0.0, 0.0, 1.0, 0.0, 0.0),
    file=Some(file),
    resources=Some(resources),
  )
  let rejected = try {
    graphics.run(b"/GS1 gs")
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "graphics-only PDF pages reject annotations" {
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
  let attrs : PdfPageAttrs = {
    media: None,
    crop: None,
    rotate: 0,
    resources: None,
  }
  let page : PdfPageLeaf = {
    dict: PdfDict([(b"Annots", PdfArray([PdfDict([])]))]),
    reference: None,
    attrs,
    error: None,
  }
  let rejected = try {
    ignore(file.graphics_page(page, "crop"))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
fn check_pdf_graphics_document(data : Bytes, expected : Bytes) -> Unit raise {
  let actual = pdf_graphics_document(data)
  let left = @core.single_to_split(actual)
  let right = @core.single_to_split(expected)
  assert_eq(left.manifest, right.manifest, msg="PDF BDF manifest")
  assert_eq(left.parts.length(), right.parts.length(), msg="PDF BDF part count")
  let actual_document = @core.open_single(actual)
  let expected_document = @core.open_single(expected)
  for i in 0..<left.parts.length() {
    assert_eq(left.parts[i].hash, right.parts[i].hash, msg="PDF BDF part hash")
    assert_eq(
      actual_document.part(left.parts[i].hash),
      expected_document.part(right.parts[i].hash),
      msg="PDF BDF part bytes",
    )
  }
}

///|
fn check_pdf_graphics_document_options(
  data : Bytes,
  expected : Bytes,
) -> Unit raise {
  let actual = pdf_graphics_document(data, box="media", title="Overridden")
  let left = @core.single_to_split(actual)
  let right = @core.single_to_split(expected)
  assert_eq(left.manifest, right.manifest)
  let actual_document = @core.open_single(actual)
  let expected_document = @core.open_single(expected)
  assert_eq(left.parts.length(), right.parts.length())
  for i in 0..<left.parts.length() {
    assert_eq(left.parts[i].hash, right.parts[i].hash)
    assert_eq(
      actual_document.part(left.parts[i].hash),
      expected_document.part(right.parts[i].hash),
    )
  }
}

///|
test "unsupported PDF text operations fail closed" {
  for
    content in [
      b"BT /missing 12 Tf 1 Tw (x) Tj ET", b"BT /missing 12 Tf (x) Tj /missing 13 Tf (y) Tj ET",
      b"BT /missing 12 Tf [(x) -200 (y)] TJ ET", b"BT /missing 12 Tf 0 0 m ET",
    ] {
    let graphics = PdfGraphics::new(10.0, 10.0, (1.0, 0.0, 0.0, 1.0, 0.0, 0.0))
    let rejected = try {
      graphics.run(content)
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "PDF text advance uses upstream Go fused arithmetic" {
  let graphics = PdfGraphics::new(10.0, 10.0, (1.0, 0.0, 0.0, 1.0, 0.0, 0.0))
  graphics.execute(b"BT", [])
  graphics.execute(b"Tf", [Name(b"missing"), Real(11.37)])
  graphics.execute(b"Tc", [Real(0.121)])
  graphics.execute(b"Tj", [Literal(b"A")])
  assert_eq(graphics.text.advance, 7.70479)
}
