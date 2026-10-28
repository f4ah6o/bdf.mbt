///|
test "XMP tree resolves namespaces, attributes and direct text" {
  let source = "<rdf:RDF xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#' xmlns:dc='http://purl.org/dc/elements/1.1/'><rdf:Description dc:creator='Ann'><dc:title>hi<![CDATA[ there]]></dc:title></rdf:Description></rdf:RDF>"
  guard xmp_tree(source) is Some(root) else { fail("no root") }
  assert_eq(root.name, "RDF")
  assert_eq(root.space, "http://www.w3.org/1999/02/22-rdf-syntax-ns#")
  let desc = root.children[0]
  assert_eq(
    desc.attribute("http://purl.org/dc/elements/1.1/", "creator"),
    "Ann",
  )
  assert_eq(desc.children[0].text.to_string(), "hi there")
}

///|
test "XMP tree preserves parsed elements on truncated XML" {
  guard xmp_tree("<root><child>some text</child><bad") is Some(root) else {
    fail("no root")
  }
  assert_eq(root.children.length(), 1)
  assert_eq(root.children[0].text.to_string(), "some text")
}

///|
test "XMP skips descendants deeper than 512 without losing later siblings" {
  let source = "<r>" +
    "<a>".repeat(612) +
    "text" +
    "</a>".repeat(612) +
    "<b>after</b></r>"
  guard xmp_tree(source) is Some(root) else { fail("no root") }
  assert_eq(root.children.length(), 2)
  assert_eq(root.children[1].text.to_string(), "after")
  let mut node = root
  let mut depth = 0
  while node.children.length() > 0 {
    depth += 1
    node = node.children[0]
  }
  assert_eq(depth, 512)
  assert_eq(node.text.to_string(), "")
}

///|
test "XMP rejects unsupported character set declarations" {
  let (_, complete) = xmp_tree_checked(
    "<?xml version='1.0' encoding='iso-8859-1'?><root/>",
  )
  assert_false(complete)
  let (root, utf16_complete) = xmp_tree_checked(
    "\u{feff}<?xml version='1.0' encoding='UTF-16'?><root/>",
    utf16=true,
  )
  assert_true(utf16_complete)
  assert_true(root is Some(_))
}
