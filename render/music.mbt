///|
/// A playing position on a score system or across an audio cue's whole line.
pub(all) struct MusicCursor {
  page : UInt32
  system : UInt32
  x : Double
  y : Double
  height : Double
  width : Double?
} derive(Eq, Debug)

///|
fn cue_at(cues : @core.Cues, tick : Double) -> Int32 {
  let mut lo = 0
  let mut hi = cues.cues.length() - 1
  while lo < hi {
    let mid = (lo + hi + 1) / 2
    if cues.cues[mid].tick.to_double() <= tick {
      lo = mid
    } else {
      hi = mid - 1
    }
  }
  lo
}

///|
/// Interpolate the score cursor at a tick; equal-tick cues select the later cue.
pub fn cursor_at_tick(cues : @core.Cues, tick : Double) -> MusicCursor? {
  if cues.cues.is_empty() {
    return None
  }
  let index = cue_at(cues, tick)
  let cue = cues.cues[index]
  if cue.system.to_uint64() >= cues.systems.length().to_uint64() {
    return None
  }
  let system = cues.systems[cue.system.to_int()]
  let mut x = cue.x
  if index + 1 < cues.cues.length() {
    let next = cues.cues[index + 1]
    if next.system == cue.system &&
      next.tick > cue.tick &&
      tick > cue.tick.to_double() {
      let fraction = (tick - cue.tick.to_double()) /
        (next.tick.to_double() - cue.tick.to_double())
      x += (next.x - cue.x) * (if fraction < 1.0 { fraction } else { 1.0 })
    }
  }
  Some({
    page: system.page,
    system: cue.system,
    x,
    y: system.y,
    height: system.height,
    width: None,
  })
}

///|
/// Find a tick at a score position, preferring the occurrence nearest `near`.
pub fn tick_at(
  cues : @core.Cues,
  system : UInt32,
  x : Double,
  near~ : Double = 0.0,
) -> Double? {
  let mut best : Double? = None
  let mut offset = 9218868437227405312UL.reinterpret_as_double()
  let mut far = offset
  for i, cue in cues.cues {
    if cue.system != system {
      continue
    }
    let distance = (cue.x - x).abs()
    let tick = cue.tick.to_double()
    let delta = (tick - near).abs()
    if distance < offset - 0.000001 ||
      (distance <= offset + 0.000001 && delta < far) {
      best = Some(tick)
      offset = distance
      far = delta
    }
    if i + 1 < cues.cues.length() {
      let next = cues.cues[i + 1]
      if next.system == system && next.tick > cue.tick && next.x != cue.x {
        let fraction = (x - cue.x) / (next.x - cue.x)
        if fraction > 0.0 && fraction < 1.0 {
          let candidate = tick + fraction * (next.tick.to_double() - tick)
          let distance_to_near = (candidate - near).abs()
          if 0.0 < offset - 0.000001 ||
            (0.0 <= offset + 0.000001 && distance_to_near < far) {
            best = Some(candidate)
            offset = 0.0
            far = distance_to_near
          }
        }
      }
    }
  }
  best
}

///|
/// Return the complete audio cue line at a time in milliseconds.
pub fn line_at_time(cues : @core.Cues, milliseconds : Double) -> MusicCursor? {
  if cues.cues.is_empty() || !(milliseconds >= cues.cues[0].tick.to_double()) {
    return None
  }
  let cue = cues.cues[cue_at(cues, milliseconds)]
  if cue.system.to_uint64() >= cues.systems.length().to_uint64() {
    return None
  }
  let system = cues.systems[cue.system.to_int()]
  Some({
    page: system.page,
    system: cue.system,
    x: system.x,
    y: system.y,
    height: system.height,
    width: Some(system.width),
  })
}

///|
/// Return the cue time of a line nearest to the supplied time.
pub fn time_of_line(
  cues : @core.Cues,
  system : UInt32,
  near~ : Double = 0.0,
) -> Double? {
  let mut best : Double? = None
  let mut far = 9218868437227405312UL.reinterpret_as_double()
  for cue in cues.cues {
    if cue.system == system {
      let time = cue.tick.to_double()
      let distance = (time - near).abs()
      if distance < far {
        best = Some(time)
        far = distance
      }
    }
  }
  best
}

///|
/// Index of the first MIDI event at or after a time.
pub fn midi_event_at(events : Array[@core.MidiEvent], time : Double) -> Int32 {
  let mut lo = 0
  let mut hi = events.length()
  while lo < hi {
    let mid = (lo + hi) / 2
    if events[mid].time < time {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  lo
}

///|
/// End of the events starting before `until`, beginning at `from`.
pub fn midi_due(
  events : Array[@core.MidiEvent],
  from : Int32,
  until : Double,
) -> Int32 {
  let mut index = from
  while index < events.length() && events[index].time < until {
    index += 1
  }
  index
}

///|
/// Note ending times after sustain-pedal controls, in seconds.
pub fn sounding_ends(
  events : Array[@core.MidiEvent],
  end? : Double,
) -> Array[Double] {
  let finish = end.unwrap_or(9218868437227405312UL.reinterpret_as_double())
  let pedal : Array[Array[Double]] = [ for _ in 0..<16 => [] ]
  let down : Array[Double?] = Array::make(16, None)
  for event in events {
    if event.message is Control(channel~, controller~, value~) &&
      (controller == 64 || controller == 121) {
      let on = controller == 64 && value >= 64
      if on && down[channel] is None {
        down[channel] = Some(event.time)
      }
      if !on && down[channel] is Some(start) {
        pedal[channel].push(start)
        pedal[channel].push(event.time)
        down[channel] = None
      }
    }
  }
  for channel in 0..<16 {
    if down[channel] is Some(start) {
      pedal[channel].push(start)
      pedal[channel].push(finish)
    }
  }
  let result : Array[Double] = Array::make(events.length(), 0.0)
  for i, event in events {
    if event.message is Note(channel~, duration~, ..) {
      let mut time = event.time +
        (if duration > 0.02 { duration } else { 0.02 })
      let periods = pedal[channel]
      let mut lo = 0
      let mut hi = periods.length() / 2 - 1
      let mut found = -1
      while lo <= hi {
        let mid = (lo + hi) / 2
        if periods[mid * 2] <= time {
          found = mid
          lo = mid + 1
        } else {
          hi = mid - 1
        }
      }
      if found >= 0 && time < periods[found * 2 + 1] {
        time = periods[found * 2 + 1]
      }
      result[i] = time
    }
  }
  result
}
