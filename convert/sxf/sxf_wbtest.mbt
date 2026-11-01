///|
test "sxf converts a minimal SFC drawing" {
  let data = @utf8.encode(
    "/*SXF\n#1 = line_feature('0','1','1','1','0','0','100','100')\nSXF*/\n/*SXF\n#2 = drawing_sheet_feature('s','3','1','0','0')\nSXF*/",
  )
  assert_true(detect(data))
  let result = convert(data) catch {
    SxfInvalid(message) => fail("SFC fixture did not convert: " + message)
  }
  assert_eq(result.pages, 1)
  let document = @core.open_single(result.bdf) catch {
    _ => fail("SFC BDF did not open")
  }
  assert_eq(document.manifest.views[0].pages.length(), 1)
  assert_true(document.manifest.views[0].pages[0].width > 1190.0)
}

///|
test "sxf rejects P21 with an explicit error" {
  let rejected = try {
    let _ = convert(b"ISO-10303-21;\nHEADER;\nENDSEC;")
    false
  } catch {
    SxfInvalid(message) => message.contains("P21")
  }
  assert_true(rejected)
}
