///|
test "XMP alternatives put the last default language first" {
  let xml = "<dc:title xmlns:dc='http://purl.org/dc/elements/1.1/' xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'><rdf:Alt><rdf:li xml:lang='en'>English</rdf:li><rdf:li xml:lang='x-default'>One</rdf:li><rdf:li xml:lang='x-default'>Two</rdf:li></rdf:Alt></dc:title>"
  guard xmp_tree(xml) is Some(root) else { fail("no root") }
  assert_eq(xmp_values(root), ["Two", "One", "English"])
}

///|
test "XMP resources and nested values" {
  let xml = "<dc:creator xmlns:dc='http://purl.org/dc/elements/1.1/' xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'><agent><dc:title>  A  B \n C </dc:title></agent></dc:creator>"
  guard xmp_tree(xml) is Some(root) else { fail("no root") }
  assert_eq(xmp_values(root), ["A B C"])
}
