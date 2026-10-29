///|
/// A compacted CFF program and its original glyph IDs in new order.
pub(all) struct Subset {
  data : Bytes
  order : Array[Int32]
}

///|
fn top_bytes(
  top : Array[DictEntry],
  offsets : Map[Int32, Array[Int32]],
) -> Bytes {
  let replacements : Map[Int32, Array[Int32]] = Map([])
  for entry in top {
    if entry.op == 16 {
      if entry.args.length() != 1 || entry.args[0] > 1.0 {
        replacements[16] = [0]
      }
    } else if entry.op == 15 ||
      entry.op == 17 ||
      entry.op == 18 ||
      entry.op == 1236 ||
      entry.op == 1237 {
      replacements[entry.op] = offsets
        .get(entry.op)
        .unwrap_or([ for _ in entry.args => 0 ])
    }
  }
  write_dict(top, replacements)
}

///|
fn fd_bytes(
  dicts : Array[Array[DictEntry]],
  sizes : Array[Int32],
  offsets : Array[Int32],
) -> Bytes {
  let items : Array[Bytes] = []
  for i, dict in dicts {
    items.push(write_dict(dict, { 18: [sizes[i], offsets[i]] }))
  }
  write_index(items)
}

///|
/// Subset a CFF program, preserving glyph 0 and the components of accents.
/// Returns original glyph IDs in the new order; invalid programs raise CffError.
pub fn subset(data : Bytes, glyphs : Array[Int32]) -> Subset raise {
  subset_impl(data, glyphs, false)
}

///|
/// Remove unused CFF glyph outlines while preserving every original glyph ID.
pub fn prune(data : Bytes, glyphs : Array[Int32]) -> Bytes raise {
  subset_impl(data, glyphs, true).data
}

