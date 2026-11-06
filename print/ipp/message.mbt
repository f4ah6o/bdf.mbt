///|
pub suberror IppError {
  IppError(String)
}

///|
pub fn fail(message : String) -> Unit raise IppError {
  raise IppError(message)
}

///|
pub(all) struct Value {
  tag : Tag
  int : Int
  str : String
  lang : String
  raw : Bytes
  time : Bytes
  res : (Int, Int, Int)?
  range : (Int, Int)?
  coll : Array[Attribute]?
}

///|
pub fn integer(value : Int) -> Value {
  {
    tag: TAG_INTEGER,
    int: value,
    str: "",
    lang: "",
    raw: Bytes::new(0),
    time: Bytes::new(0),
    res: None,
    range: None,
    coll: None,
  }
}

///|
pub fn boolean(value : Bool) -> Value {
  { ..integer(if value { 1 } else { 0 }), tag: TAG_BOOLEAN }
}

///|
pub fn enum_value(value : Int) -> Value {
  { ..integer(value), tag: TAG_ENUM }
}

///|
fn string_value(tag : Tag, value : String) -> Value {
  { ..integer(0), tag, str: value }
}

///|
pub fn keyword(value : String) -> Value { string_value(TAG_KEYWORD, value) }
pub fn name(value : String) -> Value { string_value(TAG_NAME, value) }
pub fn text(value : String) -> Value { string_value(TAG_TEXT, value) }
pub fn uri(value : String) -> Value { string_value(TAG_URI, value) }
pub fn uri_scheme(value : String) -> Value { string_value(TAG_URI_SCHEME, value) }
pub fn charset(value : String) -> Value { string_value(TAG_CHARSET, value) }
pub fn language(value : String) -> Value { string_value(TAG_LANGUAGE, value) }
pub fn mime_type(value : String) -> Value { string_value(TAG_MIME_TYPE, value) }
pub fn octet_string(value : Bytes) -> Value {
  { ..string_value(TAG_OCTET_STRING, @utf8.decode_lossy(value)), raw: value }
}

///|
pub fn text_lang(lang : String, value : String) -> Value {
  { ..string_value(TAG_TEXT_LANG, value), lang }
}

///|
pub fn name_lang(lang : String, value : String) -> Value {
  { ..string_value(TAG_NAME_LANG, value), lang }
}

///|
pub fn resolution(x : Int, y : Int, units : Int) -> Value {
  { ..integer(0), tag: TAG_RESOLUTION, res: Some((x, y, units)) }
}

///|
pub fn range(lo : Int, hi : Int) -> Value {
  { ..integer(0), tag: TAG_RANGE, range: Some((lo, hi)) }
}

///|
pub fn date_time(value : Bytes) -> Value {
  { ..integer(0), tag: TAG_DATE_TIME, time: value }
}

///|
pub fn collection(members : Array[Attribute]) -> Value {
  { ..integer(0), tag: TAG_BEGIN_COLLECTION, coll: Some(members) }
}

///|
pub fn out_of_band(tag : Tag) -> Value {
  { ..integer(0), tag }
}

///|
pub fn Value::bool(self : Value) -> Bool {
  self.int != 0
}

///|
pub(all) struct Attribute {
  name : String
  values : Array[Value]
}

///|
pub fn attr(name : String, values : Array[Value]) -> Attribute {
  { name, values }
}

///|
pub(all) struct Group {
  tag : Tag
  attrs : Array[Attribute]
}

///|
pub(all) struct Message {
  mut major : Int
  mut minor : Int
  code : Int
  request_id : Int
  groups : Array[Group]
}

///|
pub fn new_request(op : Int, id : Int, charset_value : String, lang : String) -> Message {
  let charset_value = if charset_value == "" { "utf-8" } else { charset_value }
  let lang = if lang == "" { "en" } else { lang }
  {
    major: 2,
    minor: 0,
    code: op,
    request_id: id,
    groups: [
      {
        tag: TAG_OPERATION,
        attrs: [
          attr("attributes-charset", [charset(charset_value)]),
          attr("attributes-natural-language", [language(lang)]),
        ],
      },
    ],
  }
}

///|
pub fn new_response(status : Int, id : Int, charset_value : String, lang : String) -> Message {
  new_request(status, id, charset_value, lang)
}

///|
pub fn Message::add(self : Message, tag : Tag, attrs : Array[Attribute]) -> Unit {
  for group in self.groups {
    if group.tag == tag {
      for attribute in attrs {
        group.attrs.push(attribute)
      }
      return
    }
  }
  self.groups.push({ tag, attrs })
}

