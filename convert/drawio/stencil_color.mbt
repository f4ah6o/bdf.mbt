///|
/// CSS/draw.io color parsing for stencil elements, a port of the upstream
/// converter's color.go. Colors are 0xRRGGBBAA, the same packing the rest
/// of the draw.io converter uses.

///|
/// Parse a draw.io color: #rgb, #rrggbb, #rrggbbaa, rgb()/rgba(), CSS
/// color names and light-dark(light, dark) (the light color is used).
/// None for "none", "transparent", empty and unknown values.
fn drawio_parse_color(text : String) -> UInt32? {
  let s = sfc_drawio_trim(text)
  if s == "" {
    return None
  }
  let low = s.to_lower()
  if low.has_prefix("light-dark(") && low.has_suffix(")") {
    let args = drawio_split_args(s[11:s.length() - 1].to_string())
    if args.length() > 0 {
      return drawio_parse_color(args[0])
    }
    return None
  }
  if low == "none" || low == "transparent" || low == "inherit" ||
    low == "initial" || low == "unset" {
    return None
  }
  if low[0].unsafe_to_char() == '#' {
    let h = low[1:].to_owned()
    if h.length() == 3 || h.length() == 4 {
      let v : Array[Int] = [0, 0, 0, 255]
      let mut ok = true
      for i in 0..<h.length() {
        match drawio_hex_nibble(h[i].unsafe_to_char()) {
          Some(n) => v[i] = n * 17
          None => {
            ok = false
            break
          }
        }
      }
      if ok {
        return Some(drawio_rgba(v[0], v[1], v[2], v[3]))
      }
      return None
    }
    if h.length() == 6 || h.length() == 8 {
      let n = drawio_parse_hex(h)
      match n {
        Some(v) =>
          if h.length() == 6 {
            Some(drawio_rgba((v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff, 255))
          } else {
            Some(
              drawio_rgba((v >> 24) & 0xff, (v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff),
            )
          }
        None => None
      }
    } else {
      None
    }
  } else if low.has_prefix("rgb") {
    let open = low.find("(")
    let close = low.find(")")
    match (open, close) {
      (Some(o), Some(c)) if c > o => {
        let inner = low[o + 1:c].to_string().replace(old="/", new=",")
        let args = drawio_split_args(inner)
        if args.length() < 3 {
          return None
        }
        let ch : Array[Int] = []
        for i in 0..<3 {
          let a = sfc_drawio_trim(args[i])
          let pct = a.has_suffix("%")
          let body = if pct { a[:a.length() - 1].to_owned() } else { a }
          let f = @string.parse_double(body) catch { _ => -1.0 }
          if f < 0.0 {
            return None
          }
          let v = if pct { f * 255.0 / 100.0 } else { f }
          ch.push(v.max(0.0).min(255.0).round().to_int())
        }
        let mut alpha = 255
        if args.length() > 3 {
          let a = sfc_drawio_trim(args[3])
          let pct = a.has_suffix("%")
          let body = if pct { a[:a.length() - 1].to_owned() } else { a }
          let f = @string.parse_double(body) catch { _ => -1.0 }
          if f >= 0.0 {
            let v = if pct { f / 100.0 } else { f }
            alpha = (v.max(0.0).min(1.0) * 255.0).round().to_int()
          }
        }
        Some(drawio_rgba(ch[0], ch[1], ch[2], alpha))
      }
      _ => None
    }
  } else {
    drawio_css_color(low)
  }
}

///|
fn drawio_rgba(r : Int, g : Int, b : Int, a : Int) -> UInt32 {
  (((r & 0xff) << 24) | ((g & 0xff) << 16) | ((b & 0xff) << 8) | (a & 0xff)).to_uint()
}

///|
fn drawio_hex_nibble(c : Char) -> Int? {
  let v = c.to_int()
  if v >= 48 && v <= 57 {
    Some(v - 48)
  } else if v >= 97 && v <= 102 {
    Some(v - 87)
  } else if v >= 65 && v <= 70 {
    Some(v - 55)
  } else {
    None
  }
}

///|
fn drawio_parse_hex(h : String) -> Int? {
  let mut n = 0
  for c in h {
    match drawio_hex_nibble(c) {
      Some(v) => n = n * 16 + v
      None => return None
    }
  }
  Some(n)
}

///|
/// Split a comma separated argument list at the top level of parentheses.
fn drawio_split_args(s : String) -> Array[String] {
  let out : Array[String] = []
  let mut depth = 0
  let mut start = 0
  let mut i = 0
  while i < s.length() {
    let c = s[i].unsafe_to_char()
    if c == '(' {
      depth += 1
    } else if c == ')' {
      depth -= 1
    } else if c == ',' && depth == 0 {
      out.push(sfc_drawio_trim(s[start:i]))
      start = i + 1
    }
    i += 1
  }
  out.push(sfc_drawio_trim(s[start:]))
  out
}

///|
/// The alpha byte of a packed color multiplied by f (0-1).
fn drawio_color_alpha_mul(color : UInt32, f : Double) -> UInt32 {
  let a = (((color & 0xffU).to_int()).to_double() * f.max(0.0).min(1.0)).round().to_int()
  (color & 0xffffff00U) | (a.max(0).min(255)).to_uint()
}

///|
/// Whether a string is a CSS color (mxUtils.isValidColor).
fn drawio_color_valid(value : String) -> Bool {
  let t = sfc_drawio_trim(value).to_lower()
  if t == "transparent" {
    return true
  }
  drawio_parse_color(value) is Some(_)
}

///|
/// Number(s) as JavaScript's Number() does: blank is 0, anything that is
/// not a number is NaN.
fn drawio_number_js(s : String) -> Double {
  let t = sfc_drawio_trim(s)
  if t == "" {
    return 0.0
  }
  if t.length() > 2 && t[0].unsafe_to_char() == '0' &&
    (t[1].unsafe_to_char() == 'x' || t[1].unsafe_to_char() == 'X') {
    let mut n = 0
    for i in 2..<t.length() {
      match drawio_hex_nibble(t[i].unsafe_to_char()) {
        Some(v) => n = n * 16 + v
        None => return 0.0 / 0.0
      }
    }
    return n.to_double()
  }
  if t == "Infinity" || t == "+Infinity" {
    return 1.0 / 0.0
  }
  if t == "-Infinity" {
    return -1.0 / 0.0
  }
  @string.parse_double(t) catch {
    _ => 0.0 / 0.0
  }
}

///|
/// CSS named colors (0xRRGGBB without alpha).
fn drawio_css_color(name : String) -> UInt32? {
  let v = match name {
    "aliceblue" => 0xf0f8ff
    "antiquewhite" => 0xfaebd7
    "aqua" => 0x00ffff
    "aquamarine" => 0x7fffd4
    "azure" => 0xf0ffff
    "beige" => 0xf5f5dc
    "bisque" => 0xffe4c4
    "black" => 0x000000
    "blanchedalmond" => 0xffebcd
    "blue" => 0x0000ff
    "blueviolet" => 0x8a2be2
    "brown" => 0xa52a2a
    "burlywood" => 0xdeb887
    "cadetblue" => 0x5f9ea0
    "chartreuse" => 0x7fff00
    "chocolate" => 0xd2691e
    "coral" => 0xff7f50
    "cornflowerblue" => 0x6495ed
    "cornsilk" => 0xfff8dc
    "crimson" => 0xdc143c
    "cyan" => 0x00ffff
    "darkblue" => 0x00008b
    "darkcyan" => 0x008b8b
    "darkgoldenrod" => 0xb8860b
    "darkgray" => 0xa9a9a9
    "darkgreen" => 0x006400
    "darkgrey" => 0xa9a9a9
    "darkkhaki" => 0xbdb76b
    "darkmagenta" => 0x8b008b
    "darkolivegreen" => 0x556b2f
    "darkorange" => 0xff8c00
    "darkorchid" => 0x9932cc
    "darkred" => 0x8b0000
    "darksalmon" => 0xe9967a
    "darkseagreen" => 0x8fbc8f
    "darkslateblue" => 0x483d8b
    "darkslategray" => 0x2f4f4f
    "darkslategrey" => 0x2f4f4f
    "darkturquoise" => 0x00ced1
    "darkviolet" => 0x9400d3
    "deeppink" => 0xff1493
    "deepskyblue" => 0x00bfff
    "dimgray" => 0x696969
    "dimgrey" => 0x696969
    "dodgerblue" => 0x1e90ff
    "firebrick" => 0xb22222
    "floralwhite" => 0xfffaf0
    "forestgreen" => 0x228b22
    "fuchsia" => 0xff00ff
    "gainsboro" => 0xdcdcdc
    "ghostwhite" => 0xf8f8ff
    "gold" => 0xffd700
    "goldenrod" => 0xdaa520
    "gray" => 0x808080
    "green" => 0x008000
    "greenyellow" => 0xadff2f
    "grey" => 0x808080
    "honeydew" => 0xf0fff0
    "hotpink" => 0xff69b4
    "indianred" => 0xcd5c5c
    "indigo" => 0x4b0082
    "ivory" => 0xfffff0
    "khaki" => 0xf0e68c
    "lavender" => 0xe6e6fa
    "lavenderblush" => 0xfff0f5
    "lawngreen" => 0x7cfc00
    "lemonchiffon" => 0xfffacd
    "lightblue" => 0xadd8e6
    "lightcoral" => 0xf08080
    "lightcyan" => 0xe0ffff
    "lightgoldenrodyellow" => 0xfafad2
    "lightgray" => 0xd3d3d3
    "lightgreen" => 0x90ee90
    "lightgrey" => 0xd3d3d3
    "lightpink" => 0xffb6c1
    "lightsalmon" => 0xffa07a
    "lightseagreen" => 0x20b2aa
    "lightskyblue" => 0x87cefa
    "lightslategray" => 0x778899
    "lightslategrey" => 0x778899
    "lightsteelblue" => 0xb0c4de
    "lightyellow" => 0xffffe0
    "lime" => 0x00ff00
    "limegreen" => 0x32cd32
    "linen" => 0xfaf0e6
    "magenta" => 0xff00ff
    "maroon" => 0x800000
    "mediumaquamarine" => 0x66cdaa
    "mediumblue" => 0x0000cd
    "mediumorchid" => 0xba55d3
    "mediumpurple" => 0x9370db
    "mediumseagreen" => 0x3cb371
    "mediumslateblue" => 0x7b68ee
    "mediumspringgreen" => 0x00fa9a
    "mediumturquoise" => 0x48d1cc
    "mediumvioletred" => 0xc71585
    "midnightblue" => 0x191970
    "mintcream" => 0xf5fffa
    "mistyrose" => 0xffe4e1
    "moccasin" => 0xffe4b5
    "navajowhite" => 0xffdead
    "navy" => 0x000080
    "oldlace" => 0xfdf5e6
    "olive" => 0x808000
    "olivedrab" => 0x6b8e23
    "orange" => 0xffa500
    "orangered" => 0xff4500
    "orchid" => 0xda70d6
    "palegoldenrod" => 0xeee8aa
    "palegreen" => 0x98fb98
    "paleturquoise" => 0xafeeee
    "palevioletred" => 0xdb7093
    "papayawhip" => 0xffefd5
    "peachpuff" => 0xffdab9
    "peru" => 0xcd853f
    "pink" => 0xffc0cb
    "plum" => 0xdda0dd
    "powderblue" => 0xb0e0e6
    "purple" => 0x800080
    "rebeccapurple" => 0x663399
    "red" => 0xff0000
    "rosybrown" => 0xbc8f8f
    "royalblue" => 0x4169e1
    "saddlebrown" => 0x8b4513
    "salmon" => 0xfa8072
    "sandybrown" => 0xf4a460
    "seagreen" => 0x2e8b57
    "seashell" => 0xfff5ee
    "sienna" => 0xa0522d
    "silver" => 0xc0c0c0
    "skyblue" => 0x87ceeb
    "slateblue" => 0x6a5acd
    "slategray" => 0x708090
    "slategrey" => 0x708090
    "snow" => 0xfffafa
    "springgreen" => 0x00ff7f
    "steelblue" => 0x4682b4
    "tan" => 0xd2b48c
    "teal" => 0x008080
    "thistle" => 0xd8bfd8
    "tomato" => 0xff6347
    "turquoise" => 0x40e0d0
    "violet" => 0xee82ee
    "wheat" => 0xf5deb3
    "white" => 0xffffff
    "whitesmoke" => 0xf5f5f5
    "yellow" => 0xffff00
    "yellowgreen" => 0x9acd32
    _ => return None
  }
  Some(drawio_rgba((v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff, 255))
}
