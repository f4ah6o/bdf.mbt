///|
/// A Variant (VariantEncoding.md of parquet-format) is a value of any type in
/// two binaries: the metadata, a dictionary of the names of the fields of its
/// objects, and the value, a header byte (its basic type: a primitive, a short
/// string, an object or an array) and its data. A shredded Variant
/// (VariantShredding.md) stores parts of the value as typed columns: a
/// typed_value holds the value when it is of the column's type, a group of
/// fields for an object (each a value and a typed_value), or a list of such
/// elements for an array; value holds the rest.

///|
/// The most nesting of Variant values written.
let parquet_variant_max_depth : Int = 128

///|
/// The sizes of the data of the primitive types of fixed size (-1: a byte
/// array with a 4-byte length).
let parquet_variant_sizes : Array[Int] = [
  0, 0, 0, 1, 2, 4, 8, 8, 5, 9, 17, 4, 8, 8, 4, -1, -1, 8, 8, 8, 16,
]

///|
priv struct ParquetVariantMeta {
  data : Bytes
  offset_size : Int
  count : Int
  offsets : Int
  strings : Int
}

///|
/// Read an unsigned little-endian integer of at most 4 bytes.
fn parquet_variant_uint(data : Bytes, pos : Int, size : Int) -> Int64 {
  let mut value = 0L
  for index in 0..<size {
    if pos + index < data.length() {
      value = value | (data[pos + index].to_int64() << (8 * index))
    }
  }
  value
}

///|
/// Read an unsigned little-endian 64-bit integer.
fn parquet_variant_bits(data : Bytes, pos : Int, size : Int) -> UInt64 {
  let mut value = 0UL
  for index in 0..<size {
    if pos + index < data.length() {
      value = value | (data[pos + index].to_uint64() << (8 * index))
    }
  }
  value
}

///|
/// Parse the dictionary of the field names of a Variant.
fn parquet_variant_meta_parse(data : Bytes) -> ParquetVariantMeta? {
  if data.length() < 1 || (data[0].to_int() & 0x0f) != 1 {
    return None
  }
  let offset_size = (data[0].to_int() >> 6) + 1
  if data.length() < 1 + offset_size {
    return None
  }
  let count = parquet_variant_uint(data, 1, offset_size)
  let offsets = 1 + offset_size
  if count < 0L ||
    (count + 1L) * offset_size.to_int64() > (data.length() - offsets).to_int64() {
    return None
  }
  let strings = offsets + (count.to_int() + 1) * offset_size
  Some({
    data,
    offset_size,
    count: count.to_int(),
    offsets,
    strings,
  })
}

///|
/// The field name of an id.
fn parquet_variant_meta_name(
  meta : ParquetVariantMeta,
  id : Int,
) -> String? {
  if id < 0 || id >= meta.count {
    return None
  }
  let start = parquet_variant_uint(
    meta.data,
    meta.offsets + id * meta.offset_size,
    meta.offset_size,
  )
  let end = parquet_variant_uint(
    meta.data,
    meta.offsets + (id + 1) * meta.offset_size,
    meta.offset_size,
  )
  if start < 0L || end < start || end > (meta.data.length() - meta.strings).to_int64() {
    return None
  }
  Some(
    @utf8.decode_lossy(
      meta.data[meta.strings + start.to_int():meta.strings + end.to_int()],
    ),
  )
}

///|
/// The values of an object or an array: their field ids (objects only), and
/// the byte range of each value within the data after the offsets.
priv struct ParquetVariantItems {
  data : Bytes
  payload : Int
  starts : Array[Int]
  ends : Array[Int]
  ids : Array[Int]
}

