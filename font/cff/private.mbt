///|
priv struct PrivateDict {
  entries : Array[DictEntry]?
  subrs : Subrs
}

///|
fn empty_private() -> PrivateDict {
  { entries: None, subrs: new_subrs([]), }
}

///|
fn read_private(data : Bytes, args : Array[Double]) -> PrivateDict raise {
  if args.length() != 2 {
    raise InvalidCff("bad Private operands")
  }
  let size = operand(args[0])
  let offset = operand(args[1])
  if offset < 0 ||
    size < 0 ||
    offset > data.length() ||
    size > data.length() - offset {
    raise InvalidCff("Private out of range")
  }
  let entries = parse_dict(data[offset:offset + size])
  let mut subrs = new_subrs([])
  for entry in entries {
    if entry.op == 19 && entry.args.length() == 1 {
      let rel = operand(entry.args[0])
      if rel < 0 || rel > data.length() - offset {
        raise InvalidCff("Subrs out of range")
      }
      let (items, _) = read_index(data[:], offset + rel)
      subrs = new_subrs(items)
    }
  }
  { entries: Some(entries), subrs, }
}

///|
fn fd_select(data : Bytes, offset : Int32, count : Int32) -> Array[Int32] raise {
  if offset < 0 || offset >= data.length() {
    raise InvalidCff("FDSelect out of range")
  }
  let result = [ for _ in 0..<count => 0 ]
  let format = data[offset].to_int()
  if format == 0 {
    if count > data.length() - offset - 1 {
      raise InvalidCff("truncated FDSelect")
    }
    for i in 0..<count {
      result[i] = data[offset + 1 + i].to_int()
    }
  } else if format == 3 {
    let ranges = be16(data[:], offset + 1)
    if offset > data.length() - 5 || ranges > (data.length() - offset - 5) / 3 {
      raise InvalidCff("truncated FDSelect")
    }
    for i in 0..<ranges {
      let rec = offset + 3 + 3 * i
      let first = be16(data[:], rec)
      let fd = data[rec + 2].to_int()
      let next = be16(data[:], rec + 3)
      for gid in first..<Int32::min(next, count) {
        result[gid] = fd
      }
    }
  } else {
    raise InvalidCff("unknown FDSelect format")
  }
  result
}

///|
fn private_block(private : PrivateDict, followed : Bool) -> (Bytes, Int32) {
  match private.entries {
    None => (b"", 0)
    Some(entries) => {
      let has_subrs = dict_value(entries, 19) is Some(_)
      let placeholder = if has_subrs { { 19: [0] } } else { Map([]) }
      let size = write_dict(entries, placeholder).length()
      let replacements = if has_subrs { { 19: [size] } } else { Map([]) }
      let dict = write_dict(entries, replacements)
      if !has_subrs {
        return (dict, dict.length())
      }
      let index = write_index(pruned_subrs(private.subrs, followed))
      (
        Bytes::from_array([..dict.to_array(), ..index.to_array()]),
        dict.length(),
      )
    }
  }
}
