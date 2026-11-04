///|
// Synthetic PresentationML packages for preset geometry, placeholder
// inheritance and font embedding tests.

///|
fn pptx_test_put_u16(bytes : Array[Byte], at : Int32, value : Int32) -> Unit {
  bytes[at] = (value & 0xff).to_byte()
  bytes[at + 1] = ((value >> 8) & 0xff).to_byte()
}

///|
fn pptx_test_put_u32(bytes : Array[Byte], at : Int32, value : Int32) -> Unit {
  bytes[at] = (value & 0xff).to_byte()
  bytes[at + 1] = ((value >> 8) & 0xff).to_byte()
  bytes[at + 2] = ((value >> 16) & 0xff).to_byte()
  bytes[at + 3] = ((value >> 24) & 0xff).to_byte()
}

///|
/// Build a ZIP archive of stored entries for synthetic PresentationML packages.
fn pptx_test_zip(files : Array[(String, String)]) -> Bytes {
  let names : Array[Bytes] = []
  let bodies : Array[Bytes] = []
  let offsets : Array[Int32] = []
  let mut total = 22
  for (name, body) in files {
    let name_bytes = @utf8.encode(name)
    let body_bytes = @utf8.encode(body)
    names.push(name_bytes)
    bodies.push(body_bytes)
    total += 30 + 76 + name_bytes.length() * 2 + body_bytes.length()
  }
  let out = Bytes::make(total, 0).to_array()
  let mut at = 0
  for i, name_bytes in names {
    offsets.push(at)
    let body = bodies[i]
    pptx_test_put_u32(out, at, 0x04034b50)
    pptx_test_put_u16(out, at + 4, 20)
    pptx_test_put_u32(out, at + 18, body.length())
    pptx_test_put_u32(out, at + 22, body.length())
    pptx_test_put_u16(out, at + 26, name_bytes.length())
    for j in 0..<name_bytes.length() {
      out[at + 30 + j] = name_bytes[j]
    }
    for j in 0..<body.length() {
      out[at + 30 + name_bytes.length() + j] = body[j]
    }
    at += 30 + name_bytes.length() + body.length()
  }
  let central_start = at
  for i, name_bytes in names {
    let body = bodies[i]
    pptx_test_put_u32(out, at, 0x02014b50)
    pptx_test_put_u16(out, at + 4, 20)
    pptx_test_put_u16(out, at + 6, 20)
    pptx_test_put_u32(out, at + 20, body.length())
    pptx_test_put_u32(out, at + 24, body.length())
    pptx_test_put_u16(out, at + 28, name_bytes.length())
    pptx_test_put_u32(out, at + 42, offsets[i])
    for j in 0..<name_bytes.length() {
      out[at + 46 + j] = name_bytes[j]
    }
    at += 46 + name_bytes.length()
  }
  let central_size = at - central_start
  pptx_test_put_u32(out, at, 0x06054b50)
  pptx_test_put_u16(out, at + 8, names.length())
  pptx_test_put_u16(out, at + 10, names.length())
  pptx_test_put_u32(out, at + 12, central_size)
  pptx_test_put_u32(out, at + 16, central_start)
  Bytes::from_array(out)
}

///|
let pptx_test_root_rels =
  #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="root" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/></Relationships>

///|
let pptx_test_presentation =
  #|<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><p:sldIdLst><p:sldId id="256" r:id="rId1"/></p:sldIdLst><p:sldSz cx="9144000" cy="6858000"/></p:presentation>

///|
let pptx_test_presentation_rels =
  #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/></Relationships>

///|
let pptx_test_slide_prefix =
  #|<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>

///|
let pptx_test_slide_suffix =
  #|</p:spTree></p:cSld></p:sld>

///|
/// A one-slide presentation around slide with the given extra parts.
fn pptx_test_deck(slide : String, extra : Array[(String, String)]) -> Bytes {
  let files : Array[(String, String)] = [
    ("_rels/.rels", pptx_test_root_rels),
    ("ppt/presentation.xml", pptx_test_presentation),
    ("ppt/_rels/presentation.xml.rels", pptx_test_presentation_rels),
    ("ppt/slides/slide1.xml", slide),
  ]
  for entry in extra {
    files.push(entry)
  }
  pptx_test_zip(files)
}

///|
/// The inline paths of a converted page's body layer.
fn pptx_test_body_paths(result : PptxResult) -> Array[@core.Path] raise {
  let doc = @core.open_single(result.bdf)
  let body = pptx_body_layer(doc.manifest).object
  let resources = @core.decode_object_resources(doc.part(body))
  let paths : Array[@core.Path] = []
  for entry in resources.paths {
    match entry {
      @core.Inline(path) => paths.push(path)
      @core.External(_, _) => ()
    }
  }
  paths
}

