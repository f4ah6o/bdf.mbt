///|
test "performance inherits initial channel controls across chunks" {
  let file = @midi.read_file(
    b"MThd\x00\x00\x00\x06\x00\x01\x00\x02\x01\xe0MTrk\x00\x00\x00\x0b\x00\xc1\x18\x00\xb1\x07\x5a\x00\xff\x2f\x00MTrk\x00\x00\x00\x0c\x00\x91\x3c\x50\x60\x81\x3c\x00\x00\xff\x2f\x00",
  )
  let p = @midi.performance(file)
  assert_eq(p.tracks.length(), 1)
  assert_eq(p.tracks[0].name, "Acoustic Guitar (nylon)")
  assert_eq(p.tracks[0].channel, 1)
  assert_eq(p.tracks[0].program, 24)
  assert_eq(p.tracks[0].volume, 90)
  assert_eq(p.tracks[0].pan, -1)
  assert_eq(p.tracks[0].notes[0].duration, 192L)
  assert_eq(p.end, 192L)
}

///|
test "zero length percussion is retained and tonal notes are dropped" {
  let file = @midi.read_file(
    b"MThd\x00\x00\x00\x06\x00\x00\x00\x01\x01\xe0MTrk\x00\x00\x00\x14\x00\x90\x3c\x50\x00\x80\x3c\x00\x00\x99\x24\x50\x00\x89\x24\x00\x00\xff\x2f\x00",
  )
  let p = @midi.performance(file)
  assert_eq(p.tracks.length(), 1)
  assert_eq(p.tracks[0].name, "Drums")
  assert_eq(p.tracks[0].notes[0].duration, 1L)
  assert_eq(p.end, 1L)
  assert_eq(p.warnings, ["notes of no length are left out"])
}
