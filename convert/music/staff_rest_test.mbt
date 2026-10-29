///|
test "quarter rest uses its onset position" {
  let note : @music.NotationNote = {
    tick: 960L,
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
    tracks: [track],
    times: [],
    keys: [],
    tempos: [],
    end: 1920L,
  }
  let score = @music.notate(p, key_override=Some({ fifths: 0, minor: false, }))
  let prepared = @music.prepare_score(score)
  let columns = @music.build_columns(score, prepared, _ => 0.0)
  let system = @music.break_systems(score, prepared, columns, 80.0, 0.0)[0]
  let event = prepared.measures[0][0].events[0]
  assert_true(event.rest)
  let d = @music.MusicDrawing::new()
  let l = @music.draw_staff_rest(d, score, prepared, system, 0, 0, event, 12.0)
  assert_eq(l.x, 12.0)
  assert_eq(d.primitives()[0].glyph, "restQuarter")
  assert_eq(d.primitives()[0].y, 2.0)
}
