///|
// FIGURE marks for PPTX alternative text: a shape, picture, non-table
// graphic frame or group with a cNvPr description (else title) draws
// inside a FIGURE mark, as upstream beginFigure/endFigure wrap their
// drawings. Decorative and hidden shapes draw without a mark, group
// marks nest in document order, shape text stays outside its drawing's
// FIGURE and tables keep their own structure.

///|
/// The FIGURE and END marks of `commands` as (kind name, payload) pairs.
fn pptx_figure_marks(
  commands : Array[@render.Command],
) -> Array[(String, String)] {
  let marks : Array[(String, String)] = []
  for command in commands {
    match command {
      @render.Mark(kind, payload) =>
        if kind == @core.MARK_FIGURE.to_int() {
          marks.push(("figure", payload))
        } else if kind == @core.MARK_END.to_int() {
          marks.push(("end", ""))
        }
      _ => ()
    }
  }
  marks
}

///|
/// The compiled commands of the body layer of a converted deck.
fn pptx_figure_body_commands(
  result : PptxResult,
) -> Array[@render.Command] raise {
  let doc = @core.open_single(result.bdf)
  let body = pptx_body_layer(doc.manifest).object
  let resources = @core.decode_object_resources(doc.part(body))
  @render.compile_object(resources.object)
}

///|
/// A filled rectangle shape with optional cNvPr text and shape text.
fn pptx_figure_box(cnvpr : String, text : String) -> String {
  "<p:sp><p:nvSpPr>" +
  cnvpr +
  "<p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x=\"457200\" y=\"457200\"/><a:ext cx=\"914400\" cy=\"914400\"/></a:xfrm><a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val=\"FF0000\"/></a:solidFill></p:spPr>" +
  text +
  "</p:sp>"
}

///|
/// The txBody of a one-run textbox.
fn pptx_figure_text(value : String) -> String {
  "<p:txBody><a:bodyPr/><a:p><a:r><a:rPr sz=\"1800\"/><a:t>" +
  value +
  "</a:t></a:r></a:p></p:txBody>"
}

///|
test "PPTX alt text opens a FIGURE around the shape drawing" {
  let slide = pptx_test_slide_prefix +
    pptx_figure_box(
      "<p:cNvPr id=\"2\" name=\"Red\" descr=\"A red rectangle\"/>",
      pptx_figure_text("Inside"),
    ) +
    pptx_test_slide_suffix
  let result = convert(pptx_test_deck(slide, []))
  let commands = pptx_figure_body_commands(result)
  assert_eq(pptx_figure_marks(commands), [
    ("figure", "A red rectangle"),
    ("end", ""),
  ])
  // The drawing sits inside the FIGURE; the shape's text stays outside.
  let mut mark = -1
  let mut end = -1
  let mut fill = -1
  let mut text = -1
  for index, command in commands {
    match command {
      @render.Mark(kind, _) =>
        if kind == @core.MARK_FIGURE.to_int() {
          mark = index
        } else if kind == @core.MARK_END.to_int() {
          end = index
        }
      @render.FillRect(_, _, _, _) => if fill < 0 { fill = index }
      @render.FillText(_, _, _, _) => if text < 0 { text = index }
      _ => ()
    }
  }
  assert_true(mark >= 0 && fill > mark, msg="figure opens before the fill")
  assert_true(end > fill, msg="figure closes after the fill")
  assert_true(text > end, msg="shape text stays outside the figure")
}

///|
test "PPTX alt text prefers trimmed descr over title" {
  let slide = pptx_test_slide_prefix +
    pptx_figure_box(
      "<p:cNvPr id=\"2\" name=\"Dog\" title=\"The title\" descr=\"  A picture of a dog \"/>",
      "",
    ) +
    pptx_figure_box(
      "<p:cNvPr id=\"3\" name=\"Cat\" descr=\"   \" title=\"Cat\"/>", "",
    ) +
    pptx_figure_box("<p:cNvPr id=\"4\" name=\"Title\"/>", "") +
    pptx_figure_box(
      "<p:cNvPr id=\"5\" name=\"Both\" descr=\" \" title=\"  Whitespace title  \"/>",
      "",
    ) +
    pptx_test_slide_suffix
  let result = convert(pptx_test_deck(slide, []))
  let commands = pptx_figure_body_commands(result)
  assert_eq(pptx_figure_marks(commands), [
    ("figure", "A picture of a dog"),
    ("end", ""),
    ("figure", "Cat"),
    ("end", ""),
    ("figure", "Whitespace title"),
    ("end", ""),
  ])
}

