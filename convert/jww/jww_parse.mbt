///|
fn jww_sheet(paper : Int) -> (Double, Double) {
  match paper {
    0 => (1189.0, 841.0)
    1 => (841.0, 594.0)
    2 => (594.0, 420.0)
    3 => (420.0, 297.0)
    4 => (297.0, 210.0)
    8 => (1682.0, 1189.0)
    9 => (2378.0, 1682.0)
    10 => (3364.0, 2378.0)
    11 => (4756.0, 3364.0)
    12 => (10000.0, 7071.0)
    13 => (50000.0, 35355.0)
    14 => (100000.0, 70711.0)
    _ => (420.0, 297.0)
  }
}

///|
fn read_header(archive : JwwArchive) -> JwwHeader raise {
  if archive.data.length() < 12 || !archive.data.has_prefix(b"JwwData.") {
    raise Failure("jww: not a JWW file")
  }
  archive.offset = 8
  let version = archive.u32()
  let memo = archive.str()
  let paper = archive.u32()
  ignore(archive.u32())
  let groups : Array[JwwGroup] = []
  for _ in 0..<16 {
    let group = jww_group()
    group.state = archive.u32()
    ignore(archive.u32())
    group.scale = archive.f64()
    ignore(archive.u32())
    for _ in 0..<16 {
      group.layers.push(archive.u32())
      ignore(archive.u32())
    }
    groups.push(group)
  }
  archive.skip(14 * 4)
  let dimension : Array[Int] = []
  for _ in 0..<5 {
    dimension.push(archive.u32())
  }
  ignore(archive.u32())
  let max_width = archive.i32()
  archive.skip(3 * 8)
  ignore(archive.u32())
  ignore(archive.u32())
  archive.skip(5 * 8)
  for group in groups {
    for _ in 0..<16 {
      group.names.push(archive.str())
    }
  }
  for group in groups {
    group.name = archive.str()
  }
  archive.skip(2 * 8)
  ignore(archive.u32())
  archive.skip(8)
  if version >= 300 { archive.skip(2 * 8) }
  ignore(archive.u32())
  archive.skip(3 * 8)
  archive.skip(3 * 8)
  if version >= 300 {
    for _ in 0..<8 {
      archive.skip(3 * 8)
      ignore(archive.u32())
    }
    archive.skip(3 * 8)
    ignore(archive.u32())
    archive.skip(3 * 8)
    ignore(archive.u32())
  } else {
    archive.skip(4 * 3 * 8)
  }
  archive.skip(10 * 8)
  archive.skip(8)
  let screen : Array[UInt32] = []
  for _ in 0..<10 {
    screen.push(archive.u32().reinterpret_as_uint())
    ignore(archive.u32())
  }
  let prt_pen : Array[JwwPen] = []
  for _ in 0..<10 {
    let pen = jww_pen()
    pen.color = archive.u32().reinterpret_as_uint()
    pen.width = archive.u32()
    pen.radius = archive.f64()
    prt_pen.push(pen)
  }
  let line_types : Map[Int, JwwLineType] = Map([])
  for n in 2..<10 {
    line_types[n] = {
      mask: archive.u32().reinterpret_as_uint(),
      unit: archive.u32(),
      pitch: archive.u32(),
      prt_pitch: archive.u32(),
    }
  }
  for n in 11..<16 {
    let type_ = jww_line_type()
    type_.mask = archive.u32().reinterpret_as_uint()
    ignore(archive.u32())
    type_.pitch = archive.u32()
    ignore(archive.u32())
    type_.prt_pitch = archive.u32()
    line_types[n] = type_
  }
  for n in 16..<20 {
    line_types[n] = {
      mask: archive.u32().reinterpret_as_uint(),
      unit: archive.u32(),
      pitch: archive.u32(),
      prt_pitch: archive.u32(),
    }
  }
  ignore(archive.u32())
  let draw_prt_ten = archive.u32() != 0
  ignore(archive.u32())
  ignore(archive.u32())
  ignore(archive.u32())
  let color_print = archive.u32() != 0
  ignore(archive.u32())
  ignore(archive.u32())
  ignore(archive.u32())
  ignore(archive.u32())
  let n1 = archive.u32()
  let mut dpi = 300
  if version >= 600 && (n1 / 10) % 10 == 2 { dpi = 600 }
  if version >= 223 {
    ignore(archive.u32())
    ignore(archive.u32())
    archive.skip(3 * 4)
    archive.skip(5 * 8)
  }
  if version >= 225 { archive.skip(4 * 8) }
  if version >= 230 {
    ignore(archive.u32())
    ignore(archive.u32())
  }
  let mut has_sxf = false
  let sxf_pens : Array[JwwPen] = []
  let sxf_types : Array[JwwUdLineType] = []
  if version >= 420 {
    has_sxf = true
    archive.skip(257 * 2 * 4)
    for _ in 0..<257 {
      ignore(archive.str())
      let pen = jww_pen()
      pen.color = archive.u32().reinterpret_as_uint()
      pen.width = archive.u32()
      pen.radius = archive.f64()
      sxf_pens.push(pen)
    }
    for n in 0..<33 {
      line_types[n + 30] = {
        mask: archive.u32().reinterpret_as_uint(),
        unit: archive.u32(),
        pitch: archive.u32(),
        prt_pitch: archive.u32(),
      }
    }
    for _ in 0..<33 {
      let type_ = jww_ud_line_type()
      type_.name = archive.str()
      type_.segments = archive.u32()
      for _ in 0..<10 {
        type_.pitch.push(archive.f64())
      }
      sxf_types.push(type_)
    }
  }
  let moji : Array[JwwMojiShu] = []
  for _ in 0..<10 {
    let value = jww_moji_shu()
    value.w = archive.f64()
    value.h = archive.f64()
    value.spacing = archive.f64()
    value.color = archive.u32()
    moji.push(value)
  }
  archive.skip(3 * 8)
  archive.skip(2 * 4)
  archive.skip(2 * 8)
  ignore(archive.u32())
  archive.skip(6 * 8)
  if archive.error != "" {
    raise Failure("jww: " + archive.error)
  }
  {
    version,
    memo,
    paper,
    groups,
    dimension,
    max_width,
    screen,
    prt_pen,
    line_types,
    sxf_pens,
    sxf_types,
    has_sxf,
    draw_prt_ten,
    color_print,
    dpi,
    moji,
  }
}

