///|
test "OpenType feature tag boundaries and defaults" {
  assert_eq(feature_name("ss01"), "Stylistic Set 1")
  assert_eq(feature_name("ss20"), "Stylistic Set 20")
  assert_eq(feature_name("ss21"), "")
  assert_eq(feature_name("cv99"), "Character Variant 99")
  assert_eq(feature_name("cv00"), "")
  assert_eq(feature_default("liga"), 1)
  assert_eq(feature_default("init"), 2)
  assert_eq(feature_default("vert"), 3)
  assert_eq(feature_default("ss01"), 0)
  assert_eq(language_name("JAN "), "Japanese")
  assert_eq(lookup_type_name(8), "reverse chaining")
  assert_eq(lookup_type_name(9, gpos=true), "extension")
  assert_eq(lookup_type_name(99), "type 99")
}
