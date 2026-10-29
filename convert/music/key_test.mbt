///|
test "compound time signatures have dotted beats" {
  let time : @music.TimeSig = { beats: 6, beat_type: 8, symbol: "", }
  assert_eq(time.length(), 2880)
  assert_eq(time.beat(), (1440, true))
}

///|
test "key spelling accounts for octave crossings and enharmonics" {
  let sharp : @music.KeySig = { fifths: 7, minor: false, }
  let flat : @music.KeySig = { fifths: -7, minor: false, }
  let b_sharp = @music.spell(60, sharp, 0)
  let c_flat = @music.spell(59, flat, 0)
  assert_eq(b_sharp.step, 6)
  assert_eq(b_sharp.alter, 1)
  assert_eq(b_sharp.octave, 3)
  assert_eq(c_flat.step, 0)
  assert_eq(c_flat.alter, -1)
  assert_eq(c_flat.octave, 4)
}

///|
test "empty histogram chooses C major" {
  let key = @music.estimate_key(
    [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    0,
  )
  assert_eq(key.fifths, 0)
  assert_false(key.minor)
}