///|
test "PPTX arrowheads draw filled or stroked paths" {
  for kind in ["triangle", "stealth", "diamond", "oval", "arrow"] {
    let object = @core.ObjectBuilder::new()
    object.set_bbox(0.0F, 0.0F, 200.0F, 200.0F)
    let arrow : PptxArrow = { kind, w: 3.0, l: 3.0 }
    let line : PptxLineStyle = {
      width: 2.0,
      color: 0xff0000ffU,
      cap: 0,
      join: 0,
      miter: 8.0,
      dash: [],
      head: arrow,
      tail: arrow,
    }
    try {
      pptx_draw_arrow(object, line, arrow, 100.0, 100.0, 1.0, 0.0)
    } catch {
      _ => ()
    }
    let commands = @render.decode_commands(object.encode()) catch { _ => [] }
    let mut fills = 0
    let mut strokes = 0
    for command in commands {
      match command {
        FillPath(_, _) => fills += 1
        StrokePath(_) => strokes += 1
        _ => ()
      }
    }
    if kind == "arrow" {
      assert_eq(strokes >= 1, true)
    } else {
      assert_eq(fills >= 1, true)
    }
  }
}

test "PPTX preset geometry evaluates adjust values and guides" {
  let triangle = pptx_preset_geometry("triangle", [], 200.0, 100.0).unwrap()
  assert_eq(triangle.text_left, 50.0)
  assert_eq(triangle.text_top, 50.0)
  assert_eq(triangle.text_right, 150.0)
  assert_eq(triangle.text_bottom, 100.0)
  assert_eq(triangle.paths[0].path.coordinates, [
    0.0, 100.0, 100.0, 0.0, 200.0, 100.0,
  ])
  let diamond = pptx_preset_geometry("diamond", [], 200.0, 100.0).unwrap()
  assert_eq(diamond.paths[0].path.coordinates, [
    0.0, 50.0, 100.0, 0.0, 200.0, 50.0, 100.0, 100.0,
  ])
  let arrow = pptx_preset_geometry("rightArrow", [], 200.0, 100.0).unwrap()
  assert_eq(arrow.paths[0].path.coordinates, [
    0.0, 25.0, 150.0, 25.0, 150.0, 0.0, 200.0, 50.0, 150.0, 100.0, 150.0, 75.0, 0.0,
    75.0,
  ])
  // a preset that scales its own path coordinate space
  let decision = pptx_preset_geometry("flowChartDecision", [], 200.0, 100.0).unwrap()
  assert_eq(decision.paths[0].path.coordinates, [
    0.0, 50.0, 100.0, 0.0, 200.0, 50.0, 100.0, 100.0,
  ])
  // arcs become cubic segments
  let cloud = pptx_preset_geometry("cloud", [], 200.0, 100.0).unwrap()
  assert_true(cloud.paths.length() >= 2)
  assert_true(cloud.paths[0].path.coordinates.length() > 30)
  assert_true(cloud.paths[0].path.verbs.to_array().contains(4))
  // an unknown preset is not invented
  assert_true(pptx_preset_geometry("notAPreset", [], 10.0, 10.0) is None)
}

///|
test "PPTX preset shapes are drawn and unknown presets warn" {
  let shapes =
    #|<p:sp><p:nvSpPr><p:cNvPr id="2" name="Triangle"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="914400" y="457200"/><a:ext cx="2540000" cy="1270000"/></a:xfrm><a:prstGeom prst="triangle"/><a:solidFill><a:srgbClr val="00FF00"/></a:solidFill></p:spPr><p:txBody><a:bodyPr/><a:p><a:r><a:rPr sz="1800"/><a:t>Hi</a:t></a:r></a:p></p:txBody></p:sp>
    #|<p:sp><p:nvSpPr><p:cNvPr id="3" name="Diamond"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="4572000" y="457200"/><a:ext cx="2540000" cy="1270000"/></a:xfrm><a:prstGeom prst="diamond"/><a:solidFill><a:srgbClr val="FF0000"/></a:solidFill></p:spPr></p:sp>
    #|<p:sp><p:nvSpPr><p:cNvPr id="4" name="Arrow"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="457200" y="2286000"/><a:ext cx="2540000" cy="1270000"/></a:xfrm><a:prstGeom prst="rightArrow"/><a:solidFill><a:srgbClr val="0000FF"/></a:solidFill></p:spPr></p:sp>
    #|<p:sp><p:nvSpPr><p:cNvPr id="5" name="Decision"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="4572000" y="2286000"/><a:ext cx="2540000" cy="1270000"/></a:xfrm><a:prstGeom prst="flowChartDecision"/><a:solidFill><a:srgbClr val="00FFFF"/></a:solidFill></p:spPr></p:sp>
    #|<p:sp><p:nvSpPr><p:cNvPr id="6" name="Cloud"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="914400" y="4114800"/><a:ext cx="2540000" cy="1270000"/></a:xfrm><a:prstGeom prst="cloud"/><a:solidFill><a:srgbClr val="FFFF00"/></a:solidFill></p:spPr></p:sp>
    #|<p:sp><p:nvSpPr><p:cNvPr id="7" name="Unknown"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="4572000" y="4114800"/><a:ext cx="1270000" cy="914400"/></a:xfrm><a:prstGeom prst="notAPreset"/><a:solidFill><a:srgbClr val="999999"/></a:solidFill></p:spPr></p:sp>
  let slide = pptx_test_slide_prefix + shapes + pptx_test_slide_suffix
  let result = convert(pptx_test_deck(slide, []))
  assert_eq(result.pages, 1)
  assert_true(
    result.warnings.contains(
      "unknown preset shape \"notAPreset\" drawn as a rectangle",
    ),
  )
  let paths = pptx_test_body_paths(result)
  let mut triangle = false
  let mut diamond = false
  let mut arrow = false
  let mut decision = false
  let mut cloud = false
  for path in paths {
    let coordinates = path.coordinates
    if coordinates.length() == 6 &&
      coordinates[0] == 72.0 &&
      coordinates[1] == 136.0 &&
      coordinates[2] == 172.0 &&
      coordinates[3] == 36.0 &&
      coordinates[4] == 272.0 {
      triangle = true
    }
    if coordinates.length() == 8 &&
      coordinates[0] == 360.0 &&
      coordinates[1] == 86.0 &&
      coordinates[2] == 460.0 &&
      coordinates[3] == 36.0 {
      diamond = true
    }
    if coordinates.length() == 14 &&
      coordinates[0] == 36.0 &&
      coordinates[1] == 205.0 &&
      coordinates[3] == 205.0 &&
      coordinates[4] == 186.0 {
      arrow = true
    }
    if coordinates.length() == 8 &&
      coordinates[0] == 360.0 &&
      coordinates[1] == 230.0 {
      decision = true
    }
    if coordinates.length() > 30 {
      cloud = true
    }
  }
  assert_true(triangle, msg="PPTX triangle geometry")
  assert_true(diamond, msg="PPTX diamond geometry")
  assert_true(arrow, msg="PPTX rightArrow geometry")
  assert_true(decision, msg="PPTX flowChartDecision geometry")
  assert_true(cloud, msg="PPTX cloud geometry")
  // the triangle's text starts in its text rectangle, not at the box edge
  let doc = @core.open_single(result.bdf)
  let body = pptx_body_layer(doc.manifest).object
  let resources = @core.decode_object_resources(doc.part(body))
  let commands = @render.compile_object(resources.object)
  let mut text_x = -1.0
  for command in commands {
    match command {
      @render.FillText(_, x, _, _) => if text_x < 0.0 { text_x = x }
      _ => ()
    }
  }
  assert_true((text_x - 129.2).abs() < 0.01, msg="PPTX preset text rectangle")
}

