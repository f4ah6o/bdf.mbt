///|
/// Build playback position cues for a MIDI-derived score in the original
/// MIDI division. The returned flag indicates truncation at four million cues.
pub fn midi_score_cues(
  score : NotatedScore,
  layout : MusicScoreLayout,
  division : Int32,
  keep~ : Array[Bool]? = None,
) -> (@core.Cues, Bool) {
  let sp = layout.staff_space
  let margin = 14.0 * (72.0 / 25.4)
  let div = if division <= 0 { 960 } else { division }
  let systems : Array[@core.CueSystem] = []
  let cues : Array[@core.Cue] = []
  let mut truncated = false
  let page_index : Array[Int32] = []
  let mut next_page = 0
  let page_count = if layout.systems.is_empty() {
    0
  } else {
    layout.systems[layout.systems.length() - 1].placement.page + 1
  }
  for pi in 0..<page_count {
    let selected = match keep {
      Some(pages) => pi < pages.length() && pages[pi]
      None => true
    }
    page_index.push(if selected { next_page } else { -1 })
    if selected {
      next_page += 1
    }
  }
  for system in layout.systems {
    let p = system.placement
    let page = page_index[p.page]
    if page < 0 {
      continue
    }
    let si = systems.length()
    let ox = music_mul_add(system.left, sp, margin)
    let oy = p.top
    systems.push({
      page: page.to_uint(),
      x: Float::from_double(ox).to_double(),
      y: Float::from_double(oy - sp).to_double(),
      width: Float::from_double(system.system.width * sp).to_double(),
      height: Float::from_double((p.staff_y[p.staff_y.length() - 1] + 6.0) * sp).to_double(),
    })
    for column in system.system.columns {
      if truncated {
        continue
      }
      let measure = score.timeline.measures[column.index]
      for slot in column.slots {
        if cues.length() >= 4000000 {
          truncated = true
          break
        }
        let tick = ((measure.start + slot.slot.offset) * div.to_int64() + 480L) /
          960L
        let x = music_mul_add(column.x + slot.x + 0.6, sp, ox)
        cues.push({
          tick: tick.to_int().reinterpret_as_uint(),
          system: si.to_uint(),
          x: Float::from_double(x).to_double(),
        })
      }
      if !truncated {
        if cues.length() >= 4000000 {
          truncated = true
        } else {
          let tick = ((measure.start + measure.length) * div.to_int64() + 480L) /
            960L
          let x = music_mul_add(column.x + column.width, sp, ox)
          cues.push({
            tick: tick.to_int().reinterpret_as_uint(),
            system: si.to_uint(),
            x: Float::from_double(x).to_double(),
          })
        }
      }
    }
  }
  // The encoded ticks wrap to uint32. Upstream sorts after the conversion,
  // preserving insertion order when two positions have the same tick.
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
      let order = a.1.tick.compare(b.1.tick)
      if order == 0 {
        a.0.compare(b.0)
      } else {
        order
      }
    })
    cues.clear()
    for (_, cue) in indexed {
      cues.push(cue)
    }
  }
  ({ systems, cues, }, truncated)
}
