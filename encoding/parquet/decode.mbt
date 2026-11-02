///|
/// The logical type of a schema element (the `LogicalType` union of
/// parquet.thrift), with the unit of times, whether an instant is in UTC, the
/// width and signedness of integers, and the scale and precision of decimals.
priv struct ParquetLogicalType {
  kind : Int
  unit : Int
  utc : Bool
  signed : Bool
  bit_width : Int
  scale : Int
  precision : Int
}

///|
fn parquet_logical_none() -> ParquetLogicalType {
  { kind: 0, unit: 0, utc: false, signed: true, bit_width: 0, scale: 0, precision: 0 }
}

///|
priv struct ParquetSchemaNode {
  name : String
  physical : Int
  converted : Int
  repetition : Int
  num_children : Int
  type_length : Int
  scale : Int
  precision : Int
  logical : ParquetLogicalType
  geo : Bool
  geo_kind : Int
  def_level : Int
  rep_level : Int
  index : Int
  children : Array[ParquetSchemaNode]
}

///|
priv struct ParquetMetaColumn {
  name : String
  physical : Int
  converted : Int
  optional : Bool
  values : Int64
  codec : Int
  encodings : Array[Int]
  mut data_offset : Int64
  dictionary_offset : Int64
  has_dictionary : Bool
  path : Array[String]
  type_length : Int
  scale : Int
  precision : Int
  max_rep : Int
  max_def : Int
  logical : ParquetLogicalType
  geo : Bool
  geo_kind : Int
}

///|
priv struct ParquetCompact {
  data : Bytes
  mut pos : Int
  mut last : Int
}

///|
fn ParquetCompact::new(data : Bytes) -> ParquetCompact {
  { data, pos: 0, last: 0 }
}

///|
fn ParquetCompact::byte(self : ParquetCompact) -> Int {
  if self.pos >= self.data.length() {
    return 0
  }
  let value = self.data[self.pos].to_int()
  self.pos += 1
  value
}

///|
fn ParquetCompact::varint(self : ParquetCompact) -> Int64 {
  let mut value = 0L
  let mut shift = 0
  while shift < 64 {
    let byte = self.byte()
    value = value | ((byte & 0x7f).to_int64() << shift)
    if (byte & 0x80) == 0 {
      break
    }
    shift += 7
  }
  value
}

///|
fn ParquetCompact::zigzag(self : ParquetCompact) -> Int64 {
  let value = self.varint()
  (value >> 1) ^ -(value & 1L)
}

///|
fn ParquetCompact::field(self : ParquetCompact) -> (Int, Int) {
  let header = self.byte()
  if header == 0 {
    return (0, 0)
  }
  let typ = header & 0x0f
  let delta = header >> 4
  let field_id = if delta == 0 {
    self.zigzag().to_int()
  } else {
    self.last + delta
  }
  self.last = field_id
  (field_id, typ)
}

///|
fn ParquetCompact::binary(self : ParquetCompact) -> Bytes {
  let length = self.varint().to_int()
  let end = Int::min(self.pos + length, self.data.length())
  let value = self.data[self.pos:end].to_owned()
  self.pos = end
  value
}

///|
fn ParquetCompact::list_header(self : ParquetCompact) -> (Int, Int) {
  let header = self.byte()
  let mut count = header >> 4
  if count == 15 {
    count = self.varint().to_int()
  }
  (count, header & 0x0f)
}

///|
fn ParquetCompact::skip(self : ParquetCompact, typ : Int) -> Unit {
  match typ {
    0 => ()
    1 | 2 => ()
    3 => ignore(self.byte())
    4 | 5 | 6 => ignore(self.varint())
    7 => {
      ignore(self.byte())
      ignore(self.byte())
      ignore(self.byte())
      ignore(self.byte())
      ignore(self.byte())
      ignore(self.byte())
      ignore(self.byte())
      ignore(self.byte())
    }
    8 => ignore(self.binary())
    9 | 10 => {
      let (count, element) = self.list_header()
      for _ in 0..<count {
        self.skip(element)
      }
    }
    11 => {
      let count = self.varint().to_int()
      if count > 0 {
        let types = self.byte()
        for _ in 0..<count {
          self.skip(types >> 4)
          self.skip(types & 0x0f)
        }
      }
    }
    12 => {
      let save = self.last
      self.last = 0
      while true {
        let (id, field) = self.field()
        if id == 0 {
          break
        }
        self.skip(field)
      }
      self.last = save
    }
    _ => ()
  }
}

///|
/// Read the unit of a TimeType or TimestampType: the single field of the
/// TimeUnit union names it (1 millis, 2 micros, 3 nanos).
fn parquet_schema_time_unit(reader : ParquetCompact) -> Int {
  let mut unit = 0
  let save = reader.last
  reader.last = 0
  while true {
    let (id, typ) = reader.field()
    if id == 0 {
      break
    }
    unit = id
    reader.skip(typ)
  }
  reader.last = save
  unit
}

///|
/// Read a LogicalType union: the field id is the kind, and the value holds
/// its parameters.
fn parquet_schema_logical_type(reader : ParquetCompact) -> ParquetLogicalType {
  let mut logical = parquet_logical_none()
  let save = reader.last
  reader.last = 0
  while true {
    let (id, typ) = reader.field()
    if id == 0 {
      break
    }
    if typ == 12 {
      logical = { ..logical, kind: id }
      let save_value = reader.last
      reader.last = 0
      while true {
        let (sub_id, sub_typ) = reader.field()
        if sub_id == 0 {
          break
        }
        if id == 5 {
          if sub_id == 1 && sub_typ == 5 {
            logical = { ..logical, scale: reader.zigzag().to_int() }
          } else if sub_id == 2 && sub_typ == 5 {
            logical = { ..logical, precision: reader.zigzag().to_int() }
          } else {
            reader.skip(sub_typ)
          }
        } else if id == 7 || id == 8 {
          if sub_id == 1 && (sub_typ == 1 || sub_typ == 2) {
            logical = { ..logical, utc: sub_typ == 1 }
          } else if sub_id == 2 && sub_typ == 12 {
            logical = { ..logical, unit: parquet_schema_time_unit(reader) }
          } else {
            reader.skip(sub_typ)
          }
        } else if id == 10 {
          if sub_id == 1 && sub_typ == 3 {
            logical = { ..logical, bit_width: reader.byte() }
          } else if sub_id == 2 && (sub_typ == 1 || sub_typ == 2) {
            logical = { ..logical, signed: sub_typ == 1 }
          } else {
            reader.skip(sub_typ)
          }
        } else {
          reader.skip(sub_typ)
        }
      }
      reader.last = save_value
    } else {
      reader.skip(typ)
    }
  }
  reader.last = save
  logical
}

