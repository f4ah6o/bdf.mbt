///|
test "MIDI metadata selects a legacy encoding for the whole file" {
  let input = b"MThd\x00\x00\x00\x06\x00\x00\x00\x01\x01\xe0MTrk\x00\x00\x00\x17\x00\xff\x01\x04\x82\xb1\x82\xf1\x00\xff\x01\x01\xe9\x00\xff\x01\x03\xe6\x97\xa5\x00\xff\x2f\x00"
  let file = @midi.read_file(input)
  let decoder = @midi.MidiTextDecoder::new(file)
  assert_false(decoder.uses_shift_jis())
  assert_eq(decoder.text(b"\xe9"), "é")
  assert_eq(decoder.text(b"\xe6\x97\xa5"), "日")
  assert_eq(decoder.name(b"\xef\xbb\xbf A\x00\tB \n"), "A B")
}

///|
test "MIDI metadata recognizes Shift_JIS" {
  let input = b"MThd\x00\x00\x00\x06\x00\x00\x00\x01\x01\xe0MTrk\x00\x00\x00\x0c\x00\xff\x01\x04\x82\xb1\x82\xf1\x00\xff\x2f\x00"
  let decoder = @midi.MidiTextDecoder::new(@midi.read_file(input))
  assert_true(decoder.uses_shift_jis())
  assert_eq(decoder.text(b"\x82\xb1\x82\xf1"), "こん")
}