///|
fn parquet_variant_items(data : Bytes) -> ParquetVariantItems? {
  if data.length() < 1 {
    return None
  }
  let header = data[0].to_int()
  let basic = header & 3
  let value_header = header >> 2
  let offset_size = (value_header & 3) + 1
  let mut id_size = 0
  let mut large = false
  if basic == 2 {
    id_size = ((value_header >> 2) & 3) + 1
    large = ((value_header >> 4) & 1) != 0
  } else {
    large = ((value_header >> 2) & 1) != 0
  }
  let mut pos = 1
  let mut count = 0
  if large {
    if data.length() < pos + 4 {
      return None
    }
    count = parquet_variant_uint(data, pos, 4).to_int()
    pos += 4
  } else {
    if data.length() < pos + 1 {
      return None
    }
    count = data[pos].to_int()
    pos += 1
  }
  if count < 0 ||
    count.to_int64() * id_size.to_int64() +
    (count.to_int64() + 1L) * offset_size.to_int64() >
    (data.length() - pos).to_int64() {
    return None
  }
  let ids : Array[Int] = []
  if id_size > 0 {
    for index in 0..<count {
      ids.push(parquet_variant_uint(data, pos + index * id_size, id_size).to_int())
    }
    pos += count * id_size
  }
  let offsets = pos
  let payload = pos + (count + 1) * offset_size
  let total = parquet_variant_uint(
    data,
    offsets + count * offset_size,
    offset_size,
  )
  if total < 0L || total > (data.length() - payload).to_int64() {
    return None
  }
  let starts : Array[Int] = []
  let ends : Array[Int] = []
  for index in 0..<count {
    let start = parquet_variant_uint(
      data,
      offsets + index * offset_size,
      offset_size,
    ).to_int()
    if start < 0 || start > total.to_int() {
      return None
    }
    let end = if basic == 3 {
      parquet_variant_uint(
        data,
        offsets + (index + 1) * offset_size,
        offset_size,
      ).to_int()
    } else {
      total.to_int()
    }
    if end < start || end > total.to_int() {
      return None
    }
    starts.push(start)
    ends.push(end)
  }
  Some({ data, payload, starts, ends, ids })
}

///|
fn parquet_variant_slice(items : ParquetVariantItems, index : Int) -> Bytes {
  if index < 0 || index >= items.starts.length() {
    return b""
  }
  items.data[items.payload + items.starts[index]:items.payload +
    items.ends[index]].to_owned()
}

///|
/// The decimal text of a Variant decimal: the scale byte, then the unscaled
/// value little endian (reversed into the big-endian two's complement that the
/// Parquet DECIMAL logical type uses).
fn parquet_variant_decimal_text(payload : Bytes, size : Int) -> String {
  if payload.length() < 1 {
    return "0"
  }
  let scale = payload[0].to_int()
  let length = Int::min(size - 1, payload.length() - 1)
  if length <= 0 {
    return "0"
  }
  let reversed : Array[Byte] = []
  for index in 0..<length {
    reversed.push(payload[length - index])
  }
  parquet_decimal_bytes_text(Bytes::from_array(reversed), scale)
}

///|
/// The text of a timestamp of a Variant, in UTC.
fn parquet_variant_timestamp_text(value : Int64, nanos : Bool) -> String {
  let mut seconds = if nanos {
    value / 1000000000L
  } else {
    value / 1000000L
  }
  let mut fraction = if nanos {
    value % 1000000000L
  } else {
    value % 1000000L * 1000L
  }
  if fraction < 0L {
    seconds -= 1L
    fraction += 1000000000L
  }
  parquet_timestamp_text(seconds, fraction, parquet_frac_digits(fraction))
}

///|
/// The text of a time of a Variant.
fn parquet_variant_time_text(value : Int64) -> String {
  let mut seconds = value / 1000000L
  let mut fraction = value % 1000000L * 1000L
  if fraction < 0L {
    seconds -= 1L
    fraction += 1000000000L
  }
  parquet_clock_text(seconds, fraction, parquet_frac_digits(fraction))
}

///|
/// Sign-extend the low bits of a little-endian integer.
fn parquet_variant_signed(value : Int64, bits : Int) -> Int64 {
  if bits >= 64 {
    return value
  }
  let sign = 1L << (bits - 1)
  if (value & sign) != 0L {
    value - (1L << bits)
  } else {
    value
  }
}

