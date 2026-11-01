///|
test "kicad converts a minimal board" {
  let data = @utf8.encode(
    "(kicad_pcb (version 20241229) (paper \"A4\")\n" +
    "(layers (0 \"F.Cu\" signal) (25 \"Edge.Cuts\" user))\n" +
    "(gr_line (start 0 0) (end 10 0) (stroke (width 0.1)) (layer \"Edge.Cuts\"))\n" +
    "(gr_line (start 10 0) (end 10 5) (stroke (width 0.1)) (layer \"Edge.Cuts\"))\n" +
    "(segment (start 1 1) (end 8 1) (width 0.25) (layer \"F.Cu\")))\n",
  )
  assert_true(detect(data))
  let result = convert(data) catch {
    KicadInvalid(message) => fail("KiCad fixture did not convert: " + message)
  }
  assert_eq(result.pages, 1)
  let document = @core.open_single(result.bdf) catch {
    _ => fail("KiCad BDF did not open")
  }
  assert_eq(document.manifest.views[0].pages.length(), 1)
}

///|
test "kicad rejects a schematic for now" {
  let rejected = try {
    let _ = convert(@utf8.encode("(kicad_sch (version 20241229))"))
    false
  } catch {
    KicadInvalid(message) => message.contains("kicad_pcb")
  }
  assert_true(rejected)
}