///|
fn put_u16(out : Array[Byte], value : Int) -> Unit {
  out.push(((value >> 8) & 0xff).to_byte())
  out.push((value & 0xff).to_byte())
}

///|
fn put_u32(out : Array[Byte], value : Int) -> Unit {
  out.push(((value >> 24) & 0xff).to_byte())
  out.push(((value >> 16) & 0xff).to_byte())
  out.push(((value >> 8) & 0xff).to_byte())
  out.push((value & 0xff).to_byte())
}

///|
fn value_bytes(value : Value) -> Bytes raise IppError {
  let tag = value.tag
  if tag == TAG_BOOLEAN {
    Bytes::from_array([if value.int != 0 { b'\x01' } else { b'\x00' }])
  } else if tag == TAG_INTEGER || tag == TAG_ENUM {
    let out : Array[Byte] = []
    put_u32(out, value.int)
    Bytes::from_array(out)
  } else if tag == TAG_DATE_TIME {
    if value.time.length() != 11 {
      raise IppError("ipp: a dateTime is 11 bytes")
    }
    value.time
  } else if tag == TAG_RESOLUTION {
    match value.res {
      Some((x, y, units)) => {
        let out : Array[Byte] = []
        put_u32(out, x)
        put_u32(out, y)
        out.push(units.to_byte())
        Bytes::from_array(out)
      }
      None => raise IppError("ipp: a resolution without a value")
    }
  } else if tag == TAG_RANGE {
    match value.range {
      Some((lo, hi)) => {
        let out : Array[Byte] = []
        put_u32(out, lo)
        put_u32(out, hi)
        Bytes::from_array(out)
      }
      None => raise IppError("ipp: a range without a value")
    }
  } else if tag == TAG_TEXT_LANG || tag == TAG_NAME_LANG {
    let out : Array[Byte] = []
    let lang = @utf8.encode(value.lang)
    put_u16(out, lang.length())
    for byte in lang {
      out.push(byte)
    }
    let text = @utf8.encode(value.str)
    put_u16(out, text.length())
    for byte in text {
      out.push(byte)
    }
    Bytes::from_array(out)
  } else if tag_is_out_of_band(tag) {
    Bytes::new(0)
  } else if tag == TAG_BEGIN_COLLECTION || tag == TAG_END_COLLECTION {
    raise IppError("ipp: collections are not encoded yet")
  } else if tag_is_string(tag) || tag == TAG_OCTET_STRING {
    let bytes = if tag == TAG_OCTET_STRING && value.raw.length() > 0 {
      value.raw
    } else {
      @utf8.encode(value.str)
    }
    bytes
  } else if value.raw.length() > 0 {
    value.raw
  } else {
    @utf8.encode(value.str)
  }
}

///|
fn append_value(out : Array[Byte], value : Value, name : String) -> Unit raise IppError {
  let name_bytes = @utf8.encode(name)
  if name_bytes.length() > 65535 {
    raise IppError("ipp: the attribute name is too long")
  }
  out.push(value.tag)
  put_u16(out, name_bytes.length())
  for byte in name_bytes {
    out.push(byte)
  }
  if value.tag == TAG_BEGIN_COLLECTION {
    put_u16(out, 0)
    let members = match value.coll {
      Some(values) => values
      None => []
    }
    for member in members {
      let member_name = @utf8.encode(member.name)
      out.push(TAG_MEMBER_NAME)
      put_u16(out, 0)
      put_u16(out, member_name.length())
      for byte in member_name {
        out.push(byte)
      }
      for value in member.values {
        append_value(out, value, "")
      }
    }
    out.push(TAG_END_COLLECTION)
    put_u16(out, 0)
    put_u16(out, 0)
    return
  }
  let bytes = value_bytes(value)
  if bytes.length() > 65535 {
    raise IppError("ipp: the value is too long")
  }
  put_u16(out, bytes.length())
  for byte in bytes {
    out.push(byte)
  }
}

///|
pub fn Message::encode(self : Message) -> Bytes raise IppError {
  let out : Array[Byte] = []
  out.push(self.major.to_byte())
  out.push(self.minor.to_byte())
  put_u16(out, self.code)
  put_u32(out, self.request_id)
  for group in self.groups {
    if !tag_is_group(group.tag) || group.tag == TAG_END {
      raise IppError("ipp: " + tag_name(group.tag) + " is not a group tag")
    }
    out.push(group.tag)
    for attribute in group.attrs {
      if attribute.name == "" {
        raise IppError("ipp: an empty attribute name")
      }
      for i, value in attribute.values {
        append_value(out, value, if i == 0 { attribute.name } else { "" })
      }
    }
  }
  out.push(TAG_END)
  Bytes::from_array(out)
}