///|
fn parquet_schema_element(reader : ParquetCompact) -> ParquetSchemaNode {
  let mut name = ""
  let mut physical = -1
  let mut converted = -1
  let mut repetition = 0
  let mut num_children = 0
  let mut type_length = 0
  let mut scale = 0
  let mut precision = 0
  let mut logical = parquet_logical_none()
  let save = reader.last
  reader.last = 0
  while true {
    let (id, typ) = reader.field()
    if id == 0 {
      break
    }
    match id {
      1 => physical = reader.zigzag().to_int()
      2 => type_length = reader.zigzag().to_int()
      3 => repetition = reader.zigzag().to_int()
      4 => name = @utf8.decode_lossy(reader.binary())
      5 => num_children = reader.zigzag().to_int()
      6 => converted = reader.zigzag().to_int()
      7 => scale = reader.zigzag().to_int()
      8 => precision = reader.zigzag().to_int()
      10 => logical = parquet_schema_logical_type(reader)
      _ => reader.skip(typ)
    }
  }
  reader.last = save
  {
    name,
    physical,
    converted,
    repetition,
    num_children,
    type_length,
    scale,
    precision,
    logical,
    geo: false,
    geo_kind: 0,
    def_level: 0,
    rep_level: 0,
    index: 0,
    children: [],
  }
}

///|
fn parquet_schema_placeholder() -> ParquetSchemaNode {
  {
    name: "",
    physical: -1,
    converted: -1,
    repetition: 0,
    num_children: 0,
    type_length: 0,
    scale: 0,
    precision: 0,
    logical: parquet_logical_none(),
    geo: false,
    geo_kind: 0,
    def_level: 0,
    rep_level: 0,
    index: 0,
    children: [],
  }
}

///|
fn parquet_schema_tree(elements : Array[ParquetSchemaNode]) -> ParquetSchemaNode {
  let index : Array[Int] = [0]
  fn build(parent_rep : Int, parent_def : Int) -> ParquetSchemaNode {
    let position = index[0]
    index[0] += 1
    let element = if position < elements.length() {
      elements[position]
    } else {
      parquet_schema_placeholder()
    }
    let rep = parent_rep + (if element.repetition == 2 { 1 } else { 0 })
    let def = parent_def + (if element.repetition == 0 { 0 } else { 1 })
    let children : Array[ParquetSchemaNode] = []
    for index in 0..<element.num_children {
      let child = build(rep, def)
      children.push({ ..child, index })
    }
    { ..element, def_level: def, rep_level: rep, children }
  }
  build(0, 0)
}

///|
fn parquet_schema_leaves(
  node : ParquetSchemaNode,
  path : Array[String],
  output : Array[ParquetMetaColumn],
) -> Unit {
  let next_path = path + [node.name]
  if node.num_children == 0 {
    let scale = if node.logical.kind == 5 {
      node.logical.scale
    } else if node.converted == 5 {
      node.scale
    } else {
      0
    }
    let precision = if node.logical.kind == 5 {
      node.logical.precision
    } else {
      node.precision
    }
    let logical = if node.logical.kind == 0 && node.converted == 5 {
      { ..parquet_logical_none(), kind: 5, scale, precision }
    } else {
      node.logical
    }
    output.push({
      name: node.name,
      physical: node.physical,
      converted: node.converted,
      optional: node.repetition != 0,
      values: 0L,
      codec: 0,
      encodings: [],
      data_offset: 0L,
      dictionary_offset: 0L,
      has_dictionary: false,
      path: next_path,
      type_length: node.type_length,
      scale,
      precision,
      max_rep: node.rep_level,
      max_def: node.def_level,
      logical,
      geo: node.geo,
      geo_kind: node.geo_kind,
    })
  } else {
    for child in node.children {
      parquet_schema_leaves(child, next_path, output)
    }
  }
}

///|
fn parquet_column_metadata(reader : ParquetCompact) -> ParquetMetaColumn {
  let mut name = ""
  let path : Array[String] = []
  let mut physical = 0
  let mut codec = 0
  let mut values = 0L
  let encodings : Array[Int] = []
  let mut data_offset = 0L
  let mut dictionary_offset = 0L
  let mut has_dictionary = false
  let save = reader.last
  reader.last = 0
  while true {
    let (id, typ) = reader.field()
    if id == 0 {
      break
    }
    match id {
      1 => physical = reader.zigzag().to_int()
      2 => {
        let (count, element) = reader.list_header()
        if element == 5 {
          for _ in 0..<count {
            encodings.push(reader.zigzag().to_int())
          }
        } else {
          for _ in 0..<count {
            reader.skip(element)
          }
        }
      }
      3 => {
        let (count, element) = reader.list_header()
        for _ in 0..<count {
          let value = @utf8.decode_lossy(reader.binary())
          path.push(value)
          if name == "" {
            name = value
          }
          let _ = element
        }
      }
      4 => codec = reader.zigzag().to_int()
      5 => values = reader.zigzag()
      9 => data_offset = reader.zigzag()
      11 => {
        dictionary_offset = reader.zigzag()
        has_dictionary = true
      }
      _ => reader.skip(typ)
    }
  }
  reader.last = save
  {
    name,
    physical,
    converted: -1,
    optional: false,
    values,
    codec,
    encodings,
    data_offset,
    dictionary_offset,
    has_dictionary,
    path,
    type_length: 0,
    scale: 0,
    precision: 0,
    max_rep: 0,
    max_def: 0,
    logical: parquet_logical_none(),
    geo: false,
    geo_kind: 0,
  }
}

