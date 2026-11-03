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
test "PDF indexed and separation color spaces produce RGB" {
  let indexed = PdfIndexed(
    PdfBaseRGB,
    1,
    b"\xff\x00\x00\x00\xff\x00",
  )
  assert_eq(
    pdf_device_color(indexed, [1.0]),
    pdf_color(0.0, 1.0, 0.0),
    msg="PDF indexed color",
  )
  let separation = PdfSeparation(PdfBaseRGB, pdf_default_function())
  assert_eq(
    pdf_device_color(separation, [0.5]),
    pdf_color(0.5, 0.5, 0.5),
    msg="PDF separation color",
  )
}

///|
test "PDF separation color space resources render" {
  let document = pdf_graphics_document(
    pdf_test_pdf([
      b"<< /Type /Catalog /Pages 2 0 R >>",
      b"<< /Type /Pages /Kids [3 0 R] /Count 1 /MediaBox [0 0 200 200] >>",
      b"<< /Type /Page /Parent 2 0 R /Resources << /ColorSpace << /CS0 5 0 R >> >> /Contents 4 0 R >>",
      pdf_test_stream("", b"/CS0 cs 0.5 scn 0 0 10 10 re f"),
      @utf8.encode(
        "[/Separation /Spot /DeviceCMYK << /FunctionType 2 /Domain [0 1] /C0 [0 0 0 1] /C1 [1 0 0 0] /N 1 >>]",
      ),
    ]),
    no_text_index=true,
  )
  assert_eq(pdf_test_fill_rects(document), 1, msg="PDF separation color fill")
}

///|
test "PDF text objects tolerate graphics-state operators" {
  let graphics = PdfGraphics::new(10.0, 10.0, (1.0, 0.0, 0.0, 1.0, 0.0, 0.0))
  let accepted = try {
    graphics.run(b"BT q 1 0 0 1 0 0 cm Q ET")
    true
  } catch {
    _ => false
  }
  assert_true(accepted, msg="PDF graphics-state operator in text object")
}

///|
test "PDF compatibility sections ignore unknown operators" {
  let graphics = PdfGraphics::new(10.0, 10.0, (1.0, 0.0, 0.0, 1.0, 0.0, 0.0))
  let accepted = try {
    graphics.run(b"BX /Unknown 1 2 op EX 0 0 10 10 re f")
    true
  } catch {
    _ => false
  }
  assert_true(accepted, msg="PDF compatibility section")
}

