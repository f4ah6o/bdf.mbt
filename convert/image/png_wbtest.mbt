///|
test "PNG Creation Time accepts common upstream date formats" {
  assert_eq(
    png_creation_date("Tue, 1 Sep 2026 10:20:30 +0900"),
    "2026-09-01T10:20:30+09:00",
  )
  assert_eq(
    png_creation_date("Sunday, 06-Nov-94 08:49:37 GMT"),
    "1994-11-06T08:49:37Z",
  )
  assert_eq(
    png_creation_date("Tue Sep  1 10:20:30 2026"),
    "2026-09-01T10:20:30Z",
  )
  assert_eq(
    png_creation_date("Tue, 1 Sep 2026 10:20:30 +0960"),
    "2026-09-01T10:20:30+10:00",
  )
  assert_eq(png_creation_date("Bad, 1 Sep 2026 10:20:30 +0900"), "")
}

///|
test "PNG refuses timezone abbreviations requiring host timezone rules" {
  let rejected = try {
    ignore(png_creation_date("Tue, 1 Sep 2026 10:20:30 JST"))
    false
  } catch {
    ImageFailure(message) => message.contains("timezone")
    _ => false
  }
  assert_true(rejected)
}

///|
test "PNG raw profiles decode whitespace-separated hex" {
  assert_eq(png_raw_profile("\nexif\n  4\n  4578 6966\n"), b"Exif")
  assert_eq(png_raw_profile("\nexif\n  4\n  4578 69x6\n"), b"Exi")
}

///|
test "PNG compressed text reads zlib and honors its output budget" {
  let data = @buffer.Buffer()
  data.write_bytes(b"Description\x00\x01\x00\x00\x00")
  data.write_bytes(@zlib.compress(b"hello"))
  let budget : PngTextBudget = { remaining: 100, }
  assert_eq(
    png_text("iTXt", data.to_bytes(), budget),
    Some(("Description", "hello")),
  )
  assert_eq(budget.remaining, 95)
  let limited : PngTextBudget = { remaining: 3, }
  assert_eq(
    png_text("iTXt", data.to_bytes(), limited),
    Some(("Description", "hel")),
  )
  assert_eq(limited.remaining, 0)
}

///|
test "PNG reads animation warning and preserves the image" {
  let png = b"\x89PNG\r\n\x1a\n\x00\x00\x00\x0dIHDR\x00\x00\x00\x07\x00\x00\x00\x05\x08\x02\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x08acTL\x00\x00\x00\x02\x00\x00\x00\x00\x00\x00\x00\x00"
  let result = convert(png, name="anim.png")
  assert_eq((result.format, result.width, result.height), ("png", 7.0, 5.0))
  assert_true(result.animated)
  assert_eq(result.summary, "1 page (7 × 5 px, PNG, animated)")
  assert_eq(result.warnings, ["animated image: the first frame is drawn"])
  let doc = @core.open_single(result.bdf)
  assert_eq(doc.part(doc.manifest.parts[0].hash), png)
}