///|
fn subset_impl(
  data : Bytes,
  glyphs : Array[Int32],
  keep_numbers : Bool,
) -> Subset raise {
  let parsed = parse_cff(data)
  let mut top = parsed.top
  let cs_offset = cff_value(top, 17, 0, data.length())
  let (charstrings, _) = read_index(data[:], cs_offset)
  if charstrings.length() != parsed.charstrings.length() {
    raise InvalidCff("inconsistent glyph count")
  }
  if parsed.is_cid {
    top = top.filter(entry => entry.op != 18)
  }
  if dict_value(top, 15) is None {
    top.push({ op: 15, args: [0.0], raw: b"", })
  }
  let privates : Array[PrivateDict] = []
  let fd_dicts : Array[Array[DictEntry]] = []
  let mut selection = [ for _ in charstrings => 0 ]
  if parsed.is_cid {
    let fd_array = cff_value(top, 1236, 0, data.length())
    let fd_select_offset = cff_value(top, 1237, 0, data.length())
    let (fds, _) = read_index(data[:], fd_array)
    if fds.length() == 0 || fds.length() > 255 {
      raise InvalidCff("bad FDArray")
    }
    for fd in fds {
      let entries = parse_dict(fd[:])
      let mut private = empty_private()
      for entry in entries {
        if entry.op == 18 {
          private = read_private(data, entry.args)
        }
      }
      fd_dicts.push(entries)
      privates.push(private)
    }
    selection = fd_select(data, fd_select_offset, charstrings.length())
  } else {
    match dict_value(top, 18) {
      Some(args) => privates.push(read_private(data, args))
      None => privates.push(empty_private())
    }
  }
  let fd_of = (gid : Int32) => {
    let fd = selection[gid]
    if fd < 0 || fd >= privates.length() {
      0
    } else {
      fd
    }
  }
  let global = new_subrs(parsed.global)
  let limit = if data.length() > (2147483647 - 65536) / 32 {
    2147483647
  } else {
    data.length() * 32 + 65536
  }
  let left = Ref(limit)
  let kept : Map[Int32, Bool] = { 0: true }
  let queue : Array[Int32] = [0]
  for gid in glyphs {
    if gid > 0 && gid < charstrings.length() && !kept.contains(gid) {
      kept[gid] = true
      queue.push(gid)
    }
  }
  let mut followed = true
  while queue.length() > 0 {
    let gid = queue.pop().unwrap()
    let state : Type2State = {
      stack: [],
      stems: 0,
      base: -1,
      accent: -1,
      left,
    }
    ignore(
      exec_type2(
        state,
        charstrings[gid][:],
        privates[fd_of(gid)].subrs,
        global,
        0,
      ),
    ) catch {
      TooLong => raise TooLong
      _ => followed = false
    }
    if state.base >= 0 && !parsed.is_cid {
      for code in [state.base, state.accent] {
        if code >= 0 && code < standard_encoding.length() {
          match parsed.name_to_gid.get(standard_encoding[code]) {
            Some(glyph) if !kept.contains(glyph) => {
              kept[glyph] = true
              queue.push(glyph)
            }
            _ => ()
          }
        }
      }
    }
  }
  let order : Array[Int32] = []
  let kept_chars : Array[Bytes] = []
  let charset : Array[Byte] = [0]
  for gid in 0..<charstrings.length() {
    if kept.contains(gid) || keep_numbers {
      if order.length() > 0 {
        emit16(charset, parsed.charset[gid])
      }
      order.push(gid)
      kept_chars.push(
        if kept.contains(gid) {
          charstrings[gid]
        } else {
          b"\x0e"
        },
      )
    }
  }
  let fdselect : Array[Byte] = []
  if parsed.is_cid {
    let ranges : Array[(Int32, Int32)] = []
    for i, gid in order {
      let fd = fd_of(gid)
      if i == 0 || ranges[ranges.length() - 1].1 != fd {
        ranges.push((i, fd))
      }
    }
    fdselect.push(3)
    emit16(fdselect, ranges.length())
    for (first, fd) in ranges {
      emit16(fdselect, first)
      fdselect.push(fd.to_byte())
    }
    emit16(fdselect, order.length())
  }
  let gsubrs = write_index(pruned_subrs(global, followed))
  let cs = write_index(kept_chars)
  let blocks : Array[Bytes] = []
  let sizes : Array[Int32] = []
  for private in privates {
    let (block, size) = private_block(private, followed)
    blocks.push(block)
    sizes.push(size)
  }
  let offsets : Map[Int32, Array[Int32]] = Map([])
  let top_len = write_index([top_bytes(top, offsets)]).length()
  let mut p = parsed.header.length() +
    parsed.names.length() +
    top_len +
    parsed.strings.length() +
    gsubrs.length()
  offsets[15] = [p]
  p += charset.length()
  if parsed.is_cid {
    offsets[1237] = [p]
    p += fdselect.length()
  }
  offsets[17] = [p]
  p += cs.length()
  let private_offsets = [ for _ in privates => 0 ]
  if parsed.is_cid {
    offsets[1236] = [p]
    p += fd_bytes(fd_dicts, sizes, private_offsets).length()
  }
  for i, block in blocks {
    private_offsets[i] = p
    p += block.length()
  }
  if !parsed.is_cid && privates[0].entries is Some(_) {
    offsets[18] = [sizes[0], private_offsets[0]]
  }
  let fdarray = if parsed.is_cid {
    fd_bytes(fd_dicts, sizes, private_offsets)
  } else {
    b""
  }
  let final_top = write_index([top_bytes(top, offsets)])
  let out : Array[Byte] = []
  for part in [parsed.header, parsed.names, final_top, parsed.strings, gsubrs] {
    for byte in part {
      out.push(byte)
    }
  }
  for byte in charset {
    out.push(byte)
  }
  for byte in fdselect {
    out.push(byte)
  }
  for byte in cs {
    out.push(byte)
  }
  for byte in fdarray {
    out.push(byte)
  }
  for part in blocks {
    for byte in part {
      out.push(byte)
    }
  }
  if out.length() != p {
    raise InvalidCff("layout mismatch")
  }
  let rebuilt = Bytes::from_array(out)
  let check = parse_cff(rebuilt)
  if check.charstrings.length() != order.length() ||
    check.is_cid != parsed.is_cid {
    raise InvalidCff("subset does not parse")
  }
  { data: rebuilt, order, }
}
