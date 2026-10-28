///|
// NFKC requires ordering combining marks by canonical combining class. The
// normalization library's insertion sort is quadratic for long sequences in
// reverse class order. Decompose each scalar separately, then stably count-sort
// each non-starter sequence and compose. A scalar's decomposition is bounded.
fn search_nfkc(input : String) -> String {
  let chars : Array[Char] = []
  for c in input {
    if c.to_int() < 0x80 {
      chars.push(c)
    } else {
      for d in @normalization.nfkd(c.to_string()) {
        chars.push(d)
      }
    }
  }
  let mut i = 0
  while i < chars.length() {
    if @ucd.lookup_ccc(chars[i]) == 0 {
      i += 1
      continue
    }
    let start = i
    let mut previous = 0
    let mut ordered = true
    while i < chars.length() {
      let ccc = @ucd.lookup_ccc(chars[i])
      if ccc == 0 {
        break
      }
      if ccc < previous {
        ordered = false
      }
      previous = ccc
      i += 1
    }
    if !ordered {
      let counts = FixedArray::make(256, 0)
      for j in start..<i {
        let ccc = @ucd.lookup_ccc(chars[j])
        counts[ccc] += 1
      }
      let mut position = 0
      for ccc in 0..<256 {
        let count = counts[ccc]
        counts[ccc] = position
        position += count
      }
      let sorted = Array::make(i - start, '\u{0}')
      for j in start..<i {
        let ccc = @ucd.lookup_ccc(chars[j])
        sorted[counts[ccc]] = chars[j]
        counts[ccc] += 1
      }
      for j in 0..<sorted.length() {
        chars[start + j] = sorted[j]
      }
    }
  }
  let composed : Array[Char] = []
  let mut starter = -1
  let mut last_class = 0
  for c in chars {
    let ccc = @ucd.lookup_ccc(c)
    if starter >= 0 && (last_class == 0 || (ccc != 0 && last_class < ccc)) {
      if search_compose(composed[starter], c) is Some(combination) {
        composed[starter] = combination
        continue
      }
    }
    composed.push(c)
    if ccc == 0 {
      starter = composed.length() - 1
    }
    last_class = ccc
  }
  String::from_array(composed)
}

///|
fn search_compose(first : Char, second : Char) -> Char? {
  let a = first.to_int()
  let b = second.to_int()
  // Hangul composition is algorithmic and is not in the Unicode tables.
  if a >= 0x1100 && a < 0x1113 && b >= 0x1161 && b < 0x1176 {
    return Some(
      (0xac00 + ((a - 0x1100) * 21 + b - 0x1161) * 28).unsafe_to_char(),
    )
  }
  if a >= 0xac00 &&
    a < 0xd7a4 &&
    (a - 0xac00) % 28 == 0 &&
    b > 0x11a7 &&
    b < 0x11c3 {
    return Some((a + b - 0x11a7).unsafe_to_char())
  }
  @ucd.lookup_composition(first, second)
}
