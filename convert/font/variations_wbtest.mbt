///|
test "variable axes and truncated instances" {
  let data = Bytes::make(52, 0).to_array()
  data[1] = 1
  data[5] = 16
  data[9] = 1
  data[11] = 20
  data[13] = 3
  data[15] = 8
  data[16] = b'w'
  data[17] = b'g'
  data[18] = b'h'
  data[19] = b't'
  data[20] = 0xff
  data[21] = 0xff
  data[25] = 0x01
  data[29] = 0x03
  data[33] = 1
  let result = parse_variations(
    Bytes::from_array(data),
    parse_specimen_names(b""),
  )
  assert_eq(result.axes.length(), 1)
  assert_eq(result.axes[0].tag, "wght")
  assert_eq(result.axes[0].minimum, -1.0)
  assert_eq(result.axes[0].default_value, 1.0)
  assert_true(result.axes[0].hidden)
  assert_eq(result.instances.length(), 2)
  assert_eq(result.instances[0].coordinates, [0.0])
  assert_eq(result.instances[1].coordinates, [0.0])
}

///|
test "variable axis bounds cannot overflow" {
  let data : Bytes = b"\x00\x01\x00\x00\xff\xff\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff"
  let result = parse_variations(data, parse_specimen_names(b""))
  assert_eq(result.axes.length(), 0)
  assert_eq(result.instances.length(), 0)
}