///|
/// Write the JSON of a Variant primitive.
fn parquet_variant_primitive_json(typ : Int, body : Bytes) -> String {
  if typ < 0 || typ >= parquet_variant_sizes.length() {
    return "null"
  }
  let size = parquet_variant_sizes[typ]
  let payload = if size < 0 {
    if body.length() < 4 {
      return "null"
    }
    let length = parquet_variant_uint(body, 0, 4)
    if length < 0L || length > (body.length() - 4).to_int64() {
      return "null"
    }
    body[4:4 + length.to_int()].to_owned()
  } else {
    if body.length() < size {
      return "null"
    }
    body[:size].to_owned()
  }
  match typ {
    0 => "null"
    1 => "true"
    2 => "false"
    3 => parquet_variant_signed(payload[0].to_int64(), 8).to_string()
    4 => parquet_variant_signed(parquet_variant_uint(payload, 0, 2), 16).to_string()
    5 => parquet_variant_signed(parquet_variant_uint(payload, 0, 4), 32).to_string()
    6 => parquet_variant_bits(payload, 0, 8).reinterpret_as_int64().to_string()
    7 =>
      parquet_float_text(
        parquet_variant_bits(payload, 0, 8).reinterpret_as_double(),
        64,
      )
    8 | 9 | 10 => parquet_variant_decimal_text(payload, size)
    11 =>
      "\"" +
      parquet_date_text(parquet_variant_signed(parquet_variant_uint(payload, 0, 4), 32)) +
      "\""
    12 | 13 =>
      "\"" +
      parquet_variant_timestamp_text(
        parquet_variant_bits(payload, 0, 8).reinterpret_as_int64(),
        false,
      ) +
      "\""
    14 =>
      parquet_float_text(
        Float::reinterpret_from_uint(
          parquet_variant_uint(payload, 0, 4).reinterpret_as_uint64().to_uint(),
        ).to_double(),
        32,
      )
    15 => "\"" + parquet_json_escape(parquet_hex_text(payload)) + "\""
    16 => "\"" + parquet_json_escape(parquet_text_text(payload)) + "\""
    17 => "\"" + parquet_variant_time_text(
      parquet_variant_bits(payload, 0, 8).reinterpret_as_int64(),
    ) + "\""
    18 | 19 =>
      "\"" +
      parquet_variant_timestamp_text(
        parquet_variant_bits(payload, 0, 8).reinterpret_as_int64(),
        true,
      ) +
      "\""
    20 => "\"" + parquet_json_escape(parquet_uuid_text(payload)) + "\""
    _ => "null"
  }
}

///|
/// Write the JSON of a Variant object.
fn parquet_variant_object_json(
  meta : ParquetVariantMeta,
  data : Bytes,
) -> String? {
  if data.length() == 0 || (data[0].to_int() & 3) != 2 {
    return None
  }
  let items = match parquet_variant_items(data) {
    Some(items) => items
    None => return None
  }
  let output = StringBuilder()
  output.write_char('{')
  for index, id in items.ids {
    let name = match parquet_variant_meta_name(meta, id) {
      Some(name) => name
      None => return None
    }
    if index > 0 {
      output.write_string(", ")
    }
    output.write_string("\"" + parquet_json_escape(name) + "\": ")
    output.write_string(
      parquet_variant_value_json(meta, parquet_variant_slice(items, index)),
    )
  }
  output.write_char('}')
  Some(output.to_string())
}

///|
/// Write the JSON of a Variant value (primitive, string, object or array).
fn parquet_variant_value_json(
  meta : ParquetVariantMeta,
  data : Bytes,
  depth~ : Int = 0,
) -> String {
  if data.length() == 0 || depth > parquet_variant_max_depth {
    return "null"
  }
  let header = data[0].to_int()
  let basic = header & 3
  let value_header = header >> 2
  match basic {
    0 => parquet_variant_primitive_json(value_header, data[1:].to_owned())
    1 =>
      if value_header > data.length() - 1 {
        "null"
      } else {
        "\"" +
        parquet_json_escape(
          parquet_text_text(data[1:1 + value_header]),
        ) +
        "\""
      }
    2 =>
      match parquet_variant_object_json(meta, data) {
        Some(text) => text
        None => "null"
      }
    _ => {
      let items = match parquet_variant_items(data) {
        Some(items) => items
        None => return "null"
      }
      let output = StringBuilder()
      output.write_char('[')
      for index, _ in items.starts {
        if index > 0 {
          output.write_string(", ")
        }
        output.write_string(
          parquet_variant_value_json(
            meta,
            parquet_variant_slice(items, index),
            depth=depth + 1,
          ),
        )
      }
      output.write_char(']')
      output.to_string()
    }
  }
}