///|
priv struct JwwData {
  figures : Array[JwwFigure]
  blocks : Map[Int, JwwBlockDef]
}

///|
priv struct JwwDataReader {
  archive : JwwArchive
  header : JwwHeader
  time_size : Int
  mut depth : Int
}

///|
fn JwwDataReader::list(self : JwwDataReader) -> Array[JwwFigure] {
  let count = self.archive.count()
  let output : Array[JwwFigure] = []
  for _ in 0..<count {
    if self.archive.error != "" { break }
    match self.object() {
      Some(value) => output.push(value)
      None => ()
    }
  }
  output
}

///|
fn JwwDataReader::object(self : JwwDataReader) -> JwwFigure? {
  let (class, index, old) = self.archive.object_tag()
  if class == "" { return old }
  let value : JwwFigure? = match class {
    "CDataSen" => Some(Sen(self.sen()))
    "CDataEnko" => Some(Enko(self.enko()))
    "CDataTen" => Some(Ten(self.ten()))
    "CDataMoji" => Some(Moji(self.moji()))
    "CDataSunpou" => Some(Sunpou(self.sunpou()))
    "CDataSolid" => Some(Solid(self.solid()))
    "CDataBlock" => Some(Block(self.block()))
    "CDataList" => Some(BlockDef(self.block_def(index)))
    _ => {
      self.archive.error = "figures of class " + class + " cannot be read"
      None
    }
  }
  match value {
    Some(figure) => self.archive.objects[index] = figure
    None => ()
  }
  value
}

///|
fn JwwDataReader::sen(self : JwwDataReader) -> JwwSen {
  let base = jww_base(self.archive, self.header)
  let a = jww_point(self.archive)
  let b = jww_point(self.archive)
  { base, a, b }
}

///|
fn JwwDataReader::enko(self : JwwDataReader) -> JwwEnko {
  let base = jww_base(self.archive, self.header)
  let c = jww_point(self.archive)
  let r = self.archive.f64()
  let start = self.archive.f64()
  let arc = self.archive.f64()
  let tilt = self.archive.f64()
  let flat = self.archive.f64()
  let full = self.archive.u32() != 0
  { base, c, r, start, arc, tilt, flat, full }
}

