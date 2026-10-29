///|
priv struct Waiting {
  mut missing : Int32
  output : Outputs
}

///|
/// Compute the transitive substitution closure for the supplied glyph IDs.
/// As upstream does, contextual constraints are ignored and the lookup work
/// budget is shared across calls on this parsed table.
pub fn Gsub::reachable(self : Gsub, roots : Array[Int32]) -> Array[Int32] {
  let kept : Map[Int32, Bool] = Map([])
  let added : Array[Int32] = []
  for glyph in roots {
    if glyph >= 0 && glyph <= 65535 && !kept.contains(glyph) {
      kept[glyph] = true
      added.push(glyph)
    }
  }
  let waiting : Array[Waiting] = []
  let by_glyph : Map[Int32, Array[Int32]] = Map([])
  let add_glyph = (glyph : Int32) => {
    if !kept.contains(glyph) {
      kept[glyph] = true
      added.push(glyph)
    }
  }
  let add_output = (output : Outputs) => {
    match output {
      One(glyph) => add_glyph(glyph)
      Many(data) => {
        let n = count(data, u16(data, 0), 2, 2)
        for i in 0..<n {
          add_glyph(u16(data, 2 + i * 2))
        }
      }
    }
  }
  self.list_substitutions((input, output) => {
    if input.length() == 0 {
      add_output(output)
      return
    }
    let id = waiting.length()
    for glyph in input {
      let list = match by_glyph.get(glyph) {
        Some(list) => list
        None => {
          let list : Array[Int32] = []
          by_glyph[glyph] = list
          list
        }
      }
      list.push(id)
    }
    waiting.push({ missing: input.length(), output, })
  })
  while added.length() > 0 {
    let glyph = added.pop().unwrap()
    match by_glyph.get(glyph) {
      Some(list) => {
        for id in list {
          waiting[id].missing -= 1
          if waiting[id].missing == 0 {
            add_output(waiting[id].output)
          }
        }
        by_glyph.remove(glyph)
      }
      None => ()
    }
  }
  let out = kept.keys().collect()
  out.sort()
  out
}

///|
/// Whether the table exhausted its upstream lookup work budget.
pub fn Gsub::truncated(self : Gsub) -> Bool {
  self.steps < 0
}
