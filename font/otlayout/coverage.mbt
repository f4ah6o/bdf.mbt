///|
fn coverage(data : BytesView?) -> Array[Int32] {
  let out : Array[Int32] = []
  guard data is Some(data) else { return out }
  match u16(data, 0) {
    1 => {
      let n = count(data, u16(data, 2), 4, 2)
      for i in 0..<n {
        out.push(u16(data, 4 + i * 2))
      }
    }
    2 => {
      let n = count(data, u16(data, 2), 4, 6)
      for i in 0..<n {
        let start = u16(data, 4 + i * 6)
        let end = u16(data, 6 + i * 6)
        for glyph in start..<=end {
          if out.length() >= 65536 {
            return out
          }
          out.push(glyph)
        }
      }
    }
    _ => ()
  }
  out
}