///|
test "PPTX custom geometry evaluates guides, paths and arcs" {
  let node_xml =
    #|<a:custGeom xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:avLst/><a:gdLst><a:gd name="x1" fmla="*/ w 1 4"/><a:gd name="x2" fmla="*/ w 3 4"/></a:gdLst><a:rect l="x1" t="t" r="x2" b="b"/><a:pathLst><a:path w="4" h="2" fill="darken" stroke="0"><a:moveTo><a:pt x="0" y="2"/></a:moveTo><a:lnTo><a:pt x="1" y="0"/></a:lnTo><a:lnTo><a:pt x="2" y="2"/></a:lnTo><a:close/></a:path><a:path w="4" h="2"><a:moveTo><a:pt x="2" y="0"/></a:moveTo><a:quadBezTo><a:pt x="3" y="0"/><a:pt x="4" y="1"/></a:quadBezTo><a:cubicBezTo><a:pt x="3" y="2"/><a:pt x="2" y="2"/><a:pt x="2" y="1"/></a:cubicBezTo><a:arcTo wR="1" hR="1" stAng="0" swAng="5400000"/></a:path></a:pathLst></a:custGeom>
  let node = pptx_parse_xml(node_xml)
  let (geometry, reason) = pptx_custom_geometry(node, 200.0, 100.0)
  assert_eq(reason, "")
  let geometry = geometry.unwrap()
  // the text rectangle comes from a:rect guide names
  assert_eq(geometry.text_left, 50.0)
  assert_eq(geometry.text_top, 0.0)
  assert_eq(geometry.text_right, 150.0)
  assert_eq(geometry.text_bottom, 100.0)
  assert_eq(geometry.paths.length(), 2)
  // path w/h scale its own coordinate space onto the shape box
  let triangle = geometry.paths[0]
  assert_eq(triangle.fill, "darken")
  assert_false(triangle.stroke)
  assert_false(triangle.empty)
  assert_eq(triangle.path.coordinates, [0.0, 100.0, 50.0, 0.0, 100.0, 100.0])
  assert_eq(triangle.path.verbs.length(), 4)
  assert_eq(triangle.path.verbs[0].to_int(), 0)
  assert_eq(triangle.path.verbs[1].to_int(), 1)
  assert_eq(triangle.path.verbs[3].to_int(), 4)
  // quadratic and cubic segments keep their verbs
  let curves = geometry.paths[1]
  assert_eq(curves.fill, "norm")
  assert_true(curves.stroke)
  assert_false(curves.empty)
  assert_eq(curves.path.coordinates.length(), 18)
  assert_eq(curves.path.verbs.length(), 4)
  assert_eq(curves.path.verbs[0].to_int(), 0)
  assert_eq(curves.path.verbs[1].to_int(), 2)
  assert_eq(curves.path.verbs[2].to_int(), 3)
  assert_eq(curves.path.verbs[3].to_int(), 3)
  assert_eq(curves.path.coordinates[:12], [
    100.0, 0.0, 150.0, 0.0, 200.0, 50.0, 150.0, 100.0, 100.0, 100.0, 100.0, 50.0,
  ])
  // arcTo turns its radii into shape units, and its quarter sweep into one
  // cubic ending on the ellipse edge
  let kappa = 4.0 / 3.0 * @math.tan(3.141592653589793 / 8.0) * 50.0
  assert_true((curves.path.coordinates[12] - 100.0).abs() < 0.000001)
  assert_true((curves.path.coordinates[13] - (50.0 + kappa)).abs() < 0.000001)
  assert_true((curves.path.coordinates[14] - (50.0 + kappa)).abs() < 0.000001)
  assert_true((curves.path.coordinates[15] - 100.0).abs() < 0.000001)
  assert_true((curves.path.coordinates[16] - 50.0).abs() < 0.000001)
  assert_true((curves.path.coordinates[17] - 100.0).abs() < 0.000001)
}

