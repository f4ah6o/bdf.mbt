///|
struct AvifItem {
  kind : Bytes
  content_type : Bytes
}

///|
struct AvifMetadata {
  mut width : Int64
  mut height : Int64
  exif : Array[Bytes]
  xmp : Array[Bytes]
}

///|
fn iso_reader(data : BytesView) -> IsoReader {
  { data, pos: 0, bad: false, }
}

///|
fn iso_has(boxes : Array[IsoBox], kind : Bytes) -> Bool {
  for box in boxes {
    if box.kind == kind {
      return true
    }
  }
  false
}

///|
fn is_avif(data : Bytes) -> Bool {
  if data.length() < 16 || data[4:8] != b"ftyp"[:] {
    return false
  }
  let limit = if data.length() < 1024 { data.length() } else { 1024 }
  let declared = metadata_be32(data, 0)
  let size = if declared < limit.to_int64() { declared.to_int() } else { limit }
  for i = 8; i <= size - 4; i = i + 4 {
    if i != 12 && (data[i:i + 4] == b"avif"[:] || data[i:i + 4] == b"avis"[:]) {
      return true
    }
  }
  false
}

///|
fn avif_items(meta : Array[IsoBox]) -> Map[UInt64, AvifItem] {
  let items : Map[UInt64, AvifItem] = Map([])
  let iinf = iso_find(meta, b"iinf")
  if iinf.length() < 4 {
    return items
  }
  let reader = iso_reader(iinf[4:])
  ignore(reader.uint(if iinf[0] == 0 { 2 } else { 4 }))
  for box in iso_boxes(reader.data[reader.pos:]) {
    if box.kind != b"infe" || box.data.length() < 4 || box.data[0] < 2 {
      continue
    }
    let entry = iso_reader(box.data[4:])
    let id = entry.uint(if box.data[0] == 2 { 2 } else { 4 })
    ignore(entry.uint(2))
    let kind = entry.take(4).to_bytes()
    ignore(entry.cstring())
    let content_type = if kind == b"mime" { entry.cstring() } else { b"" }
    if !entry.bad || kind != b"mime" {
      items[id] = { kind, content_type, }
    }
  }
  items
}

///|
fn avif_properties(
  meta : Array[IsoBox],
  primary : UInt64,
  picture : AvifMetadata,
) -> Unit {
  let iprp = iso_boxes(iso_find(meta, b"iprp"))
  let properties = iso_boxes(iso_find(iprp, b"ipco"))
  let mut rotated = false
  for box in iprp {
    if box.kind != b"ipma" || box.data.length() < 4 {
      continue
    }
    let version = box.data[0].to_int()
    let flags = box.data[3].to_int()
    let reader = iso_reader(box.data[4:])
    let mut count = reader.uint(4)
    while count > 0 && !reader.bad {
      let id = reader.uint(if version < 1 { 2 } else { 4 })
      let mut associations = reader.uint(1)
      while associations > 0 && !reader.bad {
        let index = if (flags & 1) != 0 {
          reader.uint(2) & 0x7fffUL
        } else {
          reader.uint(1) & 0x7fUL
        }
        if id == primary &&
          index > 0 &&
          index <= properties.length().to_uint64() {
          let property = properties[(index - 1).to_int()]
          if property.kind == b"ispe" && property.data.length() >= 12 {
            picture.width = iso_u32(property.data, 4).to_int64()
            picture.height = iso_u32(property.data, 8).to_int64()
          } else if property.kind == b"irot" {
            rotated = property.data.length() >= 1 &&
              (property.data[0].to_int() & 1) != 0
          }
        }
        associations -= 1
      }
      count -= 1
    }
  }
  if rotated {
    let width = picture.width
    picture.width = picture.height
    picture.height = width
  }
}