///|
fn parquet_column_chunk(reader : ParquetCompact) -> ParquetMetaColumn {
  let mut file_offset = 0L
  let mut metadata : ParquetMetaColumn = {
    name: "",
    physical: 0,
    converted: -1,
    optional: false,
    values: 0L,
    codec: 0,
    encodings: [],
    data_offset: 0L,
    dictionary_offset: 0L,
    has_dictionary: false,
    path: [],
    type_length: 0,
    scale: 0,
    precision: 0,
    max_rep: 0,
    max_def: 0,
    logical: parquet_logical_none(),
    geo: false,
    geo_kind: 0,
  }
  let save = reader.last
  reader.last = 0
  while true {
    let (id, typ) = reader.field()
    if id == 0 {
      break
    }
    if id == 2 {
      file_offset = reader.zigzag()
    } else if id == 3 {
      metadata = parquet_column_metadata(reader)
    } else {
      reader.skip(typ)
    }
  }
  reader.last = save
  if metadata.data_offset == 0L {
    metadata.data_offset = file_offset
  }
  metadata
}

///|
/// Mark the leaves that hold WKB geometries: the columns GeoParquet metadata
/// names (top-level BYTE_ARRAY columns), and the leaves of the GEOMETRY and
/// GEOGRAPHY logical types.
fn parquet_schema_mark_geo(
  node : ParquetSchemaNode,
  depth : Int,
  geo : Map[String, Int],
) -> ParquetSchemaNode {
  let names_kind = if depth == 1 && node.num_children == 0 && node.physical == 6 {
    geo.get(node.name).unwrap_or(0)
  } else {
    0
  }
  let kind = if names_kind != 0 {
    names_kind
  } else if node.logical.kind == 17 || node.logical.kind == 18 {
    1
  } else {
    node.geo_kind
  }
  let children : Array[ParquetSchemaNode] = []
  for child in node.children {
    children.push(parquet_schema_mark_geo(child, depth + 1, geo))
  }
  { ..node, geo: kind != 0, geo_kind: kind, children }
}

///|
fn parquet_key_value(reader : ParquetCompact) -> (String, String) {
  let mut key = ""
  let mut value = ""
  let save = reader.last
  reader.last = 0
  while true {
    let (id, typ) = reader.field()
    if id == 0 {
      break
    }
    if id == 1 {
      key = @utf8.decode_lossy(reader.binary())
    } else if id == 2 {
      value = @utf8.decode_lossy(reader.binary())
    } else {
      reader.skip(typ)
    }
  }
  reader.last = save
  (key, value)
}

///|
/// The columns that GeoParquet metadata says hold WKB geometries: the "geo"
/// key of the file's key-value metadata names them under "columns", each with
/// an "encoding" of "WKB".
fn parquet_geo_columns(values : Map[String, String]) -> Map[String, Int] {
  let result : Map[String, Int] = Map([])
  let text = match values.get("geo") {
    Some(value) => value
    None => return result
  }
  let root = @json.parse(text) catch { _ => return result }
  let fields = match root {
    Object(fields) => fields
    _ => return result
  }
  let columns = match fields.get("columns") {
    Some(Object(columns)) => columns
    _ => return result
  }
  for name, spec in columns {
    let spec_fields = match spec {
      Object(fields) => fields
      _ => continue
    }
    let encoding = match spec_fields.get("encoding") {
      Some(String(encoding)) => encoding
      _ => continue
    }
    let kind = match encoding.to_lower() {
      "wkb" => 1
      "wkt" => 2
      _ => 0
    }
    if kind != 0 {
      result[name] = kind
    }
  }
  result
}

///|
fn parquet_footer(
  data : Bytes,
) -> (ParquetSchemaNode, Array[ParquetMetaColumn], Int64, Int, String, Map[String, String]) raise {
  if data.length() < 12 || !data.has_prefix(b"PAR1") || !data.has_suffix(b"PAR1") {
    raise Failure("parquet: not a Parquet file")
  }
  let length = (data[data.length() - 8].to_int() |
    (data[data.length() - 7].to_int() << 8) |
    (data[data.length() - 6].to_int() << 16) |
    (data[data.length() - 5].to_int() << 24))
  let start = data.length() - 8 - length
  if length <= 0 || start < 4 {
    raise Failure("parquet: invalid footer length")
  }
  let reader : ParquetCompact = { data, pos: start, last: 0 }
  let columns : Array[ParquetMetaColumn] = []
  let schema : Array[ParquetSchemaNode] = []
  let key_values : Map[String, String] = Map([])
  let mut rows = 0L
  let mut row_groups = 0
  let mut created_by = ""
  while true {
    let (id, typ) = reader.field()
    if id == 0 {
      break
    }
    if id == 2 {
      let (count, element) = reader.list_header()
      for _ in 0..<count {
        schema.push(parquet_schema_element(reader))
      }
      let _ = element
    } else if id == 3 {
      rows = reader.zigzag()
    } else if id == 4 {
      let (groups, element) = reader.list_header()
      row_groups += groups
      for _ in 0..<groups {
        let save = reader.last
        reader.last = 0
        while true {
          let (group_id, group_typ) = reader.field()
          if group_id == 0 {
            break
          }
          if group_id == 1 {
            let (chunks, chunk_type) = reader.list_header()
            for _ in 0..<chunks {
              columns.push(parquet_column_chunk(reader))
            }
            let _ = chunk_type
          } else {
            reader.skip(group_typ)
          }
        }
        reader.last = save
      }
      let _ = element
    } else if id == 5 {
      let (count, element) = reader.list_header()
      for _ in 0..<count {
        let (key, value) = parquet_key_value(reader)
        key_values[key] = value
      }
      let _ = element
    } else if id == 6 {
      created_by = @utf8.decode_lossy(reader.binary())
    } else {
      reader.skip(typ)
    }
  }
  let tree = parquet_schema_tree(schema)
  let geo_columns = parquet_geo_columns(key_values)
  let root = parquet_schema_mark_geo(tree, 0, geo_columns)
  let leaves : Array[ParquetMetaColumn] = []
  for child in root.children {
    parquet_schema_leaves(child, [], leaves)
  }
  for index in 0..<columns.length() {
    for leaf in leaves {
      if columns[index].path == leaf.path {
        let geo = leaf.geo || leaf.logical.kind == 17 ||
          leaf.logical.kind == 18
        columns[index] = {
          ..columns[index],
          physical: leaf.physical,
          converted: leaf.converted,
          optional: leaf.optional,
          type_length: leaf.type_length,
          scale: leaf.scale,
          precision: leaf.precision,
          max_rep: leaf.max_rep,
          max_def: leaf.max_def,
          logical: leaf.logical,
          geo,
          geo_kind: leaf.geo_kind,
        }
      }
    }
  }
  (root, columns, rows, row_groups, created_by, key_values)
}

