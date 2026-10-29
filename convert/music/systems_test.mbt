///|
test "narrow score width breaks the measures into systems" {
  let note : @music.NotationNote = {
    tick: 0L,
    duration: 12000L,
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
    tracks: [track],
    times: [],
    keys: [],
    tempos: [],
    end: 12000L,
  }
  let score = @music.notate(p)
  let prepared = @music.prepare_score(score)
  let columns = @music.build_columns(score, prepared, _ => 0.0)
  let systems = @music.break_systems(score, prepared, columns, 10.0, 0.0)
  assert_true(systems.length() > 1)
  assert_eq(systems[0].first, 0)
  assert_eq(systems[systems.length() - 1].last, 3)
  assert_true(systems[0].header > 0.0)
}
