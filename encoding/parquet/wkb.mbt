///|
/// Geometries (the GEOMETRY and GEOGRAPHY logical types, and the columns that
/// GeoParquet metadata marks) are stored as well-known binary (WKB). They are
/// shown as well-known text (WKT). ISO WKB and the extended WKB of PostGIS
/// (with the Z, M and SRID flags) are read, as are empty geometries.
priv struct ParquetWkbReader {
  data : Bytes
  mut pos : Int
  output : StringBuilder
  mut length : Int
  mut bad : Bool
}

///|
let parquet_wkt_types : Array[String] = [
  "",
  "POINT",
  "LINESTRING",
  "POLYGON",
  "MULTIPOINT",
  "MULTILINESTRING",
  "MULTIPOLYGON",
  "GEOMETRYCOLLECTION",
]

///|
/// The most characters of WKT written for a geometry.
let parquet_max_wkt : Int = 32768

///|
/// The most nesting of geometries read.
let parquet_max_wkb_depth : Int = 32

///|
/// Convert a WKB geometry into WKT, or `None` when the bytes are not WKB.
fn parquet_wkb_text(data : Bytes) -> String? {
  let reader : ParquetWkbReader = {
    data,
    pos: 0,
    output: StringBuilder(),
    length: 0,
    bad: false,
  }
  reader.geometry(0, true)
  let text = reader.output.to_string()
  if reader.bad || (reader.pos != data.length() && text.length() < parquet_max_wkt) {
    None
  } else {
    Some(text)
  }
}

///|
fn ParquetWkbReader::raw(self : ParquetWkbReader, text : String) -> Unit {
  self.output.write_string(text)
  self.length += text.length()
}

///|
fn ParquetWkbReader::full(self : ParquetWkbReader) -> Bool {
  self.length >= parquet_max_wkt
}

///|
/// Read an unsigned 32-bit integer in the geometry's byte order.
fn ParquetWkbReader::u32(self : ParquetWkbReader, little : Bool) -> UInt {
  if self.pos + 4 > self.data.length() {
    self.bad = true
    return 0U
  }
  let data = self.data
  let mut value = 0U
  if little {
    for index in 0..<4 {
      value = value | (data[self.pos + index].to_uint() << (8 * index))
    }
  } else {
    for index in 0..<4 {
      value = (value << 8) | data[self.pos + index].to_uint()
    }
  }
  self.pos += 4
  value
}

///|
/// Read a double in the geometry's byte order.
fn ParquetWkbReader::f64(self : ParquetWkbReader, little : Bool) -> Double {
  if self.pos + 8 > self.data.length() {
    self.bad = true
    return 0.0
  }
  let data = self.data
  let mut bits = 0UL
  if little {
    for index in 0..<8 {
      bits = bits | (data[self.pos + index].to_uint64() << (8 * index))
    }
  } else {
    for index in 0..<8 {
      bits = (bits << 8) | data[self.pos + index].to_uint64()
    }
  }
  self.pos += 8
  bits.reinterpret_as_double()
}

///|
/// Read a count of items that take at least `size` bytes each.
fn ParquetWkbReader::count(
  self : ParquetWkbReader,
  little : Bool,
  size : Int,
) -> Int {
  if self.data.length() - self.pos < 4 {
    self.bad = true
    return 0
  }
  let count = self.u32(little).to_int64()
  if count < 0L || count * size.to_int64() > (self.data.length() - self.pos).to_int64() {
    self.bad = true
    return 0
  }
  count.to_int()
}

///|
/// Read the coordinates of a point.
fn ParquetWkbReader::coords(
  self : ParquetWkbReader,
  little : Bool,
  dims : Int,
) -> Array[Double] {
  let output : Array[Double] = []
  if self.data.length() - self.pos < 8 * dims {
    self.bad = true
    return output
  }
  for _ in 0..<dims {
    output.push(self.f64(little))
  }
  output
}

