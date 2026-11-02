///|
fn wkb_bytes(values : Array[Int]) -> Bytes {
  Bytes::from_array(values.map(fn(value) { value.to_byte() }))
}

///|
fn wkb_double(values : Array[Double]) -> Array[Int] {
  let output : Array[Int] = []
  for value in values {
    let bits = value.reinterpret_as_uint64()
    for index in 0..<8 {
      output.push(((bits >> (index * 8)) & 0xffUL).to_int())
    }
  }
  output
}

///|
fn wkb_u32(value : Int) -> Array[Int] {
  [
    value & 0xff,
    (value >> 8) & 0xff,
    (value >> 16) & 0xff,
    (value >> 24) & 0xff,
  ]
}

///|
/// A little-endian WKB of a point.
fn wkb_point(values : Array[Double]) -> Bytes {
  wkb_bytes([1] + wkb_u32(1) + wkb_double(values))
}

///|
test "parquet WKB point to WKT" {
  let data = wkb_point([139.767, 35.681])
  assert_eq(parquet_wkb_text(data), Some("POINT (139.767 35.681)"))
}

///|
test "parquet WKB line string and polygon to WKT" {
  let line = wkb_bytes([1] + wkb_u32(2) + wkb_u32(3) + wkb_double([0.0, 0.0, 1.5, 2.0, 3.0, 0.0]))
  assert_eq(parquet_wkb_text(line), Some("LINESTRING (0 0, 1.5 2, 3 0)"))
  let polygon = wkb_bytes(
    [1] +
    wkb_u32(3) +
    wkb_u32(1) +
    wkb_u32(4) +
    wkb_double([0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 0.0]),
  )
  assert_eq(
    parquet_wkb_text(polygon),
    Some("POLYGON ((0 0, 1 0, 1 1, 0 0))"),
  )
}

///|
test "parquet WKB multi and collection to WKT" {
  let multi = wkb_bytes(
    [1] +
    wkb_u32(4) +
    wkb_u32(2) +
    [1] +
    wkb_u32(1) +
    wkb_double([1.0, 2.0]) +
    [1] +
    wkb_u32(1) +
    wkb_double([3.0, 4.0]),
  )
  assert_eq(parquet_wkb_text(multi), Some("MULTIPOINT ((1 2), (3 4))"))
  let collection = wkb_bytes(
    [1] +
    wkb_u32(7) +
    wkb_u32(2) +
    [1] +
    wkb_u32(1) +
    wkb_double([5.0, 6.0]) +
    [1] +
    wkb_u32(2) +
    wkb_u32(2) +
    wkb_double([7.0, 8.0, 9.0, 10.0]),
  )
  assert_eq(
    parquet_wkb_text(collection),
    Some("GEOMETRYCOLLECTION (POINT (5 6), LINESTRING (7 8, 9 10))"),
  )
}

///|
test "parquet WKB Z, empty and malformed" {
  let point_z = wkb_bytes([1] + wkb_u32(1001) + wkb_double([1.0, 2.0, 3.0]))
  assert_eq(parquet_wkb_text(point_z), Some("POINT Z (1 2 3)"))
  let empty = wkb_bytes(
    [1] +
    wkb_u32(1) +
    wkb_double([0.0 / 0.0, 0.0 / 0.0]),
  )
  assert_eq(parquet_wkb_text(empty), Some("POINT EMPTY"))
  assert_eq(parquet_wkb_text(wkb_bytes([1, 1, 0])), None)
  assert_eq(parquet_wkb_text(b""), None)
}

///|
test "GeoParquet metadata marks WKB columns" {
  let values : Map[String, String] = Map([])
  values["geo"] =
    "{\"version\": \"1.0.0\", \"primary_column\": \"geometry\", \"columns\": {\"geometry\": {\"encoding\": \"WKB\", \"geometry_types\": []}}}"
  let columns = parquet_geo_columns(values)
  assert_true(columns.get("geometry").unwrap_or(false))
  let other : Map[String, String] = Map([])
  other["geo"] = "{\"columns\": {\"shape\": {\"encoding\": \"WKT\"}}}"
  assert_false(parquet_geo_columns(other).get("shape").unwrap_or(false))
}

///|
test "parquet WKB reads the GeoParquet fixture point" {
  let data = wkb_bytes([
    1, 1, 0, 0, 0, 6, 0x81, 0x95, 0x43, 0x8b, 0x78, 0x61, 0x40, 0xba, 0x49,
    0x0c, 0x02, 0x2b, 0xd7, 0x41, 0x40,
  ])
  assert_eq(parquet_wkb_text(data), Some("POINT (139.767 35.681)"))
}

///|
test "parquet WKB big-endian, SRID and ZM variants" {
  let big = wkb_bytes([
    0, 0, 0, 0, 1, 0x3f, 0xf0, 0, 0, 0, 0, 0, 0, 0x40, 0, 0, 0, 0, 0, 0, 0,
  ])
  assert_eq(parquet_wkb_text(big), Some("POINT (1 2)"))
  let with_srid = wkb_bytes(
    [1] +
    wkb_u32(536870913) +
    wkb_u32(4326) +
    wkb_double([1.0, 2.0]),
  )
  assert_eq(parquet_wkb_text(with_srid), Some("POINT (1 2)"))
  let point_zm = wkb_bytes([1] + wkb_u32(3001) + wkb_double([1.0, 2.0, 3.0, 4.0]))
  assert_eq(parquet_wkb_text(point_zm), Some("POINT ZM (1 2 3 4)"))
  assert_eq(
    parquet_wkb_text(wkb_bytes([1] + wkb_u32(1) + wkb_double([1.0, 2.0]) + [9])),
    None,
  )
}