///|
test "PPTX decorative, unfilled and hidden shapes stay unmarked" {
  let decorative = "<p:sp><p:nvSpPr><p:cNvPr id=\"2\" name=\"Deco\" descr=\"A decorative box\"><a:extLst><a:ext uri=\"http://schemas.microsoft.com/office/drawing/2017/decorative\"><adec:decorative xmlns:adec=\"http://schemas.microsoft.com/office/drawing/2017/decorative\" val=\"1\"/></a:ext></a:extLst></p:cNvPr><p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr><a:xfrm><a:off x=\"457200\" y=\"457200\"/><a:ext cx=\"914400\" cy=\"914400\"/></a:xfrm><a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val=\"00FF00\"/></a:solidFill></p:spPr></p:sp>"
  let unfilled = "<p:sp><p:nvSpPr><p:cNvPr id=\"3\" name=\"Nothing\" descr=\"An invisible box\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x=\"1828800\" y=\"457200\"/><a:ext cx=\"914400\" cy=\"914400\"/></a:xfrm><a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom><a:noFill/><a:ln><a:noFill/></a:ln></p:spPr></p:sp>"
  let hidden = "<p:sp><p:nvSpPr><p:cNvPr id=\"4\" name=\"Hidden\" descr=\"A hidden box\" hidden=\"1\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x=\"457200\" y=\"2286000\"/><a:ext cx=\"914400\" cy=\"914400\"/></a:xfrm><a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val=\"0000FF\"/></a:solidFill></p:spPr></p:sp>"
  let slide = pptx_test_slide_prefix +
    decorative +
    unfilled +
    hidden +
    pptx_test_slide_suffix
  let result = convert(pptx_test_deck(slide, []))
  let commands = pptx_figure_body_commands(result)
  assert_eq(pptx_figure_marks(commands), [])
  let mut green = false
  let mut blue = 0
  for command in commands {
    match command {
      @render.FillColor(0x00ff00ff) => green = true
      @render.FillColor(0x0000ffff) => blue += 1
      _ => ()
    }
  }
  assert_true(green, msg="the decorative shape still draws")
  assert_eq(blue, 0, msg="the hidden shape never draws")
  // A decorative ext with val="0" is not decorative, as upstream reads val.
  let root = pptx_parse_xml(
    "<p:sp xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\"><p:nvSpPr><p:cNvPr id=\"2\" name=\"Kept\" descr=\"Kept text\"><a:extLst><a:ext uri=\"u\"><a:decorative val=\"0\"/></a:ext></a:extLst></p:cNvPr></p:nvSpPr></p:sp>",
  )
  assert_eq(pptx_alt_text(root), Some("Kept text"))
  // A picture keeps its own alt text through nvPicPr.
  let pic = pptx_parse_xml(
    "<p:pic xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\"><p:nvPicPr><p:cNvPr id=\"5\" name=\"Photo\" title=\"The photo\"/></p:nvPicPr></p:pic>",
  )
  assert_eq(pptx_alt_text(pic), Some("The photo"))
}

///|
test "PPTX group FIGURE marks nest in shape order" {
  let shapes =
    #|<p:grpSp><p:nvGrpSpPr><p:cNvPr id="2" name="Outer" descr="The outer group"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="457200" y="457200"/><a:ext cx="2743200" cy="2743200"/><a:chOff x="0" y="0"/><a:chExt cx="2743200" cy="2743200"/></a:xfrm></p:grpSpPr><p:sp><p:nvSpPr><p:cNvPr id="3" name="Inner" descr="The inner box"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="12700" y="12700"/><a:ext cx="914400" cy="914400"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val="FF0000"/></a:solidFill></p:spPr></p:sp><p:grpSp><p:nvGrpSpPr><p:cNvPr id="4" name="Middle" descr="The empty middle group"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="914400" y="914400"/><a:ext cx="914400" cy="914400"/><a:chOff x="0" y="0"/><a:chExt cx="914400" cy="914400"/></a:xfrm></p:grpSpPr><p:sp><p:nvSpPr><p:cNvPr id="5" name="Unmarked"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="457200" y="457200"/><a:ext cx="914400" cy="914400"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val="0000FF"/></a:solidFill></p:spPr></p:sp></p:grpSp></p:grpSp>
  let slide = pptx_test_slide_prefix + shapes + pptx_test_slide_suffix
  let result = convert(pptx_test_deck(slide, []))
  let commands = pptx_figure_body_commands(result)
  assert_eq(pptx_figure_marks(commands), [
    ("figure", "The outer group"),
    ("figure", "The inner box"),
    ("end", ""),
    ("figure", "The empty middle group"),
    ("end", ""),
    ("end", ""),
  ])
}

