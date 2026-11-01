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
