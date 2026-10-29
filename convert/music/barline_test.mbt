///|
test "repeat barline places dots on each staff" {
  let drawing = MusicDrawing::new()
  draw_barline(drawing, 6, 10.0, 0.0, 14.0, [0.0, 10.0], false)
  let commands = drawing.primitives()
  inspect(commands.length(), content="4")
  inspect(commands[2].glyph, content="repeatDots")
  inspect(commands[3].y, content="14")
}