///|
priv struct ParquetCursor {
  data : Bytes
  mut pos : Int
}

///|
fn ParquetCursor::u32(self : ParquetCursor) -> Int {
  if self.pos + 3 >= self.data.length() {
    return 0
  }
  let value = self.data[self.pos].to_int() |
    (self.data[self.pos + 1].to_int() << 8) |
    (self.data[self.pos + 2].to_int() << 16) |
    (self.data[self.pos + 3].to_int() << 24)
  self.pos += 4
  value
}

///|
fn ParquetCursor::i32(self : ParquetCursor) -> Int {
  self.u32()
}

///|
fn ParquetCursor::u64(self : ParquetCursor) -> Int64 {
  let mut value = 0L
  for index in 0..<8 {
    if self.pos + index < self.data.length() {
      value = value | (self.data[self.pos + index].to_int64() << (index * 8))
    }
  }
  self.pos += 8
  value
}

///|
fn ParquetCursor::f64(self : ParquetCursor) -> Double {
  self.u64().reinterpret_as_double()
}

///|
fn ParquetCursor::f32(self : ParquetCursor) -> Float {
  Float::reinterpret_from_uint(self.u32().reinterpret_as_uint())
}

///|
fn parquet_rle(data : Bytes, bit_width : Int, count : Int) -> Array[Int] {
  let output : Array[Int] = []
  let cursor : ParquetCursor = { data, pos: 0 }
  let byte_width = (bit_width + 7) / 8
  while output.length() < count && cursor.pos < data.length() {
    let header = ParquetCursor::varint(cursor)
    if (header & 1L) == 0L {
      let run = (header >> 1).to_int()
      let mut value = 0
      for index in 0..<byte_width {
        if cursor.pos + index < data.length() {
          value = value | (data[cursor.pos + index].to_int() << (index * 8))
        }
      }
      cursor.pos += byte_width
      for _ in 0..<Int::min(run, count - output.length()) {
        output.push(value)
      }
    } else {
      let groups = (header >> 1).to_int()
      let total = groups * 8
      let mut bits = 0
      let mut available = 0
      for _ in 0..<total {
        if output.length() >= count { break }
        while available < bit_width && cursor.pos < data.length() {
          bits = bits | (data[cursor.pos].to_int() << available)
          available += 8
          cursor.pos += 1
        }
        let mask = if bit_width == 32 { -1 } else { (1 << bit_width) - 1 }
        output.push(bits & mask)
        bits = bits >> bit_width
        available -= bit_width
      }
    }
  }
  output
}

///|
fn ParquetCursor::zigzag(self : ParquetCursor) -> Int64 {
  let value = self.varint()
  (value >> 1) ^ -(value & 1L)
}

///|
fn ParquetCursor::varint(self : ParquetCursor) -> Int64 {
  let mut value = 0L
  let mut shift = 0
  while shift < 64 {
    if self.pos >= self.data.length() { break }
    let byte = self.data[self.pos].to_int()
    self.pos += 1
    value = value | ((byte & 0x7f).to_int64() << shift)
    if (byte & 0x80) == 0 { break }
    shift += 7
  }
  value
}

///|
priv struct ParquetPageHeader {
  mut typ : Int
  mut uncompressed : Int
  mut compressed : Int
  mut num_values : Int
  mut encoding : Int
  mut def_encoding : Int
  mut rep_length : Int
  mut def_length : Int
  mut compressed_values : Bool
}

///|
fn parquet_page_header(data : Bytes, offset : Int) -> (ParquetPageHeader, Int) {
  let reader : ParquetCompact = { data, pos: offset, last: 0 }
  let header : ParquetPageHeader = {
    typ: 0,
    uncompressed: 0,
    compressed: 0,
    num_values: 0,
    encoding: 0,
    def_encoding: 3,
    rep_length: 0,
    def_length: 0,
    compressed_values: true,
  }
  while true {
    let (id, typ) = reader.field()
    if id == 0 { break }
    if id == 1 {
      header.typ = reader.zigzag().to_int()
    } else if id == 2 {
      header.uncompressed = reader.zigzag().to_int()
    } else if id == 3 {
      header.compressed = reader.zigzag().to_int()
    } else if id == 5 || id == 7 {
      let save = reader.last
      reader.last = 0
      while true {
        let (sub, sub_type) = reader.field()
        if sub == 0 { break }
        if sub == 1 { header.num_values = reader.zigzag().to_int() } else if sub == 2 {
          header.encoding = reader.zigzag().to_int()
        } else if sub == 3 && id == 5 {
          header.def_encoding = reader.zigzag().to_int()
        } else {
          reader.skip(sub_type)
        }
      }
      reader.last = save
    } else if id == 8 {
      let save = reader.last
      reader.last = 0
      while true {
        let (sub, sub_type) = reader.field()
        if sub == 0 { break }
        if sub == 1 {
          header.num_values = reader.zigzag().to_int()
        } else if sub == 4 {
          header.encoding = reader.zigzag().to_int()
        } else if sub == 5 {
          header.def_length = reader.zigzag().to_int()
        } else if sub == 6 {
          header.rep_length = reader.zigzag().to_int()
        } else if sub == 7 {
          header.compressed_values = sub_type != 2
        } else {
          reader.skip(sub_type)
        }
      }
      reader.last = save
    } else {
      reader.skip(typ)
    }
  }
  (header, reader.pos)
}

