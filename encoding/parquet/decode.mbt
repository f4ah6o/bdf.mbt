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
fn parquet_schema_element(reader : ParquetCompact) -> ParquetSchemaNode {
  let mut name = ""
  let mut physical = -1
  let mut converted = -1
  let mut repetition = 0
  let mut num_children = 0
  let mut type_length = 0
  let mut scale = 0
  let mut precision = 0
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
      10 => {
        let save_type = reader.last
        reader.last = 0
        while true {
          let (logical_id, logical_typ) = reader.field()
          if logical_id == 0 { break }
          if logical_id == 5 {
            let save_decimal = reader.last
            reader.last = 0
            while true {
              let (decimal_id, decimal_typ) = reader.field()
              if decimal_id == 0 { break }
              if decimal_id == 1 {
                scale = reader.zigzag().to_int()
              } else if decimal_id == 2 {
                precision = reader.zigzag().to_int()
              } else {
                reader.skip(decimal_typ)
              }
            }
            reader.last = save_decimal
          } else {
            reader.skip(logical_typ)
          }
        }
        reader.last = save_type
      }
      _ => reader.skip(typ)
    }
  }
  reader.last = save
  { name, physical, converted, repetition, num_children, type_length, scale, precision, children: [] }
}

///|
fn parquet_schema_tree(elements : Array[ParquetSchemaNode]) -> ParquetSchemaNode {
  let index : Array[Int] = [0]
  fn build() -> ParquetSchemaNode {
    let position = index[0]
    index[0] += 1
    let element = if position < elements.length() {
      elements[position]
    } else {
      { name: "", physical: -1, converted: -1, repetition: 0, num_children: 0, type_length: 0, scale: 0, precision: 0, children: [] }
    }
    let children : Array[ParquetSchemaNode] = []
    for _ in 0..<element.num_children {
      children.push(build())
    }
    { ..element, children }
  }
  build()
}

///|
fn parquet_schema_leaves(
  node : ParquetSchemaNode,
  path : Array[String],
  rep : Int,
  def : Int,
  output : Array[ParquetMetaColumn],
) -> Unit {
  let next_rep = rep + (if node.repetition == 2 { 1 } else { 0 })
  let next_def = def + (if node.repetition == 0 { 0 } else { 1 })
  let next_path = path + [node.name]
  if node.num_children == 0 {
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
      scale: node.scale,
      precision: node.precision,
      max_rep: next_rep,
      max_def: next_def,
    })
  } else {
    for child in node.children {
      parquet_schema_leaves(child, next_path, next_rep, next_def, output)
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
fn parquet_footer(data : Bytes) -> (ParquetSchemaNode, Array[ParquetMetaColumn], Int64) raise {
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
  let mut rows = 0L
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
    } else {
      reader.skip(typ)
    }
  }
  let root = parquet_schema_tree(schema)
  let leaves : Array[ParquetMetaColumn] = []
  for child in root.children {
    parquet_schema_leaves(child, [], 0, 0, leaves)
  }
  for index in 0..<columns.length() {
    for leaf in leaves {
      if columns[index].path == leaf.path {
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
        }
      }
    }
  }
  (root, columns, rows)
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
fn parquet_decimal_text(data : Bytes, scale : Int) -> String {
  let value = parquet_decimal(data, scale)
  let text = value.to_string()
  if scale <= 0 {
    return text
  }
  let parts = text.split(".").collect()
  let mut whole = if parts.is_empty() { "0" } else { parts[0].to_owned() }
  let mut fraction = if parts.length() > 1 { parts[1].to_owned() } else { "" }
  if whole == "-0" {
    whole = "0"
  }
  while fraction.length() < scale {
    fraction = fraction + "0"
  }
  if fraction.length() > scale {
    fraction = fraction[:scale].to_owned()
  }
  whole + "." + fraction
}

