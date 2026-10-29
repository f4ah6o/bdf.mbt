///|
test "a sustained note crossing a bar adds a tie" {
  let note : @music.NotationNote = {
    tick: 0L,
    duration: 4800L,
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
    end: 4800L,
  }
  let score = @music.notate(p, key_override=Some({ fifths: 0, minor: false, }))
  let prepared = @music.prepare_score(score)
  let columns = @music.build_columns(score, prepared, _ => 0.0)
  let sys = @music.break_systems(score, prepared, columns, 80.0, 0.0)[0]
  let layout = @music.layout_basic_staff(score, prepared, sys, 0)
  let before = layout.drawing.primitives().length()
  @music.draw_staff_ties(layout, prepared, sys, 0)
  assert_true(layout.drawing.primitives().length() > before)
  assert_eq(layout.drawing.primitives()[before].kind, 2)
}