///|
fn parquet_plain(
  data : Bytes,
  physical : Int,
  count : Int,
  type_length~ : Int = 0,
) -> Array[ParquetScalar] {
  let output : Array[ParquetScalar] = []
  let cursor : ParquetCursor = { data, pos: 0 }
  for index in 0..<count {
    if physical == 6 {
      let length = cursor.u32()
      let end = Int::min(cursor.pos + length, data.length())
      output.push(ScalarBytes(data[cursor.pos:end].to_owned()))
      cursor.pos = end
    } else if physical == 7 {
      let length = if type_length > 0 { type_length } else { 16 }
      let end = Int::min(cursor.pos + length, data.length())
      output.push(ScalarBytes(data[cursor.pos:end].to_owned()))
      cursor.pos = end
    } else if physical == 3 {
      if cursor.pos + 12 > data.length() {
        break
      }
      let nanos = (data[cursor.pos].to_int64() |
        (data[cursor.pos + 1].to_int64() << 8) |
        (data[cursor.pos + 2].to_int64() << 16) |
        (data[cursor.pos + 3].to_int64() << 24) |
        (data[cursor.pos + 4].to_int64() << 32) |
        (data[cursor.pos + 5].to_int64() << 40) |
        (data[cursor.pos + 6].to_int64() << 48) |
        (data[cursor.pos + 7].to_int64() << 56))
      let julian = (data[cursor.pos + 8].to_int64() |
        (data[cursor.pos + 9].to_int64() << 8) |
        (data[cursor.pos + 10].to_int64() << 16) |
        (data[cursor.pos + 11].to_int64() << 24))
      output.push(ScalarInt96(nanos, julian))
      cursor.pos += 12
    } else if physical == 5 {
      output.push(ScalarDouble(cursor.f64()))
    } else if physical == 4 {
      output.push(ScalarDouble(cursor.f32().to_double()))
    } else if physical == 2 {
      output.push(ScalarInt(cursor.u64()))
    } else if physical == 1 {
      output.push(ScalarInt(cursor.i32().to_int64()))
    } else if physical == 0 {
      // PLAIN booleans are bit-packed, least significant bit first.
      let byte_index = cursor.pos + index / 8
      if byte_index >= data.length() {
        output.push(ScalarBool(false))
      } else {
        let bit = (data[byte_index].to_int() >> (index % 8)) & 1
        output.push(ScalarBool(bit != 0))
      }
    } else {
      break
    }
  }
  output
}

///|
fn parquet_values(
  data : Bytes,
  physical : Int,
  encoding : Int,
  count : Int,
  dictionary : Array[ParquetScalar],
  type_length~ : Int = 0,
) -> Array[ParquetScalar] raise {
  if encoding == 0 {
    parquet_plain(data, physical, count, type_length~)
  } else if encoding == 5 {
    let (values, _) = parquet_delta_binary(data, count)
    values.map(fn(value) { ScalarInt(value) })
  } else if encoding == 6 {
    let (values, _) = parquet_delta_length(data, count)
    values.map(fn(value) { ScalarBytes(value) })
  } else if encoding == 7 {
    let (values, _) = parquet_delta_byte_array(data, count)
    values.map(fn(value) { ScalarBytes(value) })
  } else if encoding == 9 {
    parquet_byte_stream_split(data, physical, count)
  } else if encoding == 3 {
    let offset = if data.length() >= 4 {
      let length = data[0].to_int() |
        (data[1].to_int() << 8) |
        (data[2].to_int() << 16) |
        (data[3].to_int() << 24)
      if length > 0 && length <= data.length() - 4 { 4 } else { 0 }
    } else {
      0
    }
    let levels = parquet_rle(data[offset:].to_owned(), 1, count)
    levels.map(fn(value) { ScalarBool(value != 0) })
  } else if encoding == 8 || encoding == 2 {
    if data.length() == 0 {
      []
    } else {
      let bit_width = data[0].to_int()
      let indices = parquet_rle(data[1:].to_owned(), bit_width, count)
      let output : Array[ParquetScalar] = []
      for index in indices {
        if index >= 0 && index < dictionary.length() {
          output.push(dictionary[index])
        }
      }
      output
    }
  } else {
    raise Failure("parquet: unsupported value encoding")
  }
}

///|
priv struct ParquetEntries {
  values : Array[ParquetScalar]
  defs : Array[Int]
  reps : Array[Int]
}

///|
fn parquet_bits_needed(level : Int) -> Int {
  if level <= 0 {
    0
  } else {
    let mut bits = 0
    let mut value = level
    while value > 0 {
      bits += 1
      value = value >> 1
    }
    bits
  }
}

