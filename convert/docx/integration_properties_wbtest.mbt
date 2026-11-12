///|
// Exhaustive generated properties over bounded domains, without a random seed
// or an additional test dependency. Every failure identifies its input index.
test "DOCX generated property mark size never leaks into adjacent run" {
  for half_points in 2..<130 {
    let walker = docx_mark_walker(
      "<styles/>",
      "<body><p><pPr><rPr><sz val=\"" + half_points.to_string() +
      "\"/></rPr></pPr><r><t>A</t></r></p></body>",
    )
    let paragraph = walker.paragraphs[0]
    assert_eq(paragraph.mark.size, half_points.to_double() / 2.0,
      msg=half_points.to_string())
    assert_eq(paragraph.items[0].props.size, 10.0,
      msg=half_points.to_string())
  }
}

///|
test "DOCX generated property supported Requires permutations select once" {
  let prefixes = ["wps", "wpg", "wpc", "wp14", "w14", "w15", "a14", "pic14"]
  for first in prefixes {
    for second in prefixes {
      for separator in [" ", "  ", "&#9;", "&#10;"] {
        let requires = first + separator + second
        assert_eq(docx_alternate_content_chosen(
          "<AlternateContent><Choice Requires=\"" + requires +
          "\"><chosen/></Choice><Fallback><fallback/></Fallback></AlternateContent>"),
          "chosen", msg=requires)
        assert_eq(docx_alternate_content_chosen(
          "<AlternateContent><Choice Requires=\"" + requires +
          " unknown\"><rejected/></Choice><Fallback><fallback/></Fallback></AlternateContent>"),
          "fallback", msg=requires)
      }
    }
  }
}

///|
test "DOCX generated property drawing multiplicity preserves one warning" {
  for count in 1..<17 {
    let blocks = StringBuilder()
    for index in 0..<count {
      blocks.write_string(docx_degrade_shape("", index % 2 == 0))
    }
    blocks.write_string(docx_degrade_body())
    let result = convert(docx_degrade_document(blocks.to_string()))
    let mut notes = 0
    for note in result.warnings {
      if note == DOCX_DEGRADE_NOTE { notes += 1 }
    }
    assert_eq(notes, 1, msg=count.to_string())
  }
}
