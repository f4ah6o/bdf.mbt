///|
priv struct DxfTag {
  code : Int
  s : String
  f : Double
}

///|
priv struct DxfEntity {
  typ : String
  tags : Array[DxfTag]
  kids : Array[DxfEntity]
}

///|
priv struct DxfLayer {
  name : String
  color : Int
  ltype : String
  lineweight : Int
  no_plot : Bool
  frozen : Bool
  off : Bool
}

///|
priv struct DxfBlock {
  name : String
  base : @cad.Point
  entities : Array[DxfEntity]
}

///|
priv struct DxfDrawing {
  header : Map[String, Array[DxfTag]]
  layers : Map[String, DxfLayer]
  ltypes : Map[String, Array[Double]]
  blocks : Map[String, DxfBlock]
  entities : Array[DxfEntity]
  encoding : String
}

///|
fn dxf_type(code : Int) -> Int {
  if (code >= 10 && code < 60) || (code >= 110 && code < 150) ||
    (code >= 210 && code < 240) || (code >= 460 && code < 470) ||
    (code >= 1010 && code < 1060) {
    1
  } else if (code >= 60 && code < 80) || (code >= 170 && code < 180) ||
    (code >= 270 && code < 290) || (code >= 370 && code < 390) ||
    (code >= 400 && code < 410) || (code >= 1060 && code < 1071) {
    2
  } else if (code >= 90 && code < 100) || (code >= 420 && code < 430) ||
    (code >= 440 && code < 460) || code == 1071 {
    3
  } else if code >= 160 && code < 170 {
    4
  } else if code >= 290 && code < 300 {
    5
  } else if (code >= 310 && code < 320) || code == 1004 {
    6
  } else {
    0
  }
}

///|
fn dxf_trim(value : StringView) -> String {
  let mut start = 0
  let mut end = value.length()
  while start < end {
    let c = value[start]
    if c == ' ' || c == '\t' || c == '\r' || c == '\n' {
      start += 1
    } else {
      break
    }
  }
  while end > start {
    let c = value[end - 1]
    if c == ' ' || c == '\t' || c == '\r' || c == '\n' {
      end -= 1
    } else {
      break
    }
  }
  value[start:end].to_owned()
}

///|
fn dxf_number(value : StringView) -> Double {
  let trimmed = dxf_trim(value)
  if trimmed == "" {
    return 0.0
  }
  let parsed = try {
    Some(@string.parse_double(trimmed))
  } catch {
    _ => None
  }
  match parsed {
    Some(number) => number
    None => 0.0
  }
}

///|
fn dxf_binary_sentinel(data : Bytes) -> Bool {
  data.length() >= 22 && data.has_prefix(b"AutoCAD Binary DXF") &&
  data[18] == (13).to_byte() && data[19] == (10).to_byte() &&
  data[20] == (26).to_byte() && data[21] == (0).to_byte()
}

///|
fn dxf_u16_le(data : Bytes, offset : Int) -> Int raise {
  if offset < 0 || offset + 2 > data.length() {
    raise Failure("dxf: the binary DXF data ends in the middle of a value")
  }
  data[offset].to_int() | (data[offset + 1].to_int() << 8)
}

///|
fn dxf_u64_le(data : Bytes, offset : Int) -> Int64 raise {
  if offset < 0 || offset + 8 > data.length() {
    raise Failure("dxf: the binary DXF data ends in the middle of a value")
  }
  let mut value = 0L
  for i in 0..<8 {
    value = value | (data[offset + i].to_int64() << (i * 8))
  }
  value
}

///|
fn dxf_f64_le(data : Bytes, offset : Int) -> Double raise {
  dxf_u64_le(data, offset).to_uint64().reinterpret_as_double()
}

///|
fn dxf_cstring(data : Bytes, offset : Int) -> (String, Int) raise {
  let mut end = offset
  while end < data.length() && data[end] != (0).to_byte() {
    end += 1
  }
  if end >= data.length() {
    raise Failure("dxf: the binary DXF data ends in the middle of a value")
  }
  (@utf8.decode_lossy(data[offset:end].to_owned()), end + 1)
}

