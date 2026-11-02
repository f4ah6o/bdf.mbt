///|
/// An assembled nested value: a leaf's scalar, a group of fields, or the
/// elements of a repeated field. The cells are references because the entries
/// of the leaves under a group fill the same value element by element.
priv enum ParquetNodeValue {
  NodeNull
  NodeScalar(ParquetScalar)
  NodeGroup(Array[Ref[ParquetNodeValue]])
  NodeList(Array[Ref[ParquetNodeValue]])
}

///|
/// Whether the group is a list: a single repeated child, or the repeated
/// key/value group of a map that has no values (which Arrow reads as a list of
/// keys).
fn parquet_node_is_list(node : ParquetSchemaNode) -> Bool {
  if node.num_children == 0 || node.children.length() != 1 ||
    node.children[0].repetition != 2 {
    return false
  }
  if node.logical.kind == 3 || node.converted == 3 {
    return true
  }
  let entry = node.children[0]
  parquet_node_is_map_annotated(node) && entry.num_children > 0 &&
  entry.children.length() == 1
}

///|
fn parquet_node_is_map_annotated(node : ParquetSchemaNode) -> Bool {
  node.logical.kind == 2 || node.converted == 1 || node.converted == 2
}

///|
/// Whether the group is a map: a single repeated key/value group with two
/// children.
fn parquet_node_is_map(node : ParquetSchemaNode) -> Bool {
  if node.num_children == 0 || !parquet_node_is_map_annotated(node) ||
    node.children.length() != 1 {
    return false
  }
  let entry = node.children[0]
  entry.repetition == 2 && entry.num_children > 0 && entry.children.length() == 2
}

///|
/// The element of a list, and whether it is the value of the repeated group
/// (the three-level list) rather than the repeated field itself (the
/// two-level lists of the backward-compatibility rules of LogicalTypes.md).
fn parquet_list_element(node : ParquetSchemaNode) -> (ParquetSchemaNode, Bool) {
  let entry = node.children[0]
  if entry.num_children == 0 || entry.children.length() != 1 {
    return (entry, false)
  }
  if entry.children[0].repetition == 2 {
    return (entry, false)
  }
  if entry.name == "array" || entry.name == node.name + "_tuple" {
    return (entry, false)
  }
  (entry.children[0], true)
}

///|
/// The fields of a group value, or an empty array when the value is null.
fn parquet_group_fields(cell : Ref[ParquetNodeValue]) -> Array[Ref[ParquetNodeValue]] {
  match cell.val {
    NodeGroup(fields) => fields
    _ => []
  }
}

///|
/// The items of a repeated value, or an empty array when it is null.
fn parquet_list_items(cell : Ref[ParquetNodeValue]) -> Array[Ref[ParquetNodeValue]] {
  match cell.val {
    NodeList(items) => items
    _ => []
  }
}

///|
/// A group cell with one null field per child of the node.
fn parquet_new_group(node : ParquetSchemaNode) -> Array[Ref[ParquetNodeValue]] {
  let fields : Array[Ref[ParquetNodeValue]] = []
  for _ in 0..<node.children.length() {
    fields.push(Ref(NodeNull))
  }
  fields
}

///|
/// Advance the element index of every repeated field on a leaf's path for an
/// entry: a repetition level starts a new element at that level and at every
/// field below it, and a new row (level 0) starts every list again.
fn parquet_nested_indices(
  path : Array[ParquetSchemaNode],
  rep : Int,
  indices : Array[Int],
) -> Unit {
  for pos, node in path {
    if node.repetition == 2 {
      if rep == 0 || node.rep_level > rep {
        indices[pos] = 0
      } else if node.rep_level == rep {
        indices[pos] += 1
      }
    }
  }
}

///|
/// Put an entry into the assembled value of a row.
fn parquet_nested_put(
  path : Array[ParquetSchemaNode],
  pos : Int,
  cell : Ref[ParquetNodeValue],
  def : Int,
  scalar : ParquetScalar,
  indices : Array[Int],
) -> Unit {
  let node = path[pos]
  if node.def_level > def {
    // The field is null, or a repeated field is empty: an empty list still
    // shows as [] rather than null.
    if node.repetition == 2 {
      match cell.val {
        NodeList(_) => ()
        _ => cell.val = NodeList([])
      }
    }
    return
  }
  let mut target = cell
  if node.repetition == 2 {
    let items = match cell.val {
      NodeList(items) => items
      _ => {
        let created : Array[Ref[ParquetNodeValue]] = []
        cell.val = NodeList(created)
        created
      }
    }
    let index = indices[pos]
    while items.length() <= index {
      items.push(Ref(NodeNull))
    }
    target = items[index]
  }
  if pos + 1 >= path.length() {
    target.val = NodeScalar(scalar)
    return
  }
  let fields = match target.val {
    NodeGroup(fields) => fields
    _ => {
      let created = parquet_new_group(node)
      target.val = NodeGroup(created)
      created
    }
  }
  parquet_nested_put(path, pos + 1, fields[path[pos + 1].index], def, scalar, indices)
}