///|
fn ParquetWkbReader::write_coords(self : ParquetWkbReader, coords : Array[Double]) -> Unit {
  for index, value in coords {
    if index > 0 {
      self.raw(" ")
    }
    self.raw(value.to_string())
  }
}

///|
/// Write a point, which is empty when its coordinates are NaN.
fn ParquetWkbReader::point(
  self : ParquetWkbReader,
  little : Bool,
  dims : Int,
) -> Unit {
  let coords = self.coords(little, dims)
  if self.bad {
    return
  }
  if coords.length() >= 2 && coords[0].is_nan() && coords[1].is_nan() {
    self.raw("EMPTY")
    return
  }
  self.raw("(")
  self.write_coords(coords)
  self.raw(")")
}

///|
fn ParquetWkbReader::point_list(
  self : ParquetWkbReader,
  little : Bool,
  dims : Int,
  count : Int,
) -> Unit {
  self.raw("(")
  for index in 0..<count {
    if self.full() {
      self.pos += (count - index) * 8 * dims
      break
    }
    if index > 0 {
      self.raw(", ")
    }
    self.write_coords(self.coords(little, dims))
  }
  self.raw(")")
}

///|
fn ParquetWkbReader::points(
  self : ParquetWkbReader,
  little : Bool,
  dims : Int,
) -> Unit {
  let count = self.count(little, 8 * dims)
  if self.bad {
    return
  }
  if count == 0 {
    self.raw("EMPTY")
    return
  }
  self.point_list(little, dims, count)
}

///|
fn ParquetWkbReader::rings(
  self : ParquetWkbReader,
  little : Bool,
  dims : Int,
) -> Unit {
  let count = self.count(little, 4)
  if self.bad {
    return
  }
  if count == 0 {
    self.raw("EMPTY")
    return
  }
  self.raw("(")
  for index in 0..<count {
    if index > 0 {
      self.raw(", ")
    }
    let points = self.count(little, 8 * dims)
    if self.bad {
      return
    }
    self.point_list(little, dims, points)
  }
  self.raw(")")
}

///|
/// Read a geometry; `tagged` writes the type (and dimensions) before it, which
/// the parts of a collection carry and those of the other multi geometries do
/// not.
fn ParquetWkbReader::geometry(
  self : ParquetWkbReader,
  depth : Int,
  tagged : Bool,
) -> Unit {
  if depth > parquet_max_wkb_depth || self.data.length() - self.pos < 5 {
    self.bad = true
    return
  }
  let little = match self.data[self.pos].to_int() {
    0 => false
    1 => true
    _ => {
      self.bad = true
      return
    }
  }
  self.pos += 1
  let raw = self.u32(little)
  let mut z = (raw & 0x80000000U) != 0U
  let mut m = (raw & 0x40000000U) != 0U
  if (raw & 0x20000000U) != 0U {
    self.pos += 4
  }
  let kind_bits = raw & 0x0fffffffU
  let mut kind = kind_bits.reinterpret_as_int()
  match kind / 1000 {
    1 => z = true
    2 => m = true
    3 => {
      z = true
      m = true
    }
    _ => ()
  }
  kind = kind % 1000
  if kind <= 0 || kind >= parquet_wkt_types.length() ||
    self.pos > self.data.length() {
    self.bad = true
    return
  }
  let dims = 2 + (if z { 1 } else { 0 }) + (if m { 1 } else { 0 })
  if tagged {
    self.raw(parquet_wkt_types[kind])
    if z && m {
      self.raw(" ZM")
    } else if z {
      self.raw(" Z")
    } else if m {
      self.raw(" M")
    }
    self.raw(" ")
  }
  match kind {
    1 => self.point(little, dims)
    2 => self.points(little, dims)
    3 => self.rings(little, dims)
    _ => {
      let count = self.count(little, 5)
      if count == 0 {
        self.raw("EMPTY")
        return
      }
      self.raw("(")
      for index in 0..<count {
        if self.bad || self.full() {
          return
        }
        if index > 0 {
          self.raw(", ")
        }
        self.geometry(depth + 1, kind == 7)
      }
      self.raw(")")
    }
  }
}