///|
/// A stored ZIP archive with byte bodies for picture fixtures.
fn pptx_figure_zip(files : Array[(String, Bytes)]) -> Bytes {
  let entries : Array[(Bytes, Bytes)] = []
  for (name, body) in files {
    entries.push((@utf8.encode(name), body))
  }
  let mut total = 22
  for (name, body) in entries {
    total += 30 + 46 + name.length() * 2 + body.length()
  }
  let out = Bytes::make(total, 0).to_array()
  let mut at = 0
  let offsets : Array[Int32] = []
  for (name, body) in entries {
    offsets.push(at)
    pptx_test_put_u32(out, at, 0x04034b50)
    pptx_test_put_u16(out, at + 4, 20)
    pptx_test_put_u32(out, at + 18, body.length())
    pptx_test_put_u32(out, at + 22, body.length())
    pptx_test_put_u16(out, at + 26, name.length())
    for i in 0..<name.length() {
      out[at + 30 + i] = name[i]
    }
    for i in 0..<body.length() {
      out[at + 30 + name.length() + i] = body[i]
    }
    at += 30 + name.length() + body.length()
  }
  let central_start = at
  for i, (name, body) in entries {
    pptx_test_put_u32(out, at, 0x02014b50)
    pptx_test_put_u16(out, at + 4, 20)
    pptx_test_put_u16(out, at + 6, 20)
    pptx_test_put_u32(out, at + 20, body.length())
    pptx_test_put_u32(out, at + 24, body.length())
    pptx_test_put_u16(out, at + 28, name.length())
    pptx_test_put_u32(out, at + 42, offsets[i])
    for i in 0..<name.length() {
      out[at + 46 + i] = name[i]
    }
    at += 46 + name.length()
  }
  let central_size = at - central_start
  pptx_test_put_u32(out, at, 0x06054b50)
  pptx_test_put_u16(out, at + 8, entries.length())
  pptx_test_put_u16(out, at + 10, entries.length())
  pptx_test_put_u32(out, at + 12, central_size)
  pptx_test_put_u32(out, at + 16, central_start)
  Bytes::from_array(out)
}

///|
/// A one-slide presentation with a picture, as stored ZIP parts.
fn pptx_figure_pic_deck(slide : String, image : (String, Bytes)) -> Bytes {
  let slide_rels = "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"../media/image1.png\"/></Relationships>"
  pptx_figure_zip([
    ("_rels/.rels", @utf8.encode(pptx_test_root_rels)),
    ("ppt/presentation.xml", @utf8.encode(pptx_test_presentation)),
    (
      "ppt/_rels/presentation.xml.rels",
      @utf8.encode(pptx_test_presentation_rels),
    ),
    ("ppt/slides/slide1.xml", @utf8.encode(slide)),
    ("ppt/slides/_rels/slide1.xml.rels", @utf8.encode(slide_rels)),
    (image.0, image.1),
  ])
}

///|
test "PPTX pictures draw inside their own FIGURE" {
  let image = b"\x89PNG\r\n\x1a\n\x00\x00\x00\x0dIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00"
  let shapes =
    #|<p:pic><p:nvPicPr><p:cNvPr id="2" name="Photo" descr="A captioned photo"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr><p:blipFill><a:blip r:embed="rId2" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/></p:blipFill><p:spPr><a:xfrm><a:off x="914400" y="914400"/><a:ext cx="914400" cy="914400"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr></p:pic>
  let slide = pptx_test_slide_prefix + shapes + pptx_test_slide_suffix
  let result = convert(
    pptx_figure_pic_deck(slide, ("ppt/media/image1.png", image)),
  )
  let commands = pptx_figure_body_commands(result)
  assert_eq(pptx_figure_marks(commands), [
    ("figure", "A captioned photo"),
    ("end", ""),
  ])
  let mut mark = -1
  let mut image_at = -1
  let mut end = -1
  for index, command in commands {
    match command {
      @render.Mark(kind, _) =>
        if kind == @core.MARK_FIGURE.to_int() {
          mark = index
        } else if kind == @core.MARK_END.to_int() {
          end = index
        }
      @render.Image(_, _, _, _, _) => if image_at < 0 { image_at = index }
      _ => ()
    }
  }
  assert_true(mark >= 0 && image_at > mark, msg="the picture draws inside")
  assert_true(end > image_at, msg="the figure closes after the picture")
}

