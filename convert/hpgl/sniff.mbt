///|
let hpgl_mnemonics = " AA AC AD AR AT BP BR BZ CF CI CO CP CR CT DC DF DI DL DP DR DT DV EA EC EP ER ES EW FI FN FP FR FT IN IP IR IW LA LB LM LO LT MC MG MT NP NR OD OE OH OI OP OS PA PC PD PE PG PM PP PR PS PU PW QL RA RF RO RP RR RT SA SB SC SD SI SL SM SP SR SS ST SV TD TR UL VS WG WU AF AH AP AS BF BL CA CC CM CS CV DS EL GC GM GP IM IV KY LI OA OC OF OG OK OL OO OT OW PB PT SG TL UC VA VN WD XT YT "

///|
fn hpgl_letter(c : Byte) -> Bool {
  (c >= b'A' && c <= b'Z') || (c >= b'a' && c <= b'z')
}

///|
fn hpgl_parameter(c : Byte) -> Bool {
  (c >= b'0' && c <= b'9') ||
  c == b'.' ||
  c == b',' ||
  c == b'+' ||
  c == b'-' ||
  c == b' ' ||
  c == b'\t' ||
  c == b'\r' ||
  c == b'\n'
}

///|
fn hpgl_device(data : Bytes, at : Int32) -> Int32 {
  let mut i = at + 2
  if i >= data.length() {
    return i
  }
  i += 1
  let mut j = i
  while j < data.length() &&
        j - i < 64 &&
        (
          (data[j] >= b'0' && data[j] <= b'9') ||
          data[j] == b';' ||
          data[j] == b' '
        ) {
    j += 1
  }
  if j < data.length() && data[j] == b':' {
    j + 1
  } else {
    i
  }
}

///|
fn hpgl_blank(data : Bytes, at : Int32) -> Int32 {
  let mut i = at
  while i < data.length() {
    let c = data[i]
    if c == 0 ||
      c == b' ' ||
      c == b'\t' ||
      c == b'\r' ||
      c == b'\n' ||
      c == b';' ||
      c == 3 {
      i += 1
    } else if c == 0x1b && i + 1 < data.length() && data[i + 1] == b'.' {
      i = hpgl_device(data, i)
    } else {
      break
    }
  }
  i
}

///|
fn hpgl_skip_params(data : Bytes, at : Int32) -> Int32 {
  let mut i = at
  while i < data.length() {
    let c = data[i]
    if hpgl_parameter(c) {
      i += 1
    } else if c == b';' || hpgl_letter(c) || c == 0x1b || c == 3 {
      return i
    } else {
      return -1
    }
  }
  i
}

///|
fn hpgl_find(data : Bytes, at : Int32, value : Byte) -> Int32 {
  for i in at..<data.length() {
    if data[i] == value {
      return i
    }
  }
  -1
}

///|
fn hpgl_instructions(data : Bytes, start : Int32) -> Int32 {
  let mut n = 0
  let mut numeric = false
  let mut term : Byte = 3
  let mut i = start
  while true {
    i = hpgl_blank(data, i)
    if i >= data.length() || data[i] == 0x1b {
      break
    }
    if data[i] == b'!' {
      i += 1
      while i < data.length() && hpgl_letter(data[i]) {
        i += 1
      }
      i = hpgl_skip_params(data, i)
      if i < 0 {
        return 0
      }
      continue
    }
    if !hpgl_letter(data[i]) {
      return 0
    }
    if i + 1 >= data.length() {
      break
    }
    if !hpgl_letter(data[i + 1]) {
      return 0
    }
    let name = @utf8.decode_lossy(data[i:i + 2]).to_upper()
    if !hpgl_mnemonics.contains(" " + name + " ") {
      return 0
    }
    n += 1
    i += 2
    match name {
      "LB" | "WD" | "BL" => {
        let end = hpgl_find(data, i, term)
        if end < 0 {
          return n
        }
        i = end + 1
      }
      "DT" => {
        if i < data.length() && data[i] != b';' {
          term = data[i]
          i += 1
        } else {
          term = 3
        }
        i = hpgl_skip_params(data, i)
        if i < 0 {
          return 0
        }
      }
      "SM" => if i < data.length() && data[i] != b';' { i += 1 }
      "CO" | "MG" => {
        while i < data.length() && (data[i] == b' ' || data[i] == b'\t') {
          i += 1
        }
        if i < data.length() && data[i] == b'"' {
          let end = hpgl_find(data, i + 1, b'"')
          if end < 0 {
            return n
          }
          i = end + 1
        } else {
          let end = hpgl_find(data, i, b';')
          if end < 0 {
            return n
          }
          i = end
        }
      }
      "PE" => {
        let end = hpgl_find(data, i, b';')
        if end < 0 {
          return n
        }
        i = end + 1
        numeric = true
      }
      "BP" =>
        while i < data.length() &&
              data[i] != b';' &&
              !hpgl_letter(data[i]) &&
              data[i] != 0x1b {
          if data[i] == b'"' {
            let end = hpgl_find(data, i + 1, b'"')
            if end < 0 {
              return n
            }
            i = end + 1
          } else if !hpgl_parameter(data[i]) {
            return 0
          } else {
            i += 1
          }
        }
      _ => {
        let end = hpgl_skip_params(data, i)
        if end < 0 {
          return 0
        }
        if end > i {
          numeric = true
        }
        i = end
      }
    }
  }
  if !numeric && n < 6 {
    0
  } else {
    n
  }
}