///|
fn parquet_decode_column(data : Bytes, meta : ParquetMetaColumn) -> ParquetEntries raise {
  let values : Array[ParquetScalar] = []
  let all_defs : Array[Int] = []
  let all_reps : Array[Int] = []
  let mut dictionary : Array[ParquetScalar] = []
  let mut offset = if meta.has_dictionary { meta.dictionary_offset } else { meta.data_offset }
  let end = (data.length() - 8).to_int64()
  let mut pages = 0
  while values.length() < meta.values.to_int() && offset < end && pages < 100000 {
    pages += 1
    let (header, next) = parquet_page_header(data, offset.to_int())
    if header.compressed <= 0 { break }
    let body_start = next
    let body_end = Int::min(body_start + header.compressed, data.length())
    let raw = data[body_start:body_end].to_owned()
    offset = body_end.to_int64()
    if header.typ == 2 {
      let body = parquet_decompress(raw, meta.codec, header.uncompressed) catch {
        Failure(message) => raise Failure(message)
        _ => raise Failure("parquet: page decompression failed")
      }
      dictionary = parquet_plain(
        body,
        meta.physical,
        header.num_values,
        type_length=meta.type_length,
      )
    } else if header.typ == 0 || header.typ == 3 {
      let defs : Array[Int] = []
      let reps : Array[Int] = []
      let mut value_data : Bytes = b""
      if header.typ == 3 {
        if header.rep_length < 0 || header.def_length < 0 ||
          header.rep_length + header.def_length > raw.length() {
          raise Failure("parquet: invalid DataPageV2 levels")
        }
        let rep_end = header.rep_length
        let def_start = rep_end
        let def_end = def_start + header.def_length
        if meta.max_rep > 0 {
          let decoded = parquet_rle(
            raw[:rep_end].to_owned(),
            parquet_bits_needed(meta.max_rep),
            header.num_values,
          )
          for value in decoded { reps.push(value) }
        } else {
          for _ in 0..<header.num_values { reps.push(0) }
        }
        if meta.max_def > 0 {
          let decoded = parquet_rle(
            raw[def_start:def_end].to_owned(),
            parquet_bits_needed(meta.max_def),
            header.num_values,
          )
          for value in decoded { defs.push(value) }
        } else {
          for _ in 0..<header.num_values { defs.push(0) }
        }
        let codec_data = raw[def_end:].to_owned()
        value_data = if header.compressed_values {
          parquet_decompress(
            codec_data,
            meta.codec,
            header.uncompressed - header.rep_length - header.def_length,
          ) catch {
            Failure(message) => raise Failure(message)
            _ => raise Failure("parquet: page decompression failed")
          }
        } else {
          codec_data
        }
      } else {
        let body = parquet_decompress(raw, meta.codec, header.uncompressed) catch {
          Failure(message) => raise Failure(message)
          _ => raise Failure("parquet: page decompression failed")
        }
        let cursor : ParquetCursor = { data: body, pos: 0 }
        if meta.max_rep > 0 {
          let length = cursor.u32()
          let bytes = body[Int::min(4, body.length()):Int::min(4 + length, body.length())].to_owned()
          let decoded = parquet_rle(
            bytes,
            parquet_bits_needed(meta.max_rep),
            header.num_values,
          )
          for value in decoded { reps.push(value) }
          cursor.pos += length
        } else {
          for _ in 0..<header.num_values { reps.push(0) }
        }
        if meta.max_def > 0 {
          let length = cursor.u32()
          let bytes = body[Int::min(cursor.pos, body.length()):Int::min(cursor.pos + length, body.length())].to_owned()
          let decoded = parquet_rle(
            bytes,
            parquet_bits_needed(meta.max_def),
            header.num_values,
          )
          for value in decoded { defs.push(value) }
          cursor.pos += length
        } else {
          for _ in 0..<header.num_values { defs.push(0) }
        }
        value_data = body[Int::min(cursor.pos, body.length()):].to_owned()
      }
      while defs.length() < header.num_values { defs.push(0) }
      while reps.length() < header.num_values { reps.push(0) }
      let non_null = defs.filter(fn(value) { value == meta.max_def }).length()
      let plain = parquet_values(
        value_data,
        meta.physical,
        header.encoding,
        non_null,
        dictionary,
        type_length=meta.type_length,
      )
      let mut at = 0
      for index in 0..<header.num_values {
        let def = defs[index]
        if reps.length() > index { all_reps.push(reps[index]) } else { all_reps.push(0) }
        all_defs.push(def)
        if def == meta.max_def && at < plain.length() {
          values.push(plain[at])
          at += 1
        } else {
          values.push(ScalarNull)
        }
      }
    }
  }
  { values, defs: all_defs, reps: all_reps }
}

///|
/// The indexes where a new row starts in a leaf's entries: an entry whose
/// repetition level is 0 starts one.
fn parquet_row_starts(entries : ParquetEntries) -> Array[Int] {
  let starts : Array[Int] = []
  for index, rep in entries.reps {
    if rep == 0 {
      starts.push(index)
    }
  }
  starts
}

///|
/// Concatenate the decoded chunk of each row group of a leaf.
fn parquet_leaf_entries(
  data : Bytes,
  chunks : Array[ParquetMetaColumn],
) -> ParquetEntries raise {
  let values : Array[ParquetScalar] = []
  let defs : Array[Int] = []
  let reps : Array[Int] = []
  for chunk in chunks {
    let decoded = try {
      parquet_decode_column(data, chunk)
    } catch {
      Failure(message) => raise InvalidTable(message)
      _ => raise InvalidTable("parquet: invalid column data")
    }
    for value in decoded.values {
      values.push(value)
    }
    for value in decoded.defs {
      defs.push(value)
    }
    for value in decoded.reps {
      reps.push(value)
    }
  }
  { values, defs, reps }
}

///|
/// The digits of the fractions of seconds a column shows: the most any of its
/// values needs, so a column shows all its times alike.
fn parquet_column_digits(
  format : ParquetFormat,
  values : Array[ParquetScalar],
) -> Int {
  match format {
    FormatInt96 | FormatTime(_) | FormatTimestamp(_) => {
      let mut digits = 0
      for value in values {
        if value is ScalarNull {
          continue
        }
        digits = Int::max(digits, parquet_format_digits(format, value))
      }
      digits
    }
    _ => -1
  }
}

