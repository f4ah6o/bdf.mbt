///|
/// One written note or rest value; kind 0 is breve through 8 for 128th.
pub(all) struct NotationValue {
  offset : Int64
  ticks : Int64
  kind : Int32
  dots : Int32
}

///|
/// The duration of a note value in 960-tick quarter notes.
pub fn note_ticks(kind : Int32, dots : Int32) -> Int64 {
  if kind < 0 || kind > 8 || dots < 0 {
    return 0L
  }
  let mut duration = 7680L >> kind
  let mut total = duration
  for _ in 0..<dots {
    duration = duration / 2L
    total += duration
  }
  total
}

///|
fn note_values() -> Array[NotationValue] {
  let values : Array[NotationValue] = []
  for kind in 0..<9 {
    if kind != 8 {
      values.push({ offset: 0L, ticks: note_ticks(kind, 1), kind, dots: 1, })
    }
    values.push({ offset: 0L, ticks: note_ticks(kind, 0), kind, dots: 0, })
  }
  values.sort_by((a, b) => b.ticks.compare(a.ticks))
  values
}

///|
let all_note_values : Array[NotationValue] = note_values()

///|
/// Divide a span within a measure into aligned note or rest values.
pub fn divide_values(
  start : Int64,
  end : Int64,
  beat : Int64,
  measure_length : Int64,
  compound : Bool,
  rest : Bool,
) -> Array[NotationValue] {
  let out : Array[NotationValue] = []
  if beat <= 0L {
    return out
  }
  let values = all_note_values
  let mut at = start
  while at < end {
    let mut found = false
    for value in values {
      if value.ticks > end - at ||
        (value.kind == 0 && measure_length < value.ticks) {
        continue
      }
      let base = note_ticks(value.kind, 0)
      if rest {
        if value.dots > 0 &&
          !(compound && value.ticks == beat && at % beat == 0L) {
          continue
        }
        if at % base != 0L && value.dots == 0 {
          continue
        }
      }
      if at % beat == 0L {
        if value.ticks > beat {
          if compound && value.ticks % beat != 0L {
            continue
          }
          if !compound && base % beat != 0L {
            continue
          }
        }
      } else if at / beat != (at + value.ticks - 1L) / beat {
        continue
      }
      out.push({
        offset: at,
        ticks: value.ticks,
        kind: value.kind,
        dots: value.dots,
      })
      at += value.ticks
      found = true
      break
    }
    if !found {
      out.push({ offset: at, ticks: end - at, kind: 8, dots: 0, })
      break
    }
  }
  out
}
