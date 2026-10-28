///|
test "music and audio cursors interpolate and choose repeated systems" {
  let cues : @core.Cues = {
    systems: [
      { page: 0U, x: 40.0, y: 100.0, width: 500.0, height: 80.0, },
      { page: 1U, x: 30.0, y: 60.0, width: 400.0, height: 70.0, },
    ],
    cues: [
      { tick: 100U, system: 0U, x: 50.0, },
      { tick: 200U, system: 0U, x: 150.0, },
      { tick: 200U, system: 1U, x: 30.0, },
      { tick: 300U, system: 0U, x: 50.0, },
      { tick: 400U, system: 0U, x: 150.0, },
    ],
  }
  assert_eq(@render.cursor_at_tick(cues, 150.0).unwrap().x, 100.0)
  assert_eq(@render.cursor_at_tick(cues, 200.0).unwrap().system, 1U)
  assert_eq(@render.tick_at(cues, 0U, 100.0, near=350.0), Some(350.0))
  assert_eq(@render.line_at_time(cues, 99.0), None)
  assert_eq(@render.line_at_time(cues, 200.0).unwrap().width, Some(400.0))
  assert_eq(@render.time_of_line(cues, 0U, near=390.0), Some(400.0))
}
