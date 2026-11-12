///|
test "drawio shape registry covers common boxes and stencils" {
  assert_eq(drawio_shape_kind("ellipse;html=1;", DrawioWarn::new()), DkEllipse)
  assert_eq(drawio_shape_kind("rhombus;whiteSpace=wrap;", DrawioWarn::new()), DkRhombus)
  assert_eq(drawio_shape_kind("shape=hexagon;perimeter=hexagonPerimeter2;", DrawioWarn::new()), DkHexagon)
  assert_eq(drawio_shape_kind("shape=cylinder3;size=10;", DrawioWarn::new()), DkCylinder)
  assert_eq(drawio_shape_kind("shape=process;backgroundOutline=1;", DrawioWarn::new()), DkProcess)
  assert_eq(drawio_shape_kind("shape=callout;size=20;position=0.3;", DrawioWarn::new()), DkCallout)
  assert_eq(drawio_shape_kind("shape=partialRectangle;fillColor=none;", DrawioWarn::new()), DkPartialRect)
  assert_eq(drawio_shape_kind("shape=table;startSize=0;", DrawioWarn::new()), DkTable)
  assert_eq(drawio_shape_kind("shape=tableRow;horizontal=0;", DrawioWarn::new()), DkTableRow)
  assert_eq(drawio_shape_kind("swimlane;horizontal=0;", DrawioWarn::new()), DkSwimlane)
  assert_eq(drawio_shape_kind("rounded=1;whiteSpace=wrap;", DrawioWarn::new()), DkRoundedRect)
  assert_eq(
    drawio_shape_kind("shape=mxgraph.flowchart.database;whiteSpace=wrap;", DrawioWarn::new()),
    DkCylinder,
  )
  assert_eq(
    drawio_shape_kind("shape=mxgraph.flowchart.start_1;", DrawioWarn::new()),
    DkStadium,
  )
  assert_eq(
    drawio_shape_kind("shape=mxgraph.bpmn.gateway_or;", DrawioWarn::new()),
    DkRhombus,
  )
  assert_eq(drawio_shape_kind("shape=umlActor;", DrawioWarn::new()), DkUmlActor)
}

///|
test "drawio unknown stencils warn once and fall back to a rectangle" {
  let warn = DrawioWarn::new()
  let style = "shape=mxgraph.awslambda.nonexistent_icon;html=1;"
  assert_eq(drawio_shape_kind(style, warn), DkRect)
  assert_eq(drawio_shape_kind(style, warn), DkRect)
  assert_eq(warn.items.length(), 1)
  assert_true(warn.items[0].contains("mxgraph.awslambda.nonexistent_icon"))
  assert_true(warn.items[0].contains("not supported"))
  // A plain mxGraph name that is not a stencil is not reported.
  let quiet = DrawioWarn::new()
  assert_eq(drawio_shape_kind("shape=transparent;", quiet), DkRect)
  assert_eq(quiet.items.length(), 0)
}

///|
test "drawio perimeters follow the drawn outlines" {
  let (rx, ry) = drawio_shape_perimeter(DkRect, "", 0.0, 0.0, 100.0, 50.0, 200.0, 25.0)
  assert_eq((rx, ry), (100.0, 25.0))
  let (dx, dy) = drawio_shape_perimeter(DkRhombus, "", 0.0, 0.0, 100.0, 50.0, 200.0, 25.0)
  assert_eq((dx, dy), (100.0, 25.0))
  let (ex, ey) = drawio_shape_perimeter(DkEllipse, "", 0.0, 0.0, 100.0, 50.0, 200.0, 25.0)
  assert_true((ex - 100.0).abs() < 0.001)
  assert_true((ey - 25.0).abs() < 0.001)
  let (tx, ty) = drawio_shape_perimeter(DkTriangle, "", 0.0, 0.0, 100.0, 50.0, 200.0, 25.0)
  assert_true((tx - 100.0).abs() < 0.001)
  assert_true((ty - 25.0).abs() < 0.001)
  let (tx, ty) = drawio_shape_perimeter(DkTriangle, "", 0.0, 0.0, 100.0, 50.0, -100.0, 25.0)
  assert_true((tx - 0.0).abs() < 0.001)
  assert_true((ty - 25.0).abs() < 0.001)
}

