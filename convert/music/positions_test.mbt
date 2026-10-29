///|
test "tied notes do not alter the accidental state" {
  let sharp : @music.EngravingNote = {
    pitch: { step: 0, alter: 1, octave: 4, },
    accidental: 0,
    cautionary: false,
    tie_stop: false,
  }
  let tied : @music.EngravingNote = {
    pitch: { step: 0, alter: 0, octave: 4, },
    accidental: 0,
    cautionary: false,
    tie_stop: true,
  }
  let natural : @music.EngravingNote = {
    pitch: { step: 0, alter: 0, octave: 4, },
    accidental: 0,
    cautionary: false,
    tie_stop: false,
  }
  let events : Array[@music.EngravingEvent] = [
    { offset: 0L, voice: 1, grace: false, notes: [sharp], },
    { offset: 480L, voice: 1, grace: false, notes: [tied], },
    { offset: 960L, voice: 1, grace: false, notes: [natural], },
  ]
  let signs = @music.resolve_accidentals({ fifths: 0, minor: false, }, events)
  assert_eq(signs[0][0], Some(2))
  assert_eq(signs[1][0], None)
  assert_eq(signs[2][0], Some(4))
  assert_eq(
    @music.staff_position({ sign: 0, line: 0, octave: 0, }, sharp.pitch),
    10,
  )
}

///|
test "nearby accidentals use separate columns" {
  let notes : Array[@music.EngravingNote] = [
    {
      pitch: { step: 0, alter: 1, octave: 4, },
      accidental: 0,
      cautionary: false,
      tie_stop: false,
    },
    {
      pitch: { step: 1, alter: 1, octave: 4, },
      accidental: 0,
      cautionary: false,
      tie_stop: false,
    },
  ]
  let placed = @music.place_accidentals(
    { sign: 0, line: 0, octave: 0, },
    notes,
    [Some(2), Some(2)],
  )
  assert_eq(placed.length(), 2)
  assert_eq(placed[0].column, 0)
  assert_eq(placed[1].column, 1)
}
