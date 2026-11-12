///|
fn pptx_test_shape_links(
  result : PptxResult,
) -> Array[(Double, Double, Double, Double, String)] raise {
  let links = []
  for command in pptx_figure_body_commands(result) {
    match command {
      @render.Link(x, y, w, h, url) => links.push((x, y, w, h, url))
      _ => ()
    }
  }
  links
}

///|
fn pptx_link_test_box(id : String, text : String) -> String {
  pptx_figure_box(
    "<p:cNvPr id=\"2\" name=\"Box\"><a:hlinkClick xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" r:id=\"" +
    id +
    "\"/></p:cNvPr>",
    text,
  )
}

///|
test "PPTX shape click links resolve external relationships and retain bounds" {
  let rels =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="web" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="https://example.com/path?q=1" TargetMode="External"/><Relationship Id="mail" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="mailto:test@example.com" TargetMode="External"/><Relationship Id="unsafe" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="javascript:alert(1)" TargetMode="External"/><Relationship Id="bad" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="https://example.com/%xx" TargetMode="External"/><Relationship Id="internal" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slide2.xml"/></Relationships>
  let jump = "<p:sp><p:nvSpPr><p:cNvPr id=\"9\"><a:hlinkClick xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" r:id=\"web\" action=\"ppaction://hlinkshowjump?jump=nextslide\"/></p:cNvPr></p:nvSpPr><p:spPr><a:xfrm><a:off x=\"457200\" y=\"457200\"/><a:ext cx=\"914400\" cy=\"914400\"/></a:xfrm></p:spPr></p:sp>"
  let slide = pptx_test_slide_prefix +
    jump +
    pptx_link_test_box("web", "") +
    pptx_link_test_box("mail", pptx_figure_text("Text")) +
    pptx_link_test_box("unsafe", "") +
    pptx_link_test_box("bad", "") +
    pptx_link_test_box("internal", "") +
    pptx_link_test_box("missing", "") +
    pptx_test_slide_suffix
  let links = pptx_test_shape_links(
    convert(pptx_test_deck(slide, [("ppt/slides/_rels/slide1.xml.rels", rels)])),
  )
  assert_eq(links, [
    (36.0, 36.0, 72.0, 72.0, "https://example.com/path?q=1"),
    (36.0, 36.0, 72.0, 72.0, "mailto:test@example.com"),
  ])
}

///|
test "PPTX rotated shape click link encloses the drawn rectangle" {
  let box =
    #|<p:sp><p:nvSpPr><p:cNvPr id="2" name="Rotated"><a:hlinkClick xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:id="web"/></p:cNvPr><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm rot="5400000"><a:off x="457200" y="457200"/><a:ext cx="1828800" cy="914400"/></a:xfrm><a:prstGeom prst="rect"/></p:spPr></p:sp>
  let rels =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="web" Type="hyperlink" Target="http://example.com" TargetMode="External"/></Relationships>
  let links = pptx_test_shape_links(
    convert(
      pptx_test_deck(pptx_test_slide_prefix + box + pptx_test_slide_suffix, [
        ("ppt/slides/_rels/slide1.xml.rels", rels),
      ]),
    ),
  )
  assert_eq(links.length(), 1)
  let (x, y, w, h, url) = links[0]
  assert_true((x - 72.0).abs() < 0.001 && y.abs() < 0.001)
  assert_true((w - 72.0).abs() < 0.001 && (h - 144.0).abs() < 0.001)
  assert_eq(url, "http://example.com")
}

///|
test "PPTX picture links use their own slide relationship" {
  let image = b"\x89PNG\r\n\x1a\n\x00\x00\x00\x0dIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00"
  let shapes =
    #|<p:pic><p:nvPicPr><p:cNvPr id="2" name="Photo"><a:hlinkClick r:id="web"/></p:cNvPr><p:cNvPicPr/><p:nvPr/></p:nvPicPr><p:blipFill><a:blip r:embed="image"/></p:blipFill><p:spPr><a:xfrm><a:off x="914400" y="914400"/><a:ext cx="914400" cy="914400"/></a:xfrm></p:spPr></p:pic>
  let slide = (pptx_test_slide_prefix + shapes + pptx_test_slide_suffix).replace(
    old="<p:sld ",
    new="<p:sld xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" ",
  )
  let rels =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="image" Type="image" Target="../media/image1.png"/><Relationship Id="web" Type="hyperlink" Target="https://example.com/picture" TargetMode="External"/></Relationships>
  let deck = pptx_figure_zip([
    ("_rels/.rels", @utf8.encode(pptx_test_root_rels)),
    ("ppt/presentation.xml", @utf8.encode(pptx_test_presentation)),
    (
      "ppt/_rels/presentation.xml.rels",
      @utf8.encode(pptx_test_presentation_rels),
    ),
    ("ppt/slides/slide1.xml", @utf8.encode(slide)),
    ("ppt/slides/_rels/slide1.xml.rels", @utf8.encode(rels)),
    ("ppt/media/image1.png", image),
  ])
  assert_eq(pptx_test_shape_links(convert(deck)), [
    (72.0, 72.0, 72.0, 72.0, "https://example.com/picture"),
  ])
}

///|
test "PPTX grouped shapes preserve transformed link bounds and hidden links are skipped" {
  let group =
    #|<p:grpSp><p:nvGrpSpPr><p:cNvPr id="4" name="Group"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="914400" y="914400"/><a:ext cx="1828800" cy="1828800"/><a:chOff x="0" y="0"/><a:chExt cx="914400" cy="914400"/></a:xfrm></p:grpSpPr>
  let hidden = "<p:sp><p:nvSpPr><p:cNvPr id=\"5\" hidden=\"1\"><a:hlinkClick xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" r:id=\"web\"/></p:cNvPr></p:nvSpPr></p:sp>"
  let rels =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="web" Type="hyperlink" Target="https://example.com/group" TargetMode="External"/></Relationships>
  let slide = pptx_test_slide_prefix +
    group +
    pptx_link_test_box("web", "") +
    "</p:grpSp>" +
    hidden +
    pptx_test_slide_suffix
  assert_eq(
    pptx_test_shape_links(
      convert(
        pptx_test_deck(slide, [("ppt/slides/_rels/slide1.xml.rels", rels)]),
      ),
    ),
    [(144.0, 144.0, 144.0, 144.0, "https://example.com/group")],
  )
}

///|
test "PPTX connector links retain zero-height geometry" {
  let connector =
    #|<p:cxnSp><p:nvCxnSpPr><p:cNvPr id="2" name="Line"><a:hlinkClick xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:id="web"/></p:cNvPr><p:cNvCxnSpPr/><p:nvPr/></p:nvCxnSpPr><p:spPr><a:xfrm><a:off x="457200" y="914400"/><a:ext cx="914400" cy="0"/></a:xfrm><a:prstGeom prst="line"/><a:ln><a:solidFill><a:srgbClr val="000000"/></a:solidFill></a:ln></p:spPr></p:cxnSp>
  let rels =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="web" Type="hyperlink" Target="https://example.com/line" TargetMode="External"/></Relationships>
  assert_eq(
    pptx_test_shape_links(
      convert(
        pptx_test_deck(
          pptx_test_slide_prefix + connector + pptx_test_slide_suffix,
          [("ppt/slides/_rels/slide1.xml.rels", rels)],
        ),
      ),
    ),
    [(36.0, 72.0, 72.0, 0.0, "https://example.com/line")],
  )
}