///|
test "PPTX tables stay outside every FIGURE" {
  let frame =
    #|<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id="2" name="Table" descr="The table of results"/><p:cNvGraphicFramePr/><p:nvPr/></p:nvGraphicFramePr><p:xfrm><a:off x="914400" y="457200"/><a:ext cx="4572000" cy="914400"/></p:xfrm><p:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/table"><a:tbl><a:tblPr firstRow="1"/><a:tblGrid><a:gridCol w="2286000"/><a:gridCol w="2286000"/></a:tblGrid><a:tr h="457200"><a:tc><a:txBody><a:bodyPr/><a:p><a:r><a:rPr sz="1800"/><a:t>Left</a:t></a:r></a:p></a:txBody><a:tcPr/></a:tc><a:tc><a:txBody><a:bodyPr/><a:p><a:r><a:rPr sz="1800"/><a:t>Right</a:t></a:r></a:p></a:txBody><a:tcPr/></a:tc></a:tr></a:tbl></a:graphicData></p:graphic></p:graphicFrame>
  let slide = pptx_test_slide_prefix + frame + pptx_test_slide_suffix
  let result = convert(pptx_test_deck(slide, []))
  let commands = pptx_figure_body_commands(result)
  assert_eq(pptx_figure_marks(commands), [])
  let mut text = false
  for command in commands {
    match command {
      @render.FillText(value, _, _, _) => if value == "Left" { text = true }
      _ => ()
    }
  }
  assert_true(text, msg="the table keeps its cells as text")
}

///|
/// A graphic frame with a cNvPr description wrapping the given graphicData.
fn pptx_figure_frame(cnvpr : String, graphic_data : String) -> String {
  "<p:graphicFrame><p:nvGraphicFramePr>" +
  cnvpr +
  "<p:cNvGraphicFramePr/><p:nvPr/></p:nvGraphicFramePr><p:xfrm><a:off x=\"914400\" y=\"457200\"/><a:ext cx=\"4572000\" cy=\"914400\"/></p:xfrm><p:graphic>" +
  graphic_data +
  "</p:graphic></p:graphicFrame>"
}

///|
/// The graphicData of a one-row, one-cell table whose cell text is value.
fn pptx_figure_table_data(value : String) -> String {
  let cell = if value != "" {
    "<a:txBody><a:bodyPr/><a:p><a:r><a:rPr sz=\"1800\"/><a:t>" +
    value +
    "</a:t></a:r></a:p></a:txBody>"
  } else {
    "<a:txBody><a:bodyPr/><a:p/></a:txBody>"
  }
  "<a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/table\"><a:tbl><a:tblPr/><a:tblGrid><a:gridCol w=\"4572000\"/></a:tblGrid><a:tr h=\"914400\"><a:tc>" +
  cell +
  "</a:tc></a:tr></a:tbl></a:graphicData>"
}

