///|
fn nested_test_node(
  name : String,
  index : Int,
  physical : Int,
  converted : Int,
  repetition : Int,
  logical_kind : Int,
  def_level : Int,
  rep_level : Int,
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
    geo_kind: 0,
    def_level,
    rep_level,
    index,
    children,
  }
}

///|
/// The path of a three-level list<string>: an optional list group (def 1), a
/// repeated list group (def 2, rep 1) and an optional element (def 3).
fn nested_test_list_path() -> Array[ParquetSchemaNode] {
  let element = nested_test_node("element", 0, 6, 0, 1, 0, 3, 1, [])
  let list = nested_test_node("list", 0, -1, -1, 2, 0, 2, 1, [element])
  let top = nested_test_node("tags", 0, -1, 3, 1, 3, 1, 0, [list])
  [top, list, element]
}

///|
fn nested_test_assemble(
  path : Array[ParquetSchemaNode],
  entries : Array[(Int, Int, ParquetScalar)],
) -> Ref[ParquetNodeValue] {
  let cell = Ref(NodeNull)
  let indices : Array[Int] = []
  for _ in 0..<path.length() {
    indices.push(0)
  }
  for entry in entries {
    let (rep, def, scalar) = entry
    parquet_nested_indices(path, rep, indices)
    parquet_nested_put(path, 0, cell, def, scalar, indices)
  }
  cell
}

///|
fn nested_test_render(path : Array[ParquetSchemaNode], cell : Ref[ParquetNodeValue]) -> String {
  parquet_render_node(path[0], cell, [], "tags")
}

///|
test "parquet nested list distinguishes null, empty and elements" {
  let path = nested_test_list_path()
  // A null list (def below the list group) leaves the cell null; the decoder
  // shows that as an empty cell, not as [].
  let null_list = nested_test_assemble(path, [(0, 0, ScalarNull)])
  assert_true(null_list.val is NodeNull)
  // An empty list (the list is there, but no element) shows as [].
  let empty_list = nested_test_assemble(path, [(0, 1, ScalarNull)])
  assert_eq(nested_test_render(path, empty_list), "[]")
  // One element.
  let one = nested_test_assemble(path, [(0, 3, ScalarBytes(@utf8.encode("green")))])
  assert_eq(nested_test_render(path, one), "[\"green\"]")
  // Two elements: repetition level 1 starts the second element.
  let two = nested_test_assemble(path, [
    (0, 3, ScalarBytes(@utf8.encode("red"))),
    (1, 3, ScalarBytes(@utf8.encode("blue"))),
  ])
  assert_eq(nested_test_render(path, two), "[\"red\", \"blue\"]")
  // A null element (the element is there, but its value is null).
  let null_element = nested_test_assemble(path, [(0, 2, ScalarNull)])
  assert_eq(nested_test_render(path, null_element), "[null]")
}
