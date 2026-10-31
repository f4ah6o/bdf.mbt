///|
// Adjustable arc paths generated from the upstream DrawingML definitions.
fn sheet_adjustable_arc_preset_path(
  geometry : String,
  width : Double,
  height : Double,
  adjustment : Int64?,
  extra~ : Map[String, Int64] = Map([]),
) -> @core.Path {
  let ss = Double::min(width, height)
  let ls = Double::max(width, height)
  let env : Map[String, Double] = Map([])
  env["w"] = width
  env["h"] = height
  env["l"] = 0.0
  env["t"] = 0.0
  env["r"] = width
  env["b"] = height
  env["hc"] = width / 2.0
  env["vc"] = height / 2.0
  env["ss"] = ss
  env["ls"] = ls
  env["cd2"] = 10800000.0
  env["cd4"] = 5400000.0
  env["3cd4"] = 16200000.0
  env["wd2"] = width / 2.0
  env["hd2"] = height / 2.0
  env["ssd2"] = ss / 2.0
  env["wd3"] = width / 3.0
  env["hd3"] = height / 3.0
  env["ssd3"] = ss / 3.0
  env["wd4"] = width / 4.0
  env["hd4"] = height / 4.0
  env["ssd4"] = ss / 4.0
  env["wd5"] = width / 5.0
  env["hd5"] = height / 5.0
  env["ssd5"] = ss / 5.0
  env["wd6"] = width / 6.0
  env["hd6"] = height / 6.0
  env["ssd6"] = ss / 6.0
  env["wd8"] = width / 8.0
  env["hd8"] = height / 8.0
  env["ssd8"] = ss / 8.0
  env["wd10"] = width / 10.0
  env["hd10"] = height / 10.0
  env["ssd10"] = ss / 10.0
  env["wd12"] = width / 12.0
  env["hd12"] = height / 12.0
  env["ssd12"] = ss / 12.0
  env["wd16"] = width / 16.0
  env["hd16"] = height / 16.0
  env["ssd16"] = ss / 16.0
  env["wd32"] = width / 32.0
  env["hd32"] = height / 32.0
  env["ssd32"] = ss / 32.0
  let builder : SheetArcPath = { verbs: [], coordinates: [], x: 0.0, y: 0.0, }
  match geometry {
    "plaque" => {
      env["adj"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        16667.0
      }
      env["a"] = sheet_preset_pin(0.0, env.get("adj").unwrap_or(0.0), 50000.0)
      env["x1"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a").unwrap_or(0.0),
        100000.0,
      )
      env["x2"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("x1").unwrap_or(0.0)
      env["y2"] = env.get("b").unwrap_or(0.0) +
        0.0 -
        env.get("x1").unwrap_or(0.0)
      env["il"] = sheet_preset_muldiv(
        env.get("x1").unwrap_or(0.0),
        70711.0,
        100000.0,
      )
      env["ir"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("il").unwrap_or(0.0)
      env["ib"] = env.get("b").unwrap_or(0.0) +
        0.0 -
        env.get("il").unwrap_or(0.0)
      let sx = 1.0
      let sy = 1.0
      builder.move(
        env.get("l").unwrap_or(0.0) * sx,
        env.get("x1").unwrap_or(0.0) * sy,
      )
      builder.arc(
        env.get("x1").unwrap_or(0.0) * sx,
        env.get("x1").unwrap_or(0.0) * sy,
        env.get("cd4").unwrap_or(0.0),
        -5400000.0,
        go_angles=true,
      )
      builder.line(
        env.get("x2").unwrap_or(0.0) * sx,
        env.get("t").unwrap_or(0.0) * sy,
      )
      builder.arc(
        env.get("x1").unwrap_or(0.0) * sx,
        env.get("x1").unwrap_or(0.0) * sy,
        env.get("cd2").unwrap_or(0.0),
        -5400000.0,
        go_angles=true,
      )
      builder.line(
        env.get("r").unwrap_or(0.0) * sx,
        env.get("y2").unwrap_or(0.0) * sy,
      )
      builder.arc(
        env.get("x1").unwrap_or(0.0) * sx,
        env.get("x1").unwrap_or(0.0) * sy,
        env.get("3cd4").unwrap_or(0.0),
        -5400000.0,
        go_angles=true,
      )
      builder.line(
        env.get("x1").unwrap_or(0.0) * sx,
        env.get("b").unwrap_or(0.0) * sy,
      )
      builder.arc(
        env.get("x1").unwrap_or(0.0) * sx,
        env.get("x1").unwrap_or(0.0) * sy,
        0.0,
        -5400000.0,
        go_angles=true,
      )
      builder.verbs.push(b'\x04')
    }
    "round1Rect" => {
      env["adj"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        16667.0
      }
      env["a"] = sheet_preset_pin(0.0, env.get("adj").unwrap_or(0.0), 50000.0)
      env["dx1"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a").unwrap_or(0.0),
        100000.0,
      )
      env["x1"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("dx1").unwrap_or(0.0)
      env["idx"] = sheet_preset_muldiv(
        env.get("dx1").unwrap_or(0.0),
        29289.0,
        100000.0,
      )
      env["ir"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("idx").unwrap_or(0.0)
      let sx = 1.0
      let sy = 1.0
      builder.move(
        env.get("l").unwrap_or(0.0) * sx,
        env.get("t").unwrap_or(0.0) * sy,
      )
      builder.line(
        env.get("x1").unwrap_or(0.0) * sx,
        env.get("t").unwrap_or(0.0) * sy,
      )
      builder.arc(
        env.get("dx1").unwrap_or(0.0) * sx,
        env.get("dx1").unwrap_or(0.0) * sy,
        env.get("3cd4").unwrap_or(0.0),
        env.get("cd4").unwrap_or(0.0),
        go_angles=true,
      )
      builder.line(
        env.get("r").unwrap_or(0.0) * sx,
        env.get("b").unwrap_or(0.0) * sy,
      )
      builder.line(
        env.get("l").unwrap_or(0.0) * sx,
        env.get("b").unwrap_or(0.0) * sy,
      )
      builder.verbs.push(b'\x04')
    }
    "round2DiagRect" => {
      env["adj1"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        16667.0
      }
      env["adj2"] = match extra.get("adj2") {
        Some(value) => value.to_double()
        None => 0.0
      }
      env["a1"] = sheet_preset_pin(0.0, env.get("adj1").unwrap_or(0.0), 50000.0)
      env["a2"] = sheet_preset_pin(0.0, env.get("adj2").unwrap_or(0.0), 50000.0)
      env["x1"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        100000.0,
      )
      env["y1"] = env.get("b").unwrap_or(0.0) +
        0.0 -
        env.get("x1").unwrap_or(0.0)
      env["a"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
        100000.0,
      )
      env["x2"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("a").unwrap_or(0.0)
      env["y2"] = env.get("b").unwrap_or(0.0) +
        0.0 -
        env.get("a").unwrap_or(0.0)
      env["dx1"] = sheet_preset_muldiv(
        env.get("x1").unwrap_or(0.0),
        29289.0,
        100000.0,
      )
      env["dx2"] = sheet_preset_muldiv(
        env.get("a").unwrap_or(0.0),
        29289.0,
        100000.0,
      )
      env["d"] = env.get("dx1").unwrap_or(0.0) +
        0.0 -
        env.get("dx2").unwrap_or(0.0)
      env["dx"] = if env.get("d").unwrap_or(0.0) > 0.0 {
        env.get("dx1").unwrap_or(0.0)
      } else {
        env.get("dx2").unwrap_or(0.0)
      }
      env["ir"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("dx").unwrap_or(0.0)
      env["ib"] = env.get("b").unwrap_or(0.0) +
        0.0 -
        env.get("dx").unwrap_or(0.0)
      let sx = 1.0
      let sy = 1.0
      builder.move(
        env.get("x1").unwrap_or(0.0) * sx,
        env.get("t").unwrap_or(0.0) * sy,
      )
      builder.line(
        env.get("x2").unwrap_or(0.0) * sx,
        env.get("t").unwrap_or(0.0) * sy,
      )
      builder.arc(
        env.get("a").unwrap_or(0.0) * sx,
        env.get("a").unwrap_or(0.0) * sy,
        env.get("3cd4").unwrap_or(0.0),
        env.get("cd4").unwrap_or(0.0),
        go_angles=true,
      )
      builder.line(
        env.get("r").unwrap_or(0.0) * sx,
        env.get("y1").unwrap_or(0.0) * sy,
      )
      builder.arc(
        env.get("x1").unwrap_or(0.0) * sx,
        env.get("x1").unwrap_or(0.0) * sy,
        0.0,
        env.get("cd4").unwrap_or(0.0),
        go_angles=true,
      )
      builder.line(
        env.get("a").unwrap_or(0.0) * sx,
        env.get("b").unwrap_or(0.0) * sy,
      )
      builder.arc(
        env.get("a").unwrap_or(0.0) * sx,
        env.get("a").unwrap_or(0.0) * sy,
        env.get("cd4").unwrap_or(0.0),
        env.get("cd4").unwrap_or(0.0),
        go_angles=true,
      )
      builder.line(
        env.get("l").unwrap_or(0.0) * sx,
        env.get("x1").unwrap_or(0.0) * sy,
      )
      builder.arc(
        env.get("x1").unwrap_or(0.0) * sx,
        env.get("x1").unwrap_or(0.0) * sy,
        env.get("cd2").unwrap_or(0.0),
        env.get("cd4").unwrap_or(0.0),
        go_angles=true,
      )
      builder.verbs.push(b'\x04')
    }
    "round2SameRect" => {
      env["adj1"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        16667.0
      }
      env["adj2"] = match extra.get("adj2") {
        Some(value) => value.to_double()
        None => 0.0
      }
      env["a1"] = sheet_preset_pin(0.0, env.get("adj1").unwrap_or(0.0), 50000.0)
      env["a2"] = sheet_preset_pin(0.0, env.get("adj2").unwrap_or(0.0), 50000.0)
      env["tx1"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        100000.0,
      )
      env["tx2"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("tx1").unwrap_or(0.0)
      env["bx1"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
        100000.0,
      )
      env["bx2"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("bx1").unwrap_or(0.0)
      env["by1"] = env.get("b").unwrap_or(0.0) +
        0.0 -
        env.get("bx1").unwrap_or(0.0)
      env["d"] = env.get("tx1").unwrap_or(0.0) +
        0.0 -
        env.get("bx1").unwrap_or(0.0)
      env["tdx"] = sheet_preset_muldiv(
        env.get("tx1").unwrap_or(0.0),
        29289.0,
        100000.0,
      )
      env["bdx"] = sheet_preset_muldiv(
        env.get("bx1").unwrap_or(0.0),
        29289.0,
        100000.0,
      )
      env["il"] = if env.get("d").unwrap_or(0.0) > 0.0 {
        env.get("tdx").unwrap_or(0.0)
      } else {
        env.get("bdx").unwrap_or(0.0)
      }
      env["ir"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("il").unwrap_or(0.0)
      env["ib"] = env.get("b").unwrap_or(0.0) +
        0.0 -
        env.get("bdx").unwrap_or(0.0)
      let sx = 1.0
      let sy = 1.0
      builder.move(
        env.get("tx1").unwrap_or(0.0) * sx,
        env.get("t").unwrap_or(0.0) * sy,
      )
      builder.line(
        env.get("tx2").unwrap_or(0.0) * sx,
        env.get("t").unwrap_or(0.0) * sy,
      )
      builder.arc(
        env.get("tx1").unwrap_or(0.0) * sx,
        env.get("tx1").unwrap_or(0.0) * sy,
        env.get("3cd4").unwrap_or(0.0),
        env.get("cd4").unwrap_or(0.0),
        go_angles=true,
      )
      builder.line(
        env.get("r").unwrap_or(0.0) * sx,
        env.get("by1").unwrap_or(0.0) * sy,
      )
      builder.arc(
        env.get("bx1").unwrap_or(0.0) * sx,
        env.get("bx1").unwrap_or(0.0) * sy,
        0.0,
        env.get("cd4").unwrap_or(0.0),
        go_angles=true,
      )
      builder.line(
        env.get("bx1").unwrap_or(0.0) * sx,
        env.get("b").unwrap_or(0.0) * sy,
      )
      builder.arc(
        env.get("bx1").unwrap_or(0.0) * sx,
        env.get("bx1").unwrap_or(0.0) * sy,
        env.get("cd4").unwrap_or(0.0),
        env.get("cd4").unwrap_or(0.0),
        go_angles=true,
      )
      builder.line(
        env.get("l").unwrap_or(0.0) * sx,
        env.get("tx1").unwrap_or(0.0) * sy,
      )
      builder.arc(
        env.get("tx1").unwrap_or(0.0) * sx,
        env.get("tx1").unwrap_or(0.0) * sy,
        env.get("cd2").unwrap_or(0.0),
        env.get("cd4").unwrap_or(0.0),
        go_angles=true,
      )
      builder.verbs.push(b'\x04')
    }
    "snipRoundRect" => {
      env["adj1"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        16667.0
      }
      env["adj2"] = match extra.get("adj2") {
        Some(value) => value.to_double()
        None => 16667.0
      }
      env["a1"] = sheet_preset_pin(0.0, env.get("adj1").unwrap_or(0.0), 50000.0)
      env["a2"] = sheet_preset_pin(0.0, env.get("adj2").unwrap_or(0.0), 50000.0)
      env["x1"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        100000.0,
      )
      env["dx2"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
        100000.0,
      )
      env["x2"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("dx2").unwrap_or(0.0)
      env["il"] = sheet_preset_muldiv(
        env.get("x1").unwrap_or(0.0),
        29289.0,
        100000.0,
      )
      env["ir"] = sheet_preset_adddiv(
        env.get("x2").unwrap_or(0.0),
        env.get("r").unwrap_or(0.0),
        2.0,
      )
      let sx = 1.0
      let sy = 1.0
      builder.move(
        env.get("x1").unwrap_or(0.0) * sx,
        env.get("t").unwrap_or(0.0) * sy,
      )
      builder.line(
        env.get("x2").unwrap_or(0.0) * sx,
        env.get("t").unwrap_or(0.0) * sy,
      )
      builder.line(
        env.get("r").unwrap_or(0.0) * sx,
        env.get("dx2").unwrap_or(0.0) * sy,
      )
      builder.line(
        env.get("r").unwrap_or(0.0) * sx,
        env.get("b").unwrap_or(0.0) * sy,
      )
      builder.line(
        env.get("l").unwrap_or(0.0) * sx,
        env.get("b").unwrap_or(0.0) * sy,
      )
      builder.line(
        env.get("l").unwrap_or(0.0) * sx,
        env.get("x1").unwrap_or(0.0) * sy,
      )
      builder.arc(
        env.get("x1").unwrap_or(0.0) * sx,
        env.get("x1").unwrap_or(0.0) * sy,
        env.get("cd2").unwrap_or(0.0),
        env.get("cd4").unwrap_or(0.0),
        go_angles=true,
      )
      builder.verbs.push(b'\x04')
    }
    "bentArrow" => {
      env["adj1"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        25000.0
      }
      env["adj2"] = match extra.get("adj2") {
        Some(value) => value.to_double()
        None => 25000.0
      }
      env["adj3"] = match extra.get("adj3") {
        Some(value) => value.to_double()
        None => 25000.0
      }
      env["adj4"] = match extra.get("adj4") {
        Some(value) => value.to_double()
        None => 43750.0
      }
      env["a2"] = sheet_preset_pin(0.0, env.get("adj2").unwrap_or(0.0), 50000.0)
      env["maxAdj1"] = sheet_preset_muldiv(
        env.get("a2").unwrap_or(0.0),
        2.0,
        1.0,
      )
      env["a1"] = sheet_preset_pin(
        0.0,
        env.get("adj1").unwrap_or(0.0),
        env.get("maxAdj1").unwrap_or(0.0),
      )
      env["a3"] = sheet_preset_pin(0.0, env.get("adj3").unwrap_or(0.0), 50000.0)
      env["th"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        100000.0,
      )
      env["aw2"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
        100000.0,
      )
      env["th2"] = sheet_preset_muldiv(env.get("th").unwrap_or(0.0), 1.0, 2.0)
      env["dh2"] = env.get("aw2").unwrap_or(0.0) +
        0.0 -
        env.get("th2").unwrap_or(0.0)
      env["ah"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a3").unwrap_or(0.0),
        100000.0,
      )
      env["bw"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("ah").unwrap_or(0.0)
      env["bh"] = env.get("b").unwrap_or(0.0) +
        0.0 -
        env.get("dh2").unwrap_or(0.0)
      env["bs"] = Double::min(
        env.get("bw").unwrap_or(0.0),
        env.get("bh").unwrap_or(0.0),
      )
      env["maxAdj4"] = sheet_preset_muldiv(
        100000.0,
        env.get("bs").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
      )
      env["a4"] = sheet_preset_pin(
        0.0,
        env.get("adj4").unwrap_or(0.0),
        env.get("maxAdj4").unwrap_or(0.0),
      )
      env["bd"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a4").unwrap_or(0.0),
        100000.0,
      )
      env["bd3"] = env.get("bd").unwrap_or(0.0) +
        0.0 -
        env.get("th").unwrap_or(0.0)
      env["bd2"] = Double::max(env.get("bd3").unwrap_or(0.0), 0.0)
      env["x3"] = env.get("th").unwrap_or(0.0) +
        env.get("bd2").unwrap_or(0.0) -
        0.0
      env["x4"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("ah").unwrap_or(0.0)
      env["y3"] = env.get("dh2").unwrap_or(0.0) +
        env.get("th").unwrap_or(0.0) -
        0.0
      env["y4"] = env.get("y3").unwrap_or(0.0) +
        env.get("dh2").unwrap_or(0.0) -
        0.0
      env["y5"] = env.get("dh2").unwrap_or(0.0) +
        env.get("bd").unwrap_or(0.0) -
        0.0
      env["y6"] = env.get("y3").unwrap_or(0.0) +
        env.get("bd2").unwrap_or(0.0) -
        0.0
      let sx = 1.0
      let sy = 1.0
      builder.move(
        env.get("l").unwrap_or(0.0) * sx,
        env.get("b").unwrap_or(0.0) * sy,
      )
      builder.line(
        env.get("l").unwrap_or(0.0) * sx,
        env.get("y5").unwrap_or(0.0) * sy,
      )
      builder.arc(
        env.get("bd").unwrap_or(0.0) * sx,
        env.get("bd").unwrap_or(0.0) * sy,
        env.get("cd2").unwrap_or(0.0),
        env.get("cd4").unwrap_or(0.0),
        go_angles=true,
      )
      builder.line(
        env.get("x4").unwrap_or(0.0) * sx,
        env.get("dh2").unwrap_or(0.0) * sy,
      )
      builder.line(
        env.get("x4").unwrap_or(0.0) * sx,
        env.get("t").unwrap_or(0.0) * sy,
      )
      builder.line(
        env.get("r").unwrap_or(0.0) * sx,
        env.get("aw2").unwrap_or(0.0) * sy,
      )
      builder.line(
        env.get("x4").unwrap_or(0.0) * sx,
        env.get("y4").unwrap_or(0.0) * sy,
      )
      builder.line(
        env.get("x4").unwrap_or(0.0) * sx,
        env.get("y3").unwrap_or(0.0) * sy,
      )
      builder.line(
        env.get("x3").unwrap_or(0.0) * sx,
        env.get("y3").unwrap_or(0.0) * sy,
      )
      builder.arc(
        env.get("bd2").unwrap_or(0.0) * sx,
        env.get("bd2").unwrap_or(0.0) * sy,
        env.get("3cd4").unwrap_or(0.0),
        -5400000.0,
        go_angles=true,
      )
      builder.line(
        env.get("th").unwrap_or(0.0) * sx,
        env.get("b").unwrap_or(0.0) * sy,
      )
      builder.verbs.push(b'\x04')
    }
    _ => abort("unknown adjustable arc preset")
  }
  { verbs: Bytes::from_array(builder.verbs), coordinates: builder.coordinates, }
}
