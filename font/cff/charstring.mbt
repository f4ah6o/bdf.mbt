///|
priv struct Subrs {
  items : Array[Bytes]
  used : Array[Bool]
  bias : Int32
}

///|
fn new_subrs(items : Array[Bytes]) -> Subrs {
  {
    items,
    used: [
      for _ in items => false
    ],
    bias: if items.length() >= 33900 {
      32768
    } else if items.length() >= 1240 {
      1131
    } else {
      107
    },
  }
}

///|
fn pruned_subrs(subrs : Subrs, followed : Bool) -> Array[Bytes] {
  [
    for i, item in subrs.items => {
      if followed && !subrs.used[i] {
        b"\x0b"
      } else {
        item
      }
    }
  ]
}

///|
priv struct Type2State {
  stack : Array[Double]
  mut stems : Int32
  mut base : Int32
  mut accent : Int32
  left : Ref[Int32]
}

///|
fn exec_type2(
  state : Type2State,
  code : BytesView,
  local_subrs : Subrs,
  global : Subrs,
  depth : Int32,
) -> Bool raise {
  if depth > 10 {
    raise InvalidCff("charstring cannot be followed")
  }
  let mut i = 0
  while i < code.length() {
    state.left.val -= 1
    if state.left.val < 0 || state.stack.length() > 8208 {
      raise TooLong
    }
    let byte = code[i].to_int()
    if byte == 28 {
      if i > code.length() - 3 {
        raise InvalidCff("truncated charstring")
      }
      let n = be16(code, i + 1)
      state.stack.push((if n >= 32768 { n - 65536 } else { n }).to_double())
      i += 3
      continue
    } else if byte >= 32 && byte <= 246 {
      state.stack.push((byte - 139).to_double())
      i += 1
      continue
    } else if byte >= 247 && byte <= 254 {
      if i > code.length() - 2 {
        raise InvalidCff("truncated charstring")
      }
      let v = code[i + 1].to_int()
      state.stack.push(
        (if byte <= 250 {
          (byte - 247) * 256 + v + 108
        } else {
          -(byte - 251) * 256 - v - 108
        }).to_double(),
      )
      i += 2
      continue
    } else if byte == 255 {
      if i > code.length() - 5 {
        raise InvalidCff("truncated charstring")
      }
      state.stack.push(
        be32(code, i + 1).reinterpret_as_int().to_double() / 65536.0,
      )
      i += 5
      continue
    }
    let mut op = byte
    i += 1
    if byte == 12 {
      if i >= code.length() {
        raise InvalidCff("truncated charstring")
      }
      op = 1200 + code[i].to_int()
      i += 1
    }
    match op {
      1 | 3 | 18 | 23 => state.stems += state.stack.length() / 2
      19 | 20 => {
        state.stems += state.stack.length() / 2
        i += (state.stems + 7) / 8
      }
      10 | 29 => {
        let set = if op == 29 { global } else { local_subrs }
        let value = match state.stack.pop() {
          Some(v) => v
          None => raise InvalidCff("missing subroutine operand")
        }
        if value != value.trunc() || value < -32768.0 || value > 65535.0 {
          raise InvalidCff("bad subroutine number")
        }
        let index = value.to_int() + set.bias
        if index < 0 || index >= set.items.length() {
          raise InvalidCff("bad subroutine number")
        }
        set.used[index] = true
        if exec_type2(
            state,
            set.items[index][:],
            local_subrs,
            global,
            depth + 1,
          ) {
          return true
        }
        continue
      }
      11 => return false
      14 => {
        let n = state.stack.length()
        if n >= 4 {
          state.base = state.stack[n - 2].to_int()
          state.accent = state.stack[n - 1].to_int()
        }
        return true
      }
      1200 | 1234 | 1235 | 1236 | 1237 => ()
      _ =>
        if op >= 1200 {
          raise InvalidCff("charstring arithmetic cannot be followed")
        }
    }
    state.stack.clear()
  }
  false
}
