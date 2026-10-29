///|
test "adjacent eighth notes form a beam" {
  let notes : Array[@music.NotationNote] = [
    { tick: 0L, duration: 480L, key: 60, velocity: 90, spelling: 0, },
    { tick: 480L, duration: 480L, key: 64, velocity: 90, spelling: 0, },
  ]
  let track : @music.PerformanceTrack = {
    name: "",
    channel: 0,
    program: 0,
    notes,
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
  let events : Array[@music.ScoreEvent] = []
  let signs : Array[Array[Int32?]] = []
  for i, event in sm.events {
    if !event.rest {
      events.push(event)
      signs.push(sm.accidentals[i])
    }
  }
  let groups = @music.beam_groups(
    { beats: 4, beat_type: 4, symbol: "", },
    sm,
    events,
  )
  assert_eq(groups.length(), 1)
  assert_eq(groups[0].indices, [0, 1])
  let drawing = @music.MusicDrawing::new()
  let layouts : Array[@music.NoteLayout] = []
  for i, event in events {
    layouts.push(
      @music.arrange_staff_note(
        drawing,
        sm,
        event,
        signs[i],
        i.to_double() * 3.0,
        1.0,
        beam_direction=Some(groups[0].up),
        beamed=true,
      ),
    )
  }
  @music.draw_beam(drawing, events, layouts, [0, 1], groups[0].up, 1.0)
  let mut fills = 0
  for prim in drawing.primitives() {
    if prim.kind == 2 {
      fills += 1
    }
  }
  assert_eq(fills, 1)
}
