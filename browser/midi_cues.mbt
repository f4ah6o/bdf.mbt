///|
extern "js" fn music_cue_x(cues : BrowserAudioCues, i : Int32) -> Double =
  #|(cues,i) => cues.cues[i].x

///|
extern "js" fn music_cursor(
  page : Double,
  system : Double,
  x : Double,
  y : Double,
  height : Double,
) -> BrowserAudioCursor =
  #|(page,system,x,y,h) => ({page,system,x,y,h})

///|
fn score_cursor(cues : BrowserAudioCues, tick : Double) -> BrowserAudioCursor {
  if !audio_cues_present(cues) || audio_cue_count(cues) == 0 {
    return audio_no_cursor()
  }
  let mut lo = 0
  let mut hi = audio_cue_count(cues) - 1
  while lo < hi {
    let mid = (lo + hi + 1) / 2
    if audio_cue_tick(cues, mid) <= tick {
      lo = mid
    } else {
      hi = mid - 1
    }
  }
  let system = audio_cue_system(cues, lo)
  let x = music_cue_x(cues, lo)
  let x = if lo + 1 < audio_cue_count(cues) &&
    audio_cue_system(cues, lo + 1) == system &&
    audio_cue_tick(cues, lo + 1) > audio_cue_tick(cues, lo) &&
    tick > audio_cue_tick(cues, lo) {
    let ratio = (tick - audio_cue_tick(cues, lo)) /
      (audio_cue_tick(cues, lo + 1) - audio_cue_tick(cues, lo))
    x +
    (music_cue_x(cues, lo + 1) - x) * (if ratio < 1.0 { ratio } else { 1.0 })
  } else {
    x
  }
  music_cursor(
    audio_system_page(cues, system),
    system,
    x,
    audio_system_value(cues, system, "y"),
    audio_system_value(cues, system, "h"),
  )
}

///|
fn score_tick_at(
  cues : BrowserAudioCues,
  system : Double,
  x : Double,
  near : Double,
) -> Double? {
  if !audio_cues_present(cues) {
    return None
  }
  let mut best : Double? = None
  let mut offset = 9218868437227405312UL.reinterpret_as_double()
  let mut far = offset
  for i in 0..<audio_cue_count(cues) {
    if audio_cue_system(cues, i) != system {
      continue
    }
    let cue_x = music_cue_x(cues, i)
    let tick = audio_cue_tick(cues, i)
    let distance = (cue_x - x).abs()
    let delta = (tick - near).abs()
    if distance < offset - 0.000001 ||
      (distance <= offset + 0.000001 && delta < far) {
      best = Some(tick)
      offset = distance
      far = delta
    }
    if i + 1 < audio_cue_count(cues) &&
      audio_cue_system(cues, i + 1) == system &&
      audio_cue_tick(cues, i + 1) > tick &&
      music_cue_x(cues, i + 1) != cue_x {
      let fraction = (x - cue_x) / (music_cue_x(cues, i + 1) - cue_x)
      if fraction > 0.0 && fraction < 1.0 {
        let candidate = tick + fraction * (audio_cue_tick(cues, i + 1) - tick)
        let delta = (candidate - near).abs()
        if 0.0 < offset - 0.000001 || (0.0 <= offset + 0.000001 && delta < far) {
          best = Some(candidate)
          offset = 0.0
          far = delta
        }
      }
    }
  }
  best
}
