///|
priv struct ParquetMetaColumn {
  mut name : String
  mut physical : Int
  mut converted : Int
  mut optional : Bool
  values : Int64
  codec : Int
  encodings : Array[Int]
  mut data_offset : Int64
  dictionary_offset : Int64
  has_dictionary : Bool
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
fn parquet_schema_element(reader : ParquetCompact) -> (String, Int, Int, Bool) {
  let mut name = ""
  let mut physical = -1
  let mut converted = -1
  let mut optional = false
  let save = reader.last
  reader.last = 0
  while true {
    let (id, typ) = reader.field()
    if id == 0 {
      break
    }
    match id {
      1 => physical = reader.zigzag().to_int()
      3 => optional = reader.zigzag().to_int() == 1
      4 => name = @utf8.decode_lossy(reader.binary())
      6 => converted = reader.zigzag().to_int()
      10 => reader.skip(typ)
      _ => reader.skip(typ)
    }
  }
  reader.last = save
  (name, physical, converted, optional)
}

///|
fn parquet_column_metadata(reader : ParquetCompact) -> ParquetMetaColumn {
  let mut name = ""
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
fn parquet_footer(data : Bytes) -> (Array[ParquetMetaColumn], Int64) raise {
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
  let schema : Array[(String, Int, Int, Bool)] = []
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
  for index in 0..<columns.length() {
    if index + 1 < schema.length() {
      columns[index].name = schema[index + 1].0
      columns[index].physical = schema[index + 1].1
      columns[index].converted = schema[index + 1].2
      columns[index].optional = schema[index + 1].3
    }
  }
  (columns, rows)
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
}

///|
fn parquet_page_header(data : Bytes, offset : Int) -> (ParquetPageHeader, Int) {
  let reader : ParquetCompact = { data, pos: offset, last: 0 }
  let header : ParquetPageHeader = {
    typ: 0, uncompressed: 0, compressed: 0, num_values: 0, encoding: 0, def_encoding: 3,
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
    } else if id == 5 {
      let save = reader.last
      reader.last = 0
      while true {
        let (sub, sub_type) = reader.field()
        if sub == 0 { break }
        if sub == 1 { header.num_values = reader.zigzag().to_int() } else if sub == 2 {
          header.encoding = reader.zigzag().to_int()
        } else if sub == 3 {
          header.def_encoding = reader.zigzag().to_int()
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
fn parquet_plain(data : Bytes, physical : Int, count : Int) -> Array[Value] {
  let output : Array[Value] = []
  let cursor : ParquetCursor = { data, pos: 0 }
  for _ in 0..<count {
    if physical == 6 {
      let length = cursor.u32()
      let end = Int::min(cursor.pos + length, data.length())
      let text = @utf8.decode_lossy(data[cursor.pos:end])
      cursor.pos = end
      output.push(StringValue(text))
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
fn parquet_decode_column(data : Bytes, meta : ParquetMetaColumn) -> Array[Value] raise {
  if meta.codec != 0 {
    raise Failure("parquet: only uncompressed columns are supported")
  }
  let values : Array[Value] = []
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
    let body = data[body_start:body_end].to_owned()
    offset = body_end.to_int64()
    if header.typ == 2 {
      dictionary = parquet_plain(body, meta.physical, header.num_values)
    } else if header.typ == 0 {
      let cursor : ParquetCursor = { data: body, pos: 0 }
      let def_length = cursor.u32()
      let def_bytes = body[Int::min(4, body.length()):Int::min(4 + def_length, body.length())].to_owned()
      let defs = if meta.optional {
        parquet_rle(def_bytes, 1, header.num_values)
      } else {
        let output : Array[Int] = []
        for _ in 0..<header.num_values { output.push(1) }
        output
      }
      let value_start = Int::min(4 + def_length, body.length())
      let value_data = body[value_start:].to_owned()
      let non_null = defs.filter(fn(value) { value != 0 }).length()
      let plain = if header.encoding == 0 {
        parquet_plain(value_data, meta.physical, non_null)
      } else if header.encoding == 8 || header.encoding == 2 {
        if value_data.length() == 0 {
          []
        } else {
          let bit_width = value_data[0].to_int()
          let indices = parquet_rle(value_data[1:].to_owned(), bit_width, non_null)
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
      let mut at = 0
      for def in defs {
        if def == 0 {
          values.push(Null)
        } else if at < plain.length() {
          values.push(plain[at])
          at += 1
        } else {
          values.push(Null)
        }
      }
    }
  }
  values
}

///|
/// Decode a flat Parquet table.
pub fn decode(data : Bytes) -> Table raise {
  let (metadata, row_count) = try {
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
  for meta in metadata {
    let kind = if meta.physical == 6 {
      StringColumn
    } else if meta.physical == 5 {
      NumberColumn
    } else if meta.physical == 0 {
      BooleanColumn
    } else if meta.converted == 6 {
      DateColumn
    } else if meta.converted == 9 {
      DateTimeColumn
    } else {
      IntegerColumn
    }
    columns.push({ name: meta.name, kind })
    let decoded = try {
      parquet_decode_column(data, meta)
    } catch {
      Failure(message) => raise InvalidTable(message)
      _ => raise InvalidTable("parquet: invalid column data")
    }
    column_values.push(decoded)
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
