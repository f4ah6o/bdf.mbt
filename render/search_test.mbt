///|
test "search highlights match upstream text measurement" {
  let font : @core.Font = {
    hash: None,
    family: "serif",
    weight: 400,
    style: 0,
  }
  let run : @render.TextRun = {
    text: "Hello world",
    x: 30.0,
    y: 50.0,
    advance: 110.0,
    size: 20.0,
    font: Some(font),
    align: 0,
    matrix: (1.0, 0.0, 0.0, 1.0, 0.0, 0.0),
    separator: 0,
    ordinal: 0,
    alt_text: false,
    lang: "",
    node: 0,
  }
  let measure = fn(_font, _size, text : String) {
    text.length().to_double() * 5.0
  }
  assert_true(@render.text_has_extent(run))
  assert_eq(
    @render.run_rect(run, 1, 5, measure),
    Some({ x: 40.0, y: 34.0, width: 40.0, height: 20.0, }),
  )
  let rotated = { ..run, align: 2, matrix: (0.0, 1.0, -1.0, 0.0, 5.0, 6.0), }
  assert_eq(
    @render.run_rect(rotated, 1, 5, measure),
    Some({ x: 26.0, y: 5.0, width: 20.0, height: 40.0, }),
  )
  let right = { ..run, align: 1, advance: 0.0, }
  assert_eq(
    @render.run_rect(right, 1, 5, measure),
    Some({ x: -20.0, y: 34.0, width: 20.0, height: 20.0, }),
  )
  let no_font = { ..run, font: None, }
  assert_false(@render.text_has_extent(no_font))
  assert_true(@render.run_rect(no_font, 1, 5, measure) is None)
  let alternative = { ..run, alt_text: true, advance: 0.0, }
  assert_false(@render.text_has_extent(alternative))
  assert_eq(
    @render.run_rect(alternative, 1, 5, measure),
    Some({ x: 35.0, y: 34.0, width: 20.0, height: 20.0, }),
  )
  let hit : @core.SearchHit = {
    segments: [
      { run: 0, a: 2, b: 3, ordinal: 0, start: 1, end: 5, },
      { run: 1, a: 4, b: 5, ordinal: 1, start: 1, end: 5, },
    ],
    text: "ello",
    context: "hello",
  }
  let rects = @render.locate_text_hit(
    hit,
    fn(_, _, ordinal) {
      if ordinal == 0 {
        Some(run)
      } else {
        Some(alternative)
      }
    },
    measure,
    tile_size=100.0,
  )
  assert_eq(rects, [
    { a: 2, b: 3, x: 240.0, y: 334.0, width: 40.0, height: 20.0, },
  ])
}