///|
fn dxf_binary_codes_are_wide(data : Bytes) -> Bool {
  // R12 binary files use one-byte group codes; later ones use two. The
  // group code after "$ACADVER\0" is 01 in R12 and 01 00 in later files.
  let limit = Int::min(data.length(), 1024)
  let mut i = 22
  while i + 9 <= limit {
    if data[i] == (36).to_byte() && data[i + 1] == (65).to_byte() &&
      data[i + 2] == (67).to_byte() && data[i + 3] == (65).to_byte() &&
      data[i + 4] == (68).to_byte() && data[i + 5] == (86).to_byte() &&
      data[i + 6] == (69).to_byte() && data[i + 7] == (82).to_byte() &&
      data[i + 8] == (0).to_byte() {
      return i + 10 < limit && data[i + 9] == (1).to_byte() &&
        data[i + 10] == (0).to_byte()
    }
    i += 1
  }
  false
}

///|
fn read_binary_tags(data : Bytes) -> Array[DxfTag] raise {
  let wide = dxf_binary_codes_are_wide(data)
  let tags : Array[DxfTag] = []
  let mut offset = 22
  while offset < data.length() {
    let code = if wide {
      let value = dxf_u16_le(data, offset)
      offset += 2
      value
    } else {
      let value = data[offset].to_int()
      offset += 1
      if value == 255 {
        let extended = dxf_u16_le(data, offset)
        offset += 2
        extended
      } else {
        value
      }
    }
    let kind = dxf_type(code)
    let tag = match kind {
      1 => {
        let value = dxf_f64_le(data, offset)
        offset += 8
        { code, s: value.to_string(), f: value }
      }
      2 => {
        let raw = dxf_u16_le(data, offset)
        offset += 2
        let value = if raw >= 32768 { raw - 65536 } else { raw }
        { code, s: value.to_string(), f: value.to_double() }
      }
      3 => {
        let low = dxf_u16_le(data, offset).to_int64()
        let high = dxf_u16_le(data, offset + 2).to_int64()
        offset += 4
        let raw = (high << 16) | low
        let value = if raw >= 2147483648L { raw - 4294967296L } else { raw }
        { code, s: value.to_string(), f: value.to_double() }
      }
      4 => {
        let value = dxf_u64_le(data, offset)
        offset += 8
        { code, s: value.to_string(), f: value.to_double() }
      }
      5 => {
        if offset >= data.length() {
          raise Failure("dxf: the binary DXF data ends in the middle of a value")
        }
        let value = data[offset].to_int()
        offset += 1
        { code, s: value.to_string(), f: value.to_double() }
      }
      6 => {
        if offset >= data.length() {
          raise Failure("dxf: the binary DXF data ends in the middle of a value")
        }
        let length = data[offset].to_int()
        offset += 1
        if offset + length > data.length() {
          raise Failure("dxf: the binary DXF data ends in the middle of a value")
        }
        let value = @utf8.decode_lossy(data[offset:offset + length].to_owned())
        offset += length
        { code, s: value, f: 0.0 }
      }
      _ => {
        let (value, next) = dxf_cstring(data, offset)
        offset = next
        { code, s: value, f: 0.0 }
      }
    }
    tags.push(tag)
    if code == 0 && tag.s == "EOF" {
      break
    }
  }
  if tags.is_empty() {
    raise Failure("dxf: not a DXF file")
  }
  tags
}

