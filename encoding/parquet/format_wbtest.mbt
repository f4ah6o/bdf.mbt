///|
fn format_meta(
  physical : Int,
  converted : Int,
  type_length : Int,
  logical : ParquetLogicalType,
) -> ParquetMetaColumn {
  {
    name: "c",
    physical,
    converted,
    optional: true,
    values: 0L,
    codec: 0,
    encodings: [],
    data_offset: 0L,
    dictionary_offset: 0L,
    has_dictionary: false,
    path: ["c"],
    type_length,
    scale: logical.scale,
    precision: logical.precision,
    max_rep: 0,
    max_def: 1,
    logical,
    geo: false,
    geo_kind: 0,
  }
}

///|
test "parquet UUID and interval formatting" {
  let uuid = Bytes::from_array([
    0xb5, 0xf3, 0xc2, 0xde, 0x0a, 0x41, 0x4d, 0x4b, 0x9f, 0x3e, 0x1c, 0x2d,
    0x3e, 0x4f, 0x5a, 0x6b,
  ])
  assert_eq(
    parquet_uuid_text(uuid),
    "b5f3c2de-0a41-4d4b-9f3e-1c2d3e4f5a6b",
  )
  assert_eq(
    parquet_interval_text(Bytes::from_array([14, 0, 0, 0, 3, 0, 0, 0, 68, 103, 224, 0])),
    "P1Y2M3DT4H5M6.5S",
  )
  assert_eq(
    parquet_interval_text(Bytes::from_array([0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0])),
    "P3D",
  )
  assert_eq(
    parquet_interval_text(Bytes::from_array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])),
    "PT0S",
  )
}

///|
test "parquet time and timestamp formatting" {
  let time = format_meta(2, -1, 0, { ..parquet_logical_none(), kind: 7, unit: 2 })
  assert_eq(
    parquet_scalar_text(FormatTime(2), ScalarInt(45296789012L)),
    "12:34:56.789012",
  )
  assert_eq(
    parquet_scalar_text(FormatTime(2), ScalarInt(45296789012L), digits=6),
    "12:34:56.789012",
  )
  assert_eq(
    parquet_scalar_text(FormatTime(3), ScalarInt(45296789012345L)),
    "12:34:56.789012345",
  )
  assert_eq(
    parquet_scalar_text(FormatTime(1), ScalarInt(45296789L)),
    "12:34:56.789",
  )
  assert_eq(
    parquet_scalar_text(
      FormatTimestamp(2),
      ScalarInt(1790505000123456L),
    ),
    "2026-09-27 10:30:00.123456",
  )
  assert_eq(
    parquet_scalar_text(
      FormatTimestamp(3),
      ScalarInt(1790505000123456789L),
    ),
    "2026-09-27 10:30:00.123456789",
  )
  // INT96: the Julian day and nanoseconds of the day
  assert_eq(
    parquet_scalar_text(
      FormatInt96,
      ScalarInt96(1790505000123456789L % 86400000000000L, 2461311L),
    ),
    "2026-09-27 10:30:00.123456789",
  )
  assert_eq(parquet_format(parquet_format_source(time)), FormatTime(2))
}

