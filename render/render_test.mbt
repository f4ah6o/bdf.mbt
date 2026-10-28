///|
test "fill rectangle opset decoding" {
  let object : @core.ObjectPart = {
    bbox: (0.0, 0.0, 20.0, 20.0),
    strings: [],
    images: [],
    objects: [],
    ops: b"\x01\x20\x00\x00\x80\x3f\x00\x00\x00\x40\x00\x00\x40\x40\x00\x00\x80\x40\x02",
  }
  let result = compile_object(object)
  assert_eq(result.length(), 3)
  match result[1] {
    FillRect(x, y, w, h) => {
      assert_eq(x, 1.0)
      assert_eq(y, 2.0)
      assert_eq(w, 3.0)
      assert_eq(h, 4.0)
    }
    _ => fail("expected FillRect")
  }
}

///|
test "unknown render instruction is not ignored" {
  let object : @core.ObjectPart = {
    bbox: (0.0, 0.0, 0.0, 0.0),
    strings: [],
    images: [],
    objects: [],
    ops: b"\x99",
  }
  let mut rejected = false
  ignore(compile_object(object)) catch {
    _ => rejected = true
  }
  assert_eq(rejected, true)
}

///|
test "untrusted text indices are checked" {
  let object : @core.ObjectPart = {
    bbox: (0.0, 0.0, 0.0, 0.0),
    strings: [],
    images: [],
    objects: [],
    ops: b"\x30\x00",
  }
  let mut rejected = false
  ignore(compile_object(object)) catch {
    _ => rejected = true
  }
  assert_eq(rejected, true)
}

///|
test "decode line effects and metadata commands" {
  let object : @core.ObjectPart = {
    bbox: (0.0, 0.0, 0.0, 0.0),
    strings: ["blur(2px)", "https://example.com", "heading"],
    images: [],
    objects: [],
    ops: b"\x15\x02\x00\x00\x80\x3f\x00\x00\x00\x40\x00\x00\x40\x40\x17\x01\x18\x04\x03\x02\x01\x00\x00\x80\x3f\x00\x00\x00\x40\x00\x00\x40\x40\x19\x00\x70\x00\x00\x80\x3f\x00\x00\x00\x40\x00\x00\x40\x40\x00\x00\x80\x40\x01\x71\x03\x02",
  }
  let cmds = @render.compile_object(object)
  assert_eq(cmds.length(), 6)
  guard cmds[0] is Dash(segments, offset) else { fail("dash") }
  assert_eq(segments, [1.0, 2.0])
  assert_eq(offset, 3.0)
  guard cmds[1] is Blend(1) else { fail("blend") }
  guard cmds[2] is Shadow(color, blur, dx, dy) else { fail("shadow") }
  assert_eq((color, blur, dx, dy), (0x01020304, 1.0, 2.0, 3.0))
  guard cmds[3] is Filter("blur(2px)") else { fail("filter") }
  guard cmds[4] is Link(1.0, 2.0, 3.0, 4.0, "https://example.com") else {
    fail("link")
  }
  guard cmds[5] is Mark(3, "heading") else { fail("mark") }
}

///|
test "dash rejects truncated segment data" {
  let object : @core.ObjectPart = {
    bbox: (0.0, 0.0, 0.0, 0.0),
    strings: [],
    images: [],
    objects: [],
    ops: b"\x15\x02\x00\x00\x80\x3f\x00\x00\x00\x00",
  }
  let rejected = try {
    ignore(@render.compile_object(object))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "decode path drawing instructions" {
  let object : @core.ObjectPart = {
    bbox: (0.0, 0.0, 0.0, 0.0),
    strings: [],
    images: [],
    objects: [],
    ops: b"\x06\x00\x01\x22\x00\x00\x23\x00\x24\x00\x01\x00\x00\x80\x3f\x00\x00\x00\x40\x25\x01\x01\x00\x00\x00\x40\x40\x00\x00\x80\x40",
  }
  let cmds = @render.compile_object(object)
  assert_eq(cmds.length(), 5)
  guard cmds[0] is ClipPath(0, 1) else { fail("clip") }
  guard cmds[1] is FillPath(0, 0) else { fail("fill") }
  guard cmds[2] is StrokePath(0) else { fail("stroke") }
  guard cmds[3] is FillPathAt(0, 1, 1.0, 2.0) else { fail("fill at") }
  guard cmds[4] is FillPathRun(1, glyphs) else { fail("run") }
  assert_eq(glyphs.length(), 1)
  assert_eq((glyphs[0].path, glyphs[0].x, glyphs[0].y), (0, 3.0, 4.0))
}

///|
test "path run rejects truncated placements" {
  let object : @core.ObjectPart = {
    bbox: (0.0, 0.0, 0.0, 0.0),
    strings: [],
    images: [],
    objects: [],
    ops: b"\x25\x00\x02\x00\x00\x00\x00\x00\x00\x00\x00\x00",
  }
  let rejected = try {
    ignore(@render.compile_object(object))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}
