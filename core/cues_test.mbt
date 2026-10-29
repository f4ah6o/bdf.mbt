///|
test "cue indexes encode and round trip unsigned tick deltas" {
  let cues : @core.Cues = {
    systems: [{ page: 0U, x: 1.0, y: 2.0, width: 3.0, height: 4.0, }],
    cues: [
      { tick: 300U, system: 0U, x: 9.0, },
      { tick: 7U, system: 0U, x: 8.0, },
    ],
  }
  assert_eq(@core.decode_cues(@core.encode_cues(cues)), cues)
}
