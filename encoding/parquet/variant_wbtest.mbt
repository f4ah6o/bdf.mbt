///|
fn variant_test_bytes(values : Array[Int]) -> Bytes {
  Bytes::from_array(values.map(fn(value) { value.to_byte() }))
}

///|
fn variant_test_meta_text() -> Bytes {
  // version 1, 1-byte offsets, a dictionary of "a", "b" and "c"
  variant_test_bytes([0x01, 3, 0, 1, 2, 3, 97, 98, 99])
}

///|
fn variant_test_node(
  name : String,
  index : Int,
  physical : Int,
  converted : Int,
  repetition : Int,
  logical_kind : Int,
  children : Array[ParquetSchemaNode],
) -> ParquetSchemaNode {
  {
    name,
    physical,
    converted,
    repetition,
    num_children: children.length(),
    type_length: 0,
    scale: 0,
    precision: 0,
    logical: if logical_kind == 0 {
      parquet_logical_none()
    } else {
      { ..parquet_logical_none(), kind: logical_kind }
    },
    geo: false,
    def_level: 0,
    rep_level: 0,
    index,
    children,
  }
}

///|
fn variant_test_leaf(
  name : String,
  index : Int,
  physical : Int,
  converted : Int,
  logical_kind : Int,
) -> ParquetSchemaNode {
  variant_test_node(name, index, physical, converted, 1, logical_kind, [])
}

///|
test "parquet Variant metadata dictionary" {
  let meta = parquet_variant_meta_parse(variant_test_meta_text())
  assert_true(meta is Some(_))
  let meta = meta.unwrap()
  assert_eq(parquet_variant_meta_name(meta, 0), Some("a"))
  assert_eq(parquet_variant_meta_name(meta, 1), Some("b"))
  assert_eq(parquet_variant_meta_name(meta, 2), Some("c"))
  assert_eq(parquet_variant_meta_name(meta, 3), None)
  assert_true(parquet_variant_meta_parse(variant_test_bytes([0x02])) is None)
  assert_true(parquet_variant_meta_parse(b"") is None)
}

///|
test "parquet Variant raw primitives, arrays and objects" {
  let meta = parquet_variant_meta_parse(variant_test_meta_text()).unwrap()
  assert_eq(parquet_variant_value_json(meta, variant_test_bytes([0])), "null")
  assert_eq(parquet_variant_value_json(meta, variant_test_bytes([4])), "true")
  assert_eq(parquet_variant_value_json(meta, variant_test_bytes([8])), "false")
  assert_eq(
    parquet_variant_value_json(meta, variant_test_bytes([12, 42])),
    "42",
  )
  // a short string ("hi" is 2 bytes: basic type 1 and a length of 2)
  assert_eq(
    parquet_variant_value_json(meta, variant_test_bytes([9, 104, 105])),
    "\"hi\"",
  )
  // [1, 2] as int8 values
  assert_eq(
    parquet_variant_value_json(
      meta,
      variant_test_bytes([3, 2, 0, 2, 4, 12, 1, 12, 2]),
    ),
    "[1, 2]",
  )
  // {"a": 1}
  assert_eq(
    parquet_variant_value_json(
      meta,
      variant_test_bytes([2, 1, 0, 0, 2, 12, 1]),
    ),
    "{\"a\": 1}",
  )
  // a date (primitive 11): days 19724 since the epoch
  assert_eq(
    parquet_variant_value_json(
      meta,
      variant_test_bytes([44, 19724 & 0xff, (19724 >> 8) & 0xff, (19724 >> 16) & 0xff, (19724 >> 24) & 0xff]),
    ),
    "\"2024-01-02\"",
  )
  // a float (primitive 14): 1.5
  assert_eq(
    parquet_variant_value_json(
      meta,
      variant_test_bytes([56, 0, 0, 0xc0, 0x3f]),
    ),
    "1.5",
  )
  // {"b": [1, 2]}
  let array = variant_test_bytes([3, 2, 0, 2, 4, 12, 1, 12, 2])
  assert_eq(
    parquet_variant_value_json(
      meta,
      variant_test_bytes([2, 1, 1, 0, array.length()]) + array,
    ),
    "{\"b\": [1, 2]}",
  )
}

