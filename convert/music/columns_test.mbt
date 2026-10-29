///|
test "lyric width affects onset and leading space" {
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
    lyrics: [{ tick: 0L, text: "abc", }],
  }
  let perf : @music.Performance = {
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
  let score = @music.notate(perf)
  let columns = @music.build_columns(score, @music.prepare_score(score), _ => {
    4.0
  })
  assert_eq(columns.length(), 1)
  assert_eq(columns[0].slots[0].head, 1.18)
  assert_eq(columns[0].slots[0].lyric, 2.0)
  assert_true((columns[0].lead - 1.41).abs() < 0.000001)
}
