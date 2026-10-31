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
    graphics.run(b"BT")
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