///|
test "parquet Variant column reads an unshredded value" {
  let meta = variant_test_meta_text()
  let metadata = variant_test_leaf("metadata", 0, 6, -1, 0)
  let value = variant_test_leaf("value", 1, 6, -1, 0)
  let node = variant_test_node("obj", 0, 6, -1, 1, 16, [metadata, value])
  let fields : Array[Ref[ParquetNodeValue]] = [
    Ref(NodeScalar(ScalarBytes(meta))),
    Ref(NodeScalar(ScalarBytes(variant_test_bytes([12, 42])))),
  ]
  let warnings : Array[String] = []
  assert_eq(
    parquet_variant_group_text(node, Ref(NodeGroup(fields)), warnings, "obj"),
    "42",
  )
  assert_true(warnings.is_empty())
}

///|
test "parquet Variant column warns on unsupported metadata" {
  let metadata = variant_test_leaf("metadata", 0, 6, -1, 0)
  let value = variant_test_leaf("value", 1, 6, -1, 0)
  let node = variant_test_node("obj", 0, 6, -1, 1, 16, [metadata, value])
  let fields : Array[Ref[ParquetNodeValue]] = [
    Ref(NodeScalar(ScalarBytes(variant_test_bytes([0x02, 3, 0])))),
    Ref(NodeScalar(ScalarBytes(variant_test_bytes([12, 42])))),
  ]
  let warnings : Array[String] = []
  assert_eq(
    parquet_variant_group_text(node, Ref(NodeGroup(fields)), warnings, "obj"),
    "null",
  )
  assert_eq(
    warnings,
    ["column \"obj\": unsupported Variant metadata (not version 1)"],
  )
}

///|
test "parquet Variant column reads a shredded object" {
  let metadata = variant_test_leaf("metadata", 0, 6, -1, 0)
  let value = variant_test_leaf("value", 1, 6, -1, 0)
  let a_value = variant_test_leaf("value", 0, 6, -1, 0)
  let a_typed = variant_test_leaf("typed_value", 1, 1, 17, 0)
  let b_value = variant_test_leaf("value", 0, 6, -1, 0)
  let b_typed = variant_test_leaf("typed_value", 1, 6, 0, 0)
  let a = variant_test_node("a", 0, -1, -1, 1, 0, [a_value, a_typed])
  let b = variant_test_node("b", 1, -1, -1, 1, 0, [b_value, b_typed])
  let typed = variant_test_node("typed_value", 2, -1, -1, 1, 0, [a, b])
  let node = variant_test_node("obj", 0, -1, -1, 1, 16, [
    metadata,
    value,
    typed,
  ])
  let a_fields : Array[Ref[ParquetNodeValue]] = [
    Ref(NodeNull),
    Ref(NodeScalar(ScalarInt(1L))),
  ]
  let b_fields : Array[Ref[ParquetNodeValue]] = [
    Ref(NodeNull),
    Ref(NodeScalar(ScalarBytes(Bytes::from_array([b'x'])))),
  ]
  let typed_fields : Array[Ref[ParquetNodeValue]] = [
    Ref(NodeGroup(a_fields)),
    Ref(NodeGroup(b_fields)),
  ]
  let fields : Array[Ref[ParquetNodeValue]] = [
    Ref(NodeScalar(ScalarBytes(variant_test_meta_text()))),
    Ref(NodeNull),
    Ref(NodeGroup(typed_fields)),
  ]
  let warnings : Array[String] = []
  assert_eq(
    parquet_variant_group_text(node, Ref(NodeGroup(fields)), warnings, "obj"),
    "{\"a\": 1, \"b\": \"x\"}",
  )
  assert_true(warnings.is_empty())
}