///|
fn parquet_decimal(data : Bytes, scale : Int) -> Double {
  let mut value = 0L
  for byte in data {
    value = (value << 8) | byte.to_int64()
  }
  // Sign-extend the big-endian two's-complement value.
  let bits = data.length() * 8
  if bits > 0 && bits < 64 && (value & (1L << (bits - 1))) != 0L {
    value = value - (1L << bits)
  }
  value.to_double() / @math.pow(10.0, scale.to_double())
}

///|
fn parquet_plain(
  data : Bytes,
  physical : Int,
  count : Int,
  type_length~ : Int = 0,
  scale~ : Int = 0,
) -> Array[Value] {
  let output : Array[Value] = []
  let cursor : ParquetCursor = { data, pos: 0 }
  for _ in 0..<count {
    if physical == 6 {
      let length = cursor.u32()
      let end = Int::min(cursor.pos + length, data.length())
      if scale > 0 && type_length == 0 {
        output.push(StringValue(parquet_decimal_text(data[cursor.pos:end].to_owned(), scale)))
      } else {
        let text = @utf8.decode_lossy(data[cursor.pos:end])
        output.push(StringValue(text))
      }
      cursor.pos = end
    } else if physical == 7 {
      let length = if type_length > 0 { type_length } else { 16 }
      let end = Int::min(cursor.pos + length, data.length())
      if scale > 0 {
        output.push(StringValue(parquet_decimal_text(data[cursor.pos:end].to_owned(), scale)))
      } else {
        output.push(StringValue(@utf8.decode_lossy(data[cursor.pos:end])))
      }
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
      let julian = data[cursor.pos + 8].to_int() |
        (data[cursor.pos + 9].to_int() << 8) |
        (data[cursor.pos + 10].to_int() << 16) |
        (data[cursor.pos + 11].to_int() << 24)
      let days = (julian - 2440588).to_int64()
      output.push(DateTimeValue(days * 86400000L + nanos / 1000000L))
      cursor.pos += 12
    } else if physical == 5 {
      output.push(NumberValue(cursor.f64()))
    } else if physical == 2 {
      output.push(IntegerValue(cursor.u64()))
    } else if physical == 1 {
      output.push(IntegerValue(cursor.i32().to_int64()))
    } else if physical == 0 {
      if cursor.pos >= data.length() { output.push(BooleanValue(false)); continue }
      let byte = data[cursor.pos].to_int()
      output.push(BooleanValue((byte & 1) != 0))
      cursor.pos += 1
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
  dictionary : Array[Value],
  type_length~ : Int = 0,
  scale~ : Int = 0,
) -> Array[Value] raise {
  if encoding == 0 {
    parquet_plain(data, physical, count, type_length~, scale~)
  } else if encoding == 5 {
    let (values, _) = parquet_delta_binary(data, count)
    values.map(fn(value) { IntegerValue(value) })
  } else if encoding == 6 {
    let (values, _) = parquet_delta_length(data, count)
    values
  } else if encoding == 7 {
    let (values, _) = parquet_delta_byte_array(data, count)
    values
  } else if encoding == 9 {
    parquet_byte_stream_split(data, physical, count)
  } else if encoding == 3 {
    let offset = if data.length() >= 4 {
      let length = (data[0].to_int() << 24) |
        (data[1].to_int() << 16) |
        (data[2].to_int() << 8) |
        data[3].to_int()
      if length > 0 && length <= data.length() - 4 { 4 } else { 0 }
    } else {
      0
    }
    let levels = parquet_rle(data[offset:].to_owned(), 1, count)
    levels.map(fn(value) { BooleanValue(value != 0) })
  } else if encoding == 8 || encoding == 2 {
    if data.length() == 0 {
      []
    } else {
      let bit_width = data[0].to_int()
      let indices = parquet_rle(data[1:].to_owned(), bit_width, count)
      let output : Array[Value] = []
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
  values : Array[Value]
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
  let values : Array[Value] = []
  let all_defs : Array[Int] = []
  let all_reps : Array[Int] = []
  let mut dictionary : Array[Value] = []
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
        scale=meta.scale,
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
        scale=meta.scale,
      )
      let mapped = plain.map(fn(value) {
        match (meta.converted, value) {
          (6, IntegerValue(number)) => DateValue(number)
          (9, IntegerValue(number)) => DateTimeValue(number)
          (10, IntegerValue(number)) => DateTimeValue(number / 1000L)
          (_, _) => value
        }
      })
      let mut at = 0
      for index in 0..<header.num_values {
        let def = defs[index]
        if reps.length() > index { all_reps.push(reps[index]) } else { all_reps.push(0) }
        all_defs.push(def)
        if def == meta.max_def && at < mapped.length() {
          values.push(mapped[at])
          at += 1
        } else {
          values.push(Null)
        }
      }
    }
  }
  { values, defs: all_defs, reps: all_reps }
}

///|
fn parquet_entries_rows(entries : ParquetEntries, meta : ParquetMetaColumn, row_count : Int) -> Array[Array[Value]] {
  let rows : Array[Array[Value]] = []
  if meta.max_rep == 0 {
    for index in 0..<row_count {
      if index < entries.values.length() {
        rows.push([entries.values[index]])
      } else {
        rows.push([Null])
      }
    }
    return rows
  }
  let current : Array[Value] = []
  for index in 0..<entries.values.length() {
    let rep = if index < entries.reps.length() { entries.reps[index] } else { 0 }
    if rep == 0 && !current.is_empty() {
      rows.push(current.copy())
      current.clear()
    }
    let def = if index < entries.defs.length() { entries.defs[index] } else { meta.max_def }
    if def == meta.max_def {
      current.push(entries.values[index])
    }
  }
  if !current.is_empty() || rows.length() < row_count {
    rows.push(current.copy())
  }
  while rows.length() < row_count {
    rows.push([])
  }
  if rows.length() > row_count {
    while rows.length() > row_count { rows.pop() |> ignore }
  }
  rows
}

///|
fn parquet_kind(physical : Int, converted : Int) -> ColumnType {
  if physical == 6 {
    StringColumn
  } else if physical == 5 {
    NumberColumn
  } else if physical == 0 {
    BooleanColumn
  } else if physical == 3 || converted == 9 {
    DateTimeColumn
  } else if converted == 5 {
    StringColumn
  } else if converted == 6 {
    DateColumn
  } else {
    IntegerColumn
  }
}

///|
fn parquet_value_json(value : Value) -> String {
  match value {
    Null => "null"
    StringValue(text) => "\"" + text + "\""
    NumberValue(number) => number.to_string()
    IntegerValue(number) => number.to_string()
    BooleanValue(flag) => if flag { "true" } else { "false" }
    DateValue(days) => days.to_string()
    DateTimeValue(millis) => millis.to_string()
  }
}

///|
/// Decode a flat Parquet table.
pub fn decode(data : Bytes) -> Table raise {
  let (root, metadata, row_count) = try {
    parquet_footer(data)
  } catch {
    Failure(message) => raise InvalidTable(message)
    _ => raise InvalidTable("parquet: invalid metadata")
  }
  if metadata.is_empty() {
    raise InvalidTable("parquet: the file has no columns")
  }
  let columns : Array[Column] = []
  let column_values : Array[Array[Value]] = []
  for child in root.children {
    let group : Array[ParquetMetaColumn] = []
    for meta in metadata {
      if !meta.path.is_empty() && meta.path[0] == child.name {
        group.push(meta)
      }
    }
    if group.is_empty() {
      continue
    }
    let kind = if child.num_children > 0 {
      StringColumn
    } else {
      parquet_kind(group[0].physical, group[0].converted)
    }
    columns.push({ name: child.name, kind })
    let arrays : Array[Array[Array[Value]]] = []
    let mut repeated = false
    for meta in group {
      let decoded = try {
        parquet_decode_column(data, meta)
      } catch {
        Failure(message) => raise InvalidTable(message)
        _ => raise InvalidTable("parquet: invalid column data")
      }
      if meta.max_rep > 0 { repeated = true }
      arrays.push(parquet_entries_rows(decoded, meta, row_count.to_int()))
    }
    let values : Array[Value] = []
    for index in 0..<row_count.to_int() {
      if repeated {
        let items : Array[String] = []
        for leaf_index, meta in group {
          let entries = if index < arrays[leaf_index].length() { arrays[leaf_index][index] } else { [] }
          for value in entries {
            items.push(parquet_value_json(value))
          }
        }
        values.push(StringValue("[" + items.join(", ") + "]"))
      } else if arrays.length() == 1 {
        values.push(if index < arrays[0].length() && arrays[0][index].length() > 0 {
          arrays[0][index][0]
        } else {
          Null
        })
      } else {
        let fields : Array[String] = []
        for leaf_index, meta in group {
          let value = if index < arrays[leaf_index].length() && arrays[leaf_index][index].length() > 0 {
            arrays[leaf_index][index][0]
          } else {
            Null
          }
          let field_name = if meta.path.is_empty() {
            meta.name
          } else {
            meta.path[meta.path.length() - 1]
          }
          fields.push("\"" + field_name + "\": " + parquet_value_json(value))
        }
        values.push(StringValue("{" + fields.join(", ") + "}"))
      }
    }
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
  { columns, rows }
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
      if output.length() < wanted {
        let reader : ParquetBitReader = { data, pos: cursor.pos, bit: 0 }
        let mut used = 0
        while used < per_miniblock && output.length() < wanted {
          let delta = reader.read(width)
          previous = previous + min_delta + delta
          output.push(previous)
          used += 1
        }
        cursor.pos = reader.pos + (if reader.bit > 0 { 1 } else { 0 })
      }
    }
  }
  (output, cursor.pos)
}

