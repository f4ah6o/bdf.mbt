///|
priv struct JwwArchive {
  data : Bytes
  mut offset : Int
  mut error : String
  classes : Map[Int, String]
  objects : Map[Int, JwwFigure]
  mut next : Int
}

///|
fn JwwArchive::new(data : Bytes) -> JwwArchive {
  { data, offset: 0, error: "", classes: Map([]), objects: Map([]), next: 1 }
}

///|
fn JwwArchive::need(self : JwwArchive, count : Int) -> Bool {
  if self.error != "" { return false }
  if count < 0 || self.offset + count > self.data.length() {
    self.error = "the file ends in the middle of the data"
    return false
  }
  true
}

///|
fn JwwArchive::u8(self : JwwArchive) -> Byte {
  if !self.need(1) { return 0 }
  let value = self.data[self.offset]
  self.offset += 1
  value
}

///|
fn JwwArchive::u16(self : JwwArchive) -> Int {
  if !self.need(2) { return 0 }
  let value = self.data[self.offset].to_int() | (self.data[self.offset + 1].to_int() << 8)
  self.offset += 2
  value
}

///|
fn JwwArchive::u32(self : JwwArchive) -> Int {
  if !self.need(4) { return 0 }
  let value = self.data[self.offset].to_int() |
    (self.data[self.offset + 1].to_int() << 8) |
    (self.data[self.offset + 2].to_int() << 16) |
    (self.data[self.offset + 3].to_int() << 24)
  self.offset += 4
  value
}

///|
fn JwwArchive::i32(self : JwwArchive) -> Int {
  self.u32()
}

///|
fn JwwArchive::f64(self : JwwArchive) -> Double {
  if !self.need(8) { return 0.0 }
  let mut bits = 0UL
  for index in 0..<8 {
    bits = bits | (self.data[self.offset + index].to_uint64() << (index * 8))
  }
  self.offset += 8
  let value = bits.reinterpret_as_double()
  if value.is_nan() || value.is_inf() { 0.0 } else { value }
}

///|
fn JwwArchive::skip(self : JwwArchive, count : Int) -> Unit {
  if self.need(count) { self.offset += count }
}

///|
fn jww_utf16(raw : Bytes) -> String {
  let output = StringBuilder()
  let mut index = 0
  while index + 1 < raw.length() {
    let first = raw[index].to_int() | (raw[index + 1].to_int() << 8)
    index += 2
    if first >= 0xd800 && first < 0xdc00 && index + 1 < raw.length() {
      let second = raw[index].to_int() | (raw[index + 1].to_int() << 8)
      if second >= 0xdc00 && second < 0xe000 {
        index += 2
        output.write_char((0x10000 + ((first - 0xd800) << 10) + second - 0xdc00).unsafe_to_char())
        continue
      }
    }
    output.write_char(first.unsafe_to_char())
  }
  output.to_string()
}

///|
fn JwwArchive::str(self : JwwArchive) -> String {
  let mut count = self.u8().to_int()
  let mut unicode = false
  if count == 0xff {
    count = self.u16()
    if count == 0xfffe {
      unicode = true
      count = self.u8().to_int()
      if count == 0xff {
        count = self.u16()
        if count == 0xffff { count = self.u32() }
      }
    } else if count == 0xffff {
      count = self.u32()
    }
  }
  if unicode { count *= 2 }
  if count > self.data.length() || !self.need(count) { return "" }
  let raw = self.data[self.offset:self.offset + count].to_owned()
  self.offset += count
  if unicode { return jww_utf16(raw) }
  match @encoding.decode(raw, "shift_jis") {
    Ok(value) => value
    Err(_) => @utf8.decode_lossy(raw)
  }
}

///|
fn JwwArchive::count(self : JwwArchive) -> Int {
  let mut count = self.u16()
  if count == 0xffff { count = self.u32() }
  if count > self.data.length() {
    self.error = "a list does not fit in the file"
    return 0
  }
  count
}

///|
fn JwwArchive::object_tag(self : JwwArchive) -> (String, Int, JwwFigure?) {
  let tag = self.u16()
  if self.error != "" || tag == 0 { return ("", 0, None) }
  if tag == 0xffff {
    ignore(self.u16())
    let length = self.u16()
    if !self.need(length) { return ("", 0, None) }
    let class = @utf8.decode_lossy(self.data[self.offset:self.offset + length])
    self.offset += length
    self.classes[self.next] = class
    self.next += 1
    let index = self.next
    self.next += 1
    return (class, index, None)
  }
  if (tag & 0x8000) != 0 {
    let mut index = tag & 0x7fff
    if index == 0x7fff { index = self.u32() & 0x7fffffff }
    match self.classes.get(index) {
      Some(class) => {
        let next = self.next
        self.next += 1
        (class, next, None)
      }
      None => {
        self.error = "unknown class reference"
        ("", 0, None)
      }
    }
  } else {
    let mut index = tag
    if index == 0x7fff { index = self.u32() }
    match self.objects.get(index) {
      Some(value) => ("", 0, Some(value))
      None => {
        self.error = "unknown object reference"
        ("", 0, None)
      }
    }
  }
}

