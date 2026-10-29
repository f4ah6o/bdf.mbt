///|
test "a multi-staff part gets a stretched brace" {
  let parts : Array[MusicPartSpan] = [
    { name: "Piano", abbreviation: "", staff_tops: [0.0, 10.0], },
  ]
  let drawing = draw_spanning_system(
    parts,
    [{ x: 2.0, width: 10.0, left: 1, right: 3, }],
    true,
    _ => { width: 0.0, ascent: 0.0, descent: 0.0, },
  )
  let commands = drawing.primitives()
  inspect(commands.length(), content="4")
  inspect(commands[1].glyph, content="brace")
  inspect(commands[1].scale_x, content="4.2")
  inspect(commands[1].scale_y, content="3.5")
}
