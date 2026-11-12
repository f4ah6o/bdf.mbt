///|
fn pptx_connector_fixture() -> Bytes raise {
  @base64.decode(
    (
    "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" +
    "bHMvUEsDBBQAAAAIAAVubF3MkBZmtQAAADcBAAAgAAAAcHB0L3NsaWRlcy9fcmVscy9zbGlkZTEu" +
    "eG1sLnJlbHONz70KwjAQB/Ddpwi3m7QOItLURQTBSfQBjuTaBtsk5KLYtzejBQfH+/r9uebwnkbx" +
    "osQueA21rECQN8E632u4307rHQjO6C2OwZOGmRgO7aq50oi53PDgIouCeNYw5Bz3SrEZaEKWIZIv" +
    "ky6kCXMpU68imgf2pDZVtVXp24B2YYqz1ZDOtgZxmyP9Y4euc4aOwTwn8vlHhOLRWbrgHJ65sJh6" +
    "yhqk/O4vlmpZIkC1jVq8264+UEsBAh4DFAAAAAgA7G1sXb57jY4HAQAAqAIAABMAAAAAAAAAAQAA" +
    "AICBAAAAAFtDb250ZW50X1R5cGVzXS54bWxQSwECHgMKAAAAAADubWxdAAAAAAAAAAAAAAAABgAA" +
    "AAAAAAAAABAA/UE4AQAAX3JlbHMvUEsBAh4DFAAAAAgA7m1sXc3hQ4yyAAAALgEAAAsAAAAAAAAA" +
    "AQAAAICBXAEAAF9yZWxzLy5yZWxzUEsBAh4DCgAAAAAAA25sXQAAAAAAAAAAAAAAAAQAAAAAAAAA" +
    "AAAQAP1BNwIAAHBwdC9QSwECHgMKAAAAAAAAbmxdAAAAAAAAAAAAAAAACgAAAAAAAAAAABAA/UFZ" +
    "AgAAcHB0L3RoZW1lL1BLAQIeAxQAAAAIAABubF0NAvN6ngEAAFoGAAAUAAAAAAAAAAEAAACAgYEC" +
    "AABwcHQvdGhlbWUvdGhlbWUxLnhtbFBLAQIeAxQAAAAIAPBtbF1chJLa0AAAAEoBAAAUAAAAAAAA" +
    "AAEAAACAgVEEAABwcHQvcHJlc2VudGF0aW9uLnhtbFBLAQIeAwoAAAAAAPFtbF0AAAAAAAAAAAAA" +
    "AAAKAAAAAAAAAAAAEAD9QVMFAABwcHQvX3JlbHMvUEsBAh4DFAAAAAgA8W1sXY0a/mPAAAAApgEA" +
    "AB8AAAAAAAAAAQAAAICBewUAAHBwdC9fcmVscy9wcmVzZW50YXRpb24ueG1sLnJlbHNQSwECHgMK" +
    "AAAAAABmbmxdAAAAAAAAAAAAAAAACwAAAAAAAAAAABAA/UF4BgAAcHB0L3NsaWRlcy9QSwECHgMU" +
    "AAAACABmbmxdbDCtDwUDAAC+CgAAFQAAAAAAAAABAAAAgIGhBgAAcHB0L3NsaWRlcy9zbGlkZTEu" +
    "eG1sUEsBAh4DCgAAAAAABW5sXQAAAAAAAAAAAAAAABEAAAAAAAAAAAAQAP1B2QkAAHBwdC9zbGlk" +
    "ZXMvX3JlbHMvUEsBAh4DFAAAAAgABW5sXcyQFma1AAAANwEAACAAAAAAAAAAAQAAAICBCAoAAHBw" +
    "dC9zbGlkZXMvX3JlbHMvc2xpZGUxLnhtbC5yZWxzUEsFBgAAAAANAA0AKgMAAPsKAAAAAA=="
    )[:],
  )
}

