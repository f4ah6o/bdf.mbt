///|
test "overlapping notes place the higher line in voice one" {
  let measure : @music.MeasureSpan = {
    start: 0L,
    length: 3840L,
    time: { beats: 4, beat_type: 4, symbol: "", },
    show_time: true,
    key: None,
    effective_key: { fifths: 0, minor: false, },
    tempo: [],
  }
  let beat : @music.BeatGrid = {
    start: 0L,
    length: 960L,
    compound: false,
    grid: 120L,
    triplet: false,
  }
  let notes : Array[@music.VoiceNote] = [
    {
      note: { on: 0L, off: 1920L, key: 60, velocity: 90, spelling: 0, },
      voice_hint: 0,
    },
    {
      note: { on: 480L, off: 960L, key: 72, velocity: 90, spelling: 0, },
      voice_hint: 0,
    },
  ]
  let voices = @music.assign_voices(notes, [measure], [beat], false)
  assert_eq(voices[0][0].notes[0].note.key, 72)
  assert_eq(voices[1][0].notes[0].note.key, 60)
}

///|
test "small legato overlap ends at the next onset" {
  let measure : @music.MeasureSpan = {
    start: 0L,
    length: 3840L,
    time: { beats: 4, beat_type: 4, symbol: "", },
    show_time: true,
    key: None,
    effective_key: { fifths: 0, minor: false, },
    tempo: [],
  }
  let beat : @music.BeatGrid = {
    start: 0L,
    length: 960L,
    compound: false,
    grid: 120L,
    triplet: false,
  }
  let notes : Array[@music.VoiceNote] = [
    {
      note: { on: 0L, off: 550L, key: 60, velocity: 90, spelling: 0, },
      voice_hint: 0,
    },
    {
      note: { on: 480L, off: 960L, key: 62, velocity: 90, spelling: 0, },
      voice_hint: 0,
    },
  ]
  let voices = @music.assign_voices(notes, [measure], [beat], false)
  assert_eq(voices[0].length(), 2)
  assert_eq(voices[0][0].off, 480L)
  assert_eq(voices[1].length(), 0)
}
