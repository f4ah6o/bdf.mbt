///|
fn dxf_test_u16(out : Array[Byte], value : Int) -> Unit {
  out.push((value & 255).to_byte())
  out.push(((value >> 8) & 255).to_byte())
}

///|
fn dxf_test_code(out : Array[Byte], code : Int) -> Unit {
  dxf_test_u16(out, code)
}

///|
fn dxf_test_string(out : Array[Byte], value : String) -> Unit {
  for byte in @utf8.encode(value) {
    out.push(byte)
  }
  out.push((0).to_byte())
}

///|
fn dxf_test_f64(out : Array[Byte], value : Double) -> Unit {
  let bits = value.reinterpret_as_uint64()
  for i in 0..<8 {
    out.push(((bits >> (i * 8)) & 255UL).to_byte())
  }
}

///|
test "dxf reads a binary drawing with 16-bit group codes" {
  let out : Array[Byte] = []
  for byte in @utf8.encode("AutoCAD Binary DXF") {
    out.push(byte)
  }
  for value in [13, 10, 26, 0] {
    out.push(value.to_byte())
  }
  dxf_test_code(out, 0)
  dxf_test_string(out, "SECTION")
  dxf_test_code(out, 2)
  dxf_test_string(out, "HEADER")
  dxf_test_code(out, 9)
  dxf_test_string(out, "$ACADVER")
  dxf_test_code(out, 1)
  dxf_test_string(out, "AC1032")
  dxf_test_code(out, 0)
  dxf_test_string(out, "ENDSEC")
  dxf_test_code(out, 0)
  dxf_test_string(out, "SECTION")
  dxf_test_code(out, 2)
  dxf_test_string(out, "ENTITIES")
  dxf_test_code(out, 0)
  dxf_test_string(out, "LINE")
  dxf_test_code(out, 8)
  dxf_test_string(out, "0")
  dxf_test_code(out, 10)
  dxf_test_f64(out, 0.0)
  dxf_test_code(out, 20)
  dxf_test_f64(out, 0.0)
  dxf_test_code(out, 11)
  dxf_test_f64(out, 10.0)
  dxf_test_code(out, 21)
  dxf_test_f64(out, 0.0)
  dxf_test_code(out, 0)
  dxf_test_string(out, "ENDSEC")
  dxf_test_code(out, 0)
  dxf_test_string(out, "EOF")
  let data = Bytes::from_array(out)
  assert_true(detect(data))
  let tags = read_tags(data) catch {
    _ => fail("binary DXF tags did not read")
  }
  assert_true(tags.length() > 8)
  let drawing = parse_dxf(tags)
  assert_eq(drawing.entities.length(), 1)
  let result = convert(data) catch {
    _ => fail("binary DXF did not convert")
  }
  assert_eq(result.pages, 1)
}
