///|
/// Build playback cues for an estimated guitar TAB view. `keep` identifies
/// original pages retained by a selection; page and system indexes are remapped.
pub fn guitar_tab_cues(
  score : NotatedScore,
  tab : GuitarTabView,
  division : Int32,
  keep~ : Array[Bool]? = None,
) -> (@core.Cues, Bool) {
  let page_map : Array[Int32] = []
  let mut next = 0
  for i in 0..<tab.pages.length() {
    let selected = match keep {
      None => true
      Some(pages) => i < pages.length() && pages[i]
    }
    page_map.push(if selected { next } else { -1 })
    if selected {
      next += 1
    }
  }
  let system_map : Array[Int32] = []
  let systems : Array[@core.CueSystem] = []
  for system in tab.systems {
    let page = page_map[system.page.to_int()]
    if page < 0 {
      system_map.push(-1)
      continue
    }
    system_map.push(systems.length())
    systems.push({
      page: page.to_uint(),
      x: system.x,
      y: system.y,
      width: system.width,
      height: system.height,
    })
  }
  let cues : Array[@core.Cue] = []
  let div = if division <= 0 { 960 } else { division }
  let mut truncated = false
  for point in tab.points {
    let si = system_map[point.system]
    if si < 0 {
      continue
    }
    if cues.length() >= 4000000 {
      truncated = true
      break
    }
    let tick = (
        (score.timeline.measures[point.measure].start + point.offset) *
        div.to_int64() +
        480L
      ) /
      960L
    cues.push({
      tick: tick.to_int().reinterpret_as_uint(),
      system: si.to_uint(),
      x: Float::from_double(point.x).to_double(),
    })
  }
  let mut ordered = true
  for i in 1..<cues.length() {
    if cues[i].tick < cues[i - 1].tick {
      ordered = false
      break
    }
  }
  if !ordered {
    let indexed : Array[(Int32, @core.Cue)] = [ for i, cue in cues => (i, cue) ]
    indexed.sort_by((a, b) => {
      let c = a.1.tick.compare(b.1.tick)
      if c == 0 {
        a.0.compare(b.0)
      } else {
        c
      }
    })
    cues.clear()
    for (_, cue) in indexed {
      cues.push(cue)
    }
  }
  ({ systems, cues, }, truncated)
}
