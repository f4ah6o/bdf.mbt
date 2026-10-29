///|
test "credits use karaoke title and recognize Japanese credit labels" {
  let body = b"\x00\xff\x03\x04Song\x00\xff\x01\x06@TAria\x00\xff\x01\x15\xe4\xbd\x9c\xe6\x9b\xb2\xef\xbc\x9a\xe6\xbb\x9d\xe5\xbb\x89\xe5\xa4\xaa\xe9\x83\x8e\x00\xff\x2f\x00"
  let bytes = b"MThd\x00\x00\x00\x06\x00\x00\x00\x01\x01\xe0MTrk\x00\x00\x00\x2f".to_array()
  bytes.append(body.to_array())
  let file = @midi.read_file(Bytes::from_array(bytes))
  let c = @midi.credits(file)
  assert_eq(c.title, "Aria")
  assert_eq(c.composer, "滝廉太郎")
  assert_eq(@midi.track_name(file, 0, 9, true, 0), "Drums")
  assert_eq(@midi.program_name(40), "Violin")
}