///|
test "drawio edge routes attach to shape perimeters and constraints" {
  let xml = @utf8.decode_lossy(@utf8.encode(
    "<mxGraphModel><root><mxCell id=\"0\"/><mxCell id=\"1\" parent=\"0\"/>" +
    "<mxCell id=\"a\" style=\"rounded=0;\" vertex=\"1\" parent=\"1\"><mxGeometry x=\"0\" y=\"0\" width=\"100\" height=\"50\" as=\"geometry\"/></mxCell>" +
    "<mxCell id=\"b\" style=\"rhombus;\" vertex=\"1\" parent=\"1\"><mxGeometry x=\"200\" y=\"0\" width=\"100\" height=\"50\" as=\"geometry\"/></mxCell>" +
    "<mxCell id=\"e\" edge=\"1\" parent=\"1\" source=\"a\" target=\"b\"><mxGeometry relative=\"1\" as=\"geometry\"/></mxCell>" +
    "</root></mxGraphModel>",
  ))
  let root = drawio_parse(xml) catch { _ => fail("drawio route fixture did not parse") }
  let model = drawio_model(root)
  let edge = match model.cell("e") {
    Some(value) => value
    None => fail("missing edge")
  }
  let route = model.edge_route(edge, DrawioWarn::new())
  assert_eq(route.length(), 2)
  assert_eq(route[0], (100.0, 25.0))
  assert_eq(route[1], (200.0, 25.0))
  let constrained = @utf8.decode_lossy(@utf8.encode(
    "<mxGraphModel><root><mxCell id=\"0\"/><mxCell id=\"1\" parent=\"0\"/>" +
    "<mxCell id=\"a\" style=\"rounded=0;\" vertex=\"1\" parent=\"1\"><mxGeometry x=\"0\" y=\"0\" width=\"100\" height=\"50\" as=\"geometry\"/></mxCell>" +
    "<mxCell id=\"b\" style=\"rounded=0;\" vertex=\"1\" parent=\"1\"><mxGeometry x=\"200\" y=\"0\" width=\"100\" height=\"50\" as=\"geometry\"/></mxCell>" +
    "<mxCell id=\"e\" style=\"exitX=0;exitY=0.5;exitPerimeter=0;exitDx=5;entryX=1;entryY=1;entryPerimeter=0;\" edge=\"1\" parent=\"1\" source=\"a\" target=\"b\"><mxGeometry relative=\"1\" as=\"geometry\"/></mxCell>" +
    "</root></mxGraphModel>",
  ))
  let root = drawio_parse(constrained) catch { _ => fail("drawio constraint fixture did not parse") }
  let model = drawio_model(root)
  let edge = match model.cell("e") {
    Some(value) => value
    None => fail("missing constrained edge")
  }
  let route = model.edge_route(edge, DrawioWarn::new())
  assert_eq(route.length(), 2)
  assert_eq(route[0], (5.0, 25.0))
  assert_eq(route[1], (300.0, 50.0))
}

///|
test "drawio edge labels sit on the route" {
  let geo = {
    name: "mxGeometry",
    attrs: Map([("relative", "1")]),
    children: [],
    text: StringBuilder(),
  }
  let points = [(0.0, 0.0), (100.0, 0.0), (100.0, 100.0)]
  let (x, y) = drawio_edge_label_anchor(points, geo)
  assert_eq(x, 100.0)
  assert_eq(y, 0.0)
}