///|
fn JwwDataReader::ten(self : JwwDataReader) -> JwwTen {
  let base = jww_base(self.archive, self.header)
  let p = jww_point(self.archive)
  let kari = self.archive.u32() != 0
  let mut code = 0
  let mut rot = 0.0
  let mut scale = 0.0
  let mut has_sub = false
  if base.style == 100 {
    has_sub = true
    code = self.archive.u32()
    rot = self.archive.f64()
    scale = self.archive.f64()
  }
  { base, p, kari, code, rot, scale, has_sub }
}

///|
fn JwwDataReader::moji(self : JwwDataReader) -> JwwMoji {
  let base = jww_base(self.archive, self.header)
  let a = jww_point(self.archive)
  let b = jww_point(self.archive)
  let kind = self.archive.u32()
  let w = self.archive.f64()
  let h = self.archive.f64()
  let spacing = self.archive.f64()
  let angle = self.archive.f64()
  let font = self.archive.str()
  let s = self.archive.str()
  { base, a, b, kind, w, h, spacing, angle, font, s }
}

///|
fn JwwDataReader::sunpou(self : JwwDataReader) -> JwwSunpou {
  let base = jww_base(self.archive, self.header)
  let line = self.sen()
  let text = self.moji()
  let aux : Array[JwwSen?] = []
  let points : Array[JwwTen?] = []
  let mut sxf = false
  let mut has_aux = false
  if self.header.version >= 420 {
    has_aux = true
    sxf = self.archive.u16() != 0
    aux.push(Some(self.sen()))
    aux.push(Some(self.sen()))
    for _ in 0..<4 {
      points.push(Some(self.ten()))
    }
  }
  { base, line, text, sxf, has_aux, aux, points }
}

///|
fn JwwDataReader::solid(self : JwwDataReader) -> JwwSolid {
  let base = jww_base(self.archive, self.header)
  let p1 = jww_point(self.archive)
  let p4 = jww_point(self.archive)
  let p2 = jww_point(self.archive)
  let p3 = jww_point(self.archive)
  let rgb = if base.color == 10 {
    self.archive.u32().reinterpret_as_uint()
  } else {
    0U
  }
  { base, p1, p4, p2, p3, rgb }
}

///|
fn JwwDataReader::block(self : JwwDataReader) -> JwwBlock {
  let base = jww_base(self.archive, self.header)
  let p = jww_point(self.archive)
  let sx = self.archive.f64()
  let sy = self.archive.f64()
  let rot = self.archive.f64()
  let number = self.archive.u32()
  { base, p, sx, sy, rot, number }
}

///|
fn JwwDataReader::block_def(self : JwwDataReader, index : Int) -> JwwBlockDef {
  let base = jww_base(self.archive, self.header)
  let placeholder : JwwBlockDef = {
    base,
    number: 0,
    name: "",
    figures: [],
  }
  self.archive.objects[index] = BlockDef(placeholder)
  let number = self.archive.u32()
  ignore(self.archive.u32())
  self.archive.skip(self.time_size)
  let mut name = self.archive.str()
  if name.contains("@@SfigorgFlag@@") {
    let at = name.find("@@SfigorgFlag@@")
    if at is Some(value) {
      name = name[:value].to_owned()
    }
  }
  self.depth += 1
  if self.depth > 32 {
    self.archive.error = "block definitions nested deeper than 32 levels"
    return placeholder
  }
  let figures = self.list()
  self.depth -= 1
  { base, number, name, figures }
}

///|
fn read_data(
  data : Bytes,
  start : Int,
  header : JwwHeader,
  time_size : Int,
) -> JwwData raise {
  let archive = JwwArchive::new(data)
  archive.offset = start
  let reader : JwwDataReader = {
    archive,
    header,
    time_size,
    depth: 0,
  }
  let figures = reader.list()
  let blocks : Map[Int, JwwBlockDef] = Map([])
  for figure in reader.list() {
    match figure {
      BlockDef(value) => blocks[value.number] = value
      _ => ()
    }
  }
  if archive.error != "" {
    raise Failure("jww: " + archive.error)
  }
  { figures, blocks }
}