///|
test "PPTX malformed custom geometry reports a precise reason" {
  let no_paths_xml =
    #|<a:custGeom xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:avLst/><a:rect l="l" t="t" r="r" b="b"/></a:custGeom>
  let no_paths = pptx_parse_xml(no_paths_xml)
  assert_true(
    pptx_custom_geometry(no_paths, 100.0, 50.0) is (None, "missing a:pathLst"),
  )
  let no_path_xml =
    #|<a:custGeom xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:pathLst/></a:custGeom>
  let no_path = pptx_parse_xml(no_path_xml)
  assert_true(
    pptx_custom_geometry(no_path, 100.0, 50.0)
    is (None, "a:pathLst has no a:path"),
  )
  let no_commands_xml =
    #|<a:custGeom xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:pathLst><a:path/></a:pathLst></a:custGeom>
  let no_commands = pptx_parse_xml(no_commands_xml)
  assert_true(
    pptx_custom_geometry(no_commands, 100.0, 50.0)
    is (None, "a:path has no commands"),
  )
  let unknown_xml =
    #|<a:custGeom xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:pathLst><a:path><a:moveTo><a:pt x="0" y="0"/></a:moveTo><a:foo/></a:path></a:pathLst></a:custGeom>
  let unknown = pptx_parse_xml(unknown_xml)
  assert_true(
    pptx_custom_geometry(unknown, 100.0, 50.0)
    is (None, "unsupported a:path command \"foo\""),
  )
  let short_quad_xml =
    #|<a:custGeom xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:pathLst><a:path><a:moveTo><a:pt x="0" y="0"/></a:moveTo><a:quadBezTo><a:pt x="1" y="1"/></a:quadBezTo></a:path></a:pathLst></a:custGeom>
  let short_quad = pptx_parse_xml(short_quad_xml)
  assert_true(
    pptx_custom_geometry(short_quad, 100.0, 50.0)
    is (None, "a:quadBezTo needs two a:pt"),
  )
}

///|
test "PPTX custom geometry draws paths and falls back when malformed" {
  let triangle =
    #|<p:sp><p:nvSpPr><p:cNvPr id="2" name="Custom"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="914400" y="457200"/><a:ext cx="2540000" cy="1270000"/></a:xfrm><a:custGeom><a:avLst/><a:gdLst><a:gd name="x1" fmla="*/ w 1 4"/></a:gdLst><a:rect l="x1" t="t" r="r" b="b"/><a:pathLst><a:path w="2" h="1"><a:moveTo><a:pt x="0" y="1"/></a:moveTo><a:lnTo><a:pt x="1" y="0"/></a:lnTo><a:lnTo><a:pt x="2" y="1"/></a:lnTo><a:close/></a:path></a:pathLst></a:custGeom><a:solidFill><a:srgbClr val="00FF00"/></a:solidFill></p:spPr><p:txBody><a:bodyPr/><a:p><a:r><a:rPr sz="1800"/><a:t>Custom</a:t></a:r></a:p></p:txBody></p:sp>
  let malformed =
    #|<p:sp><p:nvSpPr><p:cNvPr id="3" name="Broken"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="914400" y="4114800"/><a:ext cx="1270000" cy="914400"/></a:xfrm><a:custGeom><a:avLst/><a:rect l="l" t="t" r="r" b="b"/></a:custGeom><a:solidFill><a:srgbClr val="999999"/></a:solidFill></p:spPr></p:sp>
  let slide = pptx_test_slide_prefix +
    triangle +
    malformed +
    pptx_test_slide_suffix
  let result = convert(pptx_test_deck(slide, []))
  assert_true(
    result.warnings.contains(
      "malformed custom geometry (missing a:pathLst) drawn as a rectangle",
    ),
  )
  let paths = pptx_test_body_paths(result)
  assert_eq(paths.length(), 1)
  assert_eq(paths[0].coordinates, [72.0, 136.0, 172.0, 36.0, 272.0, 136.0])
  assert_eq(paths[0].verbs.length(), 4)
  let doc = @core.open_single(result.bdf)
  let body = pptx_body_layer(doc.manifest).object
  let resources = @core.decode_object_resources(doc.part(body))
  let commands = @render.compile_object(resources.object)
  let mut text_x = -1.0
  let mut fallback_rect = false
  let mut filled = false
  for command in commands {
    match command {
      @render.FillText(_, x, _, _) => if text_x < 0.0 { text_x = x }
      @render.FillRect(x, y, width, height) =>
        if (x - 72.0).abs() < 0.000000001 &&
          (y - 324.0).abs() < 0.000000001 &&
          (width - 100.0).abs() < 0.000000001 &&
          (height - 72.0).abs() < 0.000000001 {
          fallback_rect = true
        }
      @render.FillPath(_, _) => filled = true
      _ => ()
    }
  }
  assert_true(filled, msg="PPTX custom geometry fill path")
  assert_true(fallback_rect, msg="PPTX malformed custom geometry rectangle")
  // the custom a:rect puts the text rectangle's left edge at w/4
  assert_true((text_x - 129.2).abs() < 0.01, msg="PPTX custGeom text rectangle")
}