///|
priv struct JwwBase {
  group : Int
  style : Int
  color : Int
  width : Int
  layer : Int
  glayer : Int
  flag : Int
}

///|
priv struct JwwSen {
  base : JwwBase
  a : @cad.Point
  b : @cad.Point
}

///|
priv struct JwwEnko {
  base : JwwBase
  c : @cad.Point
  r : Double
  start : Double
  arc : Double
  tilt : Double
  flat : Double
  full : Bool
}

///|
priv struct JwwTen {
  base : JwwBase
  p : @cad.Point
  kari : Bool
  code : Int
  rot : Double
  scale : Double
  has_sub : Bool
}

///|
priv struct JwwMoji {
  base : JwwBase
  a : @cad.Point
  b : @cad.Point
  kind : Int
  w : Double
  h : Double
  spacing : Double
  angle : Double
  font : String
  s : String
}

///|
priv struct JwwSunpou {
  base : JwwBase
  line : JwwSen
  text : JwwMoji
  sxf : Bool
  has_aux : Bool
  aux : Array[JwwSen?]
  points : Array[JwwTen?]
}

///|
priv struct JwwSolid {
  base : JwwBase
  p1 : @cad.Point
  p4 : @cad.Point
  p2 : @cad.Point
  p3 : @cad.Point
  rgb : UInt32
}

///|
priv struct JwwBlock {
  base : JwwBase
  p : @cad.Point
  sx : Double
  sy : Double
  rot : Double
  number : Int
}

///|
priv struct JwwBlockDef {
  base : JwwBase
  number : Int
  name : String
  figures : Array[JwwFigure]
}

///|
priv enum JwwFigure {
  Sen(JwwSen)
  Enko(JwwEnko)
  Ten(JwwTen)
  Moji(JwwMoji)
  Sunpou(JwwSunpou)
  Solid(JwwSolid)
  Block(JwwBlock)
  BlockDef(JwwBlockDef)
}

///|
priv struct JwwGroup {
  mut state : Int
  mut scale : Double
  layers : Array[Int]
  mut name : String
  names : Array[String]
}

///|
priv struct JwwPen {
  mut color : UInt32
  mut width : Int
  mut radius : Double
}

///|
priv struct JwwLineType {
  mut mask : UInt32
  unit : Int
  mut pitch : Int
  mut prt_pitch : Int
}

///|
priv struct JwwUdLineType {
  mut name : String
  mut segments : Int
  pitch : Array[Double]
}

///|
priv struct JwwMojiShu {
  mut w : Double
  mut h : Double
  mut spacing : Double
  mut color : Int
}

///|
priv struct JwwHeader {
  version : Int
  memo : String
  paper : Int
  groups : Array[JwwGroup]
  dimension : Array[Int]
  max_width : Int
  screen : Array[UInt32]
  prt_pen : Array[JwwPen]
  line_types : Map[Int, JwwLineType]
  sxf_pens : Array[JwwPen]
  sxf_types : Array[JwwUdLineType]
  has_sxf : Bool
  draw_prt_ten : Bool
  color_print : Bool
  dpi : Int
  moji : Array[JwwMojiShu]
}

///|
fn jww_group() -> JwwGroup {
  { state: 0, scale: 1.0, layers: [], name: "", names: [] }
}

///|
fn jww_pen() -> JwwPen {
  { color: 0x00ffffffU, width: 0, radius: 0.0 }
}

///|
fn jww_line_type() -> JwwLineType {
  { mask: 0U, unit: 0, pitch: 0, prt_pitch: 0 }
}

///|
fn jww_ud_line_type() -> JwwUdLineType {
  { name: "", segments: 0, pitch: [] }
}

///|
fn jww_moji_shu() -> JwwMojiShu {
  { w: 0.0, h: 0.0, spacing: 0.0, color: 0 }
}

///|
fn jww_base(archive : JwwArchive, header : JwwHeader) -> JwwBase {
  {
    group: archive.u32(),
    style: archive.u8().to_int(),
    color: archive.u16(),
    width: if header.version >= 351 { archive.u16() } else { 0 },
    layer: archive.u16(),
    glayer: archive.u16(),
    flag: archive.u16(),
  }
}

///|
fn jww_point(archive : JwwArchive) -> @cad.Point {
  { x: archive.f64(), y: archive.f64() }
}
