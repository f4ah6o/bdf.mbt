///|
// Adobe's predefined encoding maps, as packed by upstream's cjkcmap package.
priv struct PdfCjkRange {
  low : Int64
  high : Int64
  cid : Int64
}

///|
priv struct PdfCjkMap {
  name : String
  collection : String
  vertical : Bool
  form : Int32
  base : String
  parent : String
  ranges : Array[PdfCjkRange]
  codespaces : Array[PdfCodeSpace]
}

///|
priv struct PdfCjkReader {
  data : Bytes
  mut pos : Int32
  mut bad : Bool
}

///|
fn PdfCjkReader::byte(self : PdfCjkReader) -> Int32 {
  if self.pos >= self.data.length() {
    self.bad = true
    return 0
  }
  let value = self.data[self.pos].to_int()
  self.pos += 1
  value
}

///|
fn PdfCjkReader::varuint(self : PdfCjkReader) -> Int64 {
  let mut value = 0L
  let mut shift = 0
  while shift <= 63 {
    let b = self.byte()
    if self.bad {
      return 0L
    }
    if shift == 63 && b > 1 {
      self.bad = true
      return 0L
    }
    value = value | ((b & 0x7f).to_int64() << shift)
    if b < 0x80 {
      return value
    }
    shift += 7
  }
  self.bad = true
  0L
}

///|
fn PdfCjkReader::varint(self : PdfCjkReader) -> Int64 {
  let value = self.varuint()
  (value >> 1) ^ -(value & 1L)
}

///|
fn PdfCjkReader::string(self : PdfCjkReader) -> String {
  let length = self.varuint()
  if self.bad ||
    length < 0 ||
    length > (self.data.length() - self.pos).to_int64() {
    self.bad = true
    return ""
  }
  let start = self.pos
  self.pos += length.to_int()
  @utf8.decode_lossy(self.data[start:self.pos])
}

///|
fn pdf_read_cjk_database() -> Map[String, PdfCjkMap] {
  let compressed = pdf_cjk_compressed()
  let data = @gzip.decompress(compressed[:], max_output=353523) catch {
    _ => abort("invalid embedded Adobe CMap archive")
  }
  if data.length() < 4 || data[:4].to_owned() != b"BCM1" {
    abort("invalid embedded Adobe CMap header")
  }
  let reader : PdfCjkReader = { data, pos: 4, bad: false, }
  let count = reader.varuint()
  let maps : Map[String, PdfCjkMap] = Map([])
  if count > data.length().to_int64() || count < 0 {
    abort("invalid CMap count")
  }
  for _ in 0..<count.to_int() {
    let name = reader.string()
    let parent = reader.string()
    let collection = reader.string()
    let vertical = reader.byte() == 1
    let form = reader.byte()
    let base = reader.string()
    let codespaces : Array[PdfCodeSpace] = []
    let space_count = reader.varuint()
    if space_count < 0 || space_count > data.length().to_int64() {
      abort("invalid CMap codespaces")
    }
    for _ in 0..<space_count.to_int() {
      codespaces.push({
        size: reader.byte(),
        low: reader.varuint(),
        high: reader.varuint(),
      })
    }
    let range_count = reader.varuint()
    if range_count < 0 || range_count > data.length().to_int64() {
      abort("invalid CMap ranges")
    }
    let ranges : Array[PdfCjkRange] = []
    let mut previous = -1L
    let mut next_cid = 0L
    for _ in 0..<range_count.to_int() {
      let low = previous + 1L + reader.varuint()
      let high = low + reader.varuint()
      let cid = next_cid + reader.varint()
      ranges.push({ low, high, cid, })
      previous = high
      next_cid = cid + high - low + 1L
    }
    maps[name] = {
      name,
      collection,
      vertical,
      form,
      base,
      parent,
      ranges,
      codespaces,
    }
  }
  if reader.bad {
    abort("truncated embedded Adobe CMap data")
  }
  // Resolve the complete parent chain independently of map iteration order.
  for _, map in maps {
    if map.codespaces.is_empty() && !map.parent.is_empty() {
      for space in pdf_cjk_inherited_spaces(maps, map.parent, 0) {
        map.codespaces.push(space)
      }
    }
  }
  maps
}

///|
fn pdf_cjk_inherited_spaces(
  maps : Map[String, PdfCjkMap],
  name : String,
  depth : Int32,
) -> Array[PdfCodeSpace] {
  if depth > 8 {
    return []
  }
  match maps.get(name) {
    Some(map) =>
      if !map.codespaces.is_empty() {
        map.codespaces
      } else if !map.parent.is_empty() {
        pdf_cjk_inherited_spaces(maps, map.parent, depth + 1)
      } else {
        []
      }
    None => []
  }
}

///|
let pdf_cjk_maps : Map[String, PdfCjkMap] = pdf_read_cjk_database()
