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
  emit : (Array[Int32], Outputs) -> Unit,
) -> Unit {
  for lookup in self.lookups {
    let seen : Map[String, Bool] = Map([])
    let add = (input : Array[Int32], output : Outputs) => {
      if lookup.typ != 8 {
        let key = input_key(input)
        if seen.contains(key) {
          return
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
                add([glyph], One((glyph + delta) & 65535))
              }
            }
            2 => {
              let n = count(data, u16(data, 4), 6, 2)
              for i in 0..<Int32::min(n, cov.length()) {
                add([cov[i]], One(u16(data, 6 + i * 2)))
              }
            }
            _ => ()
          }
        2 | 3 if u16(data, 0) == 1 => {
          let n = count(data, u16(data, 4), 6, 2)
          for i in 0..<Int32::min(n, cov.length()) {
            match at(data, u16(data, 6 + i * 2)) {
              Some(seq) => add([cov[i]], Many(seq))
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
              add(input, One(u16(lig, 0)))
            }
          }
        }
        8 if u16(data, 0) == 1 => {
          let mut p = 4
          p += 2 + u16(data, p) * 2
          p += 2 + u16(data, p) * 2
          let n = count(data, u16(data, p), p + 2, 2)
          for i in 0..<Int32::min(n, cov.length()) {
            add([cov[i]], One(u16(data, p + 2 + i * 2)))
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