///|
test "PPTX custom geometry paints fill modes and per-path strokes" {
  let shape =
    #|<p:sp><p:nvSpPr><p:cNvPr id="2" name="Paths"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="914400" y="457200"/><a:ext cx="2540000" cy="1270000"/></a:xfrm><a:custGeom><a:avLst/><a:gdLst/><a:rect l="l" t="t" r="r" b="b"/><a:pathLst><a:path w="2" h="1" fill="lighten" stroke="0"><a:moveTo><a:pt x="0" y="1"/></a:moveTo><a:lnTo><a:pt x="1" y="0"/></a:lnTo><a:lnTo><a:pt x="2" y="1"/></a:lnTo><a:close/></a:path><a:path w="2" h="1" fill="none"><a:moveTo><a:pt x="2" y="0"/></a:moveTo><a:lnTo><a:pt x="2" y="1"/></a:lnTo></a:path></a:pathLst></a:custGeom><a:solidFill><a:srgbClr val="808080"/></a:solidFill><a:ln w="12700"><a:solidFill><a:srgbClr val="000000"/></a:solidFill></a:ln></p:spPr></p:sp>
  let slide = pptx_test_slide_prefix + shape + pptx_test_slide_suffix
  let result = convert(pptx_test_deck(slide, []))
  let paths = pptx_test_body_paths(result)
  assert_eq(paths.length(), 2)
  assert_eq(paths[0].coordinates, [72.0, 136.0, 172.0, 36.0, 272.0, 136.0])
  assert_eq(paths[1].coordinates, [272.0, 36.0, 272.0, 136.0])
  let doc = @core.open_single(result.bdf)
  let body = pptx_body_layer(doc.manifest).object
  let resources = @core.decode_object_resources(doc.part(body))
  let commands = @render.compile_object(resources.object)
  let mut lighten = false
  let mut fills = 0
  let mut strokes = 0
  for command in commands {
    match command {
      @render.FillColor(0xc0c0c0ff) => lighten = true
      @render.FillPath(_, _) => fills += 1
      @render.StrokePath(_) => strokes += 1
      _ => ()
    }
  }
  assert_true(lighten, msg="PPTX custGeom lighten fill mode")
  assert_eq(fills, 1, msg="PPTX custGeom path fills")
  assert_eq(strokes, 1, msg="PPTX custGeom per-path stroke")
}

///|
test "PPTX path fill modes adjust the fill color" {
  assert_eq(pptx_adjust_fill_color(0x808080ff, "lighten"), 0xc0c0c0ff)
  assert_eq(pptx_adjust_fill_color(0x808080ff, "darken"), 0x656565ff)
  assert_eq(pptx_adjust_fill_color(0x808080ff, "lightenLess"), 0xa4a4a4ff)
  assert_eq(pptx_adjust_fill_color(0x808080ff, "darkenLess"), 0x737373ff)
  assert_eq(pptx_adjust_fill_color(0x808080ff, "norm"), 0x808080ff)
  assert_eq(pptx_adjust_fill_color(0x808080ff, "none"), 0x808080ff)
}

