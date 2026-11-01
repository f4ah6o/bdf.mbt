///|
priv struct IdmlPage {
  self : String
  master : String
  width : Double
  height : Double
  transform : IdmlMatrix
}

///|
priv struct IdmlSpread {
  self : String
  pages : Array[IdmlPage]
  items : Array[IdmlXmlNode]
}

///|
priv struct IdmlDocument {
  spreads : Array[IdmlSpread]
  masters : Map[String, IdmlSpread]
  stories : Map[String, String]
  story_bodies : Map[String, @drawingml.TextBody]
  flow_lines : Map[String, Array[@drawingml.TextLine]]
  flow_overflow : Bool
  layers : Map[String, Bool]
  resources : IdmlResources
  title : String
  creator : String
  language : String
}

///|
fn idml_page(node : IdmlXmlNode) -> IdmlPage {
  let bounds = idml_numbers(idml_attr(Some(node), "GeometricBounds", "0 0 0 0"))
  let width = if bounds.length() >= 4 {
    (bounds[3] - bounds[1]).abs()
  } else {
    612.0
  }
  let height = if bounds.length() >= 4 {
    (bounds[2] - bounds[0]).abs()
  } else {
    792.0
  }
  {
    self: idml_attr(Some(node), "Self", ""),
    master: idml_attr(Some(node), "AppliedMaster", ""),
    width,
    height,
    transform: idml_matrix(idml_attr(Some(node), "ItemTransform", "")),
  }
}

///|
fn idml_collect_items(node : IdmlXmlNode, output : Array[IdmlXmlNode]) -> Unit {
  for child in node.children {
    let name = child.element.name.local_name
    if name == "Page" || name == "Properties" || name == "TextFramePreference" ||
      name == "StoryPreference" || name == "InCopyExportOption" {
      continue
    }
    if name == "Group" {
      output.push(child)
      // Groups are replayed recursively; their children stay inside.
    } else if name == "Spread" || name == "MasterSpread" {
      idml_collect_items(child, output)
    } else if name == "Rectangle" || name == "Oval" || name == "Polygon" ||
      name == "GraphicLine" || name == "TextFrame" || name == "Image" ||
      name == "PDF" || name == "EPS" || name == "PageItem" {
      output.push(child)
    }
  }
}

///|
fn idml_read_spread(root : IdmlXmlNode) -> IdmlSpread {
  let spread = match idml_child(Some(root), "Spread") {
    Some(value) => value
    None =>
      match idml_child(Some(root), "MasterSpread") {
        Some(value) => value
        None => root
      }
  }
  let pages : Array[IdmlPage] = []
  let items : Array[IdmlXmlNode] = []
  for child in spread.children {
    if child.element.name.local_name == "Page" {
      pages.push(idml_page(child))
    }
  }
  idml_collect_items(spread, items)
  {
    self: idml_attr(Some(spread), "Self", idml_attr(Some(root), "Self", "")),
    pages,
    items,
  }
}

///|
fn idml_story_text(node : IdmlXmlNode, output : StringBuilder) -> Unit {
  let name = node.element.name.local_name
  if name == "Content" {
    output.write_string(node.text.to_string())
    return
  }
  if name == "Br" {
    output.write_char('\n')
    return
  }
  if name == "Table" || name == "Cell" {
    return
  }
  for child in node.children {
    idml_story_text(child, output)
  }
}

///|
fn idml_story_body(story : IdmlXmlNode, fallback : String) -> @drawingml.TextBody {
  let paragraphs : Array[@drawingml.TextParagraph] = []
  for node in story.children {
    if node.element.name.local_name != "ParagraphStyleRange" {
      continue
    }
    let runs : Array[@drawingml.TextRun] = []
    for child in node.children {
      if child.element.name.local_name != "CharacterStyleRange" {
        continue
      }
      let size = @string.parse_double(
        idml_attr(Some(child), "PointSize", "12"),
      ) catch { _ => 12.0 }
      let style_name = idml_attr(Some(child), "AppliedCharacterStyle", "")
      let bold = style_name.to_lower().contains("bold")
      let style = @drawingml.TextStyle::new(
        family="Arial", size~, bold~, italic=false, color=0x000000ffU,
      )
      let run_text = StringBuilder()
      for content in child.children {
        let name = content.element.name.local_name
        if name == "Content" {
          run_text.write_string(idml_text(Some(content)))
        } else if name == "Br" {
          run_text.write_char('\n')
        }
      }
      if run_text.to_string() != "" {
        runs.push({ text: run_text.to_string(), style })
      }
    }
    if !runs.is_empty() {
      paragraphs.push({ runs, align: 0 })
    }
  }
  if paragraphs.is_empty() {
    let runs : Array[@drawingml.TextRun] = []
    if fallback != "" {
      runs.push({ text: fallback, style: @drawingml.TextStyle::new() })
    }
    paragraphs.push({ runs, align: 0 })
  }
  { paragraphs }
}

