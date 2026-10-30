///|
// Straight-line preset paths generated from the upstream DrawingML definitions.
fn sheet_formula_preset_path(
  geometry : String,
  width : Double,
  height : Double,
  adjustment : Int64?,
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
  match geometry {
    "bentUpArrow" => {
      env["adj1"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        25000.0
      }
      env["adj2"] = 25000.0
      env["adj3"] = 25000.0
      env["a1"] = sheet_preset_pin(0.0, env.get("adj1").unwrap_or(0.0), 50000.0)
      env["a2"] = sheet_preset_pin(0.0, env.get("adj2").unwrap_or(0.0), 50000.0)
      env["a3"] = sheet_preset_pin(0.0, env.get("adj3").unwrap_or(0.0), 50000.0)
      env["y1"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a3").unwrap_or(0.0),
        100000.0,
      )
      env["dx1"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
        50000.0,
      )
      env["x1"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("dx1").unwrap_or(0.0)
      env["dx3"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
        100000.0,
      )
      env["x3"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("dx3").unwrap_or(0.0)
      env["dx2"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        200000.0,
      )
      env["x2"] = env.get("x3").unwrap_or(0.0) +
        0.0 -
        env.get("dx2").unwrap_or(0.0)
      env["x4"] = env.get("x3").unwrap_or(0.0) +
        env.get("dx2").unwrap_or(0.0) -
        0.0
      env["dy2"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        100000.0,
      )
      env["y2"] = env.get("b").unwrap_or(0.0) +
        0.0 -
        env.get("dy2").unwrap_or(0.0)
      env["x0"] = sheet_preset_muldiv(env.get("x4").unwrap_or(0.0), 1.0, 2.0)
      env["y3"] = sheet_preset_adddiv(
        env.get("y2").unwrap_or(0.0),
        env.get("b").unwrap_or(0.0),
        2.0,
      )
      env["y15"] = sheet_preset_adddiv(
        env.get("y1").unwrap_or(0.0),
        env.get("b").unwrap_or(0.0),
        2.0,
      )
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x01\x01\x01\x01\x01\x04",
        coordinates: [
          env.get("l").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("x4").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("x4").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("l").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
        ],
      }
    }
    "corner" => {
      env["adj1"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        50000.0
      }
      env["adj2"] = 50000.0
      env["maxAdj1"] = sheet_preset_muldiv(
        100000.0,
        env.get("h").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
      )
      env["maxAdj2"] = sheet_preset_muldiv(
        100000.0,
        env.get("w").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
      )
      env["a1"] = sheet_preset_pin(
        0.0,
        env.get("adj1").unwrap_or(0.0),
        env.get("maxAdj1").unwrap_or(0.0),
      )
      env["a2"] = sheet_preset_pin(
        0.0,
        env.get("adj2").unwrap_or(0.0),
        env.get("maxAdj2").unwrap_or(0.0),
      )
      env["x1"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
        100000.0,
      )
      env["dy1"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        100000.0,
      )
      env["y1"] = env.get("b").unwrap_or(0.0) +
        0.0 -
        env.get("dy1").unwrap_or(0.0)
      env["cx1"] = sheet_preset_muldiv(env.get("x1").unwrap_or(0.0), 1.0, 2.0)
      env["cy1"] = sheet_preset_adddiv(
        env.get("y1").unwrap_or(0.0),
        env.get("b").unwrap_or(0.0),
        2.0,
      )
      env["d"] = env.get("w").unwrap_or(0.0) + 0.0 - env.get("h").unwrap_or(0.0)
      env["it"] = if env.get("d").unwrap_or(0.0) > 0.0 {
        env.get("y1").unwrap_or(0.0)
      } else {
        env.get("t").unwrap_or(0.0)
      }
      env["ir"] = if env.get("d").unwrap_or(0.0) > 0.0 {
        env.get("r").unwrap_or(0.0)
      } else {
        env.get("x1").unwrap_or(0.0)
      }
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x01\x01\x04",
        coordinates: [
          env.get("l").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("l").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
        ],
      }
    }
    "diagStripe" => {
      env["adj"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        50000.0
      }
      env["a"] = sheet_preset_pin(0.0, env.get("adj").unwrap_or(0.0), 100000.0)
      env["x2"] = sheet_preset_muldiv(
        env.get("w").unwrap_or(0.0),
        env.get("a").unwrap_or(0.0),
        100000.0,
      )
      env["x1"] = sheet_preset_muldiv(env.get("x2").unwrap_or(0.0), 1.0, 2.0)
      env["x3"] = sheet_preset_adddiv(
        env.get("x2").unwrap_or(0.0),
        env.get("r").unwrap_or(0.0),
        2.0,
      )
      env["y2"] = sheet_preset_muldiv(
        env.get("h").unwrap_or(0.0),
        env.get("a").unwrap_or(0.0),
        100000.0,
      )
      env["y1"] = sheet_preset_muldiv(env.get("y2").unwrap_or(0.0), 1.0, 2.0)
      env["y3"] = sheet_preset_adddiv(
        env.get("y2").unwrap_or(0.0),
        env.get("b").unwrap_or(0.0),
        2.0,
      )
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x04",
        coordinates: [
          env.get("l").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("l").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
        ],
      }
    }
    "dodecagon" => {
      env["x1"] = sheet_preset_muldiv(
        env.get("w").unwrap_or(0.0),
        2894.0,
        21600.0,
      )
      env["x2"] = sheet_preset_muldiv(
        env.get("w").unwrap_or(0.0),
        7906.0,
        21600.0,
      )
      env["x3"] = sheet_preset_muldiv(
        env.get("w").unwrap_or(0.0),
        13694.0,
        21600.0,
      )
      env["x4"] = sheet_preset_muldiv(
        env.get("w").unwrap_or(0.0),
        18706.0,
        21600.0,
      )
      env["y1"] = sheet_preset_muldiv(
        env.get("h").unwrap_or(0.0),
        2894.0,
        21600.0,
      )
      env["y2"] = sheet_preset_muldiv(
        env.get("h").unwrap_or(0.0),
        7906.0,
        21600.0,
      )
      env["y3"] = sheet_preset_muldiv(
        env.get("h").unwrap_or(0.0),
        13694.0,
        21600.0,
      )
      env["y4"] = sheet_preset_muldiv(
        env.get("h").unwrap_or(0.0),
        18706.0,
        21600.0,
      )
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x04",
        coordinates: [
          env.get("l").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("x4").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("x4").unwrap_or(0.0) * sx,
          env.get("y4").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y4").unwrap_or(0.0) * sy,
          env.get("l").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
        ],
      }
    }
    "downArrow" => {
      env["adj1"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        50000.0
      }
      env["adj2"] = 50000.0
      env["maxAdj2"] = sheet_preset_muldiv(
        100000.0,
        env.get("h").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
      )
      env["a1"] = sheet_preset_pin(
        0.0,
        env.get("adj1").unwrap_or(0.0),
        100000.0,
      )
      env["a2"] = sheet_preset_pin(
        0.0,
        env.get("adj2").unwrap_or(0.0),
        env.get("maxAdj2").unwrap_or(0.0),
      )
      env["dy1"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
        100000.0,
      )
      env["y1"] = env.get("b").unwrap_or(0.0) +
        0.0 -
        env.get("dy1").unwrap_or(0.0)
      env["dx1"] = sheet_preset_muldiv(
        env.get("w").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        200000.0,
      )
      env["x1"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("dx1").unwrap_or(0.0)
      env["x2"] = env.get("hc").unwrap_or(0.0) +
        env.get("dx1").unwrap_or(0.0) -
        0.0
      env["dy2"] = sheet_preset_muldiv(
        env.get("x1").unwrap_or(0.0),
        env.get("dy1").unwrap_or(0.0),
        env.get("wd2").unwrap_or(0.0),
      )
      env["y2"] = env.get("y1").unwrap_or(0.0) +
        env.get("dy2").unwrap_or(0.0) -
        0.0
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x01\x01\x01\x04",
        coordinates: [
          env.get("l").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("hc").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
        ],
      }
    }
    "downArrowCallout" => {
      env["adj1"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        25000.0
      }
      env["adj2"] = 25000.0
      env["adj3"] = 25000.0
      env["adj4"] = 64977.0
      env["maxAdj2"] = sheet_preset_muldiv(
        50000.0,
        env.get("w").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
      )
      env["a2"] = sheet_preset_pin(
        0.0,
        env.get("adj2").unwrap_or(0.0),
        env.get("maxAdj2").unwrap_or(0.0),
      )
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
      env["maxAdj3"] = sheet_preset_muldiv(
        100000.0,
        env.get("h").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
      )
      env["a3"] = sheet_preset_pin(
        0.0,
        env.get("adj3").unwrap_or(0.0),
        env.get("maxAdj3").unwrap_or(0.0),
      )
      env["q2"] = sheet_preset_muldiv(
        env.get("a3").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
        env.get("h").unwrap_or(0.0),
      )
      env["maxAdj4"] = 100000.0 + 0.0 - env.get("q2").unwrap_or(0.0)
      env["a4"] = sheet_preset_pin(
        0.0,
        env.get("adj4").unwrap_or(0.0),
        env.get("maxAdj4").unwrap_or(0.0),
      )
      env["dx1"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
        100000.0,
      )
      env["dx2"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        200000.0,
      )
      env["x1"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("dx1").unwrap_or(0.0)
      env["x2"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("dx2").unwrap_or(0.0)
      env["x3"] = env.get("hc").unwrap_or(0.0) +
        env.get("dx2").unwrap_or(0.0) -
        0.0
      env["x4"] = env.get("hc").unwrap_or(0.0) +
        env.get("dx1").unwrap_or(0.0) -
        0.0
      env["dy3"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a3").unwrap_or(0.0),
        100000.0,
      )
      env["y3"] = env.get("b").unwrap_or(0.0) +
        0.0 -
        env.get("dy3").unwrap_or(0.0)
      env["y2"] = sheet_preset_muldiv(
        env.get("h").unwrap_or(0.0),
        env.get("a4").unwrap_or(0.0),
        100000.0,
      )
      env["y1"] = sheet_preset_muldiv(env.get("y2").unwrap_or(0.0), 1.0, 2.0)
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x04",
        coordinates: [
          env.get("l").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("x4").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("hc").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("l").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
        ],
      }
    }
    "halfFrame" => {
      env["adj1"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        33333.0
      }
      env["adj2"] = 33333.0
      env["maxAdj2"] = sheet_preset_muldiv(
        100000.0,
        env.get("w").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
      )
      env["a2"] = sheet_preset_pin(
        0.0,
        env.get("adj2").unwrap_or(0.0),
        env.get("maxAdj2").unwrap_or(0.0),
      )
      env["x1"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
        100000.0,
      )
      env["g1"] = sheet_preset_muldiv(
        env.get("h").unwrap_or(0.0),
        env.get("x1").unwrap_or(0.0),
        env.get("w").unwrap_or(0.0),
      )
      env["g2"] = env.get("h").unwrap_or(0.0) +
        0.0 -
        env.get("g1").unwrap_or(0.0)
      env["maxAdj1"] = sheet_preset_muldiv(
        100000.0,
        env.get("g2").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
      )
      env["a1"] = sheet_preset_pin(
        0.0,
        env.get("adj1").unwrap_or(0.0),
        env.get("maxAdj1").unwrap_or(0.0),
      )
      env["y1"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        100000.0,
      )
      env["dx2"] = sheet_preset_muldiv(
        env.get("y1").unwrap_or(0.0),
        env.get("w").unwrap_or(0.0),
        env.get("h").unwrap_or(0.0),
      )
      env["x2"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("dx2").unwrap_or(0.0)
      env["dy2"] = sheet_preset_muldiv(
        env.get("x1").unwrap_or(0.0),
        env.get("h").unwrap_or(0.0),
        env.get("w").unwrap_or(0.0),
      )
      env["y2"] = env.get("b").unwrap_or(0.0) +
        0.0 -
        env.get("dy2").unwrap_or(0.0)
      env["cx1"] = sheet_preset_muldiv(env.get("x1").unwrap_or(0.0), 1.0, 2.0)
      env["cy1"] = sheet_preset_adddiv(
        env.get("y2").unwrap_or(0.0),
        env.get("b").unwrap_or(0.0),
        2.0,
      )
      env["cx2"] = sheet_preset_adddiv(
        env.get("x2").unwrap_or(0.0),
        env.get("r").unwrap_or(0.0),
        2.0,
      )
      env["cy2"] = sheet_preset_muldiv(env.get("y1").unwrap_or(0.0), 1.0, 2.0)
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x01\x01\x04",
        coordinates: [
          env.get("l").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("l").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
        ],
      }
    }
    "heptagon" => {
      env["hf"] = 102572.0
      env["vf"] = 105210.0
      env["swd2"] = sheet_preset_muldiv(
        env.get("wd2").unwrap_or(0.0),
        env.get("hf").unwrap_or(0.0),
        100000.0,
      )
      env["shd2"] = sheet_preset_muldiv(
        env.get("hd2").unwrap_or(0.0),
        env.get("vf").unwrap_or(0.0),
        100000.0,
      )
      env["svc"] = sheet_preset_muldiv(
        env.get("vc").unwrap_or(0.0),
        env.get("vf").unwrap_or(0.0),
        100000.0,
      )
      env["dx1"] = sheet_preset_muldiv(
        env.get("swd2").unwrap_or(0.0),
        97493.0,
        100000.0,
      )
      env["dx2"] = sheet_preset_muldiv(
        env.get("swd2").unwrap_or(0.0),
        78183.0,
        100000.0,
      )
      env["dx3"] = sheet_preset_muldiv(
        env.get("swd2").unwrap_or(0.0),
        43388.0,
        100000.0,
      )
      env["dy1"] = sheet_preset_muldiv(
        env.get("shd2").unwrap_or(0.0),
        62349.0,
        100000.0,
      )
      env["dy2"] = sheet_preset_muldiv(
        env.get("shd2").unwrap_or(0.0),
        22252.0,
        100000.0,
      )
      env["dy3"] = sheet_preset_muldiv(
        env.get("shd2").unwrap_or(0.0),
        90097.0,
        100000.0,
      )
      env["x1"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("dx1").unwrap_or(0.0)
      env["x2"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("dx2").unwrap_or(0.0)
      env["x3"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("dx3").unwrap_or(0.0)
      env["x4"] = env.get("hc").unwrap_or(0.0) +
        env.get("dx3").unwrap_or(0.0) -
        0.0
      env["x5"] = env.get("hc").unwrap_or(0.0) +
        env.get("dx2").unwrap_or(0.0) -
        0.0
      env["x6"] = env.get("hc").unwrap_or(0.0) +
        env.get("dx1").unwrap_or(0.0) -
        0.0
      env["y1"] = env.get("svc").unwrap_or(0.0) +
        0.0 -
        env.get("dy1").unwrap_or(0.0)
      env["y2"] = env.get("svc").unwrap_or(0.0) +
        env.get("dy2").unwrap_or(0.0) -
        0.0
      env["y3"] = env.get("svc").unwrap_or(0.0) +
        env.get("dy3").unwrap_or(0.0) -
        0.0
      env["ib"] = env.get("b").unwrap_or(0.0) +
        0.0 -
        env.get("y1").unwrap_or(0.0)
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x01\x01\x01\x04",
        coordinates: [
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("hc").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("x5").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("x6").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x4").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
        ],
      }
    }
    "leftArrow" => {
      env["adj1"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        50000.0
      }
      env["adj2"] = 50000.0
      env["maxAdj2"] = sheet_preset_muldiv(
        100000.0,
        env.get("w").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
      )
      env["a1"] = sheet_preset_pin(
        0.0,
        env.get("adj1").unwrap_or(0.0),
        100000.0,
      )
      env["a2"] = sheet_preset_pin(
        0.0,
        env.get("adj2").unwrap_or(0.0),
        env.get("maxAdj2").unwrap_or(0.0),
      )
      env["dx2"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
        100000.0,
      )
      env["x2"] = env.get("l").unwrap_or(0.0) +
        env.get("dx2").unwrap_or(0.0) -
        0.0
      env["dy1"] = sheet_preset_muldiv(
        env.get("h").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        200000.0,
      )
      env["y1"] = env.get("vc").unwrap_or(0.0) +
        0.0 -
        env.get("dy1").unwrap_or(0.0)
      env["y2"] = env.get("vc").unwrap_or(0.0) +
        env.get("dy1").unwrap_or(0.0) -
        0.0
      env["dx1"] = sheet_preset_muldiv(
        env.get("y1").unwrap_or(0.0),
        env.get("dx2").unwrap_or(0.0),
        env.get("hd2").unwrap_or(0.0),
      )
      env["x1"] = env.get("x2").unwrap_or(0.0) +
        0.0 -
        env.get("dx1").unwrap_or(0.0)
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x01\x01\x01\x04",
        coordinates: [
          env.get("l").unwrap_or(0.0) * sx,
          env.get("vc").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
        ],
      }
    }
    "leftArrowCallout" => {
      env["adj1"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        25000.0
      }
      env["adj2"] = 25000.0
      env["adj3"] = 25000.0
      env["adj4"] = 64977.0
      env["maxAdj2"] = sheet_preset_muldiv(
        50000.0,
        env.get("h").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
      )
      env["a2"] = sheet_preset_pin(
        0.0,
        env.get("adj2").unwrap_or(0.0),
        env.get("maxAdj2").unwrap_or(0.0),
      )
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
      env["maxAdj3"] = sheet_preset_muldiv(
        100000.0,
        env.get("w").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
      )
      env["a3"] = sheet_preset_pin(
        0.0,
        env.get("adj3").unwrap_or(0.0),
        env.get("maxAdj3").unwrap_or(0.0),
      )
      env["q2"] = sheet_preset_muldiv(
        env.get("a3").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
        env.get("w").unwrap_or(0.0),
      )
      env["maxAdj4"] = 100000.0 + 0.0 - env.get("q2").unwrap_or(0.0)
      env["a4"] = sheet_preset_pin(
        0.0,
        env.get("adj4").unwrap_or(0.0),
        env.get("maxAdj4").unwrap_or(0.0),
      )
      env["dy1"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
        100000.0,
      )
      env["dy2"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        200000.0,
      )
      env["y1"] = env.get("vc").unwrap_or(0.0) +
        0.0 -
        env.get("dy1").unwrap_or(0.0)
      env["y2"] = env.get("vc").unwrap_or(0.0) +
        0.0 -
        env.get("dy2").unwrap_or(0.0)
      env["y3"] = env.get("vc").unwrap_or(0.0) +
        env.get("dy2").unwrap_or(0.0) -
        0.0
      env["y4"] = env.get("vc").unwrap_or(0.0) +
        env.get("dy1").unwrap_or(0.0) -
        0.0
      env["x1"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a3").unwrap_or(0.0),
        100000.0,
      )
      env["dx2"] = sheet_preset_muldiv(
        env.get("w").unwrap_or(0.0),
        env.get("a4").unwrap_or(0.0),
        100000.0,
      )
      env["x2"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("dx2").unwrap_or(0.0)
      env["x3"] = sheet_preset_adddiv(
        env.get("x2").unwrap_or(0.0),
        env.get("r").unwrap_or(0.0),
        2.0,
      )
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x04",
        coordinates: [
          env.get("l").unwrap_or(0.0) * sx,
          env.get("vc").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y4").unwrap_or(0.0) * sy,
        ],
      }
    }
    "leftRightArrow" => {
      env["adj1"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        50000.0
      }
      env["adj2"] = 50000.0
      env["maxAdj2"] = sheet_preset_muldiv(
        50000.0,
        env.get("w").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
      )
      env["a1"] = sheet_preset_pin(
        0.0,
        env.get("adj1").unwrap_or(0.0),
        100000.0,
      )
      env["a2"] = sheet_preset_pin(
        0.0,
        env.get("adj2").unwrap_or(0.0),
        env.get("maxAdj2").unwrap_or(0.0),
      )
      env["x2"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
        100000.0,
      )
      env["x3"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("x2").unwrap_or(0.0)
      env["dy"] = sheet_preset_muldiv(
        env.get("h").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        200000.0,
      )
      env["y1"] = env.get("vc").unwrap_or(0.0) +
        0.0 -
        env.get("dy").unwrap_or(0.0)
      env["y2"] = env.get("vc").unwrap_or(0.0) +
        env.get("dy").unwrap_or(0.0) -
        0.0
      env["dx1"] = sheet_preset_muldiv(
        env.get("y1").unwrap_or(0.0),
        env.get("x2").unwrap_or(0.0),
        env.get("hd2").unwrap_or(0.0),
      )
      env["x1"] = env.get("x2").unwrap_or(0.0) +
        0.0 -
        env.get("dx1").unwrap_or(0.0)
      env["x4"] = env.get("x3").unwrap_or(0.0) +
        env.get("dx1").unwrap_or(0.0) -
        0.0
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x01\x01\x01\x01\x01\x01\x04",
        coordinates: [
          env.get("l").unwrap_or(0.0) * sx,
          env.get("vc").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("vc").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
        ],
      }
    }
    "leftRightArrowCallout" => {
      env["adj1"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        25000.0
      }
      env["adj2"] = 25000.0
      env["adj3"] = 25000.0
      env["adj4"] = 48123.0
      env["maxAdj2"] = sheet_preset_muldiv(
        50000.0,
        env.get("h").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
      )
      env["a2"] = sheet_preset_pin(
        0.0,
        env.get("adj2").unwrap_or(0.0),
        env.get("maxAdj2").unwrap_or(0.0),
      )
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
      env["maxAdj3"] = sheet_preset_muldiv(
        50000.0,
        env.get("w").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
      )
      env["a3"] = sheet_preset_pin(
        0.0,
        env.get("adj3").unwrap_or(0.0),
        env.get("maxAdj3").unwrap_or(0.0),
      )
      env["q2"] = sheet_preset_muldiv(
        env.get("a3").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
        env.get("wd2").unwrap_or(0.0),
      )
      env["maxAdj4"] = 100000.0 + 0.0 - env.get("q2").unwrap_or(0.0)
      env["a4"] = sheet_preset_pin(
        0.0,
        env.get("adj4").unwrap_or(0.0),
        env.get("maxAdj4").unwrap_or(0.0),
      )
      env["dy1"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
        100000.0,
      )
      env["dy2"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        200000.0,
      )
      env["y1"] = env.get("vc").unwrap_or(0.0) +
        0.0 -
        env.get("dy1").unwrap_or(0.0)
      env["y2"] = env.get("vc").unwrap_or(0.0) +
        0.0 -
        env.get("dy2").unwrap_or(0.0)
      env["y3"] = env.get("vc").unwrap_or(0.0) +
        env.get("dy2").unwrap_or(0.0) -
        0.0
      env["y4"] = env.get("vc").unwrap_or(0.0) +
        env.get("dy1").unwrap_or(0.0) -
        0.0
      env["x1"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a3").unwrap_or(0.0),
        100000.0,
      )
      env["x4"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("x1").unwrap_or(0.0)
      env["dx2"] = sheet_preset_muldiv(
        env.get("w").unwrap_or(0.0),
        env.get("a4").unwrap_or(0.0),
        200000.0,
      )
      env["x2"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("dx2").unwrap_or(0.0)
      env["x3"] = env.get("hc").unwrap_or(0.0) +
        env.get("dx2").unwrap_or(0.0) -
        0.0
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x04",
        coordinates: [
          env.get("l").unwrap_or(0.0) * sx,
          env.get("vc").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x4").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x4").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("vc").unwrap_or(0.0) * sy,
          env.get("x4").unwrap_or(0.0) * sx,
          env.get("y4").unwrap_or(0.0) * sy,
          env.get("x4").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y4").unwrap_or(0.0) * sy,
        ],
      }
    }
    "leftRightUpArrow" => {
      env["adj1"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        25000.0
      }
      env["adj2"] = 25000.0
      env["adj3"] = 25000.0
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
      env["q1"] = 100000.0 + 0.0 - env.get("maxAdj1").unwrap_or(0.0)
      env["maxAdj3"] = sheet_preset_muldiv(
        env.get("q1").unwrap_or(0.0),
        1.0,
        2.0,
      )
      env["a3"] = sheet_preset_pin(
        0.0,
        env.get("adj3").unwrap_or(0.0),
        env.get("maxAdj3").unwrap_or(0.0),
      )
      env["x1"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a3").unwrap_or(0.0),
        100000.0,
      )
      env["dx2"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
        100000.0,
      )
      env["x2"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("dx2").unwrap_or(0.0)
      env["x5"] = env.get("hc").unwrap_or(0.0) +
        env.get("dx2").unwrap_or(0.0) -
        0.0
      env["dx3"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        200000.0,
      )
      env["x3"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("dx3").unwrap_or(0.0)
      env["x4"] = env.get("hc").unwrap_or(0.0) +
        env.get("dx3").unwrap_or(0.0) -
        0.0
      env["x6"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("x1").unwrap_or(0.0)
      env["dy2"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
        50000.0,
      )
      env["y2"] = env.get("b").unwrap_or(0.0) +
        0.0 -
        env.get("dy2").unwrap_or(0.0)
      env["y4"] = env.get("b").unwrap_or(0.0) +
        0.0 -
        env.get("dx2").unwrap_or(0.0)
      env["y3"] = env.get("y4").unwrap_or(0.0) +
        0.0 -
        env.get("dx3").unwrap_or(0.0)
      env["y5"] = env.get("y4").unwrap_or(0.0) +
        env.get("dx3").unwrap_or(0.0) -
        0.0
      env["il"] = sheet_preset_muldiv(
        env.get("dx3").unwrap_or(0.0),
        env.get("x1").unwrap_or(0.0),
        env.get("dx2").unwrap_or(0.0),
      )
      env["ir"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("il").unwrap_or(0.0)
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x04",
        coordinates: [
          env.get("l").unwrap_or(0.0) * sx,
          env.get("y4").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("x1").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("x1").unwrap_or(0.0) * sy,
          env.get("hc").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("x5").unwrap_or(0.0) * sx,
          env.get("x1").unwrap_or(0.0) * sy,
          env.get("x4").unwrap_or(0.0) * sx,
          env.get("x1").unwrap_or(0.0) * sy,
          env.get("x4").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("x6").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("x6").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("y4").unwrap_or(0.0) * sy,
          env.get("x6").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("x6").unwrap_or(0.0) * sx,
          env.get("y5").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y5").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
        ],
      }
    }
    "leftUpArrow" => {
      env["adj1"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        25000.0
      }
      env["adj2"] = 25000.0
      env["adj3"] = 25000.0
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
      env["maxAdj3"] = 100000.0 + 0.0 - env.get("maxAdj1").unwrap_or(0.0)
      env["a3"] = sheet_preset_pin(
        0.0,
        env.get("adj3").unwrap_or(0.0),
        env.get("maxAdj3").unwrap_or(0.0),
      )
      env["x1"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a3").unwrap_or(0.0),
        100000.0,
      )
      env["dx2"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
        50000.0,
      )
      env["x2"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("dx2").unwrap_or(0.0)
      env["y2"] = env.get("b").unwrap_or(0.0) +
        0.0 -
        env.get("dx2").unwrap_or(0.0)
      env["dx4"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
        100000.0,
      )
      env["x4"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("dx4").unwrap_or(0.0)
      env["y4"] = env.get("b").unwrap_or(0.0) +
        0.0 -
        env.get("dx4").unwrap_or(0.0)
      env["dx3"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        200000.0,
      )
      env["x3"] = env.get("x4").unwrap_or(0.0) +
        0.0 -
        env.get("dx3").unwrap_or(0.0)
      env["x5"] = env.get("x4").unwrap_or(0.0) +
        env.get("dx3").unwrap_or(0.0) -
        0.0
      env["y3"] = env.get("y4").unwrap_or(0.0) +
        0.0 -
        env.get("dx3").unwrap_or(0.0)
      env["y5"] = env.get("y4").unwrap_or(0.0) +
        env.get("dx3").unwrap_or(0.0) -
        0.0
      env["il"] = sheet_preset_muldiv(
        env.get("dx3").unwrap_or(0.0),
        env.get("x1").unwrap_or(0.0),
        env.get("dx4").unwrap_or(0.0),
      )
      env["cx1"] = sheet_preset_adddiv(
        env.get("x1").unwrap_or(0.0),
        env.get("x5").unwrap_or(0.0),
        2.0,
      )
      env["cy1"] = sheet_preset_adddiv(
        env.get("x1").unwrap_or(0.0),
        env.get("y5").unwrap_or(0.0),
        2.0,
      )
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x04",
        coordinates: [
          env.get("l").unwrap_or(0.0) * sx,
          env.get("y4").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("x1").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("x1").unwrap_or(0.0) * sy,
          env.get("x4").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("x1").unwrap_or(0.0) * sy,
          env.get("x5").unwrap_or(0.0) * sx,
          env.get("x1").unwrap_or(0.0) * sy,
          env.get("x5").unwrap_or(0.0) * sx,
          env.get("y5").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y5").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
        ],
      }
    }
    "mathMinus" => {
      env["adj1"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        23520.0
      }
      env["a1"] = sheet_preset_pin(
        0.0,
        env.get("adj1").unwrap_or(0.0),
        100000.0,
      )
      env["dy1"] = sheet_preset_muldiv(
        env.get("h").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        200000.0,
      )
      env["dx1"] = sheet_preset_muldiv(
        env.get("w").unwrap_or(0.0),
        73490.0,
        200000.0,
      )
      env["y1"] = env.get("vc").unwrap_or(0.0) +
        0.0 -
        env.get("dy1").unwrap_or(0.0)
      env["y2"] = env.get("vc").unwrap_or(0.0) +
        env.get("dy1").unwrap_or(0.0) -
        0.0
      env["x1"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("dx1").unwrap_or(0.0)
      env["x2"] = env.get("hc").unwrap_or(0.0) +
        env.get("dx1").unwrap_or(0.0) -
        0.0
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x04",
        coordinates: [
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
        ],
      }
    }
    "mathPlus" => {
      env["adj1"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        23520.0
      }
      env["a1"] = sheet_preset_pin(0.0, env.get("adj1").unwrap_or(0.0), 73490.0)
      env["dx1"] = sheet_preset_muldiv(
        env.get("w").unwrap_or(0.0),
        73490.0,
        200000.0,
      )
      env["dy1"] = sheet_preset_muldiv(
        env.get("h").unwrap_or(0.0),
        73490.0,
        200000.0,
      )
      env["dx2"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        200000.0,
      )
      env["x1"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("dx1").unwrap_or(0.0)
      env["x2"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("dx2").unwrap_or(0.0)
      env["x3"] = env.get("hc").unwrap_or(0.0) +
        env.get("dx2").unwrap_or(0.0) -
        0.0
      env["x4"] = env.get("hc").unwrap_or(0.0) +
        env.get("dx1").unwrap_or(0.0) -
        0.0
      env["y1"] = env.get("vc").unwrap_or(0.0) +
        0.0 -
        env.get("dy1").unwrap_or(0.0)
      env["y2"] = env.get("vc").unwrap_or(0.0) +
        0.0 -
        env.get("dx2").unwrap_or(0.0)
      env["y3"] = env.get("vc").unwrap_or(0.0) +
        env.get("dx2").unwrap_or(0.0) -
        0.0
      env["y4"] = env.get("vc").unwrap_or(0.0) +
        env.get("dy1").unwrap_or(0.0) -
        0.0
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x04",
        coordinates: [
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x4").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x4").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("y4").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y4").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
        ],
      }
    }
    "nonIsoscelesTrapezoid" => {
      env["adj1"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        25000.0
      }
      env["adj2"] = 25000.0
      env["maxAdj"] = sheet_preset_muldiv(
        50000.0,
        env.get("w").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
      )
      env["a1"] = sheet_preset_pin(
        0.0,
        env.get("adj1").unwrap_or(0.0),
        env.get("maxAdj").unwrap_or(0.0),
      )
      env["a2"] = sheet_preset_pin(
        0.0,
        env.get("adj2").unwrap_or(0.0),
        env.get("maxAdj").unwrap_or(0.0),
      )
      env["x1"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        200000.0,
      )
      env["x2"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        100000.0,
      )
      env["dx3"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
        100000.0,
      )
      env["x3"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("dx3").unwrap_or(0.0)
      env["x4"] = sheet_preset_adddiv(
        env.get("r").unwrap_or(0.0),
        env.get("x3").unwrap_or(0.0),
        2.0,
      )
      env["il"] = sheet_preset_muldiv(
        env.get("wd3").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        env.get("maxAdj").unwrap_or(0.0),
      )
      env["adjm"] = Double::max(
        env.get("a1").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
      )
      env["it"] = sheet_preset_muldiv(
        env.get("hd3").unwrap_or(0.0),
        env.get("adjm").unwrap_or(0.0),
        env.get("maxAdj").unwrap_or(0.0),
      )
      env["irt"] = sheet_preset_muldiv(
        env.get("wd3").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
        env.get("maxAdj").unwrap_or(0.0),
      )
      env["ir"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("irt").unwrap_or(0.0)
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x04",
        coordinates: [
          env.get("l").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
        ],
      }
    }
    "notchedRightArrow" => {
      env["adj1"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        50000.0
      }
      env["adj2"] = 50000.0
      env["maxAdj2"] = sheet_preset_muldiv(
        100000.0,
        env.get("w").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
      )
      env["a1"] = sheet_preset_pin(
        0.0,
        env.get("adj1").unwrap_or(0.0),
        100000.0,
      )
      env["a2"] = sheet_preset_pin(
        0.0,
        env.get("adj2").unwrap_or(0.0),
        env.get("maxAdj2").unwrap_or(0.0),
      )
      env["dx2"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
        100000.0,
      )
      env["x2"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("dx2").unwrap_or(0.0)
      env["dy1"] = sheet_preset_muldiv(
        env.get("h").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        200000.0,
      )
      env["y1"] = env.get("vc").unwrap_or(0.0) +
        0.0 -
        env.get("dy1").unwrap_or(0.0)
      env["y2"] = env.get("vc").unwrap_or(0.0) +
        env.get("dy1").unwrap_or(0.0) -
        0.0
      env["x1"] = sheet_preset_muldiv(
        env.get("dy1").unwrap_or(0.0),
        env.get("dx2").unwrap_or(0.0),
        env.get("hd2").unwrap_or(0.0),
      )
      env["x3"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("x1").unwrap_or(0.0)
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x01\x01\x01\x01\x04",
        coordinates: [
          env.get("l").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("vc").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("l").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("vc").unwrap_or(0.0) * sy,
        ],
      }
    }
    "quadArrow" => {
      env["adj1"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        22500.0
      }
      env["adj2"] = 22500.0
      env["adj3"] = 22500.0
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
      env["q1"] = 100000.0 + 0.0 - env.get("maxAdj1").unwrap_or(0.0)
      env["maxAdj3"] = sheet_preset_muldiv(
        env.get("q1").unwrap_or(0.0),
        1.0,
        2.0,
      )
      env["a3"] = sheet_preset_pin(
        0.0,
        env.get("adj3").unwrap_or(0.0),
        env.get("maxAdj3").unwrap_or(0.0),
      )
      env["x1"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a3").unwrap_or(0.0),
        100000.0,
      )
      env["dx2"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
        100000.0,
      )
      env["x2"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("dx2").unwrap_or(0.0)
      env["x5"] = env.get("hc").unwrap_or(0.0) +
        env.get("dx2").unwrap_or(0.0) -
        0.0
      env["dx3"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        200000.0,
      )
      env["x3"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("dx3").unwrap_or(0.0)
      env["x4"] = env.get("hc").unwrap_or(0.0) +
        env.get("dx3").unwrap_or(0.0) -
        0.0
      env["x6"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("x1").unwrap_or(0.0)
      env["y2"] = env.get("vc").unwrap_or(0.0) +
        0.0 -
        env.get("dx2").unwrap_or(0.0)
      env["y5"] = env.get("vc").unwrap_or(0.0) +
        env.get("dx2").unwrap_or(0.0) -
        0.0
      env["y3"] = env.get("vc").unwrap_or(0.0) +
        0.0 -
        env.get("dx3").unwrap_or(0.0)
      env["y4"] = env.get("vc").unwrap_or(0.0) +
        env.get("dx3").unwrap_or(0.0) -
        0.0
      env["y6"] = env.get("b").unwrap_or(0.0) +
        0.0 -
        env.get("x1").unwrap_or(0.0)
      env["il"] = sheet_preset_muldiv(
        env.get("dx3").unwrap_or(0.0),
        env.get("x1").unwrap_or(0.0),
        env.get("dx2").unwrap_or(0.0),
      )
      env["ir"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("il").unwrap_or(0.0)
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x04",
        coordinates: [
          env.get("l").unwrap_or(0.0) * sx,
          env.get("vc").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("x1").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("x1").unwrap_or(0.0) * sy,
          env.get("hc").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("x5").unwrap_or(0.0) * sx,
          env.get("x1").unwrap_or(0.0) * sy,
          env.get("x4").unwrap_or(0.0) * sx,
          env.get("x1").unwrap_or(0.0) * sy,
          env.get("x4").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("x6").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("x6").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("vc").unwrap_or(0.0) * sy,
          env.get("x6").unwrap_or(0.0) * sx,
          env.get("y5").unwrap_or(0.0) * sy,
          env.get("x6").unwrap_or(0.0) * sx,
          env.get("y4").unwrap_or(0.0) * sy,
          env.get("x4").unwrap_or(0.0) * sx,
          env.get("y4").unwrap_or(0.0) * sy,
          env.get("x4").unwrap_or(0.0) * sx,
          env.get("y6").unwrap_or(0.0) * sy,
          env.get("x5").unwrap_or(0.0) * sx,
          env.get("y6").unwrap_or(0.0) * sy,
          env.get("hc").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y6").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("y6").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("y4").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y4").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y5").unwrap_or(0.0) * sy,
        ],
      }
    }
    "quadArrowCallout" => {
      env["adj1"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        18515.0
      }
      env["adj2"] = 18515.0
      env["adj3"] = 18515.0
      env["adj4"] = 48123.0
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
      env["maxAdj3"] = 50000.0 + 0.0 - env.get("a2").unwrap_or(0.0)
      env["a3"] = sheet_preset_pin(
        0.0,
        env.get("adj3").unwrap_or(0.0),
        env.get("maxAdj3").unwrap_or(0.0),
      )
      env["q2"] = sheet_preset_muldiv(env.get("a3").unwrap_or(0.0), 2.0, 1.0)
      env["maxAdj4"] = 100000.0 + 0.0 - env.get("q2").unwrap_or(0.0)
      env["a4"] = sheet_preset_pin(
        env.get("a1").unwrap_or(0.0),
        env.get("adj4").unwrap_or(0.0),
        env.get("maxAdj4").unwrap_or(0.0),
      )
      env["dx2"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
        100000.0,
      )
      env["dx3"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        200000.0,
      )
      env["ah"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a3").unwrap_or(0.0),
        100000.0,
      )
      env["dx1"] = sheet_preset_muldiv(
        env.get("w").unwrap_or(0.0),
        env.get("a4").unwrap_or(0.0),
        200000.0,
      )
      env["dy1"] = sheet_preset_muldiv(
        env.get("h").unwrap_or(0.0),
        env.get("a4").unwrap_or(0.0),
        200000.0,
      )
      env["x8"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("ah").unwrap_or(0.0)
      env["x2"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("dx1").unwrap_or(0.0)
      env["x7"] = env.get("hc").unwrap_or(0.0) +
        env.get("dx1").unwrap_or(0.0) -
        0.0
      env["x3"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("dx2").unwrap_or(0.0)
      env["x6"] = env.get("hc").unwrap_or(0.0) +
        env.get("dx2").unwrap_or(0.0) -
        0.0
      env["x4"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("dx3").unwrap_or(0.0)
      env["x5"] = env.get("hc").unwrap_or(0.0) +
        env.get("dx3").unwrap_or(0.0) -
        0.0
      env["y8"] = env.get("b").unwrap_or(0.0) +
        0.0 -
        env.get("ah").unwrap_or(0.0)
      env["y2"] = env.get("vc").unwrap_or(0.0) +
        0.0 -
        env.get("dy1").unwrap_or(0.0)
      env["y7"] = env.get("vc").unwrap_or(0.0) +
        env.get("dy1").unwrap_or(0.0) -
        0.0
      env["y3"] = env.get("vc").unwrap_or(0.0) +
        0.0 -
        env.get("dx2").unwrap_or(0.0)
      env["y6"] = env.get("vc").unwrap_or(0.0) +
        env.get("dx2").unwrap_or(0.0) -
        0.0
      env["y4"] = env.get("vc").unwrap_or(0.0) +
        0.0 -
        env.get("dx3").unwrap_or(0.0)
      env["y5"] = env.get("vc").unwrap_or(0.0) +
        env.get("dx3").unwrap_or(0.0) -
        0.0
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x04",
        coordinates: [
          env.get("l").unwrap_or(0.0) * sx,
          env.get("vc").unwrap_or(0.0) * sy,
          env.get("ah").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("ah").unwrap_or(0.0) * sx,
          env.get("y4").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y4").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x4").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x4").unwrap_or(0.0) * sx,
          env.get("ah").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("ah").unwrap_or(0.0) * sy,
          env.get("hc").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("x6").unwrap_or(0.0) * sx,
          env.get("ah").unwrap_or(0.0) * sy,
          env.get("x5").unwrap_or(0.0) * sx,
          env.get("ah").unwrap_or(0.0) * sy,
          env.get("x5").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x7").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x7").unwrap_or(0.0) * sx,
          env.get("y4").unwrap_or(0.0) * sy,
          env.get("x8").unwrap_or(0.0) * sx,
          env.get("y4").unwrap_or(0.0) * sy,
          env.get("x8").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("vc").unwrap_or(0.0) * sy,
          env.get("x8").unwrap_or(0.0) * sx,
          env.get("y6").unwrap_or(0.0) * sy,
          env.get("x8").unwrap_or(0.0) * sx,
          env.get("y5").unwrap_or(0.0) * sy,
          env.get("x7").unwrap_or(0.0) * sx,
          env.get("y5").unwrap_or(0.0) * sy,
          env.get("x7").unwrap_or(0.0) * sx,
          env.get("y7").unwrap_or(0.0) * sy,
          env.get("x5").unwrap_or(0.0) * sx,
          env.get("y7").unwrap_or(0.0) * sy,
          env.get("x5").unwrap_or(0.0) * sx,
          env.get("y8").unwrap_or(0.0) * sy,
          env.get("x6").unwrap_or(0.0) * sx,
          env.get("y8").unwrap_or(0.0) * sy,
          env.get("hc").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("y8").unwrap_or(0.0) * sy,
          env.get("x4").unwrap_or(0.0) * sx,
          env.get("y8").unwrap_or(0.0) * sy,
          env.get("x4").unwrap_or(0.0) * sx,
          env.get("y7").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y7").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y5").unwrap_or(0.0) * sy,
          env.get("ah").unwrap_or(0.0) * sx,
          env.get("y5").unwrap_or(0.0) * sy,
          env.get("ah").unwrap_or(0.0) * sx,
          env.get("y6").unwrap_or(0.0) * sy,
        ],
      }
    }
    "rightArrow" => {
      env["adj1"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        50000.0
      }
      env["adj2"] = 50000.0
      env["maxAdj2"] = sheet_preset_muldiv(
        100000.0,
        env.get("w").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
      )
      env["a1"] = sheet_preset_pin(
        0.0,
        env.get("adj1").unwrap_or(0.0),
        100000.0,
      )
      env["a2"] = sheet_preset_pin(
        0.0,
        env.get("adj2").unwrap_or(0.0),
        env.get("maxAdj2").unwrap_or(0.0),
      )
      env["dx1"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
        100000.0,
      )
      env["x1"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("dx1").unwrap_or(0.0)
      env["dy1"] = sheet_preset_muldiv(
        env.get("h").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        200000.0,
      )
      env["y1"] = env.get("vc").unwrap_or(0.0) +
        0.0 -
        env.get("dy1").unwrap_or(0.0)
      env["y2"] = env.get("vc").unwrap_or(0.0) +
        env.get("dy1").unwrap_or(0.0) -
        0.0
      env["dx2"] = sheet_preset_muldiv(
        env.get("y1").unwrap_or(0.0),
        env.get("dx1").unwrap_or(0.0),
        env.get("hd2").unwrap_or(0.0),
      )
      env["x2"] = env.get("x1").unwrap_or(0.0) +
        env.get("dx2").unwrap_or(0.0) -
        0.0
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x01\x01\x01\x04",
        coordinates: [
          env.get("l").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("vc").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("l").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
        ],
      }
    }
    "rightArrowCallout" => {
      env["adj1"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        25000.0
      }
      env["adj2"] = 25000.0
      env["adj3"] = 25000.0
      env["adj4"] = 64977.0
      env["maxAdj2"] = sheet_preset_muldiv(
        50000.0,
        env.get("h").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
      )
      env["a2"] = sheet_preset_pin(
        0.0,
        env.get("adj2").unwrap_or(0.0),
        env.get("maxAdj2").unwrap_or(0.0),
      )
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
      env["maxAdj3"] = sheet_preset_muldiv(
        100000.0,
        env.get("w").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
      )
      env["a3"] = sheet_preset_pin(
        0.0,
        env.get("adj3").unwrap_or(0.0),
        env.get("maxAdj3").unwrap_or(0.0),
      )
      env["q2"] = sheet_preset_muldiv(
        env.get("a3").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
        env.get("w").unwrap_or(0.0),
      )
      env["maxAdj4"] = 100000.0 + 0.0 - env.get("q2").unwrap_or(0.0)
      env["a4"] = sheet_preset_pin(
        0.0,
        env.get("adj4").unwrap_or(0.0),
        env.get("maxAdj4").unwrap_or(0.0),
      )
      env["dy1"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
        100000.0,
      )
      env["dy2"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        200000.0,
      )
      env["y1"] = env.get("vc").unwrap_or(0.0) +
        0.0 -
        env.get("dy1").unwrap_or(0.0)
      env["y2"] = env.get("vc").unwrap_or(0.0) +
        0.0 -
        env.get("dy2").unwrap_or(0.0)
      env["y3"] = env.get("vc").unwrap_or(0.0) +
        env.get("dy2").unwrap_or(0.0) -
        0.0
      env["y4"] = env.get("vc").unwrap_or(0.0) +
        env.get("dy1").unwrap_or(0.0) -
        0.0
      env["dx3"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a3").unwrap_or(0.0),
        100000.0,
      )
      env["x3"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("dx3").unwrap_or(0.0)
      env["x2"] = sheet_preset_muldiv(
        env.get("w").unwrap_or(0.0),
        env.get("a4").unwrap_or(0.0),
        100000.0,
      )
      env["x1"] = sheet_preset_muldiv(env.get("x2").unwrap_or(0.0), 1.0, 2.0)
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x04",
        coordinates: [
          env.get("l").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("vc").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("y4").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("l").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
        ],
      }
    }
    "snip1Rect" => {
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
      env["it"] = sheet_preset_muldiv(env.get("dx1").unwrap_or(0.0), 1.0, 2.0)
      env["ir"] = sheet_preset_adddiv(
        env.get("x1").unwrap_or(0.0),
        env.get("r").unwrap_or(0.0),
        2.0,
      )
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x01\x04",
        coordinates: [
          env.get("l").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("dx1").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("l").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
        ],
      }
    }
    "snip2DiagRect" => {
      env["adj1"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        0.0
      }
      env["adj2"] = 16667.0
      env["a1"] = sheet_preset_pin(0.0, env.get("adj1").unwrap_or(0.0), 50000.0)
      env["a2"] = sheet_preset_pin(0.0, env.get("adj2").unwrap_or(0.0), 50000.0)
      env["lx1"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        100000.0,
      )
      env["lx2"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("lx1").unwrap_or(0.0)
      env["ly1"] = env.get("b").unwrap_or(0.0) +
        0.0 -
        env.get("lx1").unwrap_or(0.0)
      env["rx1"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
        100000.0,
      )
      env["rx2"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("rx1").unwrap_or(0.0)
      env["ry1"] = env.get("b").unwrap_or(0.0) +
        0.0 -
        env.get("rx1").unwrap_or(0.0)
      env["d"] = env.get("lx1").unwrap_or(0.0) +
        0.0 -
        env.get("rx1").unwrap_or(0.0)
      env["dx"] = if env.get("d").unwrap_or(0.0) > 0.0 {
        env.get("lx1").unwrap_or(0.0)
      } else {
        env.get("rx1").unwrap_or(0.0)
      }
      env["il"] = sheet_preset_muldiv(env.get("dx").unwrap_or(0.0), 1.0, 2.0)
      env["ir"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("il").unwrap_or(0.0)
      env["ib"] = env.get("b").unwrap_or(0.0) +
        0.0 -
        env.get("il").unwrap_or(0.0)
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x01\x01\x01\x01\x04",
        coordinates: [
          env.get("lx1").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("rx2").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("rx1").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("ly1").unwrap_or(0.0) * sy,
          env.get("lx2").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("rx1").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("l").unwrap_or(0.0) * sx,
          env.get("ry1").unwrap_or(0.0) * sy,
          env.get("l").unwrap_or(0.0) * sx,
          env.get("lx1").unwrap_or(0.0) * sy,
        ],
      }
    }
    "snip2SameRect" => {
      env["adj1"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        16667.0
      }
      env["adj2"] = 0.0
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
      env["dx"] = if env.get("d").unwrap_or(0.0) > 0.0 {
        env.get("tx1").unwrap_or(0.0)
      } else {
        env.get("bx1").unwrap_or(0.0)
      }
      env["il"] = sheet_preset_muldiv(env.get("dx").unwrap_or(0.0), 1.0, 2.0)
      env["ir"] = env.get("r").unwrap_or(0.0) +
        0.0 -
        env.get("il").unwrap_or(0.0)
      env["it"] = sheet_preset_muldiv(env.get("tx1").unwrap_or(0.0), 1.0, 2.0)
      env["ib"] = sheet_preset_adddiv(
        env.get("by1").unwrap_or(0.0),
        env.get("b").unwrap_or(0.0),
        2.0,
      )
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x01\x01\x01\x01\x04",
        coordinates: [
          env.get("tx1").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("tx2").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("tx1").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("by1").unwrap_or(0.0) * sy,
          env.get("bx2").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("bx1").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("l").unwrap_or(0.0) * sx,
          env.get("by1").unwrap_or(0.0) * sy,
          env.get("l").unwrap_or(0.0) * sx,
          env.get("tx1").unwrap_or(0.0) * sy,
        ],
      }
    }
    "star10" => {
      env["adj"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        42533.0
      }
      env["hf"] = 105146.0
      env["a"] = sheet_preset_pin(0.0, env.get("adj").unwrap_or(0.0), 50000.0)
      env["swd2"] = sheet_preset_muldiv(
        env.get("wd2").unwrap_or(0.0),
        env.get("hf").unwrap_or(0.0),
        100000.0,
      )
      env["dx1"] = sheet_preset_muldiv(
        env.get("swd2").unwrap_or(0.0),
        95106.0,
        100000.0,
      )
      env["dx2"] = sheet_preset_muldiv(
        env.get("swd2").unwrap_or(0.0),
        58779.0,
        100000.0,
      )
      env["x1"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("dx1").unwrap_or(0.0)
      env["x2"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("dx2").unwrap_or(0.0)
      env["x3"] = env.get("hc").unwrap_or(0.0) +
        env.get("dx2").unwrap_or(0.0) -
        0.0
      env["x4"] = env.get("hc").unwrap_or(0.0) +
        env.get("dx1").unwrap_or(0.0) -
        0.0
      env["dy1"] = sheet_preset_muldiv(
        env.get("hd2").unwrap_or(0.0),
        80902.0,
        100000.0,
      )
      env["dy2"] = sheet_preset_muldiv(
        env.get("hd2").unwrap_or(0.0),
        30902.0,
        100000.0,
      )
      env["y1"] = env.get("vc").unwrap_or(0.0) +
        0.0 -
        env.get("dy1").unwrap_or(0.0)
      env["y2"] = env.get("vc").unwrap_or(0.0) +
        0.0 -
        env.get("dy2").unwrap_or(0.0)
      env["y3"] = env.get("vc").unwrap_or(0.0) +
        env.get("dy2").unwrap_or(0.0) -
        0.0
      env["y4"] = env.get("vc").unwrap_or(0.0) +
        env.get("dy1").unwrap_or(0.0) -
        0.0
      env["iwd2"] = sheet_preset_muldiv(
        env.get("swd2").unwrap_or(0.0),
        env.get("a").unwrap_or(0.0),
        50000.0,
      )
      env["ihd2"] = sheet_preset_muldiv(
        env.get("hd2").unwrap_or(0.0),
        env.get("a").unwrap_or(0.0),
        50000.0,
      )
      env["sdx1"] = sheet_preset_muldiv(
        env.get("iwd2").unwrap_or(0.0),
        80902.0,
        100000.0,
      )
      env["sdx2"] = sheet_preset_muldiv(
        env.get("iwd2").unwrap_or(0.0),
        30902.0,
        100000.0,
      )
      env["sdy1"] = sheet_preset_muldiv(
        env.get("ihd2").unwrap_or(0.0),
        95106.0,
        100000.0,
      )
      env["sdy2"] = sheet_preset_muldiv(
        env.get("ihd2").unwrap_or(0.0),
        58779.0,
        100000.0,
      )
      env["sx1"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("iwd2").unwrap_or(0.0)
      env["sx2"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("sdx1").unwrap_or(0.0)
      env["sx3"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("sdx2").unwrap_or(0.0)
      env["sx4"] = env.get("hc").unwrap_or(0.0) +
        env.get("sdx2").unwrap_or(0.0) -
        0.0
      env["sx5"] = env.get("hc").unwrap_or(0.0) +
        env.get("sdx1").unwrap_or(0.0) -
        0.0
      env["sx6"] = env.get("hc").unwrap_or(0.0) +
        env.get("iwd2").unwrap_or(0.0) -
        0.0
      env["sy1"] = env.get("vc").unwrap_or(0.0) +
        0.0 -
        env.get("sdy1").unwrap_or(0.0)
      env["sy2"] = env.get("vc").unwrap_or(0.0) +
        0.0 -
        env.get("sdy2").unwrap_or(0.0)
      env["sy3"] = env.get("vc").unwrap_or(0.0) +
        env.get("sdy2").unwrap_or(0.0) -
        0.0
      env["sy4"] = env.get("vc").unwrap_or(0.0) +
        env.get("sdy1").unwrap_or(0.0) -
        0.0
      env["yAdj"] = env.get("vc").unwrap_or(0.0) +
        0.0 -
        env.get("ihd2").unwrap_or(0.0)
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x04",
        coordinates: [
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("sx2").unwrap_or(0.0) * sx,
          env.get("sy2").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("sx3").unwrap_or(0.0) * sx,
          env.get("sy1").unwrap_or(0.0) * sy,
          env.get("hc").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("sx4").unwrap_or(0.0) * sx,
          env.get("sy1").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("sx5").unwrap_or(0.0) * sx,
          env.get("sy2").unwrap_or(0.0) * sy,
          env.get("x4").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("sx6").unwrap_or(0.0) * sx,
          env.get("vc").unwrap_or(0.0) * sy,
          env.get("x4").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("sx5").unwrap_or(0.0) * sx,
          env.get("sy3").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("y4").unwrap_or(0.0) * sy,
          env.get("sx4").unwrap_or(0.0) * sx,
          env.get("sy4").unwrap_or(0.0) * sy,
          env.get("hc").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("sx3").unwrap_or(0.0) * sx,
          env.get("sy4").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y4").unwrap_or(0.0) * sy,
          env.get("sx2").unwrap_or(0.0) * sx,
          env.get("sy3").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("sx1").unwrap_or(0.0) * sx,
          env.get("vc").unwrap_or(0.0) * sy,
        ],
      }
    }
    "star7" => {
      env["adj"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        34601.0
      }
      env["hf"] = 102572.0
      env["vf"] = 105210.0
      env["a"] = sheet_preset_pin(0.0, env.get("adj").unwrap_or(0.0), 50000.0)
      env["swd2"] = sheet_preset_muldiv(
        env.get("wd2").unwrap_or(0.0),
        env.get("hf").unwrap_or(0.0),
        100000.0,
      )
      env["shd2"] = sheet_preset_muldiv(
        env.get("hd2").unwrap_or(0.0),
        env.get("vf").unwrap_or(0.0),
        100000.0,
      )
      env["svc"] = sheet_preset_muldiv(
        env.get("vc").unwrap_or(0.0),
        env.get("vf").unwrap_or(0.0),
        100000.0,
      )
      env["dx1"] = sheet_preset_muldiv(
        env.get("swd2").unwrap_or(0.0),
        97493.0,
        100000.0,
      )
      env["dx2"] = sheet_preset_muldiv(
        env.get("swd2").unwrap_or(0.0),
        78183.0,
        100000.0,
      )
      env["dx3"] = sheet_preset_muldiv(
        env.get("swd2").unwrap_or(0.0),
        43388.0,
        100000.0,
      )
      env["dy1"] = sheet_preset_muldiv(
        env.get("shd2").unwrap_or(0.0),
        62349.0,
        100000.0,
      )
      env["dy2"] = sheet_preset_muldiv(
        env.get("shd2").unwrap_or(0.0),
        22252.0,
        100000.0,
      )
      env["dy3"] = sheet_preset_muldiv(
        env.get("shd2").unwrap_or(0.0),
        90097.0,
        100000.0,
      )
      env["x1"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("dx1").unwrap_or(0.0)
      env["x2"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("dx2").unwrap_or(0.0)
      env["x3"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("dx3").unwrap_or(0.0)
      env["x4"] = env.get("hc").unwrap_or(0.0) +
        env.get("dx3").unwrap_or(0.0) -
        0.0
      env["x5"] = env.get("hc").unwrap_or(0.0) +
        env.get("dx2").unwrap_or(0.0) -
        0.0
      env["x6"] = env.get("hc").unwrap_or(0.0) +
        env.get("dx1").unwrap_or(0.0) -
        0.0
      env["y1"] = env.get("svc").unwrap_or(0.0) +
        0.0 -
        env.get("dy1").unwrap_or(0.0)
      env["y2"] = env.get("svc").unwrap_or(0.0) +
        env.get("dy2").unwrap_or(0.0) -
        0.0
      env["y3"] = env.get("svc").unwrap_or(0.0) +
        env.get("dy3").unwrap_or(0.0) -
        0.0
      env["iwd2"] = sheet_preset_muldiv(
        env.get("swd2").unwrap_or(0.0),
        env.get("a").unwrap_or(0.0),
        50000.0,
      )
      env["ihd2"] = sheet_preset_muldiv(
        env.get("shd2").unwrap_or(0.0),
        env.get("a").unwrap_or(0.0),
        50000.0,
      )
      env["sdx1"] = sheet_preset_muldiv(
        env.get("iwd2").unwrap_or(0.0),
        97493.0,
        100000.0,
      )
      env["sdx2"] = sheet_preset_muldiv(
        env.get("iwd2").unwrap_or(0.0),
        78183.0,
        100000.0,
      )
      env["sdx3"] = sheet_preset_muldiv(
        env.get("iwd2").unwrap_or(0.0),
        43388.0,
        100000.0,
      )
      env["sx1"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("sdx1").unwrap_or(0.0)
      env["sx2"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("sdx2").unwrap_or(0.0)
      env["sx3"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("sdx3").unwrap_or(0.0)
      env["sx4"] = env.get("hc").unwrap_or(0.0) +
        env.get("sdx3").unwrap_or(0.0) -
        0.0
      env["sx5"] = env.get("hc").unwrap_or(0.0) +
        env.get("sdx2").unwrap_or(0.0) -
        0.0
      env["sx6"] = env.get("hc").unwrap_or(0.0) +
        env.get("sdx1").unwrap_or(0.0) -
        0.0
      env["sdy1"] = sheet_preset_muldiv(
        env.get("ihd2").unwrap_or(0.0),
        90097.0,
        100000.0,
      )
      env["sdy2"] = sheet_preset_muldiv(
        env.get("ihd2").unwrap_or(0.0),
        22252.0,
        100000.0,
      )
      env["sdy3"] = sheet_preset_muldiv(
        env.get("ihd2").unwrap_or(0.0),
        62349.0,
        100000.0,
      )
      env["sy1"] = env.get("svc").unwrap_or(0.0) +
        0.0 -
        env.get("sdy1").unwrap_or(0.0)
      env["sy2"] = env.get("svc").unwrap_or(0.0) +
        0.0 -
        env.get("sdy2").unwrap_or(0.0)
      env["sy3"] = env.get("svc").unwrap_or(0.0) +
        env.get("sdy3").unwrap_or(0.0) -
        0.0
      env["sy4"] = env.get("svc").unwrap_or(0.0) +
        env.get("ihd2").unwrap_or(0.0) -
        0.0
      env["yAdj"] = env.get("svc").unwrap_or(0.0) +
        0.0 -
        env.get("ihd2").unwrap_or(0.0)
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x04",
        coordinates: [
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("sx1").unwrap_or(0.0) * sx,
          env.get("sy2").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("sx3").unwrap_or(0.0) * sx,
          env.get("sy1").unwrap_or(0.0) * sy,
          env.get("hc").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("sx4").unwrap_or(0.0) * sx,
          env.get("sy1").unwrap_or(0.0) * sy,
          env.get("x5").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("sx6").unwrap_or(0.0) * sx,
          env.get("sy2").unwrap_or(0.0) * sy,
          env.get("x6").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("sx5").unwrap_or(0.0) * sx,
          env.get("sy3").unwrap_or(0.0) * sy,
          env.get("x4").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("hc").unwrap_or(0.0) * sx,
          env.get("sy4").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("sx2").unwrap_or(0.0) * sx,
          env.get("sy3").unwrap_or(0.0) * sy,
        ],
      }
    }
    "upArrowCallout" => {
      env["adj1"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        25000.0
      }
      env["adj2"] = 25000.0
      env["adj3"] = 25000.0
      env["adj4"] = 64977.0
      env["maxAdj2"] = sheet_preset_muldiv(
        50000.0,
        env.get("w").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
      )
      env["a2"] = sheet_preset_pin(
        0.0,
        env.get("adj2").unwrap_or(0.0),
        env.get("maxAdj2").unwrap_or(0.0),
      )
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
      env["maxAdj3"] = sheet_preset_muldiv(
        100000.0,
        env.get("h").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
      )
      env["a3"] = sheet_preset_pin(
        0.0,
        env.get("adj3").unwrap_or(0.0),
        env.get("maxAdj3").unwrap_or(0.0),
      )
      env["q2"] = sheet_preset_muldiv(
        env.get("a3").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
        env.get("h").unwrap_or(0.0),
      )
      env["maxAdj4"] = 100000.0 + 0.0 - env.get("q2").unwrap_or(0.0)
      env["a4"] = sheet_preset_pin(
        0.0,
        env.get("adj4").unwrap_or(0.0),
        env.get("maxAdj4").unwrap_or(0.0),
      )
      env["dx1"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
        100000.0,
      )
      env["dx2"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        200000.0,
      )
      env["x1"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("dx1").unwrap_or(0.0)
      env["x2"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("dx2").unwrap_or(0.0)
      env["x3"] = env.get("hc").unwrap_or(0.0) +
        env.get("dx2").unwrap_or(0.0) -
        0.0
      env["x4"] = env.get("hc").unwrap_or(0.0) +
        env.get("dx1").unwrap_or(0.0) -
        0.0
      env["y1"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a3").unwrap_or(0.0),
        100000.0,
      )
      env["dy2"] = sheet_preset_muldiv(
        env.get("h").unwrap_or(0.0),
        env.get("a4").unwrap_or(0.0),
        100000.0,
      )
      env["y2"] = env.get("b").unwrap_or(0.0) +
        0.0 -
        env.get("dy2").unwrap_or(0.0)
      env["y3"] = sheet_preset_adddiv(
        env.get("y2").unwrap_or(0.0),
        env.get("b").unwrap_or(0.0),
        2.0,
      )
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x04",
        coordinates: [
          env.get("l").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("hc").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("x4").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("l").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
        ],
      }
    }
    "upDownArrow" => {
      env["adj1"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        50000.0
      }
      env["adj2"] = 50000.0
      env["maxAdj2"] = sheet_preset_muldiv(
        50000.0,
        env.get("h").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
      )
      env["a1"] = sheet_preset_pin(
        0.0,
        env.get("adj1").unwrap_or(0.0),
        100000.0,
      )
      env["a2"] = sheet_preset_pin(
        0.0,
        env.get("adj2").unwrap_or(0.0),
        env.get("maxAdj2").unwrap_or(0.0),
      )
      env["y2"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
        100000.0,
      )
      env["y3"] = env.get("b").unwrap_or(0.0) +
        0.0 -
        env.get("y2").unwrap_or(0.0)
      env["dx1"] = sheet_preset_muldiv(
        env.get("w").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        200000.0,
      )
      env["x1"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("dx1").unwrap_or(0.0)
      env["x2"] = env.get("hc").unwrap_or(0.0) +
        env.get("dx1").unwrap_or(0.0) -
        0.0
      env["dy1"] = sheet_preset_muldiv(
        env.get("x1").unwrap_or(0.0),
        env.get("y2").unwrap_or(0.0),
        env.get("wd2").unwrap_or(0.0),
      )
      env["y1"] = env.get("y2").unwrap_or(0.0) +
        0.0 -
        env.get("dy1").unwrap_or(0.0)
      env["y4"] = env.get("y3").unwrap_or(0.0) +
        env.get("dy1").unwrap_or(0.0) -
        0.0
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x01\x01\x01\x01\x01\x01\x04",
        coordinates: [
          env.get("l").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("hc").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("hc").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("l").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
        ],
      }
    }
    "upArrow" => {
      env["adj1"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        50000.0
      }
      env["adj2"] = 50000.0
      env["maxAdj2"] = sheet_preset_muldiv(
        100000.0,
        env.get("h").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
      )
      env["a1"] = sheet_preset_pin(
        0.0,
        env.get("adj1").unwrap_or(0.0),
        100000.0,
      )
      env["a2"] = sheet_preset_pin(
        0.0,
        env.get("adj2").unwrap_or(0.0),
        env.get("maxAdj2").unwrap_or(0.0),
      )
      env["dy2"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
        100000.0,
      )
      env["y2"] = env.get("t").unwrap_or(0.0) +
        env.get("dy2").unwrap_or(0.0) -
        0.0
      env["dx1"] = sheet_preset_muldiv(
        env.get("w").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        200000.0,
      )
      env["x1"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("dx1").unwrap_or(0.0)
      env["x2"] = env.get("hc").unwrap_or(0.0) +
        env.get("dx1").unwrap_or(0.0) -
        0.0
      env["dy1"] = sheet_preset_muldiv(
        env.get("x1").unwrap_or(0.0),
        env.get("dy2").unwrap_or(0.0),
        env.get("wd2").unwrap_or(0.0),
      )
      env["y1"] = env.get("y2").unwrap_or(0.0) +
        0.0 -
        env.get("dy1").unwrap_or(0.0)
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x01\x01\x01\x04",
        coordinates: [
          env.get("l").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("hc").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
        ],
      }
    }
    "upDownArrowCallout" => {
      env["adj1"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        25000.0
      }
      env["adj2"] = 25000.0
      env["adj3"] = 25000.0
      env["adj4"] = 48123.0
      env["maxAdj2"] = sheet_preset_muldiv(
        50000.0,
        env.get("w").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
      )
      env["a2"] = sheet_preset_pin(
        0.0,
        env.get("adj2").unwrap_or(0.0),
        env.get("maxAdj2").unwrap_or(0.0),
      )
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
      env["maxAdj3"] = sheet_preset_muldiv(
        50000.0,
        env.get("h").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
      )
      env["a3"] = sheet_preset_pin(
        0.0,
        env.get("adj3").unwrap_or(0.0),
        env.get("maxAdj3").unwrap_or(0.0),
      )
      env["q2"] = sheet_preset_muldiv(
        env.get("a3").unwrap_or(0.0),
        env.get("ss").unwrap_or(0.0),
        env.get("hd2").unwrap_or(0.0),
      )
      env["maxAdj4"] = 100000.0 + 0.0 - env.get("q2").unwrap_or(0.0)
      env["a4"] = sheet_preset_pin(
        0.0,
        env.get("adj4").unwrap_or(0.0),
        env.get("maxAdj4").unwrap_or(0.0),
      )
      env["dx1"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a2").unwrap_or(0.0),
        100000.0,
      )
      env["dx2"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a1").unwrap_or(0.0),
        200000.0,
      )
      env["x1"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("dx1").unwrap_or(0.0)
      env["x2"] = env.get("hc").unwrap_or(0.0) +
        0.0 -
        env.get("dx2").unwrap_or(0.0)
      env["x3"] = env.get("hc").unwrap_or(0.0) +
        env.get("dx2").unwrap_or(0.0) -
        0.0
      env["x4"] = env.get("hc").unwrap_or(0.0) +
        env.get("dx1").unwrap_or(0.0) -
        0.0
      env["y1"] = sheet_preset_muldiv(
        env.get("ss").unwrap_or(0.0),
        env.get("a3").unwrap_or(0.0),
        100000.0,
      )
      env["y4"] = env.get("b").unwrap_or(0.0) +
        0.0 -
        env.get("y1").unwrap_or(0.0)
      env["dy2"] = sheet_preset_muldiv(
        env.get("h").unwrap_or(0.0),
        env.get("a4").unwrap_or(0.0),
        200000.0,
      )
      env["y2"] = env.get("vc").unwrap_or(0.0) +
        0.0 -
        env.get("dy2").unwrap_or(0.0)
      env["y3"] = env.get("vc").unwrap_or(0.0) +
        env.get("dy2").unwrap_or(0.0) -
        0.0
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x04",
        coordinates: [
          env.get("l").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("hc").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("x4").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("x3").unwrap_or(0.0) * sx,
          env.get("y4").unwrap_or(0.0) * sy,
          env.get("x4").unwrap_or(0.0) * sx,
          env.get("y4").unwrap_or(0.0) * sy,
          env.get("hc").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("y4").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y4").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
          env.get("l").unwrap_or(0.0) * sx,
          env.get("y3").unwrap_or(0.0) * sy,
        ],
      }
    }
    "wedgeRectCallout" => {
      env["adj1"] = if adjustment is Some(value) {
        value.to_double()
      } else {
        -20833.0
      }
      env["adj2"] = 62500.0
      env["dxPos"] = sheet_preset_muldiv(
        env.get("w").unwrap_or(0.0),
        env.get("adj1").unwrap_or(0.0),
        100000.0,
      )
      env["dyPos"] = sheet_preset_muldiv(
        env.get("h").unwrap_or(0.0),
        env.get("adj2").unwrap_or(0.0),
        100000.0,
      )
      env["xPos"] = env.get("hc").unwrap_or(0.0) +
        env.get("dxPos").unwrap_or(0.0) -
        0.0
      env["yPos"] = env.get("vc").unwrap_or(0.0) +
        env.get("dyPos").unwrap_or(0.0) -
        0.0
      env["dx"] = env.get("xPos").unwrap_or(0.0) +
        0.0 -
        env.get("hc").unwrap_or(0.0)
      env["dy"] = env.get("yPos").unwrap_or(0.0) +
        0.0 -
        env.get("vc").unwrap_or(0.0)
      env["dq"] = sheet_preset_muldiv(
        env.get("dxPos").unwrap_or(0.0),
        env.get("h").unwrap_or(0.0),
        env.get("w").unwrap_or(0.0),
      )
      env["ady"] = env.get("dyPos").unwrap_or(0.0).abs()
      env["adq"] = env.get("dq").unwrap_or(0.0).abs()
      env["dz"] = env.get("ady").unwrap_or(0.0) +
        0.0 -
        env.get("adq").unwrap_or(0.0)
      env["xg1"] = if env.get("dxPos").unwrap_or(0.0) > 0.0 { 7.0 } else { 2.0 }
      env["xg2"] = if env.get("dxPos").unwrap_or(0.0) > 0.0 {
        10.0
      } else {
        5.0
      }
      env["x1"] = sheet_preset_muldiv(
        env.get("w").unwrap_or(0.0),
        env.get("xg1").unwrap_or(0.0),
        12.0,
      )
      env["x2"] = sheet_preset_muldiv(
        env.get("w").unwrap_or(0.0),
        env.get("xg2").unwrap_or(0.0),
        12.0,
      )
      env["yg1"] = if env.get("dyPos").unwrap_or(0.0) > 0.0 { 7.0 } else { 2.0 }
      env["yg2"] = if env.get("dyPos").unwrap_or(0.0) > 0.0 {
        10.0
      } else {
        5.0
      }
      env["y1"] = sheet_preset_muldiv(
        env.get("h").unwrap_or(0.0),
        env.get("yg1").unwrap_or(0.0),
        12.0,
      )
      env["y2"] = sheet_preset_muldiv(
        env.get("h").unwrap_or(0.0),
        env.get("yg2").unwrap_or(0.0),
        12.0,
      )
      env["t1"] = if env.get("dxPos").unwrap_or(0.0) > 0.0 {
        env.get("l").unwrap_or(0.0)
      } else {
        env.get("xPos").unwrap_or(0.0)
      }
      env["xl"] = if env.get("dz").unwrap_or(0.0) > 0.0 {
        env.get("l").unwrap_or(0.0)
      } else {
        env.get("t1").unwrap_or(0.0)
      }
      env["t2"] = if env.get("dyPos").unwrap_or(0.0) > 0.0 {
        env.get("x1").unwrap_or(0.0)
      } else {
        env.get("xPos").unwrap_or(0.0)
      }
      env["xt"] = if env.get("dz").unwrap_or(0.0) > 0.0 {
        env.get("t2").unwrap_or(0.0)
      } else {
        env.get("x1").unwrap_or(0.0)
      }
      env["t3"] = if env.get("dxPos").unwrap_or(0.0) > 0.0 {
        env.get("xPos").unwrap_or(0.0)
      } else {
        env.get("r").unwrap_or(0.0)
      }
      env["xr"] = if env.get("dz").unwrap_or(0.0) > 0.0 {
        env.get("r").unwrap_or(0.0)
      } else {
        env.get("t3").unwrap_or(0.0)
      }
      env["t4"] = if env.get("dyPos").unwrap_or(0.0) > 0.0 {
        env.get("xPos").unwrap_or(0.0)
      } else {
        env.get("x1").unwrap_or(0.0)
      }
      env["xb"] = if env.get("dz").unwrap_or(0.0) > 0.0 {
        env.get("t4").unwrap_or(0.0)
      } else {
        env.get("x1").unwrap_or(0.0)
      }
      env["t5"] = if env.get("dxPos").unwrap_or(0.0) > 0.0 {
        env.get("y1").unwrap_or(0.0)
      } else {
        env.get("yPos").unwrap_or(0.0)
      }
      env["yl"] = if env.get("dz").unwrap_or(0.0) > 0.0 {
        env.get("y1").unwrap_or(0.0)
      } else {
        env.get("t5").unwrap_or(0.0)
      }
      env["t6"] = if env.get("dyPos").unwrap_or(0.0) > 0.0 {
        env.get("t").unwrap_or(0.0)
      } else {
        env.get("yPos").unwrap_or(0.0)
      }
      env["yt"] = if env.get("dz").unwrap_or(0.0) > 0.0 {
        env.get("t6").unwrap_or(0.0)
      } else {
        env.get("t").unwrap_or(0.0)
      }
      env["t7"] = if env.get("dxPos").unwrap_or(0.0) > 0.0 {
        env.get("yPos").unwrap_or(0.0)
      } else {
        env.get("y1").unwrap_or(0.0)
      }
      env["yr"] = if env.get("dz").unwrap_or(0.0) > 0.0 {
        env.get("y1").unwrap_or(0.0)
      } else {
        env.get("t7").unwrap_or(0.0)
      }
      env["t8"] = if env.get("dyPos").unwrap_or(0.0) > 0.0 {
        env.get("yPos").unwrap_or(0.0)
      } else {
        env.get("b").unwrap_or(0.0)
      }
      env["yb"] = if env.get("dz").unwrap_or(0.0) > 0.0 {
        env.get("t8").unwrap_or(0.0)
      } else {
        env.get("b").unwrap_or(0.0)
      }
      let sx = 1.0
      let sy = 1.0
      {
        verbs: b"\x00\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x04",
        coordinates: [
          env.get("l").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("xt").unwrap_or(0.0) * sx,
          env.get("yt").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("t").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
          env.get("xr").unwrap_or(0.0) * sx,
          env.get("yr").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("r").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("x2").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("xb").unwrap_or(0.0) * sx,
          env.get("yb").unwrap_or(0.0) * sy,
          env.get("x1").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("l").unwrap_or(0.0) * sx,
          env.get("b").unwrap_or(0.0) * sy,
          env.get("l").unwrap_or(0.0) * sx,
          env.get("y2").unwrap_or(0.0) * sy,
          env.get("xl").unwrap_or(0.0) * sx,
          env.get("yl").unwrap_or(0.0) * sy,
          env.get("l").unwrap_or(0.0) * sx,
          env.get("y1").unwrap_or(0.0) * sy,
        ],
      }
    }
    _ => abort("unknown formula preset")
  }
}

///|
fn sheet_preset_muldiv(x : Double, y : Double, z : Double) -> Double {
  if z == 0.0 {
    0.0
  } else {
    x * y / z
  }
}

///|
fn sheet_preset_adddiv(x : Double, y : Double, z : Double) -> Double {
  if z == 0.0 {
    0.0
  } else {
    (x + y) / z
  }
}

///|
fn sheet_preset_pin(x : Double, y : Double, z : Double) -> Double {
  if y < x {
    x
  } else if y > z {
    z
  } else {
    y
  }
}
