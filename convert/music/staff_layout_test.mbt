///|
test "basic staff includes lines, notes and rests in drawing order" {
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
  let sys = @music.break_systems(score, prepared, columns, 80.0, 0.0)[0]
  let layout = @music.layout_basic_staff(score, prepared, sys, 0)
  assert_true(layout.events.length() >= 2)
  assert_eq(layout.drawing.primitives()[0].kind, 1)
  assert_eq(layout.drawing.primitives()[5].glyph, "gClef")
  assert_true(layout.events[0].note_layout is Some(_))
  assert_true(layout.events[1].rest_layout is Some(_))
}
