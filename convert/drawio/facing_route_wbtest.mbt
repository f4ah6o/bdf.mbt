///|
test "facing orthogonal routes and unchanged fallback cases" {
  let xml = @utf8.decode_lossy(@utf8.encode(
    "<mxGraphModel><root><mxCell id=\"0\"/><mxCell id=\"1\" parent=\"0\"/>" +
    "<mxCell id=\"a\" style=\"rounded=0;\" vertex=\"1\" parent=\"1\"><mxGeometry x=\"0\" y=\"0\" width=\"100\" height=\"50\" as=\"geometry\"/></mxCell>" +
    "<mxCell id=\"b\" style=\"BSTYLE\" vertex=\"1\" parent=\"1\"><mxGeometry x=\"XY\" y=\"YY\" width=\"100\" height=\"50\" as=\"geometry\"/></mxCell>" +
    "<mxCell id=\"e\" style=\"ESTYLE\" edge=\"1\" parent=\"1\" source=\"SRC\" target=\"TGT\">GEO</mxCell>" +
    "</root></mxGraphModel>",
  ))
  let build = fn(x : String, y : String, bstyle : String, estyle : String, geo : String, src : String, tgt : String) -> Array[(Double, Double)] raise {
    let filled = xml.replace(old="XY", new=x).replace(old="YY", new=y)
      .replace(old="BSTYLE", new=bstyle)
      .replace(old="ESTYLE", new=estyle)
      .replace(old="SRC", new=src)
      .replace(old="TGT", new=tgt)
      .replace(old="GEO", new=geo)
    let root = drawio_parse(@utf8.decode_lossy(@utf8.encode(filled))) catch {
      _ => fail("fixture did not parse")
    }
    let model = drawio_model(root)
    match model.cell("e") {
      Some(edge) => model.edge_route(edge, DrawioWarn::new())
      None => fail("missing edge")
    }
  }
  let rect = "rounded=0;"
  let zero = "<mxGeometry relative=\"1\" as=\"geometry\"/>"
  let waypoint = "<mxGeometry relative=\"1\" as=\"geometry\"><Array as=\"points\"><mxPoint x=\"125\" y=\"60\"/></Array></mxGeometry>"
  assert_eq(build("115", "10", rect, "edgeStyle=orthogonalEdgeStyle;", zero, "a", "b"), [(100, 29.34782608695652), (115, 29.34782608695652), (115, 30.652173913043477)])
  assert_eq(build("150", "10", rect, "edgeStyle=orthogonalEdgeStyle;", zero, "a", "b"), [(100, 25), (125, 25), (125, 35), (150, 35)])
  assert_eq(build("150", "10", rect, "edgeStyle=orthogonalEdgeStyle;jettySize=30;", zero, "a", "b"), [(100, 28.333333333333336), (150, 28.333333333333336), (150, 31.666666666666668)])
  assert_eq(build("150", "10", rect, "edgeStyle=orthogonalEdgeStyle;jettySize=10;", zero, "a", "b"), [(100, 25), (125, 25), (125, 35), (150, 35)])
  assert_eq(build("150", "10", rect, "edgeStyle=orthogonalEdgeStyle;sourceJettySize=auto;", zero, "a", "b"), [(100, 28.333333333333336), (150, 28.333333333333336), (150, 31.666666666666668)])
  assert_eq(build("150", "10", rect + "rotation=45;", "edgeStyle=orthogonalEdgeStyle;", zero, "a", "b"), [(100, 28.333333333333336), (150, 28.333333333333336), (150, 31.666666666666668)])
  assert_eq(build("150", "100", rect, "edgeStyle=orthogonalEdgeStyle;", zero, "a", "b"), [(87.5, 50), (162.5, 50), (162.5, 100)])
  assert_eq(build("50", "10", rect, "edgeStyle=orthogonalEdgeStyle;", zero, "a", "b"), [(50, 25)])
  assert_eq(build("150", "10", rect, "edgeStyle=orthogonalEdgeStyle;", waypoint, "a", "b"), [(100, 48.33333333333333), (125, 48.33333333333333), (125, 60), (125, 51.666666666666664), (150, 51.666666666666664)])
  assert_eq(build("150", "10", rect, "edgeStyle=orthogonalEdgeStyle;exitX=1;exitY=0.5;entryX=0;entryY=0.5;", zero, "a", "b"), [(100, 25), (150, 25), (150, 35)])
  assert_eq(build("150", "10", rect, "edgeStyle=orthogonalEdgeStyle;sourcePortConstraint=north;", zero, "a", "b"), [(100, 28.333333333333336), (150, 28.333333333333336), (150, 31.666666666666668)])
  assert_eq(build("150", "10", rect + "portConstraint=north;", "edgeStyle=orthogonalEdgeStyle;", zero, "a", "b"), [(100, 28.333333333333336), (150, 28.333333333333336), (150, 31.666666666666668)])
  assert_eq(build("150", "10", rect, "edgeStyle=orthogonalEdgeStyle;", zero, "b", "a"), [(150, 35), (125, 35), (125, 25), (100, 25)])
  assert_eq(build("150", "10", rect + "perimeter=0;", "edgeStyle=orthogonalEdgeStyle;", zero, "a", "b"), [(100, 28.333333333333336), (150, 28.333333333333336), (150, 31.666666666666668)])
}
