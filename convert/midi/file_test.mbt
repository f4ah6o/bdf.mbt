///|
test "SMF repair drops trailing damage and inserts end of track" {
  let input = b"MThd\x00\x00\x00\x06\x00\x00\x00\x01\x01\xe0MTrk\x00\x00\x00\x05\x00\x90\x3c\x40\x00"
  let file = @midi.read_file(input)
  assert_eq(file.tracks.length(), 1)
  assert_eq(file.warnings, [
    "track 1 is cut short; it is read up to the cut", "notes without a note-off end with their track",
  ])
  assert_eq(
    file.smf,
    Some(
      b"MThd\x00\x00\x00\x06\x00\x00\x00\x01\x01\xe0MTrk\x00\x00\x00\x08\x00\x90\x3c\x40\x00\xff\x2f\x00",
    ),
  )
}

///|
test "SMF formats and SMPTE playback repair" {
  let input = b"MThd\x00\x00\x00\x06\x00\x02\x00\x01\x01\xe0MTrk\x00\x00\x00\x04\x00\xff\x2f\x00"
  let file = @midi.read_file(input)
  assert_eq(file.header.format, 2)
  assert_eq(
    file.smf,
    Some(
      b"MThd\x00\x00\x00\x06\x00\x01\x00\x01\x01\xe0MTrk\x00\x00\x00\x04\x00\xff\x2f\x00",
    ),
  )
  let smpte = @midi.read_file(
    b"MThd\x00\x00\x00\x06\x00\x00\x00\x01\xe3\x50MTrk\x00\x00\x00\x04\x00\xff\x2f\x00",
  )
  assert_eq(smpte.smf, None)
}