///|
test "PPTX connectors are drawn with transforms, dashes and arrowheads" {
  let result = convert(pptx_connector_fixture())
  let split = @core.single_to_split(result.bdf)
  let manifest = @core.parse_manifest(@utf8.decode(split.manifest))
  let body_hash = pptx_body_layer(manifest).object
  let resources = @core.decode_object_resources(
    @core.open_single(result.bdf).part(body_hash),
  )
  let commands = @render.compile_object(resources.object)
  let mut red = false
  let mut green = false
  let mut blue = false
  let mut dashed = false
  let mut strokes = 0
  let mut arrowheads = 0
  for command in commands {
    match command {
      @render.StrokeColor(0xff0000ff) => red = true
      @render.StrokeColor(0x00ff00ff) => green = true
      @render.StrokeColor(0x0000ffff) => blue = true
      @render.Dash(_, _) => dashed = true
      @render.StrokePath(index) => {
        strokes += 1
        match resources.paths[index] {
          @core.Inline(path) =>
            if path.coordinates == [72.0, 144.0, 360.0, 144.0] {
              red = true
            }
          _ => ()
        }
      }
      @render.FillPath(index, _) => {
        arrowheads += 1
        match resources.paths[index] {
          @core.Inline(path) =>
            if path.coordinates == [72.0, 378.0, 216.0, 378.0] {
              blue = true
            }
          _ => ()
        }
      }
      _ => ()
    }
  }
  assert_true(red, msg="PPTX red connector stroke")
  assert_true(green, msg="PPTX rotated bent connector stroke")
  assert_true(blue, msg="PPTX connector inside group")
  assert_true(dashed, msg="PPTX connector dash pattern")
  // The red line, the bent connector, its arrow-shaped tail (stroked, not
  // filled) and the grouped line; the connector without a transform stays
  // out, as upstream skips a shape it cannot place.
  assert_eq(strokes, 4, msg="PPTX connector stroke count")
  // Stealth head and triangle tail of the red connector, triangle tail of
  // the grouped connector: arrowheads are filled paths.
  assert_eq(arrowheads, 3, msg="PPTX arrowhead count")
}

///|
test "PPTX connectors keep their transform and group placement" {
  let root = pptx_parse_xml(
    "<sld><cSld><spTree>" +
    "<cxnSp><spPr><xfrm rot=\"5400000\"><off x=\"1371600\" y=\"2743200\"/><ext cx=\"2743200\" cy=\"1828800\"/></xfrm><prstGeom prst=\"line\"><avLst/></prstGeom></spPr></cxnSp>" +
    "<grpSp><grpSpPr><xfrm><off x=\"914400\" y=\"4572000\"/><ext cx=\"1828800\" cy=\"914400\"/><chOff x=\"457200\" y=\"457200\"/><chExt cx=\"3657600\" cy=\"1828800\"/></xfrm></grpSpPr>" +
    "<cxnSp><spPr><xfrm flipH=\"1\"><off x=\"457200\" y=\"914400\"/><ext cx=\"3657600\" cy=\"0\"/></xfrm><prstGeom prst=\"line\"><avLst/></prstGeom></spPr></cxnSp>" +
    "</grpSp></spTree></cSld></sld>",
  )
  let shapes = pptx_collect_tree_shapes(root, false)
  assert_eq(shapes.length(), 2)
  let (flat, _) = shapes[0]
  assert_eq(flat.element.name.local_name, "cxnSp")
  let flat_xform = pptx_transform_node(
    pptx_child(pptx_child(Some(flat), "spPr"), "xfrm"),
  ).unwrap()
  // 1371600 EMU = 108 pt, 2743200 EMU = 216 pt, 2743200 EMU = 216 pt,
  // 1828800 EMU = 144 pt, 5400000 / 60000 = 90 degrees.
  assert_eq(flat_xform.x, 108.0)
  assert_eq(flat_xform.y, 216.0)
  assert_eq(flat_xform.width, 216.0)
  assert_eq(flat_xform.height, 144.0)
  assert_eq(flat_xform.rotation, 90.0)
  assert_false(flat_xform.flip_h)
  // The group scales by 0.5 and moves the child space.
  let (child, placement) = shapes[1]
  assert_eq(child.element.name.local_name, "cxnSp")
  assert_eq(placement.sx, 0.5)
  assert_eq(placement.sy, 0.5)
  assert_eq(placement.tx, 54.0)
  assert_eq(placement.ty, 342.0)
  let child_xform = pptx_transform_node(
    pptx_child(pptx_child(Some(child), "spPr"), "xfrm"),
  ).unwrap()
  assert_true(child_xform.flip_h)
  assert_eq(child_xform.height, 0.0)
  // 457200 EMU = 36 pt: 54 + 36 * 0.5 = 72 and 342 + 72 * 0.5 = 378,
  // the position of the grouped connector on the slide.
  assert_eq(placement.tx + child_xform.x * placement.sx, 72.0)
  assert_eq(placement.ty + child_xform.y * placement.sy, 378.0)
}

