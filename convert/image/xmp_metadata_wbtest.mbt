///|
test "XMP dates and document fields follow upstream precedence" {
  let packet = "<rdf:RDF xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'><rdf:Description xmlns:xmp='http://ns.adobe.com/xap/1.0/' xmlns:photoshop='http://ns.adobe.com/photoshop/1.0/' xmlns:dc='http://purl.org/dc/elements/1.1/' xmp:CreateDate='2026-09-03T12:00:00Z' xmp:ModifyDate='2026:09:04 08:00:00+0900' photoshop:DateCreated='2026-09-01'><dc:date><rdf:Seq><rdf:li>2026-09</rdf:li><rdf:li>yesterday</rdf:li></rdf:Seq></dc:date><dc:created>2026-01-01</dc:created></rdf:Description></rdf:RDF>"
  guard xmp_tree(packet) is Some(root) else { fail("no root") }
  let result = xmp_metadata(root)
  assert_eq(result.get("created"), Some(["2026-09-01"]))
  assert_eq(result.get("modified"), Some(["2026-09-04T08:00:00+09:00"]))
  assert_eq(result.get("date"), Some(["2026-09"]))
}

///|
test "XMP uses TIFF fallback after placeholder description" {
  let packet = "<rdf:RDF xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'><rdf:Description xmlns:tiff='http://ns.adobe.com/tiff/1.0/' xmlns:dc='http://purl.org/dc/elements/1.1/' tiff:Artist='Ann; Bob' tiff:Copyright='CC0' tiff:ImageDescription='A cat'><dc:description>OLYMPUS DIGITAL CAMERA</dc:description><dc:rights>© Ann</dc:rights></rdf:Description></rdf:RDF>"
  guard xmp_tree(packet) is Some(root) else { fail("no root") }
  let result = xmp_metadata(root)
  assert_eq(result.get("creator"), Some(["Ann", "Bob"]))
  assert_eq(result.get("rights"), Some(["© Ann"]))
  assert_eq(result.get("description"), Some(["A cat"]))
}
