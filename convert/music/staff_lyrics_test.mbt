///|
test "lyrics create text and hyphen structure" {
  let notes : Array[@music.NotationNote] = [
    { tick: 0L, duration: 480L, key: 60, velocity: 90, spelling: 0, },
    { tick: 480L, duration: 480L, key: 62, velocity: 90, spelling: 0, },
  ]
  let track : @music.PerformanceTrack = {
    name: "",
    channel: 0,
    program: 0,
    notes,
    lyrics: [{ tick: 0L, text: "Twin-", }, { tick: 480L, text: "kle", }],
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
  let columns = @music.build_columns(score, prepared, _ => 2.0)
  let sys = @music.break_systems(score, prepared, columns, 80.0, 0.0)[0]
  let layout = @music.layout_basic_staff(score, prepared, sys, 0)
  @music.draw_staff_lyrics(layout, _ => {
    width: 2.0,
    ascent: 1.76,
    descent: 0.55,
  })
  let mut text = 0
  let marks : Array[Int32] = []
  for primitive in layout.drawing.primitives() {
    if primitive.kind == 4 {
      text += 1
    }
    if primitive.kind == 5 {
      marks.push(primitive.mark)
    }
  }
  assert_eq(text, 2)
  assert_eq(marks, [0, 5])
}
