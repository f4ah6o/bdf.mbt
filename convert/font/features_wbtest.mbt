///|
test "font with no OpenType layout tables has no feature groups" {
  let file = load(small_font())
  assert_eq(file.faces()[0].feature_groups().length(), 0)
}

///|
test "feature descriptions preserve script and language order" {
  let group : FeatureGroup = {
    table: "GSUB",
    tag: "liga",
    lookups: [],
    scripts: ["latn", "latn/TRK ", " cyrl ", "latn/ROM", " cyrl /"],
    ui_name: "",
    characters: [],
  }
  assert_eq(group.script_tags(), "latn cyrl")
  assert_eq(
    group.script_list(),
    "latn (default, TRK, ROM), cyrl (default, default)",
  )
  assert_eq(group.display_name(), "Standard Ligatures")
  assert_eq(group.default_note(), "on by default")
  group.ui_name = "Custom name"
  assert_eq(group.display_name(), "Custom name")
}
