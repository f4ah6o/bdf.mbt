///|
test "drawio converts a minimal diagram" {
  let data = @utf8.encode(
    "<mxfile><diagram name=\"T\"><mxGraphModel pageWidth=\"200\" pageHeight=\"100\"><root>" +
    "<mxCell id=\"0\"/><mxCell id=\"1\" parent=\"0\"/>" +
    "<mxCell id=\"a\" value=\"Hello\" style=\"rounded=1;fillColor=#fff2cc;\" vertex=\"1\" parent=\"1\">" +
    "<mxGeometry x=\"10\" y=\"10\" width=\"80\" height=\"30\" as=\"geometry\"/></mxCell>" +
    "</root></mxGraphModel></diagram></mxfile>",
  )
  assert_true(detect(data))
  let result = convert(data) catch {
    DrawioInvalid(message) => fail("draw.io fixture did not convert: " + message)
  }
  assert_eq(result.pages, 1)
  let document = @core.open_single(result.bdf) catch {
    _ => fail("draw.io BDF did not open")
  }
  assert_eq(document.manifest.views[0].pages.length(), 1)
}

///|
test "drawio reads every diagram and compressed pages" {
  let data = @utf8.encode(
    "<mxfile><diagram id=\"a\" name=\"A\"><mxGraphModel><root><mxCell id=\"0\"/><mxCell id=\"1\" parent=\"0\"/><mxCell id=\"x\" value=\"A\" vertex=\"1\" parent=\"1\"><mxGeometry x=\"0\" y=\"0\" width=\"10\" height=\"10\"/></mxCell></root></mxGraphModel></diagram>" +
    "<diagram id=\"b\" name=\"B\"><mxGraphModel><root><mxCell id=\"0\"/><mxCell id=\"1\" parent=\"0\"/><mxCell id=\"y\" value=\"B\" vertex=\"1\" parent=\"1\"><mxGeometry x=\"0\" y=\"0\" width=\"10\" height=\"10\"/></mxCell></root></mxGraphModel></diagram></mxfile>",
  )
  let pages = drawio_read_file(data) catch { _ => fail("drawio pages failed") }
  assert_eq(pages.length(), 2)
  assert_eq(pages[0].name, "A")
  assert_eq(pages[1].name, "B")
}

///|
test "drawio percent decoding" {
  assert_eq(drawio_percent_decode("%3Cmxfile%3E"), "<mxfile>")
}

///|
test "drawio rich labels keep HTML runs" {
  let lines = drawio_rich_lines(
    "<b>Bold</b> <font color=\"#ff0000\">red</font><br>next",
    12.0,
    0x000000ffU,
  )
  assert_eq(lines.length(), 2)
  assert_eq(lines[0][0].style.bold, true)
  assert_eq(drawio_color("#ff0000", 0x000000ffU), 0xff0000ffU)
  let red = drawio_rich_lines("<font color=\"#ff0000\">red</font>", 12.0, 0x000000ffU)
  assert_eq(red[0][0].style.color, 0xff0000ffU)
}