///|
fn read_tags(data : Bytes) -> Array[DxfTag] raise {
  if dxf_binary_sentinel(data) {
    return read_binary_tags(data)
  }
  let head = @utf8.decode_lossy(data[:Int::min(data.length(), 8192)].to_owned())
  let text = if head.to_lower().contains("ansi_932") || head.to_lower().contains("shift_jis") {
    match @encoding.decode(data, "shift_jis") {
      Ok(value) => value
      Err(_) => @utf8.decode_lossy(data)
    }
  } else {
    @utf8.decode_lossy(data)
  }
  let lines = text.split("\n").collect()
  let tags : Array[DxfTag] = []
  let mut index = 0
  while index + 1 < lines.length() {
    let code_text = dxf_trim(lines[index])
    let value = lines[index + 1]
    index += 2
    if code_text == "" {
      continue
    }
    let code = try {
      @string.parse_int(code_text)
    } catch {
      _ => {
        if tags.is_empty() {
          raise Failure("dxf: not a DXF file")
        }
        0
      }
    }
    let kind = dxf_type(code)
    let tag = if kind == 0 || kind == 6 {
      { code, s: value.to_owned(), f: 0.0 }
    } else {
      let number = dxf_number(value)
      { code, s: value.to_owned(), f: number }
    }
    tags.push(tag)
    if code == 0 && dxf_trim(value) == "EOF" {
      break
    }
  }
  if tags.is_empty() {
    raise Failure("dxf: not a DXF file")
  }
  tags
}

///|
fn DxfEntity::num(self : DxfEntity, code : Int, default : Double) -> Double {
  let mut found = default
  for tag in self.tags {
    if tag.code == code {
      found = tag.f
    }
  }
  found
}

///|
fn DxfEntity::int(self : DxfEntity, code : Int, default : Int) -> Int {
  self.num(code, default.to_double()).round().to_int()
}

///|
fn DxfEntity::has(self : DxfEntity, code : Int) -> Bool {
  for tag in self.tags {
    if tag.code == code {
      return true
    }
  }
  false
}

///|
fn DxfEntity::str(self : DxfEntity, code : Int) -> String {
  let mut found = ""
  for tag in self.tags {
    if tag.code == code {
      found = tag.s
    }
  }
  found
}

///|
fn DxfEntity::point(self : DxfEntity, code : Int) -> @cad.Point {
  {
    x: self.num(code, 0.0),
    y: self.num(code + 10, 0.0),
  }
}

///|
fn DxfEntity::vec3(self : DxfEntity, code : Int) -> (Double, Double, Double) {
  (self.num(code, 0.0), self.num(code + 10, 0.0), self.num(code + 20, 0.0))
}

///|
fn parse_entity(tags : Array[DxfTag], start : Int) -> (DxfEntity, Int) {
  let typ = dxf_trim(tags[start].s)
  let values : Array[DxfTag] = []
  let mut index = start + 1
  while index < tags.length() && tags[index].code != 0 {
    values.push(tags[index])
    index += 1
  }
  ({ typ, tags: values, kids: [] }, index)
}

///|
fn parse_entities(tags : Array[DxfTag], start : Int, stop : String) -> (Array[DxfEntity], Int) {
  let output : Array[DxfEntity] = []
  let mut index = start
  while index < tags.length() {
    if tags[index].code != 0 {
      index += 1
      continue
    }
    let typ = dxf_trim(tags[index].s)
    if typ == stop || typ == "ENDSEC" || typ == "ENDBLK" {
      break
    }
    if typ == "VERTEX" || typ == "ATTRIB" || typ == "SEQEND" {
      index += 1
      continue
    }
    let (entity, next) = parse_entity(tags, index)
    index = next
    let kids : Array[DxfEntity] = []
    if entity.typ == "POLYLINE" || entity.typ == "INSERT" {
      while index < tags.length() && tags[index].code == 0 {
        let child_type = dxf_trim(tags[index].s)
        if child_type == "SEQEND" {
          index += 1
          break
        }
        if child_type != "VERTEX" && child_type != "ATTRIB" {
          break
        }
        let (child, child_next) = parse_entity(tags, index)
        kids.push(child)
        index = child_next
      }
    }
    output.push({ typ: entity.typ, tags: entity.tags, kids })
  }
  (output, index)
}

