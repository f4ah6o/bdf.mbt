///|
/// Names of glyphs in glyph-ID order, from a post format 2 table or CFF charset.
/// Duplicate post names belong to their first glyph, as in the upstream parser.
pub fn Font::glyph_names(self : Font) -> Array[String] {
  let result = [ for _ in 0..<self.metrics.glyph_count => "" ]
  let post = sfnt_table(self.source, self.tables, "post")
  let mut named = false
  if post.length() >= 34 && u32(post, 0) == 0x00020000U {
    let count = u16(post, 32)
    let names : Array[(String, String)] = []
    let mut pos = 34 + count * 2
    while pos < post.length() {
      let length = post[pos].to_int()
      pos += 1
      if length > post.length() - pos {
        break
      }
      let raw = post[pos:pos + length]
      let key = StringBuilder()
      for byte in raw {
        key.write_char(byte.to_int().unsafe_to_char())
      }
      names.push((@utf8.decode_lossy(raw), key.to_string()))
      pos += length
    }
    let seen : Map[String, Bool] = Map([])
    for gid in 0..<count {
      let index = u16(post, 34 + gid * 2)
      let (name, key) = if index < 258 {
        let name = mac_glyph_names[index]
        (name, name)
      } else if index - 258 < names.length() {
        names[index - 258]
      } else {
        ("", "")
      }
      if name != "" && !seen.contains(key) {
        seen[key] = true
        named = true
        if gid < result.length() {
          result[gid] = name
        }
      }
    }
  }
  if !named && self.tables.contains("CFF ") {
    let cff = sfnt_table(self.source, self.tables, "CFF ").to_owned()
    let names = @cff.glyph_names(cff) catch { _ => [] }
    for i in 0..<Int32::min(names.length(), result.length()) {
      result[i] = names[i]
    }
  }
  result
}
