///|
priv struct VisioPage {
  id : String
  name : String
  width : Double
  height : Double
  background : Bool
  back_page : String
  shapes : Array[VisioXmlNode]
  layers : Map[String, Bool]
}

///|
priv struct VisioDocument {
  pages : Array[VisioPage]
  backgrounds : Array[VisioPage]
  masters : Map[String, VisioXmlNode]
  title : String
  creator : String
  language : String
}

///|
fn visio_page_size(sheet : VisioXmlNode?) -> (Double, Double) {
  let cells = visio_cells(sheet)
  let width = visio_number(cells, "PageWidth", 8.5) * 72.0
  let height = visio_number(cells, "PageHeight", 11.0) * 72.0
  (width.max(1.0), height.max(1.0))
}

///|
fn visio_page_layers(sheet : VisioXmlNode?) -> Map[String, Bool] {
  let layers : Map[String, Bool] = Map([])
  for section in visio_children(sheet) {
    if section.element.name.local_name != "Section" ||
      visio_attr(Some(section), "N", "") != "Layer" {
      continue
    }
    for row in visio_children(Some(section)) {
      if row.element.name.local_name != "Row" {
        continue
      }
      let cells = visio_cells(Some(row))
      let index = visio_attr(Some(row), "IX", "0")
      layers[index] = visio_cell(cells, "Visible", "1") != "0"
    }
  }
  layers
}

///|
fn visio_page_shapes(root : VisioXmlNode) -> Array[VisioXmlNode] {
  let output : Array[VisioXmlNode] = []
  let shapes = visio_child(Some(root), "Shapes")
  for shape in visio_children(shapes) {
    if shape.element.name.local_name == "Shape" {
      output.push(shape)
    }
  }
  output
}

///|
fn visio_read_pages(
  package : @ooxml.OoxmlPackage,
) -> Array[VisioPage] raise VisioError {
  let root = visio_read_xml(package, "visio/pages/pages.xml")
  let relationships = package.relationships("visio/pages/pages.xml")
  let pages : Array[VisioPage] = []
  for node in root.children {
    if node.element.name.local_name != "Page" {
      continue
    }
    let id = visio_attr(Some(node), "ID", "")
    let sheet = visio_child(Some(node), "PageSheet")
    let (width, height) = visio_page_size(sheet)
    let rel_node = visio_child(Some(node), "Rel")
    let rel_id = visio_attr(rel_node, "id", visio_attr(rel_node, "r:id", ""))
    let mut shapes : Array[VisioXmlNode] = []
    for relationship in relationships {
      if relationship.id == rel_id {
        let part = relationship.target
        let part = if part.has_prefix("/") { part[1:].to_owned() } else { part }
        let page_root = try {
          visio_read_xml(package, part)
        } catch {
          _ => continue
        }
        shapes = visio_page_shapes(page_root)
      }
    }
    pages.push({
      id,
      name: visio_attr(Some(node), "Name", ""),
      width,
      height,
      background: visio_attr(Some(node), "Background", "0") != "0",
      back_page: visio_attr(Some(node), "BackPage", ""),
      shapes,
      layers: visio_page_layers(sheet),
    })
  }
  pages
}

///|
fn visio_read_masters(
  package : @ooxml.OoxmlPackage,
) -> Map[String, VisioXmlNode] {
  let masters : Map[String, VisioXmlNode] = Map([])
  let root = try {
    visio_read_xml(package, "visio/masters/masters.xml")
  } catch {
    _ => return masters
  }
  let relationships = package.relationships("visio/masters/masters.xml")
  for node in root.children {
    if node.element.name.local_name != "Master" {
      continue
    }
    let id = visio_attr(Some(node), "ID", "")
    let rel_node = visio_child(Some(node), "Rel")
    let rel_id = visio_attr(rel_node, "id", visio_attr(rel_node, "r:id", ""))
    for relationship in relationships {
      if relationship.id == rel_id {
        let part = if relationship.target.has_prefix("/") {
          relationship.target[1:].to_owned()
        } else {
          relationship.target
        }
        let root = try {
          visio_read_xml(package, part)
        } catch {
          _ => continue
        }
        let shapes = visio_page_shapes(root)
        if shapes.length() > 0 {
          masters[id] = shapes[0]
        }
      }
    }
  }
  masters
}

///|
fn visio_open(data : Bytes) -> VisioDocument raise VisioError {
  let package = @ooxml.open_ooxml(data) catch {
    @ooxml.InvalidOoxml(message) => raise VisioInvalid(message)
  }
  if !package.has("visio/pages/pages.xml") {
    raise VisioInvalid("Visio: the package has no pages")
  }
  let properties = package.core_properties()
  let pages = visio_read_pages(package)
  let foreground : Array[VisioPage] = []
  let backgrounds : Array[VisioPage] = []
  for page in pages {
    if page.background {
      backgrounds.push(page)
    } else {
      foreground.push(page)
    }
  }
  if foreground.is_empty() {
    raise VisioInvalid("Visio: the drawing has no foreground pages")
  }
  {
    pages: foreground,
    backgrounds,
    masters: visio_read_masters(package),
    title: if properties.title.is_empty() { "" } else { properties.title[0] },
    creator: if properties.creator.is_empty() { "" } else { properties.creator[0] },
    language: if properties.language.is_empty() { "" } else { properties.language[0] },
  }
}