///|
fn read_u16(data : Bytes, pos : Int) -> Int raise IppError {
  if pos + 2 > data.length() {
    raise IppError("ipp: the message is cut")
  }
  (data[pos].to_int() << 8) | data[pos + 1].to_int()
}

///|
fn read_u32(data : Bytes, pos : Int) -> Int raise IppError {
  if pos + 4 > data.length() {
    raise IppError("ipp: the message is cut")
  }
  (data[pos].to_int() << 24) |
  (data[pos + 1].to_int() << 16) |
  (data[pos + 2].to_int() << 8) |
  data[pos + 3].to_int()
}

///|
fn signed_u32(value : Int) -> Int {
  if value > 0x7fffffff { value - 0x7fffffff - 1 } else { value }
}

///|
fn decode_value(tag : Tag, data : Bytes) -> Value raise IppError {
  if tag == TAG_BOOLEAN {
    if data.length() != 1 {
      raise IppError("ipp: a boolean value is not one byte")
    }
    { ..integer(if data[0] != 0 { 1 } else { 0 }), tag }
  } else if tag == TAG_INTEGER || tag == TAG_ENUM {
    if data.length() != 4 {
      raise IppError("ipp: an integer value is not four bytes")
    }
    { ..integer(signed_u32(read_u32(data, 0))), tag }
  } else if tag == TAG_DATE_TIME {
    if data.length() != 11 {
      raise IppError("ipp: a dateTime value is not 11 bytes")
    }
    date_time(data)
  } else if tag == TAG_RESOLUTION {
    if data.length() != 9 {
      raise IppError("ipp: a resolution value is not 9 bytes")
    }
    resolution(read_u32(data, 0), read_u32(data, 4), data[8].to_int())
  } else if tag == TAG_RANGE {
    if data.length() != 8 {
      raise IppError("ipp: a range value is not 8 bytes")
    }
    range(read_u32(data, 0), read_u32(data, 4))
  } else if tag == TAG_TEXT_LANG || tag == TAG_NAME_LANG {
    let lang_len = read_u16(data, 0)
    if 2 + lang_len + 2 > data.length() {
      raise IppError("ipp: a language value is cut")
    }
    let lang = @utf8.decode_lossy(data[2:2 + lang_len])
    let text_len = read_u16(data, 2 + lang_len)
    if 4 + lang_len + text_len > data.length() {
      raise IppError("ipp: a language value is cut")
    }
    let value = @utf8.decode_lossy(data[4 + lang_len:4 + lang_len + text_len])
    if tag == TAG_TEXT_LANG { text_lang(lang, value) } else { name_lang(lang, value) }
  } else if tag_is_out_of_band(tag) {
    out_of_band(tag)
  } else if tag_is_string(tag) || tag == TAG_MEMBER_NAME ||
    tag == TAG_OCTET_STRING {
    let value = if tag == TAG_OCTET_STRING {
      octet_string(data)
    } else {
      string_value(tag, @utf8.decode_lossy(data))
    }
    value
  } else {
    { ..integer(0), tag, raw: data }
  }
}

///|
fn decode_collection(
  data : Bytes,
  start : Int,
) -> (Array[Attribute], Int) raise IppError {
  let attrs : Array[Attribute] = []
  let mut pos = start
  while pos < data.length() {
    let tag = data[pos]
    pos += 1
    if tag == TAG_END_COLLECTION {
      let name_len = read_u16(data, pos)
      pos += 2 + name_len
      let value_len = read_u16(data, pos)
      pos += 2 + value_len
      return (attrs, pos)
    }
    let name_len = read_u16(data, pos)
    pos += 2
    let name = @utf8.decode_lossy(data[pos:pos + name_len])
    pos += name_len
    let value_len = read_u16(data, pos)
    pos += 2
    let value = if tag == TAG_BEGIN_COLLECTION {
      let (members, next) = decode_collection(data, pos)
      pos = next
      collection(members)
    } else {
      let value = decode_value(tag, data[pos:pos + value_len].to_bytes())
      pos += value_len
      value
    }
    if tag == TAG_MEMBER_NAME {
      attrs.push({ name: value.str, values: [] })
    } else if name != "" {
      attrs.push({ name, values: [value] })
    } else if attrs.length() > 0 {
      attrs[attrs.length() - 1].values.push(value)
    } else {
      raise IppError("ipp: a collection value without a member")
    }
  }
  raise IppError("ipp: the collection is not closed")
}

