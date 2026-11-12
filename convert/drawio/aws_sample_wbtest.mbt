///|
/// The Pages AWS sample is byte-identical to the upstream fixture
/// (converter/drawio/testdata/aws.drawio at shibukawa/bdf a5e4d7a6,
/// same md5); this test holds the same input compacted, so any conversion
/// difference is a converter difference, not a data difference. It goes
/// through the same convert path the site uses: the aws3 icons must be
/// rewritten to their current aws4 counterparts (the informational
/// aws-legacy warning must appear) and every aws4 shape must resolve to
/// real stencil geometry (no "not supported" / "has no current AWS
/// counterpart" fallback warnings).
test "drawio aws pages sample: stencil geometry and group labels clear the icons" {
  let data = @utf8.encode(
    "<mxfile host=\"bdf-test\" modified=\"2026-09-26T05:00:00.000Z\"><diagram id=" +
    "\"current\" name=\"Current icons\"><mxGraphModel dx=\"800\" dy=\"600\" grid=\"1\" " +
    "gridSize=\"10\" page=\"1\" pageScale=\"1\" pageWidth=\"827\" pageHeight=\"1169\"><" +
    "root><mxCell id=\"0\" /><mxCell id=\"1\" parent=\"0\" /><mxCell id=\"cloud\" val" +
    "ue=\"AWS Cloud\" style=\"shape=mxgraph.aws4.group;grIcon=mxgraph.aws4.group" +
    "_aws_cloud_alt;strokeColor=#232F3E;fillColor=none;fontColor=#232F3E;dash" +
    "ed=0;fontSize=12;fontStyle=0;container=1;collapsible=0;recursiveResize=0" +
    ";pointerEvents=0;verticalAlign=top;align=left;spacingLeft=30;html=1;whit" +
    "eSpace=wrap;\" vertex=\"1\" parent=\"1\"><mxGeometry x=\"120\" y=\"20\" width=\"46" +
    "0\" height=\"260\" as=\"geometry\" /></mxCell><mxCell id=\"region\" value=\"Regi" +
    "on\" style=\"shape=mxgraph.aws4.group;grIcon=mxgraph.aws4.group_region;str" +
    "okeColor=#00A4A6;fillColor=none;fontColor=#147EBA;dashed=1;fontSize=12;f" +
    "ontStyle=0;container=1;collapsible=0;recursiveResize=0;pointerEvents=0;v" +
    "erticalAlign=top;align=left;spacingLeft=30;html=1;whiteSpace=wrap;\" vert" +
    "ex=\"1\" parent=\"cloud\"><mxGeometry x=\"20\" y=\"40\" width=\"420\" height=\"200\"" +
    " as=\"geometry\" /></mxCell><mxCell id=\"user\" value=\"Users\" style=\"outline" +
    "Connect=0;fontColor=#232F3E;strokeColor=#ffffff;dashed=0;verticalLabelPo" +
    "sition=bottom;verticalAlign=top;align=center;html=1;fontSize=12;fontStyl" +
    "e=0;aspect=fixed;shape=mxgraph.aws4.users;fillColor=#232F3E;strokeColor=" +
    "none;\" vertex=\"1\" parent=\"1\"><mxGeometry x=\"20\" y=\"120\" width=\"60\" heigh" +
    "t=\"60\" as=\"geometry\" /></mxCell><mxCell id=\"api\" value=\"API Gateway\" sty" +
    "le=\"outlineConnect=0;fontColor=#232F3E;strokeColor=#ffffff;dashed=0;vert" +
    "icalLabelPosition=bottom;verticalAlign=top;align=center;html=1;fontSize=" +
    "12;fontStyle=0;aspect=fixed;shape=mxgraph.aws4.resourceIcon;resIcon=mxgr" +
    "aph.aws4.api_gateway;fillColor=#E7157B;\" vertex=\"1\" parent=\"region\"><mxG" +
    "eometry x=\"40\" y=\"70\" width=\"60\" height=\"60\" as=\"geometry\" /></mxCell><m" +
    "xCell id=\"fn\" value=\"Lambda\" style=\"outlineConnect=0;fontColor=#232F3E;s" +
    "trokeColor=#ffffff;dashed=0;verticalLabelPosition=bottom;verticalAlign=t" +
    "op;align=center;html=1;fontSize=12;fontStyle=0;aspect=fixed;shape=mxgrap" +
    "h.aws4.resourceIcon;resIcon=mxgraph.aws4.lambda;fillColor=#ED7100;\" vert" +
    "ex=\"1\" parent=\"region\"><mxGeometry x=\"180\" y=\"70\" width=\"60\" height=\"60\"" +
    " as=\"geometry\" /></mxCell><mxCell id=\"db\" value=\"DynamoDB\" style=\"outlin" +
    "eConnect=0;fontColor=#232F3E;strokeColor=#ffffff;dashed=0;verticalLabelP" +
    "osition=bottom;verticalAlign=top;align=center;html=1;fontSize=12;fontSty" +
    "le=0;aspect=fixed;shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.d" +
    "ynamodb;fillColor=#C925D1;\" vertex=\"1\" parent=\"region\"><mxGeometry x=\"32" +
    "0\" y=\"20\" width=\"60\" height=\"60\" as=\"geometry\" /></mxCell><mxCell id=\"s3" +
    "\" value=\"S3\" style=\"outlineConnect=0;fontColor=#232F3E;strokeColor=#ffff" +
    "ff;dashed=0;verticalLabelPosition=bottom;verticalAlign=top;align=center;" +
    "html=1;fontSize=12;fontStyle=0;aspect=fixed;shape=mxgraph.aws4.resourceI" +
    "con;resIcon=mxgraph.aws4.s3;fillColor=#7AA116;\" vertex=\"1\" parent=\"regio" +
    "n\"><mxGeometry x=\"320\" y=\"110\" width=\"60\" height=\"60\" as=\"geometry\" /></" +
    "mxCell><mxCell id=\"e1\" style=\"edgeStyle=orthogonalEdgeStyle;html=1;endAr" +
    "row=open;endSize=10;strokeColor=#545B64;\" edge=\"1\" parent=\"1\" source=\"us" +
    "er\" target=\"api\"><mxGeometry relative=\"1\" as=\"geometry\" /></mxCell><mxCe" +
    "ll id=\"e2\" style=\"edgeStyle=orthogonalEdgeStyle;html=1;endArrow=open;end" +
    "Size=10;strokeColor=#545B64;\" edge=\"1\" parent=\"region\" source=\"api\" targ" +
    "et=\"fn\"><mxGeometry relative=\"1\" as=\"geometry\" /></mxCell><mxCell id=\"e3" +
    "\" style=\"edgeStyle=orthogonalEdgeStyle;html=1;endArrow=open;endSize=10;s" +
    "trokeColor=#545B64;\" edge=\"1\" parent=\"region\" source=\"fn\" target=\"db\"><m" +
    "xGeometry relative=\"1\" as=\"geometry\" /></mxCell><mxCell id=\"e4\" style=\"e" +
    "dgeStyle=orthogonalEdgeStyle;html=1;endArrow=open;endSize=10;strokeColor" +
    "=#545B64;\" edge=\"1\" parent=\"region\" source=\"fn\" target=\"s3\"><mxGeometry " +
    "relative=\"1\" as=\"geometry\" /></mxCell></root></mxGraphModel></diagram><d" +
    "iagram id=\"legacy\" name=\"Legacy icons (AWS17)\"><mxGraphModel dx=\"1200\" d" +
    "y=\"800\" grid=\"1\" gridSize=\"10\" guides=\"1\" tooltips=\"1\" connect=\"1\" arrow" +
    "s=\"1\" fold=\"1\" page=\"1\" pageScale=\"1\" pageWidth=\"1169\" pageHeight=\"827\" " +
    "math=\"0\" shadow=\"0\"><root><mxCell id=\"0\"/><mxCell id=\"1\" parent=\"0\"/><mx" +
    "Cell id=\"cloud\" value=\"\" style=\"rounded=1;arcSize=10;dashed=0;fillColor=" +
    "none;gradientColor=none;strokeWidth=2;\" vertex=\"1\" parent=\"1\"><mxGeometr" +
    "y x=\"140\" y=\"40\" width=\"920\" height=\"620\" as=\"geometry\"/></mxCell><mxCel" +
    "l id=\"cloudIcon\" value=\"\" style=\"dashed=0;html=1;shape=mxgraph.aws3.clou" +
    "d;fillColor=#F58536;gradientColor=none;dashed=0;\" vertex=\"1\" parent=\"1\">" +
    "<mxGeometry x=\"160\" y=\"22\" width=\"52\" height=\"36\" as=\"geometry\"/></mxCel" +
    "l><mxCell id=\"vpc\" value=\"\" style=\"rounded=1;arcSize=10;dashed=0;fillCol" +
    "or=none;gradientColor=none;strokeWidth=2;\" vertex=\"1\" parent=\"1\"><mxGeom" +
    "etry x=\"400\" y=\"100\" width=\"510\" height=\"530\" as=\"geometry\"/></mxCell><m" +
    "xCell id=\"vpcIcon\" value=\"\" style=\"dashed=0;html=1;shape=mxgraph.aws3.vi" +
    "rtual_private_cloud;fillColor=#F58536;gradientColor=none;dashed=0;\" vert" +
    "ex=\"1\" parent=\"1\"><mxGeometry x=\"420\" y=\"82\" width=\"52\" height=\"36\" as=\"" +
    "geometry\"/></mxCell><mxCell id=\"azA\" value=\"Availability Zone A\" style=\"" +
    "rounded=1;arcSize=10;dashed=1;strokeColor=#F59D56;fillColor=none;gradien" +
    "tColor=none;dashPattern=8 4;strokeWidth=2;verticalAlign=top;html=1;\" ver" +
    "tex=\"1\" parent=\"1\"><mxGeometry x=\"430\" y=\"260\" width=\"220\" height=\"350\" " +
    "as=\"geometry\"/></mxCell><mxCell id=\"azB\" value=\"Availability Zone B\" sty" +
    "le=\"rounded=1;arcSize=10;dashed=1;strokeColor=#F59D56;fillColor=none;gra" +
    "dientColor=none;dashPattern=8 4;strokeWidth=2;verticalAlign=top;html=1;\"" +
    " vertex=\"1\" parent=\"1\"><mxGeometry x=\"670\" y=\"260\" width=\"220\" height=\"3" +
    "50\" as=\"geometry\"/></mxCell><mxCell id=\"asg\" value=\"\" style=\"rounded=1;a" +
    "rcSize=10;dashed=1;fillColor=none;gradientColor=none;dashPattern=8 3 1 3" +
    ";strokeWidth=2;\" vertex=\"1\" parent=\"1\"><mxGeometry x=\"470\" y=\"290\" width" +
    "=\"380\" height=\"130\" as=\"geometry\"/></mxCell><mxCell id=\"users\" value=\"Us" +
    "ers\" style=\"outlineConnect=0;dashed=0;verticalLabelPosition=bottom;verti" +
    "calAlign=top;align=center;html=1;shape=mxgraph.aws3.users;fillColor=#D2D" +
    "3D3;gradientColor=none;\" vertex=\"1\" parent=\"1\"><mxGeometry x=\"20\" y=\"300" +
    "\" width=\"66\" height=\"63\" as=\"geometry\"/></mxCell><mxCell id=\"r53\" value=" +
    "\"Route 53\" style=\"outlineConnect=0;dashed=0;verticalLabelPosition=bottom" +
    ";verticalAlign=top;align=center;html=1;shape=mxgraph.aws3.route_53;fillC" +
    "olor=#F58536;gradientColor=none;\" vertex=\"1\" parent=\"1\"><mxGeometry x=\"1" +
    "90\" y=\"100\" width=\"70.5\" height=\"85.5\" as=\"geometry\"/></mxCell><mxCell i" +
    "d=\"cf\" value=\"CloudFront\" style=\"outlineConnect=0;dashed=0;verticalLabel" +
    "Position=bottom;verticalAlign=top;align=center;html=1;shape=mxgraph.aws3" +
    ".cloudfront;fillColor=#F58536;gradientColor=none;\" vertex=\"1\" parent=\"1\"" +
    "><mxGeometry x=\"187\" y=\"285\" width=\"76.5\" height=\"93\" as=\"geometry\"/></m" +
    "xCell><mxCell id=\"s3\" value=\"S3\" style=\"outlineConnect=0;dashed=0;vertic" +
    "alLabelPosition=bottom;verticalAlign=top;align=center;html=1;shape=mxgra" +
    "ph.aws3.s3;fillColor=#E05243;gradientColor=none;\" vertex=\"1\" parent=\"1\">" +
    "<mxGeometry x=\"187\" y=\"480\" width=\"76.5\" height=\"93\" as=\"geometry\"/></mx" +
    "Cell><mxCell id=\"s3note\" value=\"static assets\" style=\"text;html=1;align=" +
    "left;verticalAlign=middle;fontSize=10;fontColor=#666666;\" vertex=\"1\" par" +
    "ent=\"s3\"><mxGeometry x=\"84\" y=\"36\" width=\"80\" height=\"20\" as=\"geometry\"/" +
    "></mxCell><mxCell id=\"elb\" value=\"Elastic Load Balancing\" style=\"outline" +
    "Connect=0;dashed=0;verticalLabelPosition=bottom;verticalAlign=top;align=" +
    "center;html=1;shape=mxgraph.aws3.elastic_load_balancing;fillColor=#F5853" +
    "4;gradientColor=none;\" vertex=\"1\" parent=\"1\"><mxGeometry x=\"622\" y=\"120\"" +
    " width=\"76.5\" height=\"93\" as=\"geometry\"/></mxCell><mxCell id=\"web1\" valu" +
    "e=\"Web server\" style=\"outlineConnect=0;dashed=0;verticalLabelPosition=bo" +
    "ttom;verticalAlign=top;align=center;html=1;shape=mxgraph.aws3.instance;f" +
    "illColor=#F58534;gradientColor=none;\" vertex=\"1\" parent=\"1\"><mxGeometry " +
    "x=\"510\" y=\"315\" width=\"60\" height=\"63\" as=\"geometry\"/></mxCell><mxCell i" +
    "d=\"web2\" value=\"Web server\" style=\"outlineConnect=0;dashed=0;verticalLab" +
    "elPosition=bottom;verticalAlign=top;align=center;html=1;shape=mxgraph.aw" +
    "s3.instance;fillColor=#F58534;gradientColor=none;\" vertex=\"1\" parent=\"1\"" +
    "><mxGeometry x=\"750\" y=\"315\" width=\"60\" height=\"63\" as=\"geometry\"/></mxC" +
    "ell><mxCell id=\"db1\" value=\"RDS (primary)\" style=\"outlineConnect=0;dashe" +
    "d=0;verticalLabelPosition=bottom;verticalAlign=top;align=center;html=1;s" +
    "hape=mxgraph.aws3.rds_db_instance;fillColor=#2E73B8;gradientColor=none;\"" +
    " vertex=\"1\" parent=\"1\"><mxGeometry x=\"515\" y=\"490\" width=\"49.5\" height=\"" +
    "66\" as=\"geometry\"/></mxCell><mxCell id=\"db2\" value=\"RDS (standby)\" style" +
    "=\"outlineConnect=0;dashed=0;verticalLabelPosition=bottom;verticalAlign=t" +
    "op;align=center;html=1;shape=mxgraph.aws3.rds_db_instance_standby_multi_" +
    "az;fillColor=#2E73B8;gradientColor=none;\" vertex=\"1\" parent=\"1\"><mxGeome" +
    "try x=\"755\" y=\"490\" width=\"49.5\" height=\"66\" as=\"geometry\"/></mxCell><mx" +
    "Cell id=\"cache\" value=\"ElastiCache\" style=\"outlineConnect=0;dashed=0;ver" +
    "ticalLabelPosition=bottom;verticalAlign=top;align=center;html=1;shape=mx" +
    "graph.aws3.elasticache;fillColor=#2E73B8;gradientColor=none;fontColor=#1" +
    "A4C80;fontStyle=1;\" vertex=\"1\" parent=\"1\"><mxGeometry x=\"946\" y=\"440\" wi" +
    "dth=\"67.5\" height=\"81\" as=\"geometry\"/></mxCell><mxCell id=\"cw\" value=\"Cl" +
    "oudWatch\" style=\"outlineConnect=0;dashed=0;verticalLabelPosition=bottom;" +
    "verticalAlign=top;align=center;html=1;shape=mxgraph.aws3.cloudwatch;fill" +
    "Color=#759C3E;gradientColor=none;\" vertex=\"1\" parent=\"1\"><mxGeometry x=\"" +
    "939\" y=\"120\" width=\"82.5\" height=\"93\" as=\"geometry\"/></mxCell><mxCell id" +
    "=\"e1\" style=\"edgeStyle=orthogonalEdgeStyle;html=1;endArrow=block;endFill" +
    "=1;\" edge=\"1\" parent=\"1\" source=\"users\" target=\"r53\"><mxGeometry relativ" +
    "e=\"1\" as=\"geometry\"/></mxCell><mxCell id=\"e2\" value=\"HTTPS\" style=\"edgeS" +
    "tyle=orthogonalEdgeStyle;html=1;endArrow=block;endFill=1;\" edge=\"1\" pare" +
    "nt=\"1\" source=\"users\" target=\"cf\"><mxGeometry relative=\"1\" as=\"geometry\"" +
    "/></mxCell><mxCell id=\"e3\" style=\"edgeStyle=orthogonalEdgeStyle;html=1;e" +
    "ndArrow=block;endFill=1;\" edge=\"1\" parent=\"1\" source=\"cf\" target=\"s3\"><m" +
    "xGeometry relative=\"1\" as=\"geometry\"/></mxCell><mxCell id=\"e4\" style=\"ed" +
    "geStyle=orthogonalEdgeStyle;html=1;endArrow=block;endFill=1;\" edge=\"1\" p" +
    "arent=\"1\" source=\"cf\" target=\"elb\"><mxGeometry relative=\"1\" as=\"geometry" +
    "\"/></mxCell><mxCell id=\"e5\" style=\"edgeStyle=orthogonalEdgeStyle;html=1;" +
    "endArrow=block;endFill=1;\" edge=\"1\" parent=\"1\" source=\"elb\" target=\"web1" +
    "\"><mxGeometry relative=\"1\" as=\"geometry\"/></mxCell><mxCell id=\"e6\" style" +
    "=\"edgeStyle=orthogonalEdgeStyle;html=1;endArrow=block;endFill=1;\" edge=\"" +
    "1\" parent=\"1\" source=\"elb\" target=\"web2\"><mxGeometry relative=\"1\" as=\"ge" +
    "ometry\"/></mxCell><mxCell id=\"e7\" style=\"edgeStyle=orthogonalEdgeStyle;h" +
    "tml=1;endArrow=block;endFill=1;\" edge=\"1\" parent=\"1\" source=\"web1\" targe" +
    "t=\"db1\"><mxGeometry relative=\"1\" as=\"geometry\"/></mxCell><mxCell id=\"e8\"" +
    " style=\"edgeStyle=orthogonalEdgeStyle;html=1;endArrow=block;endFill=1;\" " +
    "edge=\"1\" parent=\"1\" source=\"web2\" target=\"db1\"><mxGeometry relative=\"1\" " +
    "as=\"geometry\"><Array as=\"points\"><mxPoint x=\"780\" y=\"450\"/><mxPoint x=\"5" +
    "40\" y=\"450\"/></Array></mxGeometry></mxCell><mxCell id=\"e9\" value=\"replic" +
    "ation\" style=\"html=1;endArrow=block;endFill=1;dashed=1;fontSize=10;\" edg" +
    "e=\"1\" parent=\"1\" source=\"db1\" target=\"db2\"><mxGeometry relative=\"1\" as=\"" +
    "geometry\"/></mxCell><mxCell id=\"e10\" style=\"edgeStyle=orthogonalEdgeStyl" +
    "e;html=1;endArrow=block;endFill=1;\" edge=\"1\" parent=\"1\" source=\"web2\" ta" +
    "rget=\"cache\"><mxGeometry relative=\"1\" as=\"geometry\"/></mxCell><mxCell id" +
    "=\"e11\" style=\"html=1;endArrow=block;endFill=1;dashed=1;\" edge=\"1\" parent" +
    "=\"1\" source=\"web2\" target=\"cw\"><mxGeometry relative=\"1\" as=\"geometry\"/><" +
    "/mxCell></root></mxGraphModel></diagram></mxfile>",
  )
  let result = convert(data) catch {
    DrawioInvalid(message) => fail("AWS pages sample did not convert: " + message)
  }
  assert_eq(result.pages, 2)
  let mut legacy = false
  for w in result.warnings {
    assert_true(!w.contains("is not supported"), msg="stencil fallback: " + w)
    assert_true(
      !w.contains("has no current AWS counterpart"),
      msg="aws legacy gap: " + w,
    )
    if w.contains("AWS icon set") {
      legacy = true
    }
  }
  assert_true(legacy, msg="aws3 icons were not rewritten to aws4 counterparts")
  // Drawing-level check on the real fixture cells: the aws4 group labels
  // ("AWS Cloud", "Region", spacingLeft=30) must start right of the corner
  // icon square, in measurement and in the drawn extent.
  let font = @canvas.Fonts::new(None)
  let warn2 = DrawioWarn::new()
  let pages = drawio_read_file(data) catch { _ => fail("aws fixture re-read failed") }
  let mut checked = 0
  for page in pages {
    let model = drawio_model(page.model)
    for cell in model.cells {
      if cell.vertex && cell.style.contains("shape=mxgraph.aws4.group;") &&
        drawio_plain(cell.value) != "" {
        let kind = drawio_shape_kind(cell.style, warn2)
        let geo = cell.geometry()
        match geo {
          Some(node) => {
            let gx = drawio_num(node, "x", 0.0)
            let gy = drawio_num(node, "y", 0.0)
            let gw = drawio_num(node, "width", 1.0)
            let gh = drawio_num(node, "height", 1.0)
            let spacing = drawio_label_spacing(cell.style)
            let box = drawio_label_box(kind, cell.style, gx, gy, gw, gh)
            let origin = drawio_label_origin_x(box, 50.0, spacing)
            // Relative to the cell: spacingLeft=30 (+2 base) must move the
            // label past the corner icon square in every group, in any
            // diagram position (the pre-fix 2pt offset fails this).
            assert_true(
              origin - gx >= 30.0,
              msg="group label overlaps the corner icon: " +
                origin.to_string() + " vs cell " + gx.to_string(),
            )
            match drawio_measure_label(cell, kind, gx, gy, gw, gh, font, false, warn2) {
              Some(measure) => {
                let (x0, _, x1, _) = drawio_label_extent(measure, gx, gy, gw, gh)
                assert_true(x1 > x0, msg="empty label extent")
              }
              None => fail("group label not measured")
            }
            checked = checked + 1
          }
          None => ()
        }
      }
    }
  }
  assert_true(checked >= 2, msg="expected the Cloud and Region groups, got " + checked.to_string())
}