///|
test "PPTX custom geometry uses theme fill and line style references" {
  let theme =
    #|<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Test"><a:themeElements><a:clrScheme name="Test"><a:dk1><a:srgbClr val="000000"/></a:dk1><a:lt1><a:srgbClr val="FFFFFF"/></a:lt1><a:accent1><a:srgbClr val="CC0000"/></a:accent1></a:clrScheme><a:fmtScheme name="Test"><a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst><a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst><a:lnStyleLst><a:ln w="12700"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst></a:fmtScheme></a:themeElements></a:theme>
  let shape =
    #|<p:sp><p:nvSpPr><p:cNvPr id="2" name="Styled"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="914400" y="914400"/><a:ext cx="2540000" cy="1270000"/></a:xfrm><a:custGeom><a:avLst/><a:gdLst/><a:rect l="l" t="t" r="r" b="b"/><a:pathLst><a:path><a:moveTo><a:pt x="0" y="0"/></a:moveTo><a:lnTo><a:pt x="1" y="0"/></a:lnTo><a:lnTo><a:pt x="1" y="1"/></a:lnTo><a:close/></a:path></a:pathLst></a:custGeom></p:spPr><p:style><a:lnRef idx="1"><a:schemeClr val="accent1"/></a:lnRef><a:fillRef idx="1"><a:schemeClr val="accent1"/></a:fillRef><a:effectRef idx="0"><a:schemeClr val="accent1"/></a:effectRef><a:fontRef idx="minor"><a:schemeClr val="lt1"/></a:fontRef></p:style></p:sp>
  let slide = pptx_test_slide_prefix + shape + pptx_test_slide_suffix
  let root_rels =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="root" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/><Relationship Id="theme" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="ppt/theme/theme1.xml"/></Relationships>
  let result = convert(
    pptx_test_deck(slide, [
      ("_rels/.rels", root_rels),
      ("ppt/theme/theme1.xml", theme),
    ]),
  )
  let doc = @core.open_single(result.bdf)
  let body = pptx_body_layer(doc.manifest).object
  let resources = @core.decode_object_resources(doc.part(body))
  let commands = @render.compile_object(resources.object)
  let mut filled = false
  let mut stroked = false
  let mut fill_path = false
  let mut stroke_path = false
  for command in commands {
    match command {
      @render.FillColor(0xcc0000ff) => filled = true
      @render.StrokeColor(0xcc0000ff) => stroked = true
      @render.FillPath(_, _) => fill_path = true
      @render.StrokePath(_) => stroke_path = true
      _ => ()
    }
  }
  assert_true(filled, msg="PPTX custGeom theme fill")
  assert_true(stroked, msg="PPTX custGeom theme line")
  assert_true(fill_path, msg="PPTX custGeom theme fill path")
  assert_true(stroke_path, msg="PPTX custGeom theme stroke path")
}

///|
let pptx_test_master =
  #|<p:sldMaster xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/><p:cSld><p:spTree><p:sp><p:nvSpPr><p:cNvPr id="2" name="Master"/><p:cNvSpPr/><p:nvPr><p:ph type="body"/></p:nvPr></p:nvSpPr><p:spPr><a:solidFill><a:srgbClr val="0000FF"/></a:solidFill><a:ln w="25400"><a:solidFill><a:srgbClr val="00FF00"/></a:solidFill></a:ln></p:spPr></p:sp></p:spTree></p:cSld></p:sldMaster>

///|
let pptx_test_slide_rels =
  #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="l1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/></Relationships>

///|
let pptx_test_layout_rels =
  #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="m1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/></Relationships>

///|
let pptx_test_body_slide =
  #|<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><p:cSld><p:spTree><p:sp><p:nvSpPr><p:cNvPr id="2" name="Body"/><p:cNvSpPr/><p:nvPr><p:ph type="body" idx="1"/></p:nvPr></p:nvSpPr><p:spPr><a:xfrm><a:off x="914400" y="914400"/><a:ext cx="4572000" cy="914400"/></a:xfrm></p:spPr><p:txBody><a:bodyPr/><a:p><a:r><a:rPr sz="1800"/><a:t>Inherit</a:t></a:r></a:p></p:txBody></p:sp></p:spTree></p:cSld></p:sld>

///|
test "PPTX placeholder fills and outlines inherit from the layout" {
  let layout =
    #|<p:sldLayout xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><p:cSld><p:spTree><p:sp><p:nvSpPr><p:cNvPr id="2" name="Layout"/><p:cNvSpPr/><p:nvPr><p:ph type="body" idx="1"/></p:nvPr></p:nvSpPr><p:spPr><a:solidFill><a:srgbClr val="FF0000"/></a:solidFill><a:ln w="25400"><a:solidFill><a:srgbClr val="00FF00"/></a:solidFill></a:ln></p:spPr></p:sp></p:spTree></p:cSld></p:sldLayout>
  let result = convert(
    pptx_test_deck(pptx_test_body_slide, [
      ("ppt/slides/_rels/slide1.xml.rels", pptx_test_slide_rels),
      ("ppt/slideLayouts/slideLayout1.xml", layout),
      ("ppt/slideLayouts/_rels/slideLayout1.xml.rels", pptx_test_layout_rels),
      ("ppt/slideMasters/slideMaster1.xml", pptx_test_master),
    ]),
  )
  let doc = @core.open_single(result.bdf)
  let body = pptx_body_layer(doc.manifest).object
  let resources = @core.decode_object_resources(doc.part(body))
  let commands = @render.compile_object(resources.object)
  let mut filled = false
  let mut stroked = false
  let mut line_width = 0.0
  for command in commands {
    match command {
      @render.FillColor(0xff0000ff) => filled = true
      @render.StrokeColor(0x00ff00ff) => stroked = true
      @render.Line(width, _, _, _) => line_width = width
      _ => ()
    }
  }
  assert_true(filled, msg="PPTX placeholder fill inheritance")
  assert_true(stroked, msg="PPTX placeholder line inheritance")
  assert_eq(line_width, 2.0)
}

