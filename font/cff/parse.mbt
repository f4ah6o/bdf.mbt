///|
priv struct CffData {
  header : Bytes
  names : Bytes
  strings : Bytes
  global : Array[Bytes]
  top : Array[DictEntry]
  charstrings : Array[Bytes]
  charset : Array[Int32]
  name_to_gid : Map[String, Int32]
  is_cid : Bool
}

///|
fn cff_value(
  entries : Array[DictEntry],
  op : Int32,
  index : Int32,
  max : Int32,
) -> Int32 raise {
  let values = match dict_value(entries, op) {
    Some(v) => v
    None => raise InvalidCff("missing DICT offset")
  }
  if index >= values.length() || values[index] < 0.0 {
    raise InvalidCff("bad DICT offset")
  }
  let value = operand(values[index])
  if value < 0 || value > max {
    raise InvalidCff("bad DICT offset")
  }
  value
}

///|
fn parse_cff(data : Bytes) -> CffData raise {
  if data.length() < 4 {
    raise InvalidCff("too short")
  }
  let header_size = data[2].to_int()
  if header_size < 4 || header_size > data.length() {
    raise InvalidCff("bad header")
  }
  let (names, after_names) = read_index(data[:], header_size)
  if names.length() != 1 {
    raise InvalidCff("only single-font CFF is supported")
  }
  let (dicts, after_dicts) = read_index(data[:], after_names)
  if dicts.length() != 1 {
    raise InvalidCff("no top dict")
  }
  let (strings, after_strings) = read_index(data[:], after_dicts)
  let (global, _) = read_index(data[:], after_strings)
  let top = parse_dict(dicts[0][:])
  let is_cid = dict_value(top, 1230) is Some(_)
  let cs_values = match dict_last(top, 17) {
    Some(v) => v
    None => raise InvalidCff("missing CharStrings")
  }
  if cs_values.length() == 0 {
    raise InvalidCff("missing CharStrings")
  }
  let cs_offset = operand(cs_values[0])
  if cs_offset < 0 || cs_offset > data.length() {
    raise InvalidCff("bad CharStrings offset")
  }
  let (charstrings, _) = read_index(data[:], cs_offset)
  if charstrings.length() == 0 {
    raise InvalidCff("no glyphs")
  }
  let charset = [ for _ in charstrings => 0 ]
  let charset_offset = match dict_last(top, 15) {
    Some(args) if args.length() > 0 => operand(args[0])
    _ => 0
  }
  if charset_offset >= 0 && charset_offset <= 2 {
    for i in 0..<charset.length() {
      charset[i] = i
    }
  } else if charset_offset >= 0 && charset_offset < data.length() {
    let format = data[charset_offset].to_int()
    let mut pos = charset_offset + 1
    let mut gid = 1
    if format == 0 {
      while gid < charset.length() && pos < data.length() - 1 {
        charset[gid] = be16(data[:], pos)
        pos += 2
        gid += 1
      }
    } else if format == 1 || format == 2 {
      while gid < charset.length() && pos < data.length() - 2 {
        let first = be16(data[:], pos)
        let length = if format == 1 {
          data[pos + 2].to_int()
        } else {
          be16(data[:], pos + 2)
        }
        pos += if format == 1 { 3 } else { 4 }
        for k in 0..<=length {
          if gid >= charset.length() {
            break
          }
          charset[gid] = first + k
          gid += 1
        }
      }
    }
  }
  let name_to_gid : Map[String, Int32] = Map([])
  if !is_cid {
    for gid, sid in charset {
      let name = if sid >= 0 && sid < standard_strings.length() {
        standard_strings[sid]
      } else if sid >= standard_strings.length() &&
        sid - standard_strings.length() < strings.length() {
        @utf8.decode_lossy(strings[sid - standard_strings.length()][:])
      } else {
        ""
      }
      if name != "" && !name_to_gid.contains(name) {
        name_to_gid[name] = gid
      }
    }
  }
  {
    header: data[:header_size].to_owned(),
    names: data[header_size:after_names].to_owned(),
    strings: data[after_dicts:after_strings].to_owned(),
    global,
    top,
    charstrings,
    charset,
    name_to_gid,
    is_cid,
  }
}

///|
/// Return glyph names from a CFF charset, including CID names.
pub fn glyph_names(data : Bytes) -> Array[String] raise {
  let font = parse_cff(data)
  let (strings, _) = read_index(font.strings[:], 0)
  [
    for sid in font.charset => {
      if font.is_cid {
        "cid" + sid.to_string()
      } else if sid >= 0 && sid < standard_strings.length() {
        standard_strings[sid]
      } else if sid >= standard_strings.length() &&
        sid - standard_strings.length() < strings.length() {
        @utf8.decode_lossy(strings[sid - standard_strings.length()][:])
      } else {
        ""
      }
    }
  ]
}