///|
/// The node of a Variant group's field, by name.
fn parquet_variant_field_node(
  node : ParquetSchemaNode,
  name : String,
) -> ParquetSchemaNode? {
  for child in node.children {
    if child.name == name {
      return Some(child)
    }
  }
  None
}

///|
/// The bytes of a scalar cell, when it holds a byte array.
fn parquet_cell_bytes(cell : Ref[ParquetNodeValue]) -> Bytes? {
  match cell.val {
    NodeScalar(ScalarBytes(value)) => Some(value)
    _ => None
  }
}

///|
/// Whether a group is a Variant: one annotated so, or a group of the binary
/// fields metadata and value (with typed_value when it is shredded) as Spark
/// wrote them before the annotation.
fn parquet_node_is_variant(node : ParquetSchemaNode) -> Bool {
  if node.num_children == 0 {
    return false
  }
  let meta = parquet_variant_field_node(node, "metadata")
  let value = parquet_variant_field_node(node, "value")
  let metadata = match meta {
    Some(metadata) => metadata
    None => return false
  }
  if metadata.num_children != 0 || metadata.physical != 6 {
    return false
  }
  if node.logical.kind == 16 {
    return true
  }
  match value {
    Some(value) =>
      value.num_children == 0 && value.physical == 6 &&
      node.children.length() == 2 && metadata.logical.kind == 0 &&
      metadata.converted == -1 && value.logical.kind == 0 &&
      value.converted == -1
    None => false
  }
}

///|
priv struct ParquetVariantEntry {
  name : String
  text : String
}

///|
/// Write a shredded Variant value from the value and typed_value fields of a
/// group (a Variant column, a field of a shredded object or an element of a
/// shredded array).
fn parquet_variant_shredded(
  meta : ParquetVariantMeta,
  fields : Array[Ref[ParquetNodeValue]],
  value_node : ParquetSchemaNode?,
  typed_node : ParquetSchemaNode?,
  depth : Int,
) -> String {
  if depth > parquet_variant_max_depth {
    return "null"
  }
  let value = match value_node {
    Some(node) =>
      if node.index < fields.length() {
        parquet_cell_bytes(fields[node.index])
      } else {
        None
      }
    None => None
  }
  let typed = match typed_node {
    Some(node) =>
      if node.index < fields.length() {
        Some(fields[node.index])
      } else {
        None
      }
    None => None
  }
  let typed = match typed {
    Some(cell) =>
      match cell.val {
        NodeNull => None
        _ => Some(cell)
      }
    None => None
  }
  match (typed, value) {
    (None, Some(value)) => parquet_variant_value_json(meta, value, depth=depth)
    (None, None) => "null"
    (Some(cell), _) => {
      let node = match typed_node {
        Some(node) => node
        None => return "null"
      }
      if node.num_children == 0 {
        match cell.val {
          NodeScalar(scalar) =>
            parquet_scalar_json(parquet_format(parquet_node_format_source(node)), scalar)
          _ => "null"
        }
      } else if parquet_node_is_list(node) {
        parquet_variant_shredded_list(meta, node, cell, depth)
      } else {
        let value_bytes = match value {
          Some(bytes) => bytes
          None => b""
        }
        parquet_variant_shredded_object(meta, node, cell, value_bytes, depth)
      }
    }
  }
}

///|
fn parquet_variant_shredded_list(
  meta : ParquetVariantMeta,
  node : ParquetSchemaNode,
  cell : Ref[ParquetNodeValue],
  depth : Int,
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
    let mut element_fields = parquet_group_fields(item)
    if inner {
      let inner_cell = if element_fields.length() > 0 {
        element_fields[0]
      } else {
        Ref(NodeNull)
      }
      element_fields = parquet_group_fields(inner_cell)
    }
    let value_node = parquet_variant_field_node(element, "value")
    let typed_node = parquet_variant_field_node(element, "typed_value")
    output.write_string(
      parquet_variant_shredded(
        meta,
        element_fields,
        value_node,
        typed_node,
        depth + 1,
      ),
    )
  }
  output.write_char(']')
  output.to_string()
}