///|
fn avif_extents(
  meta : Array[IsoBox],
  file : Bytes,
  items : Map[UInt64, AvifItem],
  picture : AvifMetadata,
) -> Unit {
  let iloc = iso_find(meta, b"iloc")
  if iloc.length() < 6 {
    return
  }
  let idat = iso_find(meta, b"idat")
  let version = iloc[0].to_int()
  let reader = iso_reader(iloc[4:])
  let sizes = reader.uint(1).to_int()
  let offset_size = sizes >> 4
  let length_size = sizes & 15
  let sizes2 = reader.uint(1).to_int()
  let base_size = sizes2 >> 4
  let index_size = if version == 1 || version == 2 { sizes2 & 15 } else { 0 }
  let mut count = reader.uint(if version < 2 { 2 } else { 4 })
  let mut room = file.length().to_uint64()
  while count > 0 && !reader.bad {
    let id = reader.uint(if version < 2 { 2 } else { 4 })
    let method = if version == 1 || version == 2 {
      reader.uint(2) & 15UL
    } else {
      0UL
    }
    ignore(reader.uint(2))
    let base = reader.variable(base_size)
    let item = items.get(id)
    let mut exif = match item {
      Some(value) => value.kind == b"Exif"
      None => false
    }
    let mut xmp = match item {
      Some(value) =>
        value.kind == b"mime" && value.content_type == b"application/rdf+xml"
      None => false
    }
    let src = if method == 1 { idat } else { file[:] }
    let output = @buffer.Buffer()
    let mut extents = reader.uint(2)
    while extents > 0 && !reader.bad {
      if index_size > 0 {
        ignore(reader.variable(index_size))
      }
      let offset = base + reader.variable(offset_size)
      let mut length = reader.variable(length_size)
      if exif || xmp {
        if length == 0 && offset <= src.length().to_uint64() {
          length = src.length().to_uint64() - offset
        }
        if method > 1 ||
          offset > src.length().to_uint64() ||
          length > src.length().to_uint64() - offset ||
          length > room {
          exif = false
          xmp = false
        } else {
          room -= length
          output.write_bytes(src[offset.to_int():(offset + length).to_int()])
        }
      }
      extents -= 1
    }
    let bytes = output.to_bytes()
    if exif && bytes.length() >= 4 {
      let start = metadata_be32(bytes, 0) + 4
      if start < bytes.length().to_int64() {
        picture.exif.push(bytes[start.to_int():].to_bytes())
      }
    } else if xmp && bytes.length() > 0 {
      picture.xmp.push(bytes)
    }
    count -= 1
  }
}

///|
fn read_avif(data : Bytes) -> Picture raise {
  let top = iso_boxes(data)
  let picture : AvifMetadata = { width: 0, height: 0, exif: [], xmp: [], }
  let ftyp = iso_find(top, b"ftyp")
  let mut animated = false
  if iso_has(top, b"moov") {
    for i = 0; i <= ftyp.length() - 4; i = i + 4 {
      if i != 4 && ftyp[i:i + 4] == b"avis"[:] {
        animated = true
      }
    }
  }
  let meta_data = iso_find(top, b"meta")
  if meta_data.length() >= 4 {
    let meta = iso_boxes(meta_data[4:])
    let pitm = iso_find(meta, b"pitm")
    let primary = if pitm.length() >= 4 {
      let reader = iso_reader(pitm[4:])
      reader.uint(if pitm[0] == 0 { 2 } else { 4 })
    } else {
      0UL
    }
    avif_properties(meta, primary, picture)
    avif_extents(meta, data, avif_items(meta), picture)
  }
  if picture.width == 0 {
    let tracks = iso_boxes(iso_find(iso_boxes(iso_find(top, b"moov")), b"trak"))
    let tkhd = iso_find(tracks, b"tkhd")
    if tkhd.length() >= 84 {
      let at = if tkhd[0] == 1 { 88 } else { 76 }
      if tkhd.length() >= at + 8 {
        picture.width = (iso_u32(tkhd, at) >> 16).to_int64()
        picture.height = (iso_u32(tkhd, at + 4) >> 16).to_int64()
      }
    }
  }
  if picture.width == 0 || picture.height == 0 {
    raise ImageFailure("image: AVIF: the AVIF image has no size")
  }
  let dc : Map[String, Array[String]] = Map([])
  for packet in picture.xmp {
    metadata_merge(dc, metadata_xmp(packet))
  }
  for block in picture.exif {
    if exif_fields(block) is Some(fields) {
      metadata_merge(dc, exif_metadata(fields))
    }
  }
  {
    format: "avif",
    width: picture.width,
    height: picture.height,
    dc,
    animated,
    warnings: [],
  }
}
