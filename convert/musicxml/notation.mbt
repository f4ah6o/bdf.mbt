///|
fn musicxml_lcm(a : Int32, b : Int32) -> Int32 {
  let mut x = a
  let mut y = b
  while y != 0 {
    let n = x % y
    x = y
    y = n
  }
  a / x * b
}

///|
/// Read additive and composite MusicXML time signatures.
pub fn musicxml_time_sig(node : MusicXmlNode) -> @music.TimeSig? {
  let beats : Array[Int64] = []
  let types : Array[Int32] = []
  for child in node.children {
    if child.name == "beats" {
      let mut sum = 0L
      for part in musicxml_trim(child.text).split("+") {
        let (n, valid) = musicxml_integer(part.to_owned())
        if !valid || n < 1L {
          return None
        }
        sum += Int64::min(n, 1000L)
      }
      beats.push(sum)
    } else if child.name == "beat-type" {
      let (n, valid) = musicxml_integer(child.text)
      if !valid || n < 1L {
        return None
      }
      types.push(Int64::min(n, 1024L).to_int())
    }
  }
  if beats.is_empty() || beats.length() != types.length() {
    return None
  }
  let mut n = beats[0]
  let mut d = types[0]
  for i in 1..<beats.length() {
    let common = musicxml_lcm(d, types[i])
    if common > 1024 {
      break
    }
    n = n * (common / d).to_int64() + beats[i] * (common / types[i]).to_int64()
    d = common
  }
  let symbol = node.attribute("symbol")
  Some({
    beats: Int64::min(n, 1000L).to_int(),
    beat_type: d,
    symbol: if symbol == "common" || symbol == "cut" {
      symbol
    } else {
      ""
    },
  })
}

///|
/// Interpret a MusicXML clef, preserving its line and octave change.
pub fn musicxml_clef(node : MusicXmlNode) -> @music.EngravingClef {
  let (raw, _) = musicxml_integer(node.child_text("line"))
  let mut line = if raw >= -2147483648L && raw <= 2147483647L {
    raw.to_int()
  } else {
    0
  }
  let mut usual = 0
  let sign = match node.child_text("sign").to_upper() {
    "F" => {
      usual = 4
      1
    }
    "C" => {
      usual = 3
      2
    }
    "PERCUSSION" => {
      line = 0
      3
    }
    "TAB" => {
      line = 0
      4
    }
    "NONE" => {
      line = 0
      5
    }
    _ => {
      usual = 2
      0
    }
  }
  let (oct, valid) = musicxml_integer(node.child_text("clef-octave-change"))
  {
    sign,
    line: if line >= 1 && line <= 5 && line != usual {
      line
    } else {
      0
    },
    octave: if valid {
      Int64::min(Int64::max(oct, -2L), 2L).to_int()
    } else {
      0
    },
  }
}

///|
/// Infer a written note type and dots from its duration in ticks.
pub fn musicxml_infer_type(ticks : Int32) -> (Int32, Int32) {
  if ticks <= 0 {
    return (3, 0)
  }
  for kind in 0..<=8 {
    for dots in 0..<=3 {
      if musicxml_note_ticks(kind, dots) == ticks {
        return (kind, dots)
      }
    }
  }
  let mut kind = 0
  while kind < 8 && musicxml_note_ticks(kind, 0) > ticks {
    kind += 1
  }
  let mut dots = 0
  while dots < 3 && musicxml_note_ticks(kind, dots + 1) <= ticks {
    dots += 1
  }
  (kind, dots)
}

///|
fn musicxml_note_ticks(kind : Int32, dots : Int32) -> Int32 {
  let mut d = 7680 >> kind
  let mut result = d
  for _ in 0..<dots {
    d = d / 2
    result += d
  }
  result
}

///|
/// Map a MusicXML accidental name and alteration to a staff accidental.
pub fn musicxml_accidental(name : String, alter : Int32) -> Int32 {
  match name {
    "sharp" => return 2
    "flat" => return 3
    "natural" => return 4
    "double-sharp"
    | "sharp-sharp"
    | "triple-sharp"
    | "double-sharp-down"
    | "double-sharp-up" => return 5
    "flat-flat"
    | "double-flat"
    | "triple-flat"
    | "double-flat-down"
    | "double-flat-up" => return 6
    _ => ()
  }
  if name.contains("sharp") || name == "sori" {
    2
  } else if name.contains("flat") || name == "koron" {
    3
  } else if name.contains("natural") {
    4
  } else if alter >= 2 {
    5
  } else if alter == 1 {
    2
  } else if alter == -1 {
    3
  } else if alter <= -2 {
    6
  } else {
    4
  }
}
