///|
test "localized name records and priority" {
  let data : Bytes = b"\x00\x01\x00\x07\x00\x64\x00\x03\x00\x01\x04\x09\x00\x01\x00\x04\x00\x00\x00\x00\x00\x00\x80\x00\x00\x01\x00\x02\x00\x04\x00\x03\x00\x01\x80\x01\x00\x01\x00\x02\x00\x06\x00\x01\x00\x00\x00\x00\x00\x02\x00\x07\x00\x08\x00\x00\x00\x00\x00\x07\x00\x04\x00\x04\x00\x0f\x00\x03\x00\x01\x04\x11\x00\x01\x00\x02\x00\x13\x00\x03\x00\x01\x04\x11\x00\x01\x00\x02\x00\x15\x00\x02\x00\x04\x00\x17\x00\x04\x00\x1b\x00\x41\x00\x42\x00\x58\x00\x59\x52\x65\x67\x75\x6c\x61\x72\x00\x54\x00\x00\x00\x58\x00\x58\x00\x6a\x00\x61\x00\x66\x00\x72"
  let names = parse_specimen_names(data)
  assert_false(names.cut)
  assert_eq(names.best(1), "AB")
  assert_eq(names.family(), "AB")
  assert_eq(names.full(), "T")
  assert_eq(names.local(1).length(), 2)
  assert_eq(names.local(1)[0].lang, "ja")
}

///|
test "name table budget counts repeated records" {
  let n = 100
  let offset = 6 + n * 12
  let data = Bytes::make(offset + 65534, 0).to_array()
  data[3] = n.to_byte()
  data[4] = (offset >> 8).to_byte()
  data[5] = (offset & 255).to_byte()
  for i in 0..<n {
    let rec = 6 + i * 12
    data[rec + 1] = 3
    data[rec + 3] = 1
    data[rec + 4] = 4
    data[rec + 5] = 9
    data[rec + 7] = 1
    data[rec + 8] = 255
    data[rec + 9] = 254
  }
  for i in offset..<data.length() {
    if i % 2 == 1 {
      data[i] = b'A'
    }
  }
  let names = parse_specimen_names(Bytes::from_array(data))
  assert_true(names.cut)
  assert_eq(names.records.length(), 1)
}