///|
test "drawio latex becomes readable text" {
  let warn = DrawioWarn::new()
  let (text, converted) = drawio_math_text(
    "\\(\\frac{a}{b} + \\sqrt{x^2+1} \\ne \\pm \\to \\sum_{k=1}^{n} \\int_0^1 \\pi \\infty \\cdot \\times \\left( x \\right)\\)",
    true,
    warn,
  )
  assert_true(converted)
  assert_true(text.contains("a/b"))
  assert_true(text.contains("√(x²+1)"))
  assert_true(text.contains("≠"))
  assert_true(text.contains("±"))
  assert_true(text.contains("→"))
  assert_true(text.contains("∑"))
  assert_true(text.contains("∫₀¹"))
  assert_true(text.contains("π"))
  assert_true(text.contains("∞"))
  assert_true(text.contains("·"))
  assert_true(text.contains("×"))
  assert_true(text.contains("( x )"))
  let (unchanged, found) = drawio_math_text("\\(x^2\\)", false, warn)
  assert_eq(unchanged, "\\(x^2\\)")
  assert_false(found)
}

///|
test "drawio latex warns for what it cannot simplify" {
  let warn = DrawioWarn::new()
  let (text, _) = drawio_math_text("\\(\\unknownmacro{x}\\)", true, warn)
  assert_true(text.contains("unknownmacro"))
  assert_eq(warn.items.length(), 1)
  assert_true(warn.items[0].contains("\\unknownmacro"))
  let warn = DrawioWarn::new()
  let (text, _) = drawio_math_text("\\(x^2", true, warn)
  assert_true(text.contains("\\(x^2"))
  assert_eq(warn.items.length(), 1)
  assert_true(warn.items[0].contains("unclosed"))
}

///|
test "drawio display formulas keep their distance from the words" {
  let warn = DrawioWarn::new()
  let (text, _) = drawio_math_text("are$$x = 1$$when", true, warn)
  assert_eq(text, "are x = 1 when")
}

///|
test "drawio rich labels wrap across runs and keep their style" {
  let font = @canvas.Fonts::new(None)
  let lines = drawio_rich_lines(
    "<b>Bold words here</b> and <i>italic words there</i>",
    12.0,
    0x000000ffU,
  )
  let wrapped = drawio_wrap_rich_lines(lines, 60.0, font, "", false, false, 12.0)
  assert_true(wrapped.length() > 1)
  let mut saw_bold = false
  let mut saw_italic = false
  for line in wrapped {
    for run in line {
      if run.style.bold {
        saw_bold = true
      }
      if run.style.italic {
        saw_italic = true
      }
    }
  }
  assert_true(saw_bold)
  assert_true(saw_italic)
}

///|
test "drawio wraps East Asian text between characters" {
  let font = @canvas.Fonts::new(None)
  let lines = drawio_wrap_text(
    "日本語のラベルは文字ごとに折り返されます。",
    60.0,
    font,
    "",
    false,
    false,
    9.0,
  )
  assert_true(lines.length() > 1)
  for line in lines {
    assert_true(line.length() > 0)
  }
}

///|
test "drawio keeps Japanese closing punctuation off line starts" {
  let font = @canvas.Fonts::new(None)
  let text = "日本語のラベルは文字ごとに折り返されます。句読点は行頭に来ません。"
  for i in 0..<12 {
    let width = 40.0 + i.to_double() * 10.0
    let lines = drawio_wrap_text(text, width, font, "", false, false, 9.0)
    for line in lines {
      assert_true(!line.has_prefix("。"), msg="plain line starts with punctuation")
    }
    let wrapped = drawio_wrap_rich_lines(
      drawio_rich_lines(text, 12.0, 0x000000ffU),
      width,
      font,
      "",
      false,
      false,
      12.0,
    )
    for line in wrapped {
      if !line.is_empty() {
        assert_true(
          !line[0].text.has_prefix("。"),
          msg="rich line starts with punctuation",
        )
      }
    }
  }
}

