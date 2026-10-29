///|
test "specimen document plan selects views and names for collections" {
  let file = load(small_font())
  let single = file.document_plan("", "Custom")
  assert_eq(single.metadata.source, "font")
  assert_eq(single.metadata.type_name, "Font")
  assert_eq(single.metadata.title, "Custom")
  assert_eq(single.views.map(v => v.id), ["overview", "glyphs"])
  let repeated = file.document_plan("1,1", "")
  assert_eq(repeated.views.map(v => v.id), [
    "overview-1", "glyphs-1", "overview-1", "glyphs-1",
  ])
  assert_eq(repeated.views[0].title, "Font 1: Overview")
}