///|
/// Render an assembled nested value the way JSON writes it, with the
/// annotations applied: lists as arrays, maps and groups as objects, Variants
/// as what they hold, and geometries as WKT.
fn parquet_render_node(
  node : ParquetSchemaNode,
  cell : Ref[ParquetNodeValue],
  warnings : Array[String],
  column_name : String,
  instance~ : Bool = false,
) -> String {
  if !instance && node.repetition == 2 {
    let items = parquet_list_items(cell)
    let output = StringBuilder()
    output.write_char('[')
    for index, item in items {
      if index > 0 {
        output.write_string(", ")
      }
      output.write_string(
        parquet_render_node(node, item, warnings, column_name, instance=true),
      )
    }
    output.write_char(']')
    return output.to_string()
  }
  match cell.val {
    NodeNull => return "null"
    NodeScalar(scalar) => {
      let format = parquet_format(parquet_node_format_source(node))
      return parquet_scalar_json(format, scalar)
    }
    _ => ()
  }
  if node.num_children == 0 {
    return "null"
  }
  if parquet_node_is_variant(node) {
    return parquet_variant_group_text(node, cell, warnings, column_name)
  }
  if parquet_node_is_list(node) {
    return parquet_render_list(node, cell, warnings, column_name)
  }
  if parquet_node_is_map(node) {
    return parquet_render_map(node, cell, warnings, column_name)
  }
  let fields = parquet_group_fields(cell)
  let output = StringBuilder()
  output.write_char('{')
  for index, child in node.children {
    if index > 0 {
      output.write_string(", ")
    }
    output.write_string("\"" + parquet_json_escape(child.name) + "\": ")
    let field = if index < fields.length() {
      fields[index]
    } else {
      Ref(NodeNull)
    }
    output.write_string(
      parquet_render_node(child, field, warnings, column_name),
    )
  }
  output.write_char('}')
  output.to_string()
}

///|
fn parquet_render_list(
  node : ParquetSchemaNode,
  cell : Ref[ParquetNodeValue],
  warnings : Array[String],
  column_name : String,
) -> String {
  let (element, inner) = parquet_list_element(node)
  let fields = parquet_group_fields(cell)
  let items = if fields.length() > 0 {
    parquet_list_items(fields[0])
  } else {
    []
  }
  let output = StringBuilder()
  output.write_char('[')
  for index, item in items {
    if index > 0 {
      output.write_string(", ")
    }
    if !inner {
      output.write_string(
        parquet_render_node(
          element,
          item,
          warnings,
          column_name,
          instance=true,
        ),
      )
    } else {
      let element_fields = parquet_group_fields(item)
      let value = if element_fields.length() > 0 {
        element_fields[0]
      } else {
        Ref(NodeNull)
      }
      output.write_string(
        parquet_render_node(element, value, warnings, column_name),
      )
    }
  }
  output.write_char(']')
  output.to_string()
}

///|
fn parquet_render_map(
  node : ParquetSchemaNode,
  cell : Ref[ParquetNodeValue],
  warnings : Array[String],
  column_name : String,
) -> String {
  let entry = node.children[0]
  let fields = parquet_group_fields(cell)
  let items = if fields.length() > 0 {
    parquet_list_items(fields[0])
  } else {
    []
  }
  let output = StringBuilder()
  output.write_char('{')
  for index, item in items {
    if index > 0 {
      output.write_string(", ")
    }
    let entry_fields = parquet_group_fields(item)
    if entry_fields.length() < 2 {
      output.write_string("null: null")
      continue
    }
    output.write_string(
      parquet_render_node(
        entry.children[0],
        entry_fields[0],
        warnings,
        column_name,
      ),
    )
    output.write_string(": ")
    output.write_string(
      parquet_render_node(
        entry.children[1],
        entry_fields[1],
        warnings,
        column_name,
      ),
    )
  }
  output.write_char('}')
  output.to_string()
}
