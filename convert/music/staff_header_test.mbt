///|
test "staff header draws five lines, a clef and time signature" {
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
    tracks: [track],
    times: [],
    keys: [],
    tempos: [],
    end: 960L,
  }
  let score = @music.notate(p, key_override=Some({ fifths: 0, minor: false, }))
  let prepared = @music.prepare_score(score)
  let columns = @music.build_columns(score, prepared, _ => 0.0)
  let system = @music.break_systems(score, prepared, columns, 80.0, 0.0)[0]
  let prims = @music.staff_header(score, prepared, system, 0).primitives()
  assert_eq(prims.length(), 8)
  assert_eq(prims[0].kind, 1)
  assert_eq(prims[5].glyph, "gClef")
  assert_eq(prims[6].glyph, "timeSig4")
  assert_eq(prims[7].glyph, "timeSig4")
}