///|
test "PPTX empty single-cell tables stay outside every FIGURE" {
  // Upstream drawFrame tells a table by its tbl element, not by its text,
  // so a frame whose only cell is empty or whitespace-only is still a
  // table and its alternative text never opens a FIGURE.
  let empty_frame = pptx_figure_frame(
    "<p:cNvPr id=\"2\" name=\"Empty\" descr=\"An empty table\"/>",
    pptx_figure_table_data(""),
  )
  let blank_frame = pptx_figure_frame(
    "<p:cNvPr id=\"3\" name=\"Blank\" descr=\"A blank table\"/>",
    pptx_figure_table_data(" \t "),
  )
  let text_frame = pptx_figure_frame(
    "<p:cNvPr id=\"4\" name=\"Cell\" descr=\"A one-cell table\"/>",
    pptx_figure_table_data("Only cell"),
  )
  let slide = pptx_test_slide_prefix +
    empty_frame +
    blank_frame +
    text_frame +
    pptx_test_slide_suffix
  let result = convert(pptx_test_deck(slide, []))
  let commands = pptx_figure_body_commands(result)
  assert_eq(pptx_figure_marks(commands), [])
  // The filled single-cell table keeps its cell as text.
  let mut text = false
  for command in commands {
    match command {
      @render.FillText(value, _, _, _) => if value == "Only cell" {
        text = true
      }
      _ => ()
    }
  }
  assert_true(text, msg="the one-cell table keeps its cell as text")
  // Detection is structural: a tbl child is a table, anything else is not.
  let namespaces = " xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\""
  let table_frame = pptx_parse_xml(
    "<p:graphicFrame" +
    namespaces +
    "><p:graphic><a:graphicData xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/table\"><a:tbl/></a:graphicData></p:graphic></p:graphicFrame>",
  )
  assert_true(pptx_frame_table(table_frame) is Some(_))
  let chart_frame = pptx_parse_xml(
    "<p:graphicFrame" +
    namespaces +
    "><p:graphic><a:graphicData xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/chart\"/></p:graphic></p:graphicFrame>",
  )
  assert_true(pptx_frame_table(chart_frame) is None)
}

///|
test "PPTX non-table graphic frames draw inside a FIGURE" {
  // A frame that holds no tbl - a chart, an OLE object or any other
  // embedding - draws inside a FIGURE of the frame's alternative text,
  // as upstream drawFrame wraps every non-table embedding.
  let chart_frame = pptx_figure_frame(
    "<p:cNvPr id=\"2\" name=\"Chart\" descr=\"The embedded chart\"/>",
    "<a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/chart\"/>",
  )
  let ole_frame = pptx_figure_frame(
    "<p:cNvPr id=\"3\" name=\"Object\" descr=\"An embedded object\"/>",
    "<a:graphicData uri=\"http://schemas.openxmlformats.org/presentationml/2006/ole\"/>",
  )
  // A frame without alternative text keeps its bare rendering.
  let bare_frame = pptx_figure_frame(
    "<p:cNvPr id=\"4\" name=\"Bare\"/>",
    "<a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/chart\"/>",
  )
  let slide = pptx_test_slide_prefix +
    chart_frame +
    ole_frame +
    bare_frame +
    pptx_test_slide_suffix
  let result = convert(pptx_test_deck(slide, []))
  let commands = pptx_figure_body_commands(result)
  assert_eq(pptx_figure_marks(commands), [
    ("figure", "The embedded chart"),
    ("end", ""),
    ("figure", "An embedded object"),
    ("end", ""),
  ])
}

///|
/// A group with a cNvPr description around the given children.
fn pptx_figure_group(cnvpr : String, children : String) -> String {
  "<p:grpSp><p:nvGrpSpPr>" +
  cnvpr +
  "<p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x=\"457200\" y=\"457200\"/><a:ext cx=\"4572000\" cy=\"2743200\"/><a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"4572000\" cy=\"2743200\"/></a:xfrm></p:grpSpPr>" +
  children +
  "</p:grpSp>"
}

///|
test "PPTX connector alt text wraps its visible line in a FIGURE" {
  // A connector draws like a shape: its alternative text opens a FIGURE
  // around the stroke itself, before the figure closes.
  let connector =
    #|<p:cxnSp><p:nvCxnSpPr><p:cNvPr id="2" name="Lead" descr="A leading line"/><p:cNvCxnSpPr/><p:nvPr/></p:nvCxnSpPr><p:spPr><a:xfrm><a:off x="457200" y="2286000"/><a:ext cx="2743200" cy="0"/></a:xfrm><a:prstGeom prst="line"><a:avLst/></a:prstGeom><a:ln w="12700"><a:solidFill><a:srgbClr val="000080"/></a:solidFill></a:ln></p:spPr></p:cxnSp>
  let slide = pptx_test_slide_prefix + connector + pptx_test_slide_suffix
  let result = convert(pptx_test_deck(slide, []))
  let commands = pptx_figure_body_commands(result)
  assert_eq(pptx_figure_marks(commands), [
    ("figure", "A leading line"),
    ("end", ""),
  ])
  let mut figure = -1
  let mut stroke = -1
  let mut end = -1
  for index, command in commands {
    match command {
      @render.Mark(kind, _) =>
        if kind == @core.MARK_FIGURE.to_int() {
          figure = index
        } else if kind == @core.MARK_END.to_int() {
          end = index
        }
      @render.StrokePath(_) => if stroke < 0 { stroke = index }
      @render.FillText(_, _, _, _) => fail("the line connector draws no text")
      _ => ()
    }
  }
  assert_true(figure >= 0 && stroke > figure, msg="the line strokes inside")
  assert_true(end > stroke, msg="the figure closes after the stroke")
}

