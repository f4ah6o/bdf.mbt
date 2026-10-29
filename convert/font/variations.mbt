///|
/// One variable-font axis from an OpenType fvar table.
pub(all) struct VariationAxis {
  tag : String
  name : String
  minimum : Double
  default_value : Double
  maximum : Double
  hidden : Bool
}

///|
/// One named instance and its axis coordinates.
pub(all) struct VariationInstance {
  name : String
  postscript : String
  coordinates : Array[Double]
}

///|
pub(all) struct Variations {
  axes : Array[VariationAxis]
  instances : Array[VariationInstance]
}

///|
fn variation_fixed(data : BytesView, offset : Int32) -> Double {
  be32(data, offset).reinterpret_as_int().to_double() / 65536.0
}

///|
/// Read variable-font axes and instances using the specimen's name priorities.
pub fn FileFace::variations(self : FileFace) -> Variations {
  parse_variations(
    self.font.table("fvar").unwrap_or(b""),
    self.specimen_names(),
  )
}

///|
/// Parse a raw fvar table using decoded name records.
pub fn parse_variations(data : Bytes, names : SpecimenNames) -> Variations {
  let axes : Array[VariationAxis] = []
  let instances : Array[VariationInstance] = []
  if data.length() < 16 || be16(data[:], 0) != 1 {
    return { axes, instances, }
  }
  let offset = be16(data[:], 4)
  let count = be16(data[:], 8)
  let size = be16(data[:], 10)
  let instance_count = be16(data[:], 12)
  let instance_size = be16(data[:], 14)
  if size < 20 ||
    offset.to_int64() + count.to_int64() * size.to_int64() >
    data.length().to_int64() {
    return { axes, instances, }
  }
  for i in 0..<count {
    let pos = offset + i * size
    axes.push({
      tag: @utf8.decode_lossy(data[pos:pos + 4]),
      name: names.best(be16(data[:], pos + 18)),
      minimum: variation_fixed(data[:], pos + 4),
      default_value: variation_fixed(data[:], pos + 8),
      maximum: variation_fixed(data[:], pos + 12),
      hidden: (be16(data[:], pos + 16) & 1) != 0,
    })
  }
  let start = offset + count * size
  if instance_size < 4 + 4 * count {
    return { axes, instances, }
  }
  for i in 0..<instance_count {
    let pos = start.to_int64() + i.to_int64() * instance_size.to_int64()
    if pos + instance_size.to_int64() > data.length().to_int64() {
      break
    }
    let pos = pos.to_int()
    let coords = [
      for k in 0..<count => variation_fixed(data[:], pos + 4 + 4 * k)
    ]
    let ps_id = if instance_size >= 6 + 4 * count {
      be16(data[:], pos + 4 + 4 * count)
    } else {
      0xffff
    }
    instances.push({
      name: names.best(be16(data[:], pos)),
      postscript: if ps_id == 0xffff {
        ""
      } else {
        names.best(ps_id)
      },
      coordinates: coords,
    })
  }
  { axes, instances, }
}