///|
fn parse_dxf(tags : Array[DxfTag]) -> DxfDrawing {
  let header : Map[String, Array[DxfTag]] = Map([])
  let layers : Map[String, DxfLayer] = Map([])
  let ltypes : Map[String, Array[Double]] = Map([])
  let blocks : Map[String, DxfBlock] = Map([])
  let entities : Array[DxfEntity] = []
  let mut encoding = ""
  let mut index = 0
  while index < tags.length() {
    if tags[index].code == 0 && dxf_trim(tags[index].s) == "SECTION" &&
      index + 1 < tags.length() && tags[index + 1].code == 2 {
      let name = dxf_trim(tags[index + 1].s)
      index += 2
      if name == "HEADER" {
        let mut variable = ""
        let values : Array[DxfTag] = []
        while index < tags.length() && !(tags[index].code == 0 && dxf_trim(tags[index].s) == "ENDSEC") {
          if tags[index].code == 9 {
            if variable != "" {
              header[variable] = values.copy()
              values.clear()
            }
            variable = dxf_trim(tags[index].s)
          } else if variable != "" {
            values.push(tags[index])
          }
          index += 1
        }
        if variable != "" {
          header[variable] = values.copy()
        }
        if index < tags.length() { index += 1 }
      } else if name == "TABLES" {
        index = parse_tables(tags, index, layers, ltypes)
      } else if name == "BLOCKS" {
        index = parse_blocks(tags, index, blocks)
      } else if name == "ENTITIES" {
        let (list, next) = parse_entities(tags, index, "ENDSEC")
        entities.append(list)
        index = next
        if index < tags.length() { index += 1 }
      } else {
        while index < tags.length() && !(tags[index].code == 0 && dxf_trim(tags[index].s) == "ENDSEC") {
          index += 1
        }
        if index < tags.length() { index += 1 }
      }
    } else {
      index += 1
    }
  }
  match header.get("$DWGCODEPAGE") {
    Some(values) =>
      if !values.is_empty() {
        encoding = values[0].s.to_lower()
      }
    None => ()
  }
  { header, layers, ltypes, blocks, entities, encoding }
}

///|
fn parse_tables(
  tags : Array[DxfTag],
  start : Int,
  layers : Map[String, DxfLayer],
  ltypes : Map[String, Array[Double]],
) -> Int {
  let mut index = start
  while index < tags.length() {
    if tags[index].code == 0 && dxf_trim(tags[index].s) == "ENDSEC" {
      return index + 1
    }
    if tags[index].code == 0 && dxf_trim(tags[index].s) == "LAYER" {
      let (entity, next) = parse_entity(tags, index)
      index = next
      let layer = {
        name: entity.str(2),
        color: entity.int(62, 7),
        ltype: entity.str(6),
        lineweight: entity.int(370, -3),
        no_plot: entity.int(290, 0) == 0,
        frozen: (entity.int(70, 0) & 1) != 0,
        off: entity.int(62, 7) < 0,
      }
      layers[layer.name.to_upper()] = layer
    } else if tags[index].code == 0 && dxf_trim(tags[index].s) == "LTYPE" {
      let (entity, next) = parse_entity(tags, index)
      index = next
      let elements : Array[Double] = []
      for tag in entity.tags {
        if tag.code == 49 {
          elements.push(tag.f)
        }
      }
      ltypes[entity.str(2).to_upper()] = elements
    } else {
      index += 1
    }
  }
  index
}

///|
fn parse_blocks(tags : Array[DxfTag], start : Int, blocks : Map[String, DxfBlock]) -> Int {
  let mut index = start
  while index < tags.length() {
    if tags[index].code == 0 && dxf_trim(tags[index].s) == "ENDSEC" {
      return index + 1
    }
    if tags[index].code == 0 && dxf_trim(tags[index].s) == "BLOCK" {
      let (entity, next) = parse_entity(tags, index)
      index = next
      let name = entity.str(2)
      let base = entity.point(10)
      let (list, next2) = parse_entities(tags, index, "ENDBLK")
      index = next2
      if index < tags.length() { index += 1 }
      blocks[name.to_upper()] = { name, base, entities: list }
    } else {
      index += 1
    }
  }
  index
}