///|
test "unsupported PDF graphics operators name the operator" {
  let graphics = PdfGraphics::new(10.0, 10.0, (1.0, 0.0, 0.0, 1.0, 0.0, 0.0))
  let named = try {
    graphics.run(b"QX")
    false
  } catch {
    InvalidStream(message) => message.contains("QX")
    _ => false
  }
  assert_true(named, msg="PDF unsupported operator name")
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
fn pdf_soft_mask_test_document(subtype : String, extra : String) -> Bytes {
  pdf_test_pdf([
    b"<< /Type /Catalog /Pages 2 0 R >>",
    b"<< /Type /Pages /Kids [3 0 R] /Count 1 /MediaBox [0 0 200 200] >>",
    b"<< /Type /Page /Parent 2 0 R /Resources << /ExtGState << /GS1 5 0 R >> >> /Contents 4 0 R >>",
    pdf_test_stream("", b"q /GS1 gs 0 0 100 100 re f Q"),
    @utf8.encode(
      "<< /Type /ExtGState /SMask << /S /" +
      subtype +
      " " +
      extra +
      " /G 6 0 R >> >>",
    ),
    pdf_test_stream(
      "/Type /XObject /Subtype /Form /BBox [0 0 100 100] /Resources << >>",
      b"1 g 0 0 100 100 re f",
    ),
  ])
}

///|
test "PDF ExtGState soft masks use BDF mask commands" {
  let document = pdf_graphics_document(
    pdf_soft_mask_test_document("Luminosity", ""),
    no_text_index=true,
  )
  let commands = pdf_test_body_commands(document)
  let mut groups = 0
  let mut masks = 0
  let mut mask_kind = -1
  for command in commands {
    match command {
      @render.GroupBegin(_, _, _, _, _, _) => groups += 1
      @render.MaskBegin(kind, _, _) => {
        masks += 1
        mask_kind = kind
      }
      _ => ()
    }
  }
  assert_eq(groups, 1, msg="PDF soft mask group count")
  assert_eq(masks, 1, msg="PDF soft mask command count")
  assert_eq(mask_kind, 1, msg="PDF luminosity soft mask kind")
}

///|
test "PDF alpha soft masks use the alpha kind" {
  let document = pdf_graphics_document(
    pdf_soft_mask_test_document("Alpha", ""),
    no_text_index=true,
  )
  let commands = pdf_test_body_commands(document)
  let mut mask_kind = -1
  for command in commands {
    match command {
      @render.MaskBegin(kind, _, _) => mask_kind = kind
      _ => ()
    }
  }
  assert_eq(mask_kind, 0, msg="PDF alpha soft mask kind")
}

///|
test "PDF soft mask transfer functions become a table" {
  let document = pdf_graphics_document(
    pdf_soft_mask_test_document(
      "Luminosity",
      "/TR << /FunctionType 2 /Domain [0 1] /C0 [0] /C1 [1] /N 1 >>",
    ),
    no_text_index=true,
  )
  let commands = pdf_test_body_commands(document)
  let mut transfer_length = -1
  for command in commands {
    match command {
      @render.MaskBegin(_, _, transfer) => transfer_length = transfer.length()
      _ => ()
    }
  }
  assert_eq(transfer_length, 256, msg="PDF soft mask transfer table size")
}

///|
fn check_pdf_graphics_document(data : Bytes, expected : Bytes) -> Unit raise {
  let actual = pdf_graphics_document(data, no_text_index=true)
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
fn check_pdf_indexed_graphics_document(
  data : Bytes,
  expected : Bytes,
) -> Unit raise {
  let actual = pdf_graphics_document(data)
  let left = @core.single_to_split(actual)
  let right = @core.single_to_split(expected)
  assert_eq(left.manifest, right.manifest, msg="PDF indexed BDF manifest")
  assert_eq(
    left.parts.length(),
    right.parts.length(),
    msg="PDF indexed BDF part count",
  )
  let actual_document = @core.open_single(actual)
  let expected_document = @core.open_single(expected)
  for i in 0..<left.parts.length() {
    assert_eq(
      left.parts[i].hash,
      right.parts[i].hash,
      msg="PDF indexed BDF part hash",
    )
    assert_eq(
      actual_document.part(left.parts[i].hash),
      expected_document.part(right.parts[i].hash),
      msg="PDF indexed BDF part bytes",
    )
  }
}

///|
fn check_pdf_graphics_document_options(
  data : Bytes,
  expected : Bytes,
) -> Unit raise {
  let actual = pdf_graphics_document(
    data,
    box="media",
    title="Overridden",
    no_text_index=true,
  )
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
      b"BT /missing 12 Tf (x) Tj BI ET", b"BT /missing 12 Tf 0 0 m ET",
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

///|
test "PDF matrix scale matches upstream Go fused determinant" {
  assert_eq(
    pdf_matrix_scale((1.0, 0.667, 11.37, 7.82579, 0.0, 0.0)),
    0.49193495504995344,
  )
}

///|
test "unsupported positioning during vertical PDF text fails closed" {
  let graphics = PdfGraphics::new(10.0, 10.0, (1.0, 0.0, 0.0, 1.0, 0.0, 0.0))
  graphics.text.vertical_text.write_string("a")
  let rejected = try {
    ignore(graphics.text_operator(b"Td", [Integer(0L), Integer(-12L)]))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "PDF text index failure warns and leaves the document unindexed" {
  let writer = @core.DocumentWriter::new()
  let view : Map[String, Json] = {
    "id": Json::string("pages"),
    "kind": Json::string("fixed"),
  }
  let warnings = pdf_write_index(
    writer,
    view,
    [],
    Some("objects are drawn too many times"),
    false,
  )
  assert_eq(warnings, ["text index: bdf: objects are drawn too many times"])
  assert_true(view.get("textIndex") is None)
  writer.add_view(Json::object(view))
  let split = @core.single_to_split(writer.write_single())
  assert_eq(split.parts.length(), 0)
  assert_eq(
    pdf_write_index(writer, view, [], Some("ignored"), true).length(),
    0,
  )
}

///|
// The stored length of a compressed part depends on the DEFLATE encoder, so
// compare manifests with every part's "len" field canonicalized. Hashes,
// decoded sizes, page references and the part bytes themselves are still
// compared exactly.
fn pdf_manifest_without_stored_lengths(manifest : Bytes) -> Bytes {
  let out = @buffer.Buffer(size_hint=manifest.length())
  let mut i = 0
  while i < manifest.length() {
    if i + 6 <= manifest.length() &&
      manifest[i] == b'"' &&
      manifest[i + 1] == b'l' &&
      manifest[i + 2] == b'e' &&
      manifest[i + 3] == b'n' &&
      manifest[i + 4] == b'"' &&
      manifest[i + 5] == b':' {
      out.write_string_utf8("\"len\":0")
      i += 6
      while i < manifest.length() && manifest[i] >= b'0' && manifest[i] <= b'9' {
        i += 1
      }
    } else {
      out.write_byte(manifest[i])
      i += 1
    }
  }
  out.to_bytes()
}

///|
fn check_pdf_shared_document(
  data : Bytes,
  no_share : Bool,
  no_index : Bool,
  expected : Bytes,
  expected_count : Int32,
  expected_saved : Int64,
  expected_warnings : Array[String],
) -> Unit raise {
  let (actual, warnings, count, saved) = pdf_graphics_document_full(
    data,
    no_share_prefix=no_share,
    no_text_index=no_index,
  )
  assert_eq(
    (count, saved),
    (expected_count, expected_saved),
    msg="PDF prefix share stats",
  )
  assert_eq(warnings, expected_warnings, msg="PDF warnings")
  let left = @core.single_to_split(actual)
  let right = @core.single_to_split(expected)
  assert_eq(
    pdf_manifest_without_stored_lengths(left.manifest),
    pdf_manifest_without_stored_lengths(right.manifest),
    msg="PDF shared BDF manifest",
  )
  assert_eq(
    left.parts.length(),
    right.parts.length(),
    msg="PDF shared BDF part count",
  )
  let actual_doc = @core.open_single(actual)
  let expected_doc = @core.open_single(expected)
  for i in 0..<left.parts.length() {
    assert_eq(
      left.parts[i].hash,
      right.parts[i].hash,
      msg="PDF shared BDF part hash",
    )
    assert_eq(
      actual_doc.part(left.parts[i].hash),
      expected_doc.part(right.parts[i].hash),
      msg="PDF shared BDF part bytes",
    )
  }
}