///|
test "PPTX connector placeholders are read through nvCxnSpPr" {
  let root = pptx_parse_xml(
    "<sld><cSld><spTree>" +
    "<cxnSp><nvCxnSpPr><cNvPr id=\"2\" name=\"Line\"/><cNvCxnSpPr/><nvPr/></nvCxnSpPr><spPr><xfrm><off x=\"12700\" y=\"12700\"/><ext cx=\"914400\" cy=\"0\"/></xfrm></spPr></cxnSp>" +
    "<cxnSp><nvCxnSpPr><cNvPr id=\"3\" name=\"Mark\"/><cNvCxnSpPr/><nvPr><ph type=\"sldNum\" idx=\"3\"/></nvPr></nvCxnSpPr><spPr><xfrm><off x=\"12700\" y=\"12700\"/><ext cx=\"914400\" cy=\"0\"/></xfrm></spPr></cxnSp>" +
    "<sp><nvSpPr><cNvPr id=\"4\" name=\"Box\"/><cNvSpPr/><nvPr><ph type=\"sldNum\" idx=\"4\"/></nvPr></nvSpPr><spPr><xfrm><off x=\"12700\" y=\"12700\"/><ext cx=\"914400\" cy=\"914400\"/></xfrm></spPr></sp>" +
    "</spTree></cSld></sld>",
  )
  let tree = pptx_child(pptx_child(Some(root), "cSld"), "spTree")
  let children = pptx_children(tree)
  assert_false(pptx_has_placeholder(children[0]))
  assert_true(pptx_has_placeholder(children[1]))
  assert_true(pptx_has_placeholder(children[2]))
  // A layout tree keeps only shapes without a placeholder.
  let kept = pptx_collect_tree_shapes(root, true)
  assert_eq(kept.length(), 1)
  assert_eq(kept[0].0.element.name.local_name, "cxnSp")
  // A slide body keeps every shape.
  assert_eq(pptx_collect_tree_shapes(root, false).length(), 3)
}

