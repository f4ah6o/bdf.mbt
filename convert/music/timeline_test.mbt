///|
test "time and key changes are placed on measure boundaries" {
  let histogram = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
  let times : Array[@music.TimeChange] = [
    { tick: 1920L, time: { beats: 3, beat_type: 4, symbol: "", }, },
  ]
  let keys : Array[@music.KeyChange] = [
    { tick: 1000L, key: { fifths: 2, minor: false, }, },
  ]
  let tempos : Array[@music.TempoChange] = [{ tick: 1920L, bpm: 120.0, }]
  let timeline = @music.build_timeline(5000L, times, keys, tempos, histogram, 0)
  assert_eq(timeline.measures.length(), 3)
  assert_eq(timeline.measures[0].length, 1920L)
  assert_eq(timeline.measures[1].start, 1920L)
  assert_true(timeline.measures[1].show_time)
  assert_eq(timeline.measures[1].effective_key.fifths, 2)
  assert_eq(timeline.measures[1].tempo[0].per_minute, 120.0)
}

///|
test "measure limit reports omitted music" {
  let histogram = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
  let timeline = @music.build_timeline(76800001L, [], [], [], histogram, 0)
  assert_eq(timeline.measures.length(), 20000)
  assert_eq(timeline.warnings, [
    "the music is longer than 20000 measures; the rest is left out",
  ])
}
