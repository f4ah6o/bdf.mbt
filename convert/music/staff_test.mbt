///|
test "keyboard range chooses grand staff while guitar transposes" {
  let notes : Array[@music.QuantizedNote] = [
    { on: 0L, off: 480L, key: 48, velocity: 90, spelling: 0, },
    { on: 0L, off: 480L, key: 72, velocity: 90, spelling: 0, },
  ]
  let piano = @music.plan_staff(notes, 0, 0).unwrap()
  assert_eq(piano.clefs.length(), 2)
  assert_eq(piano.staff_for(48), 1)
  assert_eq(piano.staff_for(72), 0)
  let guitar = @music.plan_staff(notes, 0, 24).unwrap()
  assert_eq(guitar.clefs.length(), 1)
  assert_eq(guitar.clefs[0].octave, 0)
}

///|
test "percussion voices end at the next matching hit" {
  let beat : @music.BeatGrid = {
    start: 0L,
    length: 960L,
    compound: false,
    grid: 240L,
    triplet: false,
  }
  let notes : Array[@music.QuantizedNote] = [
    { on: 0L, off: 240L, key: 36, velocity: 90, spelling: 0, },
    { on: 240L, off: 480L, key: 38, velocity: 90, spelling: 0, },
    { on: 480L, off: 720L, key: 44, velocity: 90, spelling: 0, },
  ]
  let result = @music.percussion_durations(notes, [beat])
  assert_eq(result[0].off, 480L)
  assert_eq(result[1].off, 960L)
  assert_eq(result[2].off, 960L)
  assert_eq(@music.drum_of(44).voice, 2)
}
