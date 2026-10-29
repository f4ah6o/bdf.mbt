///|
priv struct SmuflSource {
  codepoint : Int32
  advance : Int32
  bbox : (Double, Double, Double, Double)
  anchors : Map[String, (Double, Double)]
  path : String
}

///|
/// A Bravura symbol in staff spaces, with its Y axis pointing down.
pub(all) struct MusicGlyph {
  name : String
  codepoint : Int32
  advance : Double
  bbox : (Double, Double, Double, Double)
  anchors : Map[String, (Double, Double)]
  verbs : Bytes
  coordinates : Array[Double]
}

///|
priv struct OutlineReader {
  data : String
  mut pos : Int32
}

///|
fn OutlineReader::number(self : OutlineReader) -> Double {
  let start = self.pos
  if self.pos < self.data.length() && self.data[self.pos] == 0x2d {
    self.pos += 1
  }
  while self.pos < self.data.length() {
    let c = self.data[self.pos]
    if c == 0x2e || (c >= 0x30 && c <= 0x39) {
      self.pos += 1
    } else {
      break
    }
  }
  let value = @string.parse_double(self.data[start:self.pos].to_owned()) catch {
    _ => 0.0
  }
  while self.pos < self.data.length() && self.data[self.pos] == 0x20 {
    self.pos += 1
  }
  value
}

///|
let music_glyph_cache : Map[String, MusicGlyph] = Map([])

///|
/// Look up an embedded SMuFL symbol and parse its outline in staff spaces.
pub fn music_glyph(name : String) -> MusicGlyph? {
  match music_glyph_cache.get(name) {
    Some(glyph) => return Some(glyph)
    None => ()
  }
  let source = match smufl_glyphs.get(name) {
    Some(source) => source
    None => return None
  }
  let (x0, y0, x1, y1) = source.bbox
  let anchors : Map[String, (Double, Double)] = Map([])
  for (key, (x, y)) in source.anchors {
    anchors[key] = (x / 250.0, -y / 250.0)
  }
  let reader : OutlineReader = { data: source.path, pos: 0, }
  let verbs : Array[Byte] = []
  let coordinates : Array[Double] = []
  while reader.pos < reader.data.length() {
    let op = reader.data[reader.pos]
    reader.pos += 1
    let (verb, points) = match op {
      0x4d => (0, 1)
      0x4c => (1, 1)
      0x51 => (2, 2)
      0x43 => (3, 3)
      0x5a => (4, 0)
      _ => continue
    }
    verbs.push(verb.to_byte())
    for _ in 0..<points {
      let x = reader.number()
      let y = reader.number()
      coordinates.push(x * 0.004)
      coordinates.push(-y * 0.004)
    }
  }
  let result : MusicGlyph = {
    name,
    codepoint: source.codepoint,
    advance: source.advance.to_double() / 250.0,
    bbox: (x0 / 250.0, -y1 / 250.0, x1 / 250.0, -y0 / 250.0),
    anchors,
    verbs: Bytes::from_array(verbs),
    coordinates,
  }
  music_glyph_cache[name] = result
  Some(result)
}