///|
pub(all) struct Limits {
  max_bytes : Int
  max_attributes : Int
  max_value_bytes : Int
  max_values : Int
  max_depth : Int
}

///|
pub fn default_limits() -> Limits {
  {
    max_bytes: 4 * 1024 * 1024,
    max_attributes: 10000,
    max_value_bytes: 64 * 1024,
    max_values: 1000,
    max_depth: 8,
  }
}

///|
fn check_limits(data : Bytes, limits : Limits) -> Unit raise IppError {
  if data.length() > limits.max_bytes {
    raise IppError("ipp: the message is larger than the limit")
  }
  let mut pos = 8
  let mut attributes = 0
  let mut values_in_attr = 0
  let mut depth = 0
  let mut finished = false
  while pos < data.length() && !finished {
    let tag = data[pos]
    pos += 1
    if tag == TAG_END {
      finished = true
      continue
    }
    if tag_is_group(tag) {
      continue
    }
    if pos + 2 > data.length() {
      raise IppError("ipp: the message is cut")
    }
    let name_len = read_u16(data, pos)
    pos += 2 + name_len
    if pos + 2 > data.length() {
      raise IppError("ipp: the message is cut")
    }
    let value_len = read_u16(data, pos)
    pos += 2
    if pos + value_len > data.length() {
      raise IppError("ipp: the message is cut")
    }
    pos += value_len
    if value_len > limits.max_value_bytes {
      raise IppError("ipp: a value is larger than the limit")
    }
    if tag == TAG_END_COLLECTION {
      if depth > 0 {
        depth -= 1
      }
      continue
    }
    if tag == TAG_BEGIN_COLLECTION {
      depth += 1
      if depth > limits.max_depth {
        raise IppError("ipp: collections are nested too deeply")
      }
    }
    if name_len == 0 {
      values_in_attr += 1
    } else {
      attributes += 1
      values_in_attr = 1
    }
    if attributes > limits.max_attributes {
      raise IppError("ipp: too many attributes")
    }
    if values_in_attr > limits.max_values {
      raise IppError("ipp: too many values in an attribute")
    }
  }
  if !finished {
    raise IppError("ipp: the message has no end-of-attributes")
  }
}

///|
pub fn decode_with(data : Bytes, limits : Limits) -> Message raise IppError {
  check_limits(data, limits)
  decode_body(data).0
}

///|
/// Decode one message and report where it ends, leaving a document that
/// follows it.
pub fn decode_prefix(data : Bytes) -> (Message, Int) raise IppError {
  decode_body(data)
}

///|
pub fn decode(data : Bytes) -> Message raise IppError {
  decode_with(data, default_limits())
}

///|
fn decode_body(data : Bytes) -> (Message, Int) raise IppError {
  if data.length() < 8 {
    raise IppError("ipp: the message is cut")
  }
  let groups : Array[Group] = []
  let mut group_index = -1
  let mut pos = 8
  let mut finished = false
  while pos < data.length() && !finished {
    let tag = data[pos]
    pos += 1
    if tag == TAG_END {
      finished = true
      continue
    }
    if tag_is_group(tag) {
      groups.push({ tag, attrs: [] })
      group_index += 1
      continue
    }
    if group_index < 0 {
      raise IppError("ipp: a value before a group")
    }
    let name_len = read_u16(data, pos)
    pos += 2
    if pos + name_len > data.length() {
      raise IppError("ipp: the message is cut")
    }
    let name = @utf8.decode_lossy(data[pos:pos + name_len])
    pos += name_len
    let value_len = read_u16(data, pos)
    pos += 2
    if pos + value_len > data.length() {
      raise IppError("ipp: the message is cut")
    }
    let value = if tag == TAG_BEGIN_COLLECTION {
      let (members, next) = decode_collection(data, pos)
      pos = next
      collection(members)
    } else {
      let value = decode_value(tag, data[pos:pos + value_len].to_bytes())
      pos += value_len
      value
    }
    let group = groups[group_index]
    if name != "" {
      group.attrs.push({ name, values: [value] })
    } else if group.attrs.length() > 0 {
      group.attrs[group.attrs.length() - 1].values.push(value)
    } else {
      raise IppError("ipp: a value without an attribute")
    }
  }
  if !finished {
    raise IppError("ipp: the message has no end-of-attributes")
  }
  (
    {
      major: data[0].to_int(),
      minor: data[1].to_int(),
      code: read_u16(data, 2),
      request_id: read_u32(data, 4),
      groups,
    },
    pos,
  )
}