///|
fn parquet_leaf_values(
  format : ParquetFormat,
  entries : ParquetEntries,
  row_count : Int,
) -> Array[Value] {
  let digits = parquet_column_digits(format, entries.values)
  let starts = parquet_row_starts(entries)
  let values : Array[Value] = []
  for row in 0..<row_count {
    let scalar = if row < starts.length() && starts[row] < entries.values.length() {
      entries.values[starts[row]]
    } else {
      ScalarNull
    }
    values.push(parquet_scalar_value(format, scalar, digits~))
  }
  values
}

///|
fn parquet_node_leaves(node : ParquetSchemaNode) -> Array[ParquetSchemaNode] {
  let leaves : Array[ParquetSchemaNode] = []
  fn visit(node : ParquetSchemaNode) {
    if node.num_children == 0 {
      leaves.push(node)
    } else {
      for child in node.children {
        visit(child)
      }
    }
  }
  visit(node)
  leaves
}

///|
/// The names of the leaves under a top-level field, in column order.
fn parquet_leaf_name_paths(top : ParquetSchemaNode) -> Array[Array[String]] {
  let output : Array[Array[String]] = []
  fn visit(node : ParquetSchemaNode, path : Array[String]) {
    let next = path + [node.name]
    if node.num_children == 0 {
      output.push(next)
    } else {
      for child in node.children {
        visit(child, next)
      }
    }
  }
  visit(top, [])
  output
}

///|
/// The nodes from a top-level field down to each of its leaves, in column
/// order.
fn parquet_leaf_node_paths(top : ParquetSchemaNode) -> Array[Array[ParquetSchemaNode]] {
  let output : Array[Array[ParquetSchemaNode]] = []
  fn visit(node : ParquetSchemaNode, path : Array[ParquetSchemaNode]) {
    let next = path + [node]
    if node.num_children == 0 {
      output.push(next)
    } else {
      for child in node.children {
        visit(child, next)
      }
    }
  }
  visit(top, [])
  output
}

///|
/// Decode a Parquet table: flat leaves as typed values, and groups, lists,
/// maps and Variants as the JSON text that shows them.
pub fn decode(data : Bytes) -> Table raise {
  let (table, _) = decode_with_warnings(data)
  table
}

///|
/// Decode a Parquet table, and collect the non-fatal problems met (values
/// that cannot be shown, such as unsupported Variant metadata).
pub fn decode_with_warnings(data : Bytes) -> (Table, Array[String]) raise {
  let (root, metadata, row_count, _, _, _) = try {
    parquet_footer(data)
  } catch {
    Failure(message) => raise InvalidTable(message)
    _ => raise InvalidTable("parquet: invalid metadata")
  }
  if metadata.is_empty() {
    raise InvalidTable("parquet: the file has no columns")
  }
  let warnings : Array[String] = []
  let columns : Array[Column] = []
  let column_values : Array[Array[Value]] = []
  for child in root.children {
    let leaves = parquet_node_leaves(child)
    if leaves.is_empty() {
      continue
    }
    let nested = child.num_children > 0 || child.repetition == 2
    let format = parquet_format(parquet_node_format_source(child))
    let kind = if nested {
      StringColumn
    } else {
      parquet_format_kind(format, child.physical)
    }
    let meta_paths = parquet_leaf_name_paths(child)
    let node_paths = parquet_leaf_node_paths(child)
    let values : Array[Value] = []
    if !nested {
      let chunk_path = meta_paths[0]
      let chunks : Array[ParquetMetaColumn] = []
      for meta in metadata {
        if meta.path == chunk_path {
          chunks.push(meta)
        }
      }
      if chunks.is_empty() {
        continue
      }
      let entries = parquet_leaf_entries(data, chunks)
      let leaf_values = parquet_leaf_values(format, entries, row_count.to_int())
      for value in leaf_values {
        values.push(value)
      }
    } else {
      let leaf_chunks : Array[Array[ParquetMetaColumn]] = []
      for path in meta_paths {
        let chunks : Array[ParquetMetaColumn] = []
        for meta in metadata {
          if meta.path == path {
            chunks.push(meta)
          }
        }
        leaf_chunks.push(chunks)
      }
      let leaf_entries : Array[ParquetEntries] = []
      for chunks in leaf_chunks {
        leaf_entries.push(parquet_leaf_entries(data, chunks))
      }
      let leaf_starts : Array[Array[Int]] = []
      for entries in leaf_entries {
        leaf_starts.push(parquet_row_starts(entries))
      }
      let leaf_paths = node_paths
      for row in 0..<row_count.to_int() {
        let cell = Ref(NodeNull)
        for leaf_index in 0..<leaves.length() {
          let entries = leaf_entries[leaf_index]
          let starts = leaf_starts[leaf_index]
          let path = leaf_paths[leaf_index]
          let start = if row < starts.length() { starts[row] } else { entries.values.length() }
          let end = if row + 1 < starts.length() {
            starts[row + 1]
          } else {
            entries.values.length()
          }
          let indices : Array[Int] = []
          for _ in 0..<path.length() {
            indices.push(0)
          }
          for entry in start..<end {
            let rep = if entry < entries.reps.length() {
              entries.reps[entry]
            } else {
              0
            }
            let def = if entry < entries.defs.length() {
              entries.defs[entry]
            } else {
              leaves[leaf_index].def_level
            }
            let scalar = if entry < entries.values.length() {
              entries.values[entry]
            } else {
              ScalarNull
            }
            parquet_nested_indices(path, rep, indices)
            parquet_nested_put(path, 0, cell, def, scalar, indices)
          }
        }
        let text = match cell.val {
          NodeNull => ""
          _ => parquet_render_node(child, cell, warnings, child.name)
        }
        values.push(StringValue(text))
      }
    }
    columns.push({ name: child.name, kind })
    column_values.push(values)
  }
  let rows : Array[Array[Value]] = []
  for index in 0..<row_count.to_int() {
    let row : Array[Value] = []
    for values in column_values {
      row.push(if index < values.length() { values[index] } else { Null })
    }
    rows.push(row)
  }
  ({ columns, rows }, warnings)
}