///|
test "drawio label boxes honor rotation and vertical labels" {
  let box = drawio_label_box(DkRect, "rotation=30;", 0.0, 0.0, 100.0, 50.0)
  assert_true((box.rotation - 30.0).abs() < 0.001)
  let vertical = drawio_label_box(DkRect, "horizontal=0;", 0.0, 0.0, 40.0, 100.0)
  assert_true((vertical.rotation + 90.0).abs() < 0.001)
  assert_true((vertical.w - 100.0).abs() < 0.001)
  assert_true((vertical.h - 40.0).abs() < 0.001)
  let swimlane = drawio_label_box(DkSwimlane, "swimlane;horizontal=0;startSize=24;", 0.0, 0.0, 200.0, 100.0)
  assert_true((swimlane.rotation + 90.0).abs() < 0.001)
  assert_true((swimlane.w - 100.0).abs() < 0.001)
  assert_true((swimlane.h - 24.0).abs() < 0.001)
  let right = drawio_label_box(DkRect, "labelPosition=right;align=left;", 0.0, 0.0, 100.0, 50.0)
  assert_true(right.x >= 100.0)
}

///|
test "drawio paints shape detail and partial borders" {
  let process = drawio_shape_paint(DkProcess, "", 0.0, 0.0, 100.0, 50.0)
  assert_true(process.stroke.size() >= 8)
  let plain = drawio_shape_paint(DkPartialRect, "top=1;left=0;bottom=0;right=0;", 0.0, 0.0, 100.0, 50.0)
  assert_true(plain.has_stroke)
  let open = drawio_shape_paint(
    DkPartialRect,
    "top=0;left=0;bottom=0;right=0;",
    0.0,
    0.0,
    100.0,
    50.0,
  )
  assert_false(open.has_stroke)
  let text = drawio_shape_paint(DkText, "", 0.0, 0.0, 100.0, 50.0)
  assert_false(text.has_fill)
  assert_false(text.has_stroke)
}

///|
test "drawio latex matrices, roots and inline templates" {
  let warn = DrawioWarn::new()
  let (text, _) = drawio_math_text(
    "\\(A=\\begin{pmatrix}1 & 2\\\\ 3 & 4\\end{pmatrix}\\)",
    true,
    warn,
  )
  assert_eq(text, "A=[1 2; 3 4]")
  let (text, _) = drawio_math_text("\\(\\sqrt[3]{x+1}\\)", true, warn)
  assert_eq(text, "∛(x+1)")
  let (text, _) = drawio_math_text("\\(x_{i}^{2}\\)", true, warn)
  assert_eq(text, "xᵢ²")
  let (text, _) = drawio_math_text(
    "\\(\\text{if } x \\leq 0 \\text{ then } y\\)",
    true,
    warn,
  )
  assert_eq(text, "if x ≤ 0 then y")
}

///|
test "drawio latex bounds long formulas and keeps them as text" {
  let warn = DrawioWarn::new()
  let body = StringBuilder()
  for _ in 0..<5000 {
    body.write_char('x')
  }
  let label = "\\(" + body.to_string() + "\\)"
  let (text, converted) = drawio_math_text(label, true, warn)
  assert_eq(text, label)
  assert_false(converted)
  assert_true(warn.items.length() == 1)
  assert_true(warn.items[0].contains("too long"))
}

///|
test "drawio inline stencil definitions are reported once" {
  let warn = DrawioWarn::new()
  let style = "shape=stencil(abc);html=1;"
  assert_eq(drawio_shape_kind(style, warn), DkRect)
  assert_eq(drawio_shape_kind(style, warn), DkRect)
  assert_eq(warn.items.length(), 1)
  assert_true(warn.items[0].contains("stencil"))
}

///|
test "orthogonal edge routes add corners" {
  let route = drawio_orthogonal_route(
    [(0.0, 0.0), (10.0, 20.0)],
    "edgeStyle=orthogonalEdgeStyle;",
  )
  assert_eq(route.length(), 3)
  assert_eq(route[1], (0.0, 20.0))
  assert_true(drawio_edge_is_orthogonal("edgeStyle=orthogonalEdgeStyle;"))
  assert_false(drawio_edge_is_orthogonal("edgeStyle=entityRelationEdgeStyle;"))
}

