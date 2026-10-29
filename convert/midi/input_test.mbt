///|
test "MIDI header detection and timing" {
  let smf = b"MThd\x00\x00\x00\x06\x00\x01\x00\x01\x01\xe0"
  assert_true(@midi.detect(smf))
  let h = @midi.read_header(smf)
  assert_eq(h.format, 1)
  assert_eq(h.tracks, 1)
  assert_eq(h.division, 480)
  assert_eq(h.max_tick, 480000000L)
  assert_eq(h.ppq(123L), 246L)
  assert_false(@midi.detect(b"MThd\x00\x01\x00\x00"))
  assert_eq(@midi.read_varlen(b"\x81\x80\x01"), (16385, 3))
  assert_eq(@midi.read_varlen(b"\x80"), (0, 0))
  assert_eq(@midi.read_varlen(b"\x80\x80\x80\x80\x00"), (0, -1))
}

///|
test "RIFF MIDI extracts empty first data and INFO metadata" {
  let data = b"RIFF\x00\x00\x00\x00RMIDLIST\x10\x00\x00\x00INFOINAM\x03\x00\x00\x00abc\x00data\x00\x00\x00\x00data\x01\x00\x00\x00x\x00"
  assert_true(@midi.detect(data))
  let input = @midi.unwrap_rmid(data)
  assert_eq(input.smf, b"")
  assert_eq(input.title, b"abc")
}

///|
test "SMPTE drop frame timing and validation" {
  let h = @midi.read_header(b"MThd\x00\x00\x00\x06\x00\x02\x00\x01\xe3\x50")
  assert_true(h.smpte)
  assert_eq(h.timing_numerator, 239760L)
  assert_eq(h.timing_denominator, 200L)
  assert_eq(h.ppq(100L), 80L)
  assert_eq(h.warnings.length(), 2)
  let error = Ok(
    @midi.read_header(b"MThd\x00\x00\x00\x06\x00\x00\x00\x01\xe2\x00"),
  ) catch {
    e => Err(e)
  }
  match error {
    Err(@midi.InvalidMidiInput(message)) =>
      assert_eq(message, "midi: the SMPTE division 0xe200 is invalid")
    _ => fail("expected an invalid SMPTE division")
  }
}
