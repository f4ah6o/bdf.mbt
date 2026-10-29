///|
test "triplet onsets choose a triplet grid" {
  let time : @music.TimeSig = { beats: 4, beat_type: 4, symbol: "", }
  let measure : @music.MeasureSpan = {
    start: 0L,
    length: 3840L,
    time,
    show_time: true,
    key: None,
    effective_key: { fifths: 0, minor: false, },
    tempo: [],
  }
  let beats = @music.beat_grids([measure], [0L, 320L, 640L])
  assert_eq(beats[0].grid, 320L)
  assert_true(beats[0].triplet)
  assert_eq(beats[0].snap(315L), 320L)
}

///|
test "quantization keeps the first duplicate pitch" {
  let time : @music.TimeSig = { beats: 4, beat_type: 4, symbol: "", }
  let measure : @music.MeasureSpan = {
    start: 0L,
    length: 3840L,
    time,
    show_time: true,
    key: None,
    effective_key: { fifths: 0, minor: false, },
    tempo: [],
  }
  let notes : Array[@music.NotationNote] = [
    { tick: 0L, duration: 480L, key: 60, velocity: 90, spelling: 0, },
    { tick: 1L, duration: 960L, key: 60, velocity: 70, spelling: 0, },
  ]
  let result = @music.quantize_notes([measure], notes)
  assert_eq(result.length(), 1)
  assert_eq(result[0].on, 0L)
  assert_eq(result[0].velocity, 90)
}

///|
test "invalid zero-length beat cannot loop" {
  let time : @music.TimeSig = { beats: 1, beat_type: 7680, symbol: "", }
  let measure : @music.MeasureSpan = {
    start: 0L,
    length: 1L,
    time,
    show_time: true,
    key: None,
    effective_key: { fifths: 0, minor: false, },
    tempo: [],
  }
  assert_eq(@music.beat_grids([measure], []).length(), 0)
}