///|
/// Directional label spacing follows draw.io's mxText.getSpacing
/// (upstream label.go): spacingLeft/Right/Top/Bottom add to the base
/// spacing, left-aligned text sits spacingLeft inside the box,
/// right-aligned one spacingRight from its right edge, the center
/// balances them, and top/bottom labels sit at the base paddings
/// (5 above, 1 below) on top of their directional value.
test "drawio directional label spacing offsets" {
  let spacing = drawio_label_spacing("spacing=8;spacingLeft=30;spacingTop=4;")
  assert_eq(spacing.left, 38.0)
  assert_eq(spacing.right, 8.0)
  assert_eq(spacing.top, 12.0)
  assert_eq(spacing.bottom, 8.0)
  let plain = drawio_label_spacing("align=left;")
  assert_eq(plain.left, 2.0)
  let left = drawio_label_box(DkRect, "align=left;spacingLeft=30;", 0.0, 0.0, 100.0, 50.0)
  assert_eq(drawio_label_origin_x(left, 40.0, spacing), 38.0)
  let center = drawio_label_box(DkRect, "align=center;spacingLeft=30;spacing=8;", 0.0, 0.0, 100.0, 50.0)
  assert_eq(drawio_label_origin_x(center, 40.0, spacing), 45.0)
  let right = drawio_label_box(DkRect, "align=right;spacing=8;spacingLeft=30;", 0.0, 0.0, 100.0, 50.0)
  assert_eq(drawio_label_origin_x(right, 40.0, spacing), 52.0)
  let top = drawio_label_box(DkRect, "verticalAlign=top;spacingTop=4;", 0.0, 0.0, 100.0, 50.0)
  assert_eq(drawio_label_block_top(top, 20.0, drawio_label_spacing("spacingTop=4;")), 11.0)
  let bottom = drawio_label_box(DkRect, "verticalAlign=bottom;spacingBottom=3;", 0.0, 0.0, 100.0, 50.0)
  assert_eq(
    drawio_label_block_top(bottom, 20.0, drawio_label_spacing("spacingBottom=3;")),
    24.0,
  )
  let middle = drawio_label_box(DkRect, "verticalAlign=middle;spacingTop=6;spacingBottom=2;", 0.0, 0.0, 100.0, 50.0)
  assert_eq(drawio_label_block_top(middle, 20.0, drawio_label_spacing("spacingTop=6;spacingBottom=2;")), 17.0)
}

///|
/// The AWS group sample shapes (site/samples/aws.drawio) carry
/// `spacingLeft=30` so their labels start right of the corner icon. The
/// label must sit at least the 30-unit spacing inside the group frame,
/// not at the box edge where it overlaps the icon (the Pages mismatch).
test "drawio aws group labels clear the corner icon" {
  let style = "shape=mxgraph.aws4.group;grIcon=mxgraph.aws4.group_aws_cloud_alt;verticalAlign=top;align=left;spacingLeft=30;fontSize=12;html=1;whiteSpace=wrap;"
  let warn = DrawioWarn::new()
  let kind = drawio_shape_kind(style, warn)
  assert_eq(kind, DkStencil)
  let box = drawio_label_box(kind, style, 0.0, 0.0, 400.0, 300.0)
  let spacing = drawio_label_spacing(style)
  assert_eq(spacing.left, 32.0)
  let origin = drawio_label_origin_x(box, 50.0, spacing)
  // Relative to the cell at x=0: the label must clear the icon square.
  assert_true(origin >= 30.0, msg="label clear of the 30-unit corner icon, got " + origin.to_string())
  assert_true(origin < 34.0, msg="label not pushed past spacingLeft, got " + origin.to_string())
}

