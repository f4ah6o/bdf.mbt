///|
priv enum Outputs {
  One(Int32)
  Many(BytesView)
}

///|
fn Gsub::spend(self : Gsub, n : Int32) -> Bool {
  self.steps -= n.to_int64()
  self.steps >= 0
}

///|
fn input_key(input : Array[Int32]) -> String {
  let out = StringBuilder()
  for glyph in input {
    out.write_char((glyph >> 8).unsafe_to_char())
    out.write_char((glyph & 255).unsafe_to_char())
  }
  out.to_string()
}

///|
fn Gsub::list_substitutions(
  self : Gsub,
  emit : (Array[Int32], Outputs) -> Bool,
  only~ : Int32 = -1,
) -> Unit {
  for index, lookup in self.lookups {
    if only >= 0 && only != index {
      continue
    }
    let seen : Map[String, Bool] = Map([])
    let add : (Array[Int32], Outputs) -> Bool = (input, output) => {
      if lookup.typ != 8 {
        let key = input_key(input)
        if seen.contains(key) {
          return true
        }
        seen[key] = true
      }
      emit(input, output)
    }
    for data in lookup.subtables {
      let cov = if lookup.typ == 1 ||
        lookup.typ == 2 ||
        lookup.typ == 3 ||
        lookup.typ == 4 ||
        lookup.typ == 8 {
        coverage(at(data, u16(data, 2)))
      } else {
        []
      }
      if !self.spend(1 + cov.length()) {
        break
      }
      let mut aborted = false
      match lookup.typ {
        1 =>
          match u16(data, 0) {
            1 => {
              let raw = u16(data, 4)
              let delta = if raw >= 32768 { raw - 65536 } else { raw }
              for glyph in cov {
                if !add([glyph], One((glyph + delta) & 65535)) {
                  return
                }
              }
            }
            2 => {
              let n = count(data, u16(data, 4), 6, 2)
              for i in 0..<Int32::min(n, cov.length()) {
                if !add([cov[i]], One(u16(data, 6 + i * 2))) {
                  return
                }
              }
            }
            _ => ()
          }
        2 | 3 if u16(data, 0) == 1 => {
          let n = count(data, u16(data, 4), 6, 2)
          for i in 0..<Int32::min(n, cov.length()) {
            match at(data, u16(data, 6 + i * 2)) {
              Some(seq) => if !add([cov[i]], Many(seq)) { return }
              None => ()
            }
          }
        }
        4 if u16(data, 0) == 1 => {
          let n = count(data, u16(data, 4), 6, 2)
          for i in 0..<Int32::min(n, cov.length()) {
            guard at(data, u16(data, 6 + i * 2)) is Some(set) else { continue }
            let m = count(set, u16(set, 0), 2, 2)
            if !self.spend(m) {
              aborted = true
              break
            }
            for j in 0..<m {
              guard at(set, u16(set, 2 + j * 2)) is Some(lig) else { continue }
              let components = count(lig, Int32::max(u16(lig, 2) - 1, 0), 4, 2)
              let input = [cov[i]]
              for k in 0..<components {
                input.push(u16(lig, 4 + k * 2))
              }
              if !add(input, One(u16(lig, 0))) {
                return
              }
            }
          }
        }
        8 if u16(data, 0) == 1 => {
          let mut p = 4
          p += 2 + u16(data, p) * 2
          p += 2 + u16(data, p) * 2
          let n = count(data, u16(data, p), p + 2, 2)
          for i in 0..<Int32::min(n, cov.length()) {
            if !add([cov[i]], One(u16(data, p + 2 + i * 2))) {
              return
            }
          }
        }
        _ => ()
      }
      if aborted {
        break
      }
    }
  }
}

///|
/// A substitution in lookup order, with all input and output glyph IDs.
pub(all) struct Substitution {
  input : Array[Int32]
  output : Array[Int32]
}

///|
/// Visit substitutions in one lookup. Return false from the callback to stop.
/// Work consumes the shared table budget, matching the upstream parser.
pub fn Gsub::each_substitution(
  self : Gsub,
  index : Int32,
  visit : (Substitution) -> Bool,
) -> Unit {
  if index < 0 || index >= self.lookups.length() {
    return
  }
  self.list_substitutions(
    (input, output) => {
      let glyphs = match output {
        One(glyph) => [glyph]
        Many(data) => {
          let n = count(data, u16(data, 0), 2, 2)
          [
            for i in 0..<n => u16(data, 2 + i * 2)
          ]
        }
      }
      visit({ input, output: glyphs, })
    },
    only=index,
  )
}
