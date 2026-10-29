///|
test "middle C has a ledger line and upward stem" {
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
  let sm = @music.prepare_score(score).measures[0][0]
  let d = @music.MusicDrawing::new()
  let l = @music.arrange_staff_note(
    d,
    sm,
    sm.events[0],
    sm.accidentals[0],
    10.0,
    1.0,
  )
  @music.draw_isolated_stem(d, l, 1.0)
  assert_true(l.up)
  assert_true(l.stem)
  assert_eq(l.heads[0].position, 10)
  assert_eq(d.primitives().length(), 3)
  assert_eq(d.primitives()[0].glyph, "noteheadBlack")
  assert_eq(d.primitives()[1].kind, 1)
  assert_eq(d.primitives()[2].kind, 1)
}
