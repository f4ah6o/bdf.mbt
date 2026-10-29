///|
test "overlapping notes end in arrival order and all notes off closes remaining keys" {
  let body = b"\x00\x90\x3c\x64\x00\x90\x3c\x50\x0a\x80\x3c\x00\x00\x90\x28\x40\x0a\xb0\x7b\x00\x00\xff\x2f\x00"
  let reader = @midi.MidiTrackReader::new()
  let result = reader.read(@midi.scan_track(body, 1000L), 0)
  assert_eq(result.notes.length(), 3)
  assert_eq(result.notes[0].key, 60)
  assert_eq(result.notes[0].velocity, 100)
  assert_eq(result.notes[0].off, 10L)
  assert_eq(result.notes[1].key, 40)
  assert_eq(result.notes[1].off, 20L)
  assert_eq(result.notes[2].key, 60)
  assert_eq(result.notes[2].velocity, 80)
  assert_eq(result.notes[2].off, 20L)
  assert_eq(reader.warnings().length(), 0)
}

///|
test "track reader shares warning state across tracks" {
  let reader = @midi.MidiTrackReader::new()
  let body = b"\x00\x90\xbc\xff\x00\xff\x58\x02\x00\x09\x00\xf8\x00"
  let first = reader.read(@midi.scan_track(body, 1000L), 0)
  let second = reader.read(@midi.scan_track(body, 1000L), 1)
  assert_eq(first.notes[0].key, 60)
  assert_eq(first.notes[0].velocity, 127)
  assert_eq(second.notes[0].off, 0L)
  assert_eq(reader.warnings(), [
    "data bytes out of range are read without their top bit", "invalid time signatures are ignored",
    "system messages in tracks are ignored", "track 1 is cut short; it is read up to the cut",
    "notes without a note-off end with their track",
  ])
}