///|
fn parquet_delta_length(data : Bytes, count : Int) -> (Array[Value], Int) {
  let (lengths, consumed) = parquet_delta_binary(data, count)
  let output : Array[Value] = []
  let mut pos = consumed
  for length in lengths {
    let size = if length < 0L || length > 268435456L { 0 } else { length.to_int() }
    let end = Int::min(pos + size, data.length())
    output.push(StringValue(@utf8.decode_lossy(data[pos:end])))
    pos = end
  }
  (output, pos)
}

///|
fn parquet_delta_byte_array(data : Bytes, count : Int) -> (Array[Value], Int) {
  let (prefixes, prefix_end) = parquet_delta_binary(data, count)
  let (suffixes, suffix_end) = parquet_delta_length(data[prefix_end:].to_owned(), count)
  let output : Array[Value] = []
  let mut previous = ""
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
      Some(StringValue(value)) => value
      _ => ""
    }
    previous = prefix + suffix
    output.push(StringValue(previous))
  }
  (output, prefix_end + suffix_end)
}

///|
fn parquet_byte_stream_split(data : Bytes, physical : Int, count : Int) -> Array[Value] {
  let width = if physical == 5 || physical == 2 {
    8
  } else if physical == 4 || physical == 1 {
    4
  } else {
    0
  }
  let output : Array[Value] = []
  if width == 0 || data.length() < width * count {
    return output
  }
  for index in 0..<count {
    let mut bits = 0UL
    for lane in 0..<width {
      bits = bits | (data[lane * count + index].to_uint64() << (lane * 8))
    }
    if physical == 5 {
      output.push(NumberValue(bits.reinterpret_as_double()))
    } else if physical == 4 {
      output.push(NumberValue(Float::reinterpret_from_uint(bits.to_int().to_uint()).to_double()))
    } else if physical == 2 {
      output.push(IntegerValue(bits.reinterpret_as_int64()))
    } else {
      output.push(IntegerValue(bits.to_int().to_int64()))
    }
  }
  output
}

