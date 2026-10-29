///|
test "grand staff shares a lyric across both staves" {
  let notes : Array[@music.NotationNote] = [
    { tick: 0L, duration: 960L, key: 72, velocity: 90, spelling: 0, },
    { tick: 0L, duration: 960L, key: 48, velocity: 90, spelling: 0, },
  ]
  let track : @music.PerformanceTrack = {
    name: "Piano",
    channel: 0,
    program: 0,
    notes,
    lyrics: [{ tick: 0L, text: "word", }],
  }
  let p : @music.Performance = {
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
    end: 960L,
  }
  let score = @music.notate(p)
  assert_eq(score.error, "")
  assert_eq(score.parts[0].clefs.length(), 2)
  let mut count = 0
  for event in score.parts[0].measures[0].events {
    if event.lyric is Some(_) {
      count += 1
      assert_eq(event.staff, 0)
    }
  }
  assert_eq(count, 1)
}

///|
test "empty performance still produces one measure" {
  let p : @music.Performance = {
    title: "Empty",
    subtitle: "",
    composer: "",
    lyricist: "",
    arranger: "",
    copyright: "",
    tracks: [],
    times: [],
    keys: [],
    tempos: [],
    end: 0L,
  }
  let score = @music.notate(p)
  assert_eq(score.timeline.measures.length(), 1)
  assert_eq(score.timeline.measures[0].length, 3840L)
  assert_eq(score.parts.length(), 0)
}

///|
test "track budget stops before tempo and parts are generated" {
  let note : @music.NotationNote = {
    tick: 0L,
    duration: 960L,
    key: 60,
    velocity: 90,
    spelling: 0,
  }
  let track : @music.PerformanceTrack = {
    name: "",
    channel: 0,
    program: 0,
    notes: [note],
    lyrics: [],
  }
  let p : @music.Performance = {
    title: "",
    subtitle: "",
    composer: "",
    lyricist: "",
    arranger: "",
    copyright: "",
    tracks: Array::make(4097, track),
    times: [],
    keys: [],
    tempos: [{ tick: 0L, bpm: 120.0, }],
    end: 960L,
  }
  let score = @music.notate(p)
  assert_eq(score.error, "music: the score has more than 4096 staves")
  assert_eq(score.parts.length(), 0)
  assert_eq(score.timeline.measures[0].tempo.length(), 0)
}