///|
priv struct ParquetBitReader {
  data : Bytes
  mut pos : Int
  mut bit : Int
}

///|
fn ParquetBitReader::read(self : ParquetBitReader, width : Int) -> Int64 {
  if width <= 0 {
    return 0L
  }
  let mut value = 0L
  for index in 0..<width {
    if self.pos >= self.data.length() {
      break
    }
    let bit = (self.data[self.pos].to_int() >> self.bit) & 1
    value = value | (bit.to_int64() << index)
    self.bit += 1
    if self.bit == 8 {
      self.bit = 0
      self.pos += 1
    }
  }
  value
}

///|
fn parquet_delta_binary(data : Bytes, count : Int) -> (Array[Int64], Int) {
  let output : Array[Int64] = []
  if count <= 0 {
    return (output, 0)
  }
  let cursor : ParquetCursor = { data, pos: 0 }
  let block_size = cursor.varint().to_int()
  let miniblocks = cursor.varint().to_int()
  let total = cursor.varint().to_int()
  if block_size <= 0 || miniblocks <= 0 || total < 0 || miniblocks > block_size {
    return (output, cursor.pos)
  }
  let first = cursor.zigzag()
  output.push(first)
  let mut previous = first
  let per_miniblock = block_size / miniblocks
  let wanted = Int::min(count, total)
  while output.length() < wanted && cursor.pos < data.length() {
    let min_delta = cursor.zigzag()
    let widths : Array[Int] = []
    for _ in 0..<miniblocks {
      if cursor.pos < data.length() {
        widths.push(data[cursor.pos].to_int())
        cursor.pos += 1
      }
    }
    for width in widths {
      if output.length() >= wanted {
        break
      }
      let reader : ParquetBitReader = { data, pos: cursor.pos, bit: 0 }
      let mut used = 0
      while used < per_miniblock && output.length() < wanted {
        let delta = reader.read(width)
        previous = previous + min_delta + delta
        output.push(previous)
        used += 1
      }
      // A miniblock is padded to its full size, even when only part of it is
      // used; the miniblocks after the last value have no body at all.
      cursor.pos = cursor.pos + (per_miniblock * width + 7) / 8
    }
  }
  (output, cursor.pos)
}

///|
fn parquet_delta_length(data : Bytes, count : Int) -> (Array[Bytes], Int) {
  let (lengths, consumed) = parquet_delta_binary(data, count)
  let output : Array[Bytes] = []
  let mut pos = consumed
  for length in lengths {
    let size = if length < 0L || length > 268435456L { 0 } else { length.to_int() }
    let end = Int::min(pos + size, data.length())
    output.push(data[pos:end].to_owned())
    pos = end
  }
  (output, pos)
}

///|
fn parquet_delta_byte_array(data : Bytes, count : Int) -> (Array[Bytes], Int) {
  let (prefixes, prefix_end) = parquet_delta_binary(data, count)
  let (suffixes, suffix_end) = parquet_delta_length(
    data[prefix_end:].to_owned(),
    count,
  )
  let output : Array[Bytes] = []
  let mut previous : Bytes = b""
  for index in 0..<prefixes.length() {
    let prefix_size = if prefixes[index] < 0L || prefixes[index] > 268435456L {
      0
    } else {
      prefixes[index].to_int()
    }
    let prefix = if prefix_size < previous.length() {
      previous[:prefix_size].to_owned()
    } else {
      previous
    }
    let suffix = match suffixes.get(index) {
      Some(value) => value
      None => b""
    }
    previous = prefix + suffix
    output.push(previous)
  }
  (output, prefix_end + suffix_end)
}

///|
fn parquet_byte_stream_split(
  data : Bytes,
  physical : Int,
  count : Int,
) -> Array[ParquetScalar] {
  let width = if physical == 5 || physical == 2 {
    8
  } else if physical == 4 || physical == 1 {
    4
  } else {
    0
  }
  let output : Array[ParquetScalar] = []
  if width == 0 || data.length() < width * count {
    return output
  }
  for index in 0..<count {
    let mut bits = 0UL
    for lane in 0..<width {
      bits = bits | (data[lane * count + index].to_uint64() << (lane * 8))
    }
    if physical == 5 {
      output.push(ScalarDouble(bits.reinterpret_as_double()))
    } else if physical == 4 {
      output.push(
        ScalarDouble(
          Float::reinterpret_from_uint(bits.to_int().reinterpret_as_uint()).to_double(),
        ),
      )
    } else if physical == 2 {
      output.push(ScalarInt(bits.reinterpret_as_int64()))
    } else {
      output.push(ScalarInt(bits.to_int().to_int64()))
    }
  }
  output
}


///|
pub(all) struct FileInfo {
  rows : Int64
  columns : Int
  row_groups : Int
  codecs : Array[String]
  created_by : String
}

///|
fn parquet_codec_name(codec : Int) -> String {
  match codec {
    0 => "uncompressed"
    1 => "Snappy"
    2 => "GZIP"
    4 => "Brotli"
    5 => "LZ4"
    6 => "Zstandard"
    7 => "LZ4_RAW"
    _ => "codec" + codec.to_string()
  }
}

///|
pub fn info(data : Bytes) -> FileInfo raise {
  let (root, metadata, rows, row_groups, created_by, _) = parquet_footer(data) catch {
    Failure(message) => raise InvalidTable(message)
    _ => raise InvalidTable("parquet: invalid metadata")
  }
  let codecs : Array[String] = []
  for meta in metadata {
    let name = parquet_codec_name(meta.codec)
    if !codecs.contains(name) {
      codecs.push(name)
    }
  }
  {
    rows,
    columns: root.children.length(),
    row_groups,
    codecs,
    created_by,
  }
}