///|
test "PPTX hidden and decorative groups keep their children unmarked" {
  // A hidden group never draws, and a group marked decorative draws its
  // children without any FIGURE, group alt text or not.
  let child = pptx_figure_box("<p:cNvPr id=\"3\" name=\"Child\"/>", "")
  let hidden_group = pptx_figure_group(
    "<p:cNvPr id=\"2\" name=\"Hidden group\" descr=\"A hidden group\" hidden=\"1\"/>",
    child,
  )
  let decorative_group = pptx_figure_group(
    "<p:cNvPr id=\"4\" name=\"Deco group\" descr=\"A decorative group\"><a:extLst><a:ext uri=\"http://schemas.microsoft.com/office/drawing/2017/decorative\"><adec:decorative xmlns:adec=\"http://schemas.microsoft.com/office/drawing/2017/decorative\" val=\"1\"/></a:ext></a:extLst></p:cNvPr>",
    child,
  )
  let slide = pptx_test_slide_prefix +
    hidden_group +
    decorative_group +
    pptx_test_slide_suffix
  let result = convert(pptx_test_deck(slide, []))
  let commands = pptx_figure_body_commands(result)
  assert_eq(pptx_figure_marks(commands), [])
  // Both boxes fill red: exactly one may draw, from the decorative group.
  let mut red = 0
  for command in commands {
    match command {
      @render.FillColor(0xff0000ff) => red += 1
      _ => ()
    }
  }
  assert_eq(red, 1, msg="only the decorative group draws its child")
}

///|
test "PPTX nested group FIGURE holds a table and a marked shape" {
  // A group's FIGURE wraps an inner table, which keeps its own structure
  // without any mark, and an inner marked shape whose FIGURE is nested.
  let table = pptx_figure_frame(
    "<p:cNvPr id=\"3\" name=\"Inner table\" descr=\"The inner table\"/>",
    pptx_figure_table_data("Only cell"),
  )
  let marked_box = pptx_figure_box(
    "<p:cNvPr id=\"5\" name=\"Marked\" descr=\"The marked box\"/>",
    "",
  )
  let group = pptx_figure_group(
    "<p:cNvPr id=\"2\" name=\"Set\" descr=\"The framed set\"/>",
    table + marked_box,
  )
  let slide = pptx_test_slide_prefix + group + pptx_test_slide_suffix
  let result = convert(pptx_test_deck(slide, []))
  let commands = pptx_figure_body_commands(result)
  assert_eq(pptx_figure_marks(commands), [
    ("figure", "The framed set"),
    ("figure", "The marked box"),
    ("end", ""),
    ("end", ""),
  ])
  // The table cell text stays inside the group FIGURE without a mark,
  // before the nested shape's FIGURE opens.
  let mut group_figure = -1
  let mut table_text = -1
  let mut box_figure = -1
  let mut box_end = -1
  let mut group_end = -1
  for index, command in commands {
    match command {
      @render.Mark(kind, _) =>
        if kind == @core.MARK_FIGURE.to_int() {
          if group_figure < 0 {
            group_figure = index
          } else if box_figure < 0 {
            box_figure = index
          }
        } else if kind == @core.MARK_END.to_int() {
          if box_end < 0 {
            box_end = index
          } else {
            group_end = index
          }
        }
      @render.FillText(value, _, _, _) =>
        if value == "Only cell" && table_text < 0 {
          table_text = index
        }
      _ => ()
    }
  }
  assert_true(
    group_figure < table_text &&
      table_text < box_figure &&
      box_figure < box_end &&
      box_end < group_end,
    msg="the nested marks and the unmarked table keep their order",
  )
}