///|
/// blockSpacing=1 labels keep draw.io's base paddings off (upstream
/// passes blockSpacing=1 as noBase to mxText.getSpacing): a top-aligned
/// label sits at its spacingTop alone, a bottom-aligned one at its
/// spacingBottom alone.
test "drawio blockSpacing=1 labels skip the base paddings" {
  let top = drawio_label_box(DkRect, "verticalAlign=top;blockSpacing=1;spacingTop=4;", 0.0, 0.0, 100.0, 50.0)
  assert_eq(drawio_label_block_top(top, 20.0, drawio_label_spacing("verticalAlign=top;blockSpacing=1;spacingTop=4;")), 6.0)
  let bottom = drawio_label_box(DkRect, "verticalAlign=bottom;blockSpacing=1;spacingBottom=3;", 0.0, 0.0, 100.0, 50.0)
  assert_eq(
    drawio_label_block_top(bottom, 20.0, drawio_label_spacing("verticalAlign=bottom;blockSpacing=1;spacingBottom=3;")),
    25.0,
  )
  assert_eq(drawio_label_spacing("blockSpacing=1;").block, true)
  assert_eq(drawio_label_spacing("").block, false)
}

///|
/// The label extent covers the drawn text rectangle: an external right
/// label pushed out by spacingLeft=100 lands that far past the shape,
/// and the page bounds must cover it (the drawing path and the extent
/// share drawio_label_origin_x / drawio_label_block_top).
test "drawio label extent covers spacing-pushed text" {
  let data = @utf8.encode(
    "<mxfile><diagram name=\"T\"><mxGraphModel><root><mxCell id=\"0\"/><mxCell id=\"1\" parent=\"0\"/>" +
    "<mxCell id=\"v\" value=\"XYZ\" style=\"labelPosition=right;align=left;spacingLeft=100;\" vertex=\"1\" parent=\"1\">" +
    "<mxGeometry x=\"10\" y=\"10\" width=\"50\" height=\"20\" as=\"geometry\"/></mxCell>" +
    "</root></mxGraphModel></diagram></mxfile>",
  )
  let pages = drawio_read_file(data) catch { _ => fail("fixture did not read") }
  let model = drawio_model(pages[0].model)
  let cell = model.cells[2]
  let style = cell.style
  let box = drawio_label_box(DkRect, style, 10.0, 10.0, 50.0, 20.0)
  assert_eq(box.x, 64.0)
  let spacing = drawio_label_spacing(style)
  assert_eq(spacing.left, 102.0)
  let measure : DrawioLabelMeasure = { width: 40.0, height: 10.0, box, spacing }
  let (x0, _, x1, _) = drawio_label_extent(measure, 10.0, 10.0, 50.0, 20.0)
  assert_eq(x0, 10.0)
  assert_true(x1 >= 206.0, msg="page must cover the pushed-out label, got " + x1.to_string())
  // The real pipeline: the measured label reads the same style and the
  // page it sizes must cover the spacing-pushed text too.
  let font = @canvas.Fonts::new(None)
  let warn = DrawioWarn::new()
  let kind = drawio_shape_kind(style, warn)
  match drawio_measure_label(cell, kind, 10.0, 10.0, 50.0, 20.0, font, false, warn) {
    Some(measure) => {
      let (mx0, _, mx1, _) = drawio_label_extent(measure, 10.0, 10.0, 50.0, 20.0)
      assert_true(mx1 >= 165.0, msg="full-path extent must cover the spacing-pushed label, got " + mx1.to_string())
      assert_true(mx0 < 14.0, msg="extent still covers the shape, got " + mx0.to_string())
    }
    None => fail("label not measured")
  }
}