///|
test "parquet decimals, binary and floats" {
  let dec = format_meta(7, -1, 13, { ..parquet_logical_none(), kind: 5, scale: 4, precision: 30 })
  assert_eq(
    parquet_scalar_text(
      FormatDecimal(4),
      ScalarBytes(Bytes::from_array([
        0xfe, 0x71, 0x16, 0xf0, 0x09, 0x3c, 0x8c, 0x1f, 0x11, 0xb1, 0xc0, 0xf5,
        0x2e,
      ])),
    ),
    "-12345678901234567890123456.7890",
  )
  assert_eq(
    parquet_scalar_text(FormatDecimal(2), ScalarInt(-123L)),
    "-1.23",
  )
  assert_eq(
    parquet_scalar_text(FormatDecimal(2), ScalarInt(0L)),
    "0.00",
  )
  assert_eq(parquet_format(parquet_format_source(dec)), FormatDecimal(4))
  assert_eq(
    parquet_binary_text(Bytes::from_array([b'A', b'B', b'C', b'D'])),
    "ABCD",
  )
  assert_eq(
    parquet_binary_text(Bytes::from_array([0x00, 0x01])),
    "0x0001",
  )
  assert_eq(parquet_float_text(0.1, 32), "0.1")
  assert_eq(parquet_float_text(1.0e-7, 64), "1e-07")
  assert_eq(parquet_float_text(2.5e21, 64), "2.5e+21")
  assert_eq(
    parquet_half_text(Bytes::from_array([0x66, 0x2e])),
    "0.1",
  )
  assert_eq(
    parquet_half_text(Bytes::from_array([0xff, 0xfb])),
    "-65500",
  )
}

///|
test "parquet logical types choose the formatted value" {
  let uuid = format_meta(
    7,
    -1,
    16,
    { ..parquet_logical_none(), kind: 14 },
  )
  assert_eq(parquet_format(parquet_format_source(uuid)), FormatUUID)
  assert_eq(
    parquet_scalar_value(
      FormatUUID,
      ScalarBytes(Bytes::from_array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])),
    ),
    StringValue("00000000-0000-0000-0000-000000000000"),
  )
  let millis = format_meta(
    2,
    -1,
    0,
    { ..parquet_logical_none(), kind: 8, unit: 1, utc: true },
  )
  assert_eq(parquet_format(parquet_format_source(millis)), FormatTimestamp(1))
  assert_eq(
    parquet_scalar_value(FormatTimestamp(1), ScalarInt(1704067200123L)),
    DateTimeValue(1704067200123L),
  )
  assert_eq(
    parquet_scalar_value(FormatTimestamp(2), ScalarInt(1704067200123456L)),
    StringValue("2024-01-01 00:00:00.123456"),
  )
  let date = format_meta(1, -1, 0, { ..parquet_logical_none(), kind: 6 })
  assert_eq(parquet_format(parquet_format_source(date)), FormatDate)
  assert_eq(
    parquet_scalar_value(FormatDate, ScalarInt(19723L)),
    DateValue(19723L),
  )
  let unknown = format_meta(1, -1, 0, { ..parquet_logical_none(), kind: 11 })
  assert_eq(parquet_format(parquet_format_source(unknown)), FormatNull)
  assert_eq(parquet_scalar_value(FormatNull, ScalarInt(0L)), Null)
}

///|
test "parquet geometry format decodes WKT and keeps other binary" {
  let geo = format_meta(6, -1, 0, { ..parquet_logical_none(), kind: 17 })
  assert_eq(parquet_format(parquet_format_source(geo)), FormatGeometry)
  let point = Bytes::from_array([
    1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xf0, 0x3f, 0, 0, 0, 0, 0, 0, 0, 0x40,
  ])
  assert_eq(
    parquet_scalar_value(FormatGeometry, ScalarBytes(point)),
    StringValue("POINT (1 2)"),
  )
  let plain = format_meta(6, -1, 0, parquet_logical_none())
  assert_eq(parquet_format(parquet_format_source(plain)), FormatBinary)
  assert_eq(
    parquet_scalar_value(FormatBinary, ScalarBytes(Bytes::from_array([0xff]))),
    StringValue("0xff"),
  )
}

///|
test "WKT GeoParquet columns stay text" {
  let source : ParquetFormatSource = {
    physical: 6,
    converted: -1,
    type_length: 0,
    scale: 0,
    logical: parquet_logical_none(),
    geo: true,
    geo_kind: 2,
  }
  let format = parquet_format(source)
  assert_eq(format, FormatString)
  assert_eq(
    parquet_scalar_json(format, ScalarBytes(b"POINT (1 2)")),
    "\"POINT (1 2)\"",
  )
}