///|
test "PPTX placeholder noFill stops master inheritance" {
  let layout =
    #|<p:sldLayout xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><p:cSld><p:spTree><p:sp><p:nvSpPr><p:cNvPr id="2" name="Layout"/><p:cNvSpPr/><p:nvPr><p:ph type="body" idx="1"/></p:nvPr></p:nvSpPr><p:spPr><a:noFill/><a:ln w="25400"><a:noFill/></a:ln></p:spPr></p:sp></p:spTree></p:cSld></p:sldLayout>
  let result = convert(
    pptx_test_deck(pptx_test_body_slide, [
      ("ppt/slides/_rels/slide1.xml.rels", pptx_test_slide_rels),
      ("ppt/slideLayouts/slideLayout1.xml", layout),
      ("ppt/slideLayouts/_rels/slideLayout1.xml.rels", pptx_test_layout_rels),
      ("ppt/slideMasters/slideMaster1.xml", pptx_test_master),
    ]),
  )
  let doc = @core.open_single(result.bdf)
  let body = pptx_body_layer(doc.manifest).object
  let resources = @core.decode_object_resources(doc.part(body))
  let commands = @render.compile_object(resources.object)
  let mut fill_rects = 0
  let mut stroke_rects = 0
  for command in commands {
    match command {
      @render.FillRect(_, _, _, _) => fill_rects += 1
      @render.StrokeRect(_, _, _, _) => stroke_rects += 1
      _ => ()
    }
  }
  assert_eq(fill_rects, 0, msg="PPTX noFill fill")
  assert_eq(stroke_rects, 0, msg="PPTX noFill outline")
}

///|
test "PPTX slide placeholder fill overrides the layout" {
  let layout =
    #|<p:sldLayout xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><p:cSld><p:spTree><p:sp><p:nvSpPr><p:cNvPr id="2" name="Layout"/><p:cNvSpPr/><p:nvPr><p:ph type="body" idx="1"/></p:nvPr></p:nvSpPr><p:spPr><a:solidFill><a:srgbClr val="FF0000"/></a:solidFill></p:spPr></p:sp></p:spTree></p:cSld></p:sldLayout>
  let slide =
    #|<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><p:cSld><p:spTree><p:sp><p:nvSpPr><p:cNvPr id="2" name="Body"/><p:cNvSpPr/><p:nvPr><p:ph type="body" idx="1"/></p:nvPr></p:nvSpPr><p:spPr><a:xfrm><a:off x="914400" y="914400"/><a:ext cx="4572000" cy="914400"/></a:xfrm><a:solidFill><a:srgbClr val="112233"/></a:solidFill></p:spPr><p:txBody><a:bodyPr/><a:p><a:r><a:rPr sz="1800"/><a:t>Own</a:t></a:r></a:p></p:txBody></p:sp></p:spTree></p:cSld></p:sld>
  let result = convert(
    pptx_test_deck(slide, [
      ("ppt/slides/_rels/slide1.xml.rels", pptx_test_slide_rels),
      ("ppt/slideLayouts/slideLayout1.xml", layout),
    ]),
  )
  let doc = @core.open_single(result.bdf)
  let body = pptx_body_layer(doc.manifest).object
  let resources = @core.decode_object_resources(doc.part(body))
  let commands = @render.compile_object(resources.object)
  let mut own = false
  let mut layout_fill = false
  for command in commands {
    match command {
      @render.FillColor(0x112233ff) => own = true
      @render.FillColor(0xff0000ff) => layout_fill = true
      _ => ()
    }
  }
  assert_true(own, msg="PPTX slide fill")
  assert_true(!layout_fill)
}

///|
test "PPTX theme fill and line style references use phClr" {
  let theme =
    #|<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Test"><a:themeElements><a:clrScheme name="Test"><a:dk1><a:srgbClr val="000000"/></a:dk1><a:lt1><a:srgbClr val="FFFFFF"/></a:lt1><a:accent1><a:srgbClr val="CC0000"/></a:accent1></a:clrScheme><a:fmtScheme name="Test"><a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst><a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst><a:lnStyleLst><a:ln w="12700"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst></a:fmtScheme></a:themeElements></a:theme>
  let shape =
    #|<p:sp><p:nvSpPr><p:cNvPr id="2" name="Styled"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="914400" y="914400"/><a:ext cx="2540000" cy="1270000"/></a:xfrm><a:prstGeom prst="rect"/></p:spPr><p:style><a:lnRef idx="1"><a:schemeClr val="accent1"/></a:lnRef><a:fillRef idx="1"><a:schemeClr val="accent1"/></a:fillRef><a:effectRef idx="0"><a:schemeClr val="accent1"/></a:effectRef><a:fontRef idx="minor"><a:schemeClr val="lt1"/></a:fontRef></p:style></p:sp>
  let slide = pptx_test_slide_prefix + shape + pptx_test_slide_suffix
  let root_rels =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="root" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/><Relationship Id="theme" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="ppt/theme/theme1.xml"/></Relationships>
  let result = convert(
    pptx_test_deck(slide, [
      ("_rels/.rels", root_rels),
      ("ppt/theme/theme1.xml", theme),
    ]),
  )
  let doc = @core.open_single(result.bdf)
  let body = pptx_body_layer(doc.manifest).object
  let resources = @core.decode_object_resources(doc.part(body))
  let commands = @render.compile_object(resources.object)
  let mut filled = false
  let mut stroked = false
  for command in commands {
    match command {
      @render.FillColor(0xcc0000ff) => filled = true
      @render.StrokeColor(0xcc0000ff) => stroked = true
      _ => ()
    }
  }
  assert_true(filled, msg="PPTX theme fill reference")
  assert_true(stroked, msg="PPTX theme line reference")
}

