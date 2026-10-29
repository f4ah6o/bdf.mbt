///|
test "tempo mark includes metronome glyph and alternate text" {
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
    tempos: [{ tick: 0L, bpm: 120.0, }],
    end: 960L,
  }
  let score = @music.notate(p)
  let prepared = @music.prepare_score(score)
  let columns = @music.build_columns(score, prepared, _ => 0.0)
  let sys = @music.break_systems(score, prepared, columns, 80.0, 0.0)[0]
  let layout = @music.layout_basic_staff(score, prepared, sys, 0)
  @music.draw_system_marks(layout, score, prepared, sys, (_, _, _) => {
    width: 3.0,
    ascent: 1.9,
    descent: 0.6,
  })
  let mut has_metronome = false
  let mut has_alt = false
  for prim in layout.drawing.primitives() {
    if prim.glyph == "metNoteQuarterUp" {
      has_metronome = true
    }
    if prim.kind == 5 && prim.mark == 4 && prim.text == "♩" {
      has_alt = true
    }
  }
  assert_true(has_metronome)
  assert_true(has_alt)
}
