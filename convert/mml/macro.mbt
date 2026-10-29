///|
priv struct MmlMacros {
  defs : Map[String, String]
  mut total : Int64
  source : MmlSource
}

///|
fn MmlMacros::expand(self : MmlMacros, text : String) -> String {
  let data = @utf8.encode(text)
  let mut has_macro = false
  for b in data {
    if b == b'$' {
      has_macro = true
      break
    }
  }
  if !has_macro {
    self.total += data.length().to_int64()
    return text
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < data.length() {
    if data[i] != b'$' {
      out.push(data[i])
      i += 1
      continue
    }
    let mut end = i + 1
    while end < data.length() && mml_ident(data[end].to_int()) {
      end += 1
    }
    let mut k = Int32::min(end, i + 65)
    let mut name = ""
    while k > i + 1 {
      let candidate = @utf8.decode_lossy(data[i + 1:k])
      if self.defs.contains(candidate) {
        name = candidate
        break
      }
      k -= 1
    }
    if name == "" {
      let unknown = @utf8.decode_lossy(data[i + 1:end])
      self.source.warn(
        "macro:" + unknown,
        "macro $" + unknown + " is not defined",
      )
      i = end
      if i < data.length() && data[i] == b'{' {
        let mut close = i
        while close < data.length() && data[close] != b'}' {
          close += 1
        }
        if close < data.length() {
          i = close + 1
        }
      }
      continue
    }
    let value = @utf8.encode(self.defs[name])
    if self.total + out.length().to_int64() + value.length().to_int64() >
      16777216L {
      self.source.warn(
        "macro-size", "the macros expand to more than 16 MiB of MML; the rest is left out",
      )
      break
    }
    for b in value {
      out.push(b)
    }
    i += 1 + name.length()
  }
  self.total += out.length().to_int64()
  @utf8.decode_lossy(Bytes::from_array(out)[:])
}

///|
fn mml_macro_definition(
  text : String,
  source : MmlSource,
) -> (Bool, String, String) {
  let data = @utf8.encode(text)
  if data.is_empty() || data[0] != b'$' {
    return (false, "", "")
  }
  let mut i = 1
  while i < data.length() && mml_ident(data[i].to_int()) {
    i += 1
  }
  let name = @utf8.decode_lossy(data[1:i])
  while i < data.length() &&
        (data[i] == b' ' || data[i] == b'\t' || data[i] == b'\n') {
    i += 1
  }
  if i < data.length() && data[i] == b'{' {
    let mut end = i + 1
    while end < data.length() && data[end] != b'}' {
      end += 1
    }
    if end == data.length() {
      return (false, "", "")
    }
    end += 1
    while end < data.length() &&
          (data[end] == b' ' || data[end] == b'\t' || data[end] == b'\n') {
      end += 1
    }
    if end == data.length() || data[end] != b'=' {
      return (false, "", "")
    }
    source.warn(
      "macro-args",
      "macros with arguments ($" + name + "{…}) are not expanded",
    )
    return (true, "", "")
  }
  if name == "" || i == data.length() || data[i] != b'=' {
    return (false, "", "")
  }
  (true, name, @utf8.decode_lossy(data[i + 1:]))
}
