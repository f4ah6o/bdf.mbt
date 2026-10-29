///|
/// Draw a barline spanning a part, with repeat dots on its staff tops.
/// Kinds follow the upstream score model: regular, none, double, final,
/// heavy-light, repeat-start, repeat-end, repeat-both and dashed (0 to 8).
pub fn draw_barline(
  drawing : MusicDrawing,
  kind : Int32,
  x : Double,
  top : Double,
  bottom : Double,
  staff_tops : Array[Double],
  left : Bool,
) -> Unit {
  let thin = 0.16
  let thick = 0.5
  let separation = 0.4
  let height = bottom - top
  if left {
    if kind == 4 || kind == 5 {
      drawing.rect(x, top, thick, height)
      drawing.rect(x + thick + separation, top, thin, height)
      if kind == 5 {
        for y in staff_tops {
          drawing.glyph(
            "repeatDots",
            x + thick + separation + thin + 0.4,
            y + 4.0,
            1.0,
          )
        }
      }
    }
    return
  }
  match kind {
    1 => ()
    2 => {
      drawing.rect(x - thin, top, thin, height)
      drawing.rect(x - 2.0 * thin - separation, top, thin, height)
    }
    3 => {
      drawing.rect(x - thick, top, thick, height)
      drawing.rect(x - thick - separation - thin, top, thin, height)
    }
    4 => {
      drawing.rect(x - thin, top, thin, height)
      drawing.rect(x - thin - separation - thick, top, thick, height)
    }
    6 | 7 => {
      drawing.rect(x - thick, top, thick, height)
      drawing.rect(x - thick - separation - thin, top, thin, height)
      let dot_x = x -
        thick -
        separation -
        thin -
        0.4 -
        glyph_advance("repeatDots")
      for y in staff_tops {
        drawing.glyph("repeatDots", dot_x, y + 4.0, 1.0)
      }
    }
    8 =>
      for y in staff_tops {
        drawing.line(x - thin / 2.0, y, x - thin / 2.0, y + 4.0, thin, 0.5)
      }
    _ => drawing.rect(x - thin, top, thin, height)
  }
}