///|
fn hpgl_job(data : Bytes, start : Int32) -> Bool {
  let mut i = start
  while i < data.length() {
    if data[i:].has_prefix(b"@PJL") {
      let mut end = i
      while end < data.length() && data[end] != b'\r' && data[end] != b'\n' {
        end += 1
      }
      let line = @utf8.decode_lossy(data[i:end]).to_upper()
      if line.contains("ENTER") && line.contains("LANGUAGE") {
        let parts = line.split("LANGUAGE").to_array()
        let mut lang = hpgl_trim(parts[1].to_owned())
        if lang.has_prefix("=") {
          lang = hpgl_trim(lang.substring(start=1))
        }
        if lang.has_prefix("HPGL") || lang.has_prefix("RTL") {
          return true
        }
        if !lang.has_prefix("PCL") {
          return false
        }
      }
      i = end + 1
      continue
    }
    if data[i] == 0x1b && i + 1 < data.length() {
      if data[i + 1] == b'%' {
        let mut j = i + 2
        if j < data.length() && (data[j] == b'+' || data[j] == b'-') {
          j += 1
        }
        let mut k = j
        while k < data.length() && data[k] >= b'0' && data[k] <= b'9' {
          k += 1
        }
        if k > j && k < data.length() && data[k] == b'B' {
          return true
        }
      } else if data[i + 1] == b'*' && i + 2 < data.length() {
        let kind = data[i + 2]
        if kind == b'v' || kind == b'r' || kind == b'b' {
          let mut k = i + 3
          while k < data.length() &&
                (
                  (data[k] >= b'0' && data[k] <= b'9') ||
                  data[k] == b'-' ||
                  data[k] == b'+' ||
                  data[k] == b'.'
                ) {
            k += 1
          }
          if k < data.length() &&
            (
              (kind == b'v' && data[k] == b'W') ||
              (kind == b'r' && data[k] == b'A') ||
              (kind == b'b' && data[k] == b'W')
            ) {
            return true
          }
        }
      }
    }
    i += 1
  }
  false
}

///|
/// Detect an HP-GL or HP-GL/2 plotter stream from its leading bytes.
pub fn detect(head : Bytes) -> Bool {
  let at = hpgl_blank(head, 0)
  if at >= head.length() {
    return false
  }
  if head[at] == 0x1b || head[at:].has_prefix(b"@PJL") {
    hpgl_job(head, at)
  } else {
    hpgl_instructions(head, at) >= 3
  }
}

///|
fn hpgl_trim(text : String) -> String {
  let output = StringBuilder()
  let pending = StringBuilder()
  let mut started = false
  for c in text {
    if c.is_whitespace() {
      if started {
        pending.write_char(c)
      }
    } else {
      if started {
        output.write_string(pending.to_string())
        pending.reset()
      }
      output.write_char(c)
      started = true
    }
  }
  output.to_string()
}