///|
test "PPTX connector presets stay valid at zero and full sizes" {
  let connectors = [
    "line", "lineInv", "straightConnector1", "bentConnector2",
    "bentConnector3", "bentConnector4", "bentConnector5", "curvedConnector2",
    "curvedConnector3", "curvedConnector4", "curvedConnector5",
  ]
  let sizes : Array[(Double, Double)] = [
    (12.0, 0.0), (12.0, 12.0), (288.0, 0.0), (288.0, 144.0),
  ]
  for name in connectors {
    let mut stroked = false
    for (width, height) in sizes {
      let geometry = match pptx_preset_geometry(name, [], width, height) {
        Some(value) => value
        None => fail("PPTX connector preset is missing: " + name)
      }
      assert_false(geometry.paths.is_empty(), msg=name)
      for entry in geometry.paths {
        if entry.stroke && !entry.empty {
          stroked = true
        }
        let parts = entry.path.coordinates.length() / 2
        for i in 0..<parts {
          let x = entry.path.coordinates[i * 2]
          let y = entry.path.coordinates[i * 2 + 1]
          assert_true(
            x.abs() < 1000000000000.0 && y.abs() < 1000000000000.0,
            msg=name + " has a non-finite coordinate",
          )
          let box_width = if width > 0.0 { width } else { 1.0 }
          let box_height = if height > 0.0 { height } else { 1.0 }
          assert_true(
            x > -0.000001 && x < box_width + 0.000001,
            msg=name + " x coordinate is out of the box",
          )
          assert_true(
            y > -0.000001 && y < box_height + 0.000001,
            msg=name + " y coordinate is out of the box",
          )
        }
      }
    }
    assert_true(stroked, msg=name)
  }
  // Straight connectors span the whole box.
  let line = pptx_preset_geometry("line", [], 288.0, 144.0).unwrap()
  assert_eq(line.paths[0].path.coordinates, [0.0, 0.0, 288.0, 144.0])
  let straight = pptx_preset_geometry("straightConnector1", [], 10.0, 0.0)
    .unwrap()
  assert_eq(straight.paths[0].path.coordinates, [0.0, 0.0, 10.0, 0.0])
}

///|
test "PPTX connector strokes resolve own and theme line styles" {
  let package = @ooxml.open_ooxml(pptx_connector_fixture())
  let (theme_fills, theme_bg_fills, theme_lines) = pptx_theme_style_lists(
    package,
  )
  let ctx : PptxShapeContext = {
    package,
    writer: @core.DocumentWriter::new(),
    part: "ppt/slides/slide1.xml",
    theme: pptx_theme_colors(package),
    theme_fonts: pptx_theme_fonts(package),
    theme_fills,
    theme_bg_fills,
    theme_lines,
    default_text_style: None,
    layout_root: None,
    master_root: None,
    layout_placeholders: [],
    master_placeholders: [],
    is_body: true,
    fonts: Map([]),
    font_ctx: pptx_font_context(@canvas.Fonts::new(None), Map([])),
    warnings: [],
    warned: Map([]),
  }
  let slide = pptx_read_xml(package, "ppt/slides/slide1.xml")
  let tree = pptx_child(pptx_child(Some(slide), "cSld"), "spTree")
  let mut index = 0
  let mut own : PptxLineStyle? = None
  let mut themed : PptxLineStyle? = None
  let mut themed_fill = false
  for shape in pptx_children(tree) {
    if shape.element.name.local_name != "cxnSp" {
      continue
    }
    index += 1
    if index == 1 {
      own = pptx_shape_line(ctx, shape, [])
    }
    if index == 3 {
      themed = pptx_shape_line(ctx, shape, [])
      match pptx_shape_paint(ctx, shape, []) {
        PptxPaintNone => themed_fill = true
        _ => ()
      }
    }
  }
  let own = own.unwrap()
  // 12700 EMU = 1 pt, FF0000 is red, and sm and lg arrows scale by
  // 2 and 5.
  assert_eq(own.width, 1.0)
  assert_eq(own.color, 0xff0000ff)
  assert_eq(own.dash, [4.0, 3.0])
  assert_eq(own.head.kind, "stealth")
  assert_eq(own.head.w, 2.0)
  assert_eq(own.head.l, 2.0)
  assert_eq(own.tail.kind, "triangle")
  assert_eq(own.tail.w, 5.0)
  assert_eq(own.tail.l, 5.0)
  // p:style lnRef 2 resolves the theme's second line style with the
  // accent1 phClr; fillRef 0 leaves the connector unfilled.
  let themed = themed.unwrap()
  assert_eq(themed.width, 2.0)
  assert_eq(themed.color, 0x4472c4ff)
  assert_true(themed_fill)
}
