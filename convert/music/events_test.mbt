///|
test "cross-bar note is tied and receives its lyric once" {
  let time : @music.TimeSig = { beats: 4, beat_type: 4, symbol: "", }
  let measures : Array[@music.MeasureSpan] = [
    {
      start: 0L,
      length: 3840L,
      time,
      show_time: true,
      key: None,
      effective_key: { fifths: 0, minor: false, },
      tempo: [],
    },
    {
      start: 3840L,
      length: 3840L,
      time,
      show_time: false,
      key: None,
      effective_key: { fifths: 0, minor: false, },
      tempo: [],
    },
  ]
  let beats : Array[@music.BeatGrid] = []
  for i in 0..<8 {
    beats.push({
      start: i.to_int64() * 960L,
      length: 960L,
      compound: false,
      grid: 480L,
      triplet: false,
    })
  }
  let notes : Array[@music.VoiceNote] = [
    {
      note: { on: 3360L, off: 4320L, key: 60, velocity: 90, spelling: 0, },
      voice_hint: 0,
    },
  ]
  let events = @music.write_staff_events(
    notes,
    measures,
    beats,
    [{ tick: 3360L, text: "hello-", }],
    0,
    false,
  )
  let first = events[0][events[0].length() - 1]
  let second = events[1][0]
  assert_eq(first.offset, 3360L)
  assert_true(first.notes[0].tie_start)
  assert_false(first.notes[0].tie_stop)
  assert_eq(first.lyric.unwrap().text, "hello")
  assert_eq(first.lyric.unwrap().syllabic, 1)
  assert_true(second.notes[0].tie_stop)
  assert_false(second.notes[0].tie_start)
  assert_true(second.lyric is None)
}
