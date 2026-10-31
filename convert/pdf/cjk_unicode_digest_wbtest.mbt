///|
fn pdf_cjk_unicode_digest(collection : String) -> UInt64 {
  let mut digest = 14695981039346656037UL
  for index in 0..<131072 {
    let cid = index.to_int64()
    let value = match pdf_cjk_unicode(collection, cid) {
      Some((code, vertical)) => {
        let value = code.reinterpret_as_uint64() + 1UL
        if vertical {
          value | (1UL << 21)
        } else {
          value
        }
      }
      None => 0UL
    }
    digest = (digest ^ value) * 1099511628211UL
    let form = match pdf_cjk_vertical_form(collection, cid) {
      Some(code) => code.reinterpret_as_uint64() + 1UL
      None => 0UL
    }
    digest = (digest ^ form) * 1099511628211UL
  }
  digest
}