///|
fn parquet_variant_shredded_object(
  meta : ParquetVariantMeta,
  node : ParquetSchemaNode,
  cell : Ref[ParquetNodeValue],
  value : Bytes,
  depth : Int,
) -> String {
  let fields = parquet_group_fields(cell)
  let entries : Array[ParquetVariantEntry] = []
  for child in node.children {
    let child_fields = if child.index < fields.length() {
      parquet_group_fields(fields[child.index])
    } else {
      []
    }
    let value_node = parquet_variant_field_node(child, "value")
    let typed_node = parquet_variant_field_node(child, "typed_value")
    let absent = {
      let value_absent = match value_node {
        Some(node) =>
          node.index >= child_fields.length() ||
          child_fields[node.index].val is NodeNull
        None => true
      }
      let typed_absent = match typed_node {
        Some(node) =>
          node.index >= child_fields.length() ||
          child_fields[node.index].val is NodeNull
        None => true
      }
      value_absent && typed_absent
    }
    if absent {
      continue
    }
    entries.push({
      name: child.name,
      text: parquet_variant_shredded(
        meta,
        child_fields,
        value_node,
        typed_node,
        depth + 1,
      ),
    })
  }
  if value.length() > 0 {
    let text = parquet_variant_value_json(meta, value, depth=depth)
    if text != "null" {
      if !parquet_variant_is_object(value) {
        return text
      }
      let items = match parquet_variant_items(value) {
        Some(items) => items
        None => return parquet_variant_entries_json(entries)
      }
      for index, id in items.ids {
        let name = match parquet_variant_meta_name(meta, id) {
          Some(name) => name
          None => continue
        }
        let mut shredded = false
        for child in node.children {
          if child.name == name {
            shredded = true
          }
        }
        if shredded {
          continue
        }
        entries.push({
          name,
          text: parquet_variant_value_json(
            meta,
            parquet_variant_slice(items, index),
            depth=depth + 1,
          ),
        })
      }
    }
  }
  parquet_variant_entries_json(entries)
}

///|
fn parquet_variant_is_object(data : Bytes) -> Bool {
  data.length() > 0 && (data[0].to_int() & 3) == 2
}

///|
fn parquet_variant_entries_json(
  entries : Array[ParquetVariantEntry],
) -> String {
  entries.sort_by(fn(left, right) { left.name.compare(right.name) })
  let output = StringBuilder()
  output.write_char('{')
  for index, entry in entries {
    if index > 0 {
      output.write_string(", ")
    }
    output.write_string("\"" + parquet_json_escape(entry.name) + "\": ")
    output.write_string(entry.text)
  }
  output.write_char('}')
  output.to_string()
}

///|
/// Write a Variant column's value: its metadata, and the value, shredded or
/// not.
fn parquet_variant_group_text(
  node : ParquetSchemaNode,
  cell : Ref[ParquetNodeValue],
  warnings : Array[String],
  column_name : String,
) -> String {
  let fields = parquet_group_fields(cell)
  let meta_node = match parquet_variant_field_node(node, "metadata") {
    Some(meta) => meta
    None => return "null"
  }
  let meta_bytes = if meta_node.index < fields.length() {
    match parquet_cell_bytes(fields[meta_node.index]) {
      Some(bytes) => bytes
      None => b""
    }
  } else {
    b""
  }
  let meta = match parquet_variant_meta_parse(meta_bytes) {
    Some(meta) => meta
    None => {
      if meta_bytes.length() > 0 {
        let message = "column \"" + column_name +
          "\": unsupported Variant metadata (not version 1)"
        if !warnings.contains(message) {
          warnings.push(message)
        }
      }
      return "null"
    }
  }
  let value_node = parquet_variant_field_node(node, "value")
  let typed_node = parquet_variant_field_node(node, "typed_value")
  parquet_variant_shredded(meta, fields, value_node, typed_node, 0)
}