///|
fn idml_read_stories(
  package : @ooxml.OoxmlPackage,
  designmap : IdmlXmlNode,
) -> (Map[String, String], Map[String, @drawingml.TextBody]) {
  let stories : Map[String, String] = Map([])
  let bodies : Map[String, @drawingml.TextBody] = Map([])
  for node in designmap.children {
    let name = node.element.name.local_name
    if name != "Story" {
      continue
    }
    let src = idml_attr(Some(node), "src", "")
    if src == "" {
      continue
    }
    let root = try {
      idml_read_xml(package, src)
    } catch {
      _ => continue
    }
    let story = match idml_child(Some(root), "Story") {
      Some(value) => value
      None => root
    }
    let output = StringBuilder()
    idml_story_text(story, output)
    let self = idml_attr(Some(story), "Self", "")
    let text = output.to_string()
    stories[self] = text
    bodies[self] = idml_story_body(story, text)
  }
  (stories, bodies)
}

///|
fn idml_metadata_walk(node : IdmlXmlNode, fields : Map[String, String]) -> Unit {
  let name = node.element.name.local_name
  if (name == "title" || name == "creator" || name == "language") &&
    !fields.contains(name) {
    fields[name] = idml_text(Some(node))
  }
  for child in node.children {
    idml_metadata_walk(child, fields)
  }
}

///|
fn idml_metadata(package : @ooxml.OoxmlPackage) -> (String, String, String) {
  let root = try {
    idml_read_xml(package, "META-INF/metadata.xml")
  } catch {
    _ => return ("", "", "")
  }
  let fields : Map[String, String] = Map([])
  idml_metadata_walk(root, fields)
  (
    fields.get("title").unwrap_or(""),
    fields.get("creator").unwrap_or(""),
    fields.get("language").unwrap_or(""),
  )
}

///|
fn idml_open(data : Bytes) -> IdmlDocument raise IdmlError {
  let package = @ooxml.open_ooxml(data) catch {
    @ooxml.InvalidOoxml(message) => raise IdmlInvalid(message)
  }
  let mimetype = try {
    @utf8.decode_lossy(package.read("mimetype")[:], ignore_bom=true)
  } catch {
    _ => ""
  }
  if mimetype != "" && !mimetype.contains("adobe.indesign-idml-package") {
    raise IdmlInvalid("IDML: the package is not an InDesign document")
  }
  if !package.has("designmap.xml") {
    raise IdmlInvalid("IDML: the package has no design map")
  }
  let designmap = idml_read_xml(package, "designmap.xml")
  let layers : Map[String, Bool] = Map([])
  for node in designmap.children {
    if node.element.name.local_name == "Layer" {
      layers[idml_attr(Some(node), "Self", "")] =
        idml_attr(Some(node), "Visible", "true").to_lower() != "false"
    }
  }
  let masters : Map[String, IdmlSpread] = Map([])
  let spreads : Array[IdmlSpread] = []
  for node in designmap.children {
    let name = node.element.name.local_name
    let src = idml_attr(Some(node), "src", "")
    if src == "" || (name != "Spread" && name != "MasterSpread") {
      continue
    }
    let root = try {
      idml_read_xml(package, src)
    } catch {
      _ => continue
    }
    let spread = idml_read_spread(root)
    if name == "MasterSpread" {
      masters[spread.self] = spread
    } else {
      spreads.push(spread)
    }
  }
  let (title, creator, language) = idml_metadata(package)
  let (stories, story_bodies) = idml_read_stories(package, designmap)
  let document : IdmlDocument = {
    spreads,
    masters,
    stories,
    story_bodies,
    flow_lines: Map([]),
    flow_overflow: false,
    layers,
    resources: idml_read_resources(package),
    title,
    creator,
    language,
  }
  let (flow, overflow) = idml_flow_stories(document)
  { ..document, flow_lines: flow, flow_overflow: overflow, }
}
