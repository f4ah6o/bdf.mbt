///|
test "pagination observes explicit page breaks and staff spacing" {
  let systems : Array[MusicSystemExtent] = [
    {
      staves: [
        { part: 0, above: -2.0, below: 7.0, },
        { part: 0, above: -3.0, below: 5.0, },
      ],
      page_break: false,
    },
    {
      staves: [
        { part: 0, above: -2.0, below: 7.0, },
        { part: 0, above: -3.0, below: 5.0, },
      ],
      page_break: true,
    },
  ]
  let positions = paginate_systems(systems, 800.0, 5.0, 40.0)
  inspect(positions[0].staff_y, content="[0, 11]")
  inspect(positions[0].page, content="0")
  inspect(positions[1].page, content="1")
  assert_true(positions[0].top > positions[1].top)
}
