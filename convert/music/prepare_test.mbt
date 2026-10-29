///|
test "prepare resolves sharps and measure boundaries" {
  let notes : Array[@music.NotationNote] = [
    { tick: 0L, duration: 960L, key: 61, velocity: 90, spelling: 1, },
    { tick: 960L, duration: 960L, key: 60, velocity: 90, spelling: 0, },
  ]
  let track : @music.PerformanceTrack = {
    name: "Piano",
    channel: 0,
    program: 0,
    notes,
    lyrics: [],
  }
  let performance : @music.Performance = {
    title: "",
    subtitle: "",
    composer: "",
    lyricist: "",
    arranger: "",
    copyright: "",
    tracks: [track],
    times: [],
    keys: [],
    tempos: [],
    end: 1920L,
  }
  let score = @music.notate(
    performance,
    key_override=Some({ fifths: 0, minor: false, }),
  )
  let p = @music.prepare_score(score)
  assert_eq(p.staves.length(), 1)
  assert_eq(p.starts, [0L, 3840L])
  assert_eq(p.measures[0][0].accidentals[0][0], Some(2))
  assert_eq(p.measures[0][0].accidentals[1][0], Some(4))
}
