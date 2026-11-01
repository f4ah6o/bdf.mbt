///|
test "gerber converts a minimal flash" {
  let data = @utf8.encode("%FSLAX24Y24*%\n%MOMM*%\n%ADD10C,0.5*%\nD10*\nX10000Y10000D03*\nM02*\n")
  assert_true(detect(data))
  let result = convert(data) catch {
    GerberInvalid(message) => fail("Gerber fixture did not convert: " + message)
  }
  assert_eq(result.pages, 1)
  let document = @core.open_single(result.bdf) catch {
    _ => fail("Gerber BDF did not open")
  }
  assert_eq(document.manifest.views[0].pages.length(), 1)
}

///|
test "gerber rejects a non-Gerber input" {
  let rejected = try {
    let _ = convert(b"not a Gerber file")
    false
  } catch {
    GerberInvalid(_) => true
  }
  assert_true(rejected)
}