///|
/// Narrow directional padding can drop a wrapped label's usable width
/// below one unit: measurement and drawing keep the label on one line
/// then (the same `max_width > 1` policy in measure and draw).
test "drawio wrap stays off when directional padding exhausts the box" {
  let data = @utf8.encode(
    "<mxfile><diagram name=\"T\"><mxGraphModel><root><mxCell id=\"0\"/><mxCell id=\"1\" parent=\"0\"/>" +
    "<mxCell id=\"w\" value=\"one two three four five six\" style=\"whiteSpace=wrap;html=1;spacing=2000;\" vertex=\"1\" parent=\"1\">" +
    "<mxGeometry x=\"0\" y=\"0\" width=\"100\" height=\"40\" as=\"geometry\"/></mxCell>" +
    "</root></mxGraphModel></diagram></mxfile>",
  )
  let pages = drawio_read_file(data) catch { _ => fail("fixture did not read") }
  let model = drawio_model(pages[0].model)
  let cell = model.cells[2]
  let font = @canvas.Fonts::new(None)
  let warn = DrawioWarn::new()
  let kind = drawio_shape_kind(cell.style, warn)
  match drawio_measure_label(cell, kind, 0.0, 0.0, 100.0, 40.0, font, false, warn) {
    Some(measure) => {
      let whole = font.measure("", "", false, false, "one two three four five six") * 8.25
      if measure.width < whole - 0.001 {
        fail("label wrapped although the padding left no room: " + measure.width.to_string())
      }
    }
    None => fail("label not measured")
  }
}

///|
/// A rotated label's extent covers the rotated, spacing-pushed text
/// rectangle: with rotation=90 and an external right label pushed out by
/// spacingLeft=100, the pushed-out corner turns below the shape, and the
/// extent must cover it (the corners rotate around the label anchor like
/// draw.io's rotateLabelBounds).
test "drawio rotated label extent covers spacing-pushed text" {
  let font = @canvas.Fonts::new(None)
  let warn = DrawioWarn::new()
  let build = fn(style : String) -> DrawioLabelMeasure? raise {
    let data = @utf8.encode(
      "<mxfile><diagram name=\"T\"><mxGraphModel><root><mxCell id=\"0\"/><mxCell id=\"1\" parent=\"0\"/>" +
      "<mxCell id=\"r\" value=\"XYZ\" style=\"" + style + "\" vertex=\"1\" parent=\"1\">" +
      "<mxGeometry x=\"10\" y=\"10\" width=\"50\" height=\"20\" as=\"geometry\"/></mxCell>" +
      "</root></mxGraphModel></diagram></mxfile>",
    )
    let pages = drawio_read_file(data)
    let model = drawio_model(pages[0].model)
    let cell = model.cells[2]
    let kind = drawio_shape_kind(style, warn)
    drawio_measure_label(cell, kind, 10.0, 10.0, 50.0, 20.0, font, false, warn)
  }
  let big = match (build("rotation=90;labelPosition=right;align=left;spacingLeft=100;") catch {
    _ => fail("big-spacing rotated fixture failed")
  }) {
    Some(measure) => measure
    None => fail("big-spacing rotated label not measured")
  }
  assert_true(big.box.rotation - 90.0 < 0.001, msg="label not rotated")
  let (bx0, by0, bx1, by1) = drawio_label_extent(big, 10.0, 10.0, 50.0, 20.0)
  assert_true(by1 >= 150.0, msg="rotated pushed label corner uncovered, got y1=" + by1.to_string())
  assert_true(bx0 <= 10.0 && bx1 >= 60.0, msg="rotated extent lost the shape")
  let small = match (build("rotation=90;labelPosition=right;align=left;") catch {
    _ => fail("unspaced rotated fixture failed")
  }) {
    Some(measure) => measure
    None => fail("unspaced rotated label not measured")
  }
  let (_, sy0, _, sy1) = drawio_label_extent(small, 10.0, 10.0, 50.0, 20.0)
  // Without the directional push the rotated label stays near the shape
  // (the pushed variant reaches y1 >= 150 above).
  assert_true(sy1 > 60.0 && sy1 < 70.0, msg="unspaced rotated label extent unexpected, got y1=" + sy1.to_string())
}
