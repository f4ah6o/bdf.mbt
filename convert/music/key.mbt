///|
/// A musical time signature.
pub(all) struct TimeSig {
  beats : Int32
  beat_type : Int32
  symbol : String
}

///|
/// Return the length of a measure in 960-tick quarter notes.
pub fn TimeSig::length(self : TimeSig) -> Int32 {
  if self.beat_type <= 0 || self.beats <= 0 {
    return 3840
  }
  self.beats * 3840 / self.beat_type
}

///|
/// Return the beat length and whether it is a compound meter.
pub fn TimeSig::beat(self : TimeSig) -> (Int32, Bool) {
  if self.beat_type == 8 && self.beats % 3 == 0 && self.beats > 3 {
    return (1440, true)
  }
  if self.beat_type <= 0 {
    return (960, false)
  }
  (3840 / self.beat_type, false)
}

///|
/// Sharps (positive) or flats (negative), and major/minor mode.
pub(all) struct KeySig {
  fifths : Int32
  minor : Bool
}

///|
/// A written pitch: step 0–6 is C–B, with an alteration and octave.
pub(all) struct Pitch {
  step : Int32
  alter : Int32
  octave : Int32
}

///|
let major_profile : Array[Double] = [
  6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88,
]

///|
let minor_profile : Array[Double] = [
  6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17,
]

///|
/// Return the signature for a tonic pitch class, favoring flats when asked.
pub fn key_of(tonic : Int32, minor : Bool, flats : Int32) -> KeySig {
  let major = if minor { (tonic + 3) % 12 } else { tonic }
  let fifths = [0, -5, 2, -3, 4, -1, 6, 1, -4, 3, -2, 5][major]
  { fifths: if fifths == 6 && flats > 0 { -6 } else { fifths }, minor, }
}

///|
fn correlation(
  hist : Array[Double],
  tonic : Int32,
  profile : Array[Double],
) -> Double {
  let mut mx = 0.0
  let mut my = 0.0
  for i in 0..<12 {
    mx += hist[(tonic + i) % 12]
    my += profile[i]
  }
  mx /= 12.0
  my /= 12.0
  let mut xy = 0.0
  let mut xx = 0.0
  let mut yy = 0.0
  for i in 0..<12 {
    let dx = hist[(tonic + i) % 12] - mx
    let dy = profile[i] - my
    xy += dx * dy
    xx += dx * dx
    yy += dy * dy
  }
  if xx == 0.0 || yy == 0.0 {
    return 0.0
  }
  xy / (xx * yy).sqrt()
}

///|
/// Estimate a key from twelve pitch-class duration weights.
pub fn estimate_key(histogram : Array[Double], flats : Int32) -> KeySig {
  let mut total = 0.0
  for i in 0..<12 {
    total += histogram[i]
  }
  if total == 0.0 {
    return { fifths: 0, minor: false, }
  }
  let mut best : KeySig = { fifths: 0, minor: false, }
  let mut best_r = -2.0
  for tonic in 0..<12 {
    for minor in [false, true] {
      let profile = if minor { minor_profile } else { major_profile }
      let r = correlation(histogram, tonic, profile)
      if r > best_r + 1.0e-9 {
        best_r = r
        best = key_of(tonic, minor, flats)
      }
    }
  }
  best
}

///|
/// Spell a MIDI pitch for the key, respecting an optional sharp/flat hint.
pub fn spell(key : Int32, signature : KeySig, hint : Int32) -> Pitch {
  let pc = (key % 12 + 12) % 12
  let octave = if key < 0 { (key - 11) / 12 - 1 } else { key / 12 - 1 }
  let semitones = [0, 2, 4, 5, 7, 9, 11]
  let fifths = [0, 2, 4, -1, 1, 3, 5]
  let center = signature.fifths.to_double() +
    2.0 +
    (if signature.minor { 1.5 } else { 0.0 })
  let mut best : Pitch = { step: 0, alter: 0, octave: 0, }
  let mut best_d = 1.0e99
  for step in 0..<7 {
    for alter = -2; alter <= 2; alter = alter + 1 {
      if (semitones[step] + alter + 12) % 12 != pc {
        continue
      }
      let line = fifths[step] + 7 * alter
      let mut d = (line.to_double() - center).abs()
      let diatonic = line >= signature.fifths - 1 &&
        line <= signature.fifths + 5
      if diatonic {
        d -= 100.0
      } else if (hint > 0 && alter == 1) || (hint < 0 && alter == -1) {
        d -= 10.0
      } else if alter == 2 || alter == -2 {
        d += 20.0
      }
      if d < best_d - 1.0e-9 ||
        (d < best_d + 1.0e-9 && alter > best.alter && signature.fifths >= 0) {
        best_d = d
        let mut written_octave = octave
        if step == 6 && semitones[step] + alter >= 12 {
          written_octave -= 1
        }
        if step == 0 && alter < 0 {
          written_octave += 1
        }
        best = { step, alter, octave: written_octave, }
      }
    }
  }
  best
}
