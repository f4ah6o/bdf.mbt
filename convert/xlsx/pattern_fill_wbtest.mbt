///|
test "XLSX pattern fills cover the upstream pattern table" {
  let names = [
    "gray0625", "gray125", "lightGray", "mediumGray", "darkGray",
    "darkHorizontal", "lightHorizontal", "darkVertical", "lightVertical",
    "darkDown", "darkUp", "lightDown", "lightUp", "darkGrid", "lightGrid",
    "darkTrellis", "lightTrellis",
  ]
  for name in names {
    match xlsx_plain_pattern_bits(name) {
      Some(bits) => assert_eq(bits.length(), 8)
      None => fail("missing pattern " + name)
    }
  }
  assert_true(xlsx_plain_pattern_bits("not-a-pattern") is None)
}
