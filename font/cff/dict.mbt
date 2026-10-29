///|
priv struct DictEntry {
  op : Int32
  args : Array[Double]
  raw : Bytes
}

///|
fn parse_dict(data : BytesView) -> Array[DictEntry] raise {
  let entries : Array[DictEntry] = []
  let args : Array[Double] = []
  let mut start = 0
  let mut i = 0
  while i < data.length() {
    let byte = data[i].to_int()
    if byte <= 21 {
      let mut op = byte
      let op_start = i
      i += 1
      if byte == 12 {
        if i >= data.length() {
          raise InvalidCff("truncated DICT")
        }
        op = 1200 + data[i].to_int()
        i += 1
      }
      entries.push({
        op,
        args: args.copy(),
        raw: data[start:op_start].to_owned(),
      })
      args.clear()
      start = i
    } else if byte == 28 {
      if i > data.length() - 3 {
        raise InvalidCff("truncated DICT")
      }
      let value = be16(data, i + 1)
      args.push(
        (if value >= 32768 { value - 65536 } else { value }).to_double(),
      )
      i += 3
    } else if byte == 29 {
      if i > data.length() - 5 {
        raise InvalidCff("truncated DICT")
      }
      args.push(be32(data, i + 1).reinterpret_as_int().to_double())
      i += 5
    } else if byte == 30 {
      i += 1
      let raw = StringBuilder()
      let mut ended = false
      while i < data.length() && !ended {
        let value = data[i].to_int()
        i += 1
        for n in [value >> 4, value & 15] {
          if n <= 9 {
            raw.write_char((48 + n).unsafe_to_char())
          } else if n == 10 {
            raw.write_char('.')
          } else if n == 11 {
            raw.write_char('E')
          } else if n == 12 {
            raw.write_string("E-")
          } else if n == 14 {
            raw.write_char('-')
          } else if n == 15 {
            ended = true
            break
          }
        }
      }
      let text = raw.to_string()
      let number = @string.parse_double(text) catch { _ => 0.0 }
      args.push(number)
    } else if byte >= 32 && byte <= 246 {
      args.push((byte - 139).to_double())
      i += 1
    } else if byte >= 247 && byte <= 254 {
      if i > data.length() - 2 {
        raise InvalidCff("truncated DICT")
      }
      let tail = data[i + 1].to_int()
      let value = if byte <= 250 {
        (byte - 247) * 256 + tail + 108
      } else {
        -(byte - 251) * 256 - tail - 108
      }
      args.push(value.to_double())
      i += 2
    } else {
      raise InvalidCff("reserved byte in DICT")
    }
  }
  entries
}

///|
fn dict_value(entries : Array[DictEntry], op : Int32) -> Array[Double]? {
  for entry in entries {
    if entry.op == op {
      return Some(entry.args)
    }
  }
  None
}

///|
fn dict_last(entries : Array[DictEntry], op : Int32) -> Array[Double]? {
  let mut result = None
  for entry in entries {
    if entry.op == op {
      result = Some(entry.args)
    }
  }
  result
}

///|
fn operand(value : Double) -> Int32 {
  if value != value ||
    value >= 9223372036854775808.0 ||
    value < -9223372036854775808.0 {
    -2147483647
  } else if value > 2147483647.0 {
    2147483647
  } else if value < -2147483647.0 {
    -2147483647
  } else {
    value.to_int()
  }
}

///|
fn write_dict(
  entries : Array[DictEntry],
  replacements : Map[Int32, Array[Int32]],
) -> Bytes {
  let out : Array[Byte] = []
  for entry in entries {
    match replacements.get(entry.op) {
      Some(values) =>
        for n in values {
          out.push(29)
          emit32(out, n)
        }
      None =>
        for byte in entry.raw {
          out.push(byte)
        }
    }
    if entry.op >= 1200 {
      out.push(12)
      out.push((entry.op - 1200).to_byte())
    } else {
      out.push(entry.op.to_byte())
    }
  }
  Bytes::from_array(out)
}