///|
/// The small upstream TrueType test face used by the font tests.
let pptx_test_font_base64 : String = "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" +
  "AAYABwAIAAljYWx0ADhjY21wAD5jdjAxAERsaWdhAF5sb2NsAGRyY2x0AGpzYWx0AHBzbWNwAHZz" +
  "czAxAHwAAAABAAUAAAABAAIABgABAAgAAAEA/////wAA//8AAgAAYQAAYgAAAAEABAAAAAEAAQAA" +
  "AAEABwAAAAEAAwAAAAEAAAAGAAEACQAAAQEACgAWAC4AQABWAG4AmACoALgA5AD4AAEAAAABAAgA" +
  "AQAGAAcAAQADAAIAAwAEAAEAAAABAAgAAgCgAAIABgAEAAIAAAABAAgAAQCWAAEACAACAAIAAwAD" +
  "AAAAAQAIAAEAlAABAAgAAwAJAAoACwAEAAAAAQAIAAEAHAABAAgAAgAGAA4ADQADAAcACAAMAAIA" +
  "CAABAAEABwAHAAAAAQAIAAEABgAAAGwABwAAAAEACAABAAEAAAB6AAgAAAABAAgAAQAQAAEAFgAB" +
  "AB4AAQAGAAEAAQAEAAEAAgACAAMAAQABAAUAAQAAAAEACAABAAYABwABAAEAAgABAAAAAQAIAAEA" +
  "BgAHAAEAAQADAAMAAAABABIAAQAYAAEAAAAGAAEAAQACAAEAAQADAAEABgAHAAEAAQAC"

///|
fn pptx_test_font() -> Bytes {
  @base64.decode(pptx_test_font_base64[:]) catch {
    _ => b""
  }
}

///|
fn pptx_test_font_deck(text : String) -> Bytes {
  let shape = StringBuilder()
  shape.write_string(
    (
      #|<p:sp><p:nvSpPr><p:cNvPr id="2" name="Text"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="914400" y="914400"/><a:ext cx="4572000" cy="914400"/></a:xfrm><a:prstGeom prst="rect"/></p:spPr><p:txBody><a:bodyPr/><a:p><a:r><a:rPr sz="2400" lang="en-US"><a:latin typeface="Features Test"/></a:rPr><a:t>
    ),
  )
  shape.write_string(text)
  shape.write_string(
    (
      #|</a:t></a:r></a:p></p:txBody></p:sp>
    ),
  )
  pptx_test_deck(
    pptx_test_slide_prefix + shape.to_string() + pptx_test_slide_suffix,
    [],
  )
}

///|
test "PPTX font directories measure glyphs and embed subsets" {
  let db = @fontdb.Database::new()
  assert_eq(db.add_file("features.ttf", pptx_test_font()), 1)
  let result = convert(pptx_test_font_deck("abcdefi z"), db=Some(db))
  assert_eq(result.summary, "1 slide(s), 1 embedded font(s)")
  assert_eq(result.warnings, [
    "no available font has glyphs for: z U+007A; viewers draw them with their own fonts",
  ])
  let doc = @core.open_single(result.bdf)
  let mut font_parts = 0
  for part in doc.manifest.parts {
    if part.kind == "font" {
      font_parts += 1
    }
  }
  assert_eq(font_parts, 1, msg="PPTX embedded font parts")
  let body = pptx_body_layer(doc.manifest).object
  let resources = @core.decode_object_resources(doc.part(body))
  let mut embedded = false
  for font in resources.fonts {
    if font.hash is Some(_) {
      embedded = true
    }
  }
  assert_true(embedded, msg="PPTX font record")
  let face = db.face(0).unwrap()
  let commands = @render.compile_object(resources.object)
  let mut advance = -1.0
  let mut drawn = ""
  for command in commands {
    match command {
      @render.FillText(text, _, _, width) =>
        if text.has_prefix("abcdefi") {
          advance = width
          drawn = text
        }
      _ => ()
    }
  }
  assert_true(drawn != "", msg="PPTX measured text")
  let mut expected = 0.0
  for character in drawn {
    let code = character.to_int()
    expected += (match face.font.glyph(code) {
        Some(glyph) => face.font.advance(glyph)
        None => if code == 0x20 { 0.25 } else { 0.55 }
      }) *
      24.0
  }
  assert_true(
    (advance - expected).abs() < 0.01,
    msg="PPTX font advance " + advance.to_string(),
  )
}

///|
test "PPTX without fonts keeps estimated metrics and warns" {
  let result = convert(pptx_test_font_deck("abcdefi"))
  assert_eq(result.summary, "1 slide(s), 0 embedded font(s)")
  assert_eq(result.warnings, [
    "no fonts found; text is laid out with estimated metrics and not embedded",
  ])
  let doc = @core.open_single(result.bdf)
  let mut font_parts = 0
  for part in doc.manifest.parts {
    if part.kind == "font" {
      font_parts += 1
    }
  }
  assert_eq(font_parts, 0)
  let body = pptx_body_layer(doc.manifest).object
  let resources = @core.decode_object_resources(doc.part(body))
  for font in resources.fonts {
    assert_true(font.hash is None)
  }
}
