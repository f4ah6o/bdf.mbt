///|
test "search bounds normalization work on long sequences of marks" {
  let runs : Array[@core.IndexRun] = [
    {
      a: 0,
      b: 0,
      ordinal: 0,
      separator: 0,
      text: "e" + "\u{301}".repeat(200000) + "x",
    },
  ]
  let search = @core.TextSearch::new(runs)
  let hit = search.search("é", context=0)
  assert_eq(hit.length(), 1)
  assert_eq((hit[0].segments[0].start, hit[0].segments[0].end), (0, 32))
  assert_eq(search.search("x", context=0).length(), 1)
}

///|
test "search clamps original text slices if a run is replaced" {
  let runs : Array[@core.IndexRun] = [
    { a: 0, b: 0, ordinal: 0, separator: 0, text: "hello", },
  ]
  let search = @core.TextSearch::new(runs)
  runs[0] = { a: 0, b: 0, ordinal: 0, separator: 0, text: "a", }
  let hits = search.search("hello")
  assert_eq(hits[0].text, "a")
  assert_eq(hits[0].segments[0].end, 5)
}
